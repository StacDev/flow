import 'package:flutter/widgets.dart';

import '../models/flow_attachment.dart';
import '../models/flow_attachment_options.dart';
import '../utils/flow_attachment_intake.dart';
import '../utils/flow_file_drop.dart';

/// Turns the area its [child] occupies into a file drop target, decoding
/// what lands there into attachments.
///
/// ```dart
/// FlowDropTarget(
///   onDropped: (dropped) => setState(() => _pending.addAll(dropped)),
///   onHoverChanged: (hovering) => setState(() => _dragging = hovering),
///   child: surface,
/// )
/// ```
///
/// **The web only.** The Flutter SDK has no OS file-drop support in the
/// framework or the engine on any other target, so on desktop, iOS and
/// Android this widget is its child and nothing more: [onDropped] never
/// fires and [onHoverChanged] never reports true. Nothing throws and
/// nothing needs to be guarded — but a desktop host that wants drop has
/// to bring its own detection and drive `FlowChatView.dropActive`, which
/// stays writable for exactly that. In debug builds the widget prints
/// this once if it is given an [onDropped] it can never call.
///
/// The hovering report is separate from the dropping one so the two can
/// be wired independently: `FlowChatView` raises its own treatment from
/// the first and appends attachments from the second.
class FlowDropTarget extends StatefulWidget {
  const FlowDropTarget({
    super.key,
    required this.child,
    this.onDropped,
    this.onHoverChanged,
    this.enabled = true,
    this.attachmentOptions = const FlowAttachmentOptions(),
    this.onAttachmentRejected,
  });

  /// The subtree, and the rectangle files can be dropped onto.
  final Widget child;

  /// Dropped files, decoded. Null leaves the drop to the browser, which
  /// is what makes the detection opt-in.
  final ValueChanged<List<FlowAttachment>>? onDropped;

  /// Whether a file drag is currently over the child. Raise the drop
  /// treatment from this.
  final ValueChanged<bool>? onHoverChanged;

  /// Whether drops are taken right now. [onDropped] says the target is
  /// wired; this says it is on.
  ///
  /// False keeps the target *registered* and yields to any enabled target
  /// around it — a composer switched off inside a chat view that still
  /// takes drops hands them up to the view. Where nothing enabled
  /// contains the point, the browser is still told the rectangle is a
  /// drop zone, shows its refusing cursor, and what lands is swallowed:
  /// no treatment, nothing delivered. Unregistering instead would hand
  /// the drop back to the browser, whose default for a file is to
  /// navigate the tab to it, which is not what "off" means to someone
  /// who has just dropped a photo on a chat.
  final bool enabled;

  /// What is accepted, and how what lands is decoded. A dropped file
  /// never passed through a dialog's filter, so
  /// [FlowAttachmentOptions.accept] is enforced here rather than merely
  /// suggested.
  final FlowAttachmentOptions attachmentOptions;

  /// A dropped file that [attachmentOptions] refused, reported with its
  /// name so the host can say so in its own words.
  final void Function(String name, FlowAttachmentRejection reason)?
  onAttachmentRejected;

  @override
  State<FlowDropTarget> createState() => _FlowDropTargetState();
}

/// One warning per process, not one per widget: a thread of them would
/// bury whatever the developer was actually reading.
bool _warnedUnsupported = false;

class _FlowDropTargetState extends State<FlowDropTarget> {
  FlowDropRegistration? _registration;
  int? _viewId;

  /// Unhooking while hovering hands back a final `false`, which is worth
  /// hearing when the callback merely went null — and fatal on the way
  /// out, where the host's listener would `setState` on an element the
  /// framework is already unmounting.
  bool _disposed = false;

  /// What the listener last said, kept even while [FlowDropTarget.enabled]
  /// is false so a switch flipped mid-drag can report the right thing.
  bool _hovering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewId = View.of(context).viewId;
    if (viewId == _viewId) return;
    _viewId = viewId;
    _register();
  }

  @override
  void didUpdateWidget(FlowDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.onDropped == null) != (oldWidget.onDropped == null)) {
      _register();
    }
    // Flipping the switch mid-drag: the treatment comes down at once
    // when it goes off, and back up — if a drag is still over us — when
    // it comes on. The listener only reports transitions, so it would
    // not repeat the hover on its own.
    if (widget.enabled != oldWidget.enabled && _hovering) {
      widget.onHoverChanged?.call(widget.enabled);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _registration?.dispose();
    _registration = null;
    super.dispose();
  }

  void _register() {
    _registration?.dispose();
    _registration = null;

    final viewId = _viewId;
    if (viewId == null || widget.onDropped == null) return;

    _registration = flowRegisterDropTarget(
      viewId: viewId,
      bounds: _bounds,
      isEnabled: () => widget.enabled,
      onHover: _handleHover,
      onDrop: _handleDrop,
    );

    assert(() {
      if (_registration == null && !_warnedUnsupported) {
        _warnedUnsupported = true;
        debugPrint(
          'FlowDropTarget was given an onDropped callback on a platform '
          'with no file drop. The Flutter SDK implements OS file drop on '
          'the web only, so this callback will never fire here. Drive '
          'FlowChatView.dropActive from your own drop detection instead.',
        );
      }
      return true;
    }());
  }

  /// The child's rectangle in the view's coordinate space — the same
  /// space the drop listener converts pointer positions into. Null while
  /// unlaid-out, which reads as "not a target yet".
  Rect? _bounds() {
    if (!mounted) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _handleHover(bool hovering) {
    if (_disposed || !mounted) return;
    _hovering = hovering;
    if (!widget.enabled) return;
    widget.onHoverChanged?.call(hovering);
  }

  Future<void> _handleDrop(List<FlowFileCandidate> files) async {
    // Swallowed, not delivered: the listener has already kept the
    // browser from navigating, which is the point of staying registered.
    if (!widget.enabled) return;
    final attachments = await flowIntakeAttachments(
      files,
      options: widget.attachmentOptions,
      onRejected: widget.onAttachmentRejected,
    );
    if (!mounted || attachments.isEmpty) return;
    widget.onDropped?.call(attachments);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
