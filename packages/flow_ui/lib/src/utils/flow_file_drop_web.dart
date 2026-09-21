import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'flow_attachment_intake.dart';
import 'flow_web_dom.dart' as dom;

/// A live drop registration; [dispose] unhooks it.
class FlowDropRegistration {
  FlowDropRegistration._(this._view, this._target);

  final _ViewDropListener _view;
  final _DropTarget _target;
  bool _disposed = false;

  /// Unhooks the registration. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _view._remove(_target);
  }
}

/// Hooks a rectangle of the given Flutter view up to the browser's file
/// drop.
///
/// The listeners go on the view's host element rather than on a platform
/// view laid over the widget, because a platform view cannot both pass
/// clicks through and receive drags: `HtmlElementView.hitTestBehavior`
/// defaults to opaque and would swallow every tap, and the CSS
/// `pointer-events: none` that fixes the browser's half of that also
/// stops `dragover` and `drop` from firing at all — one property gates
/// both. Listening at the host element sidesteps Flutter's hit-test tree
/// entirely; [bounds] then does the scoping in arithmetic, which is
/// exact: Flutter web's logical pixels are the host element's CSS pixels
/// with the origin at its top-left.
FlowDropRegistration? flowRegisterDropTarget({
  required int viewId,
  required Rect? Function() bounds,
  required bool Function() isEnabled,
  required void Function(bool hovering) onHover,
  required void Function(List<FlowFileCandidate> files) onDrop,
}) {
  final host = ui_web.views.getHostElement(viewId);
  if (host == null) return null;

  final view = _views.putIfAbsent(
    viewId,
    () => _ViewDropListener(viewId, host as dom.HTMLElement),
  );
  final target = _DropTarget(bounds, isEnabled, onHover, onDrop);
  view._add(target);
  return FlowDropRegistration._(view, target);
}

/// One listener set per Flutter view, shared by every target inside it
/// and torn down when the last one goes.
final Map<int, _ViewDropListener> _views = <int, _ViewDropListener>{};

/// Twice the 350ms the HTML drag-and-drop model runs its loop at.
const Duration _watchdogIdle = Duration(milliseconds: 700);

class _DropTarget {
  _DropTarget(this.bounds, this.isEnabled, this.onHover, this.onDrop);

  final Rect? Function() bounds;

  /// Read at event time, so a target switched off mid-drag shows the
  /// refusing cursor at once.
  final bool Function() isEnabled;
  final void Function(bool hovering) onHover;
  final void Function(List<FlowFileCandidate> files) onDrop;
}

class _ViewDropListener {
  _ViewDropListener(this.viewId, this.host) {
    _onEnter = _handleDragEnter.toJS;
    _onOver = _handleDragOver.toJS;
    _onLeave = _handleDragLeave.toJS;
    _onDrop = _handleDrop.toJS;
    host
      ..addEventListener('dragenter', _onEnter)
      ..addEventListener('dragover', _onOver)
      ..addEventListener('dragleave', _onLeave)
      ..addEventListener('drop', _onDrop);
  }

  final int viewId;
  final dom.HTMLElement host;
  final List<_DropTarget> _targets = <_DropTarget>[];

  late final dom.EventListener _onEnter;
  late final dom.EventListener _onOver;
  late final dom.EventListener _onLeave;
  late final dom.EventListener _onDrop;

  /// Balances `dragenter` against `dragleave`. Crossing from the view
  /// into one of its descendants fires a leave and an enter, so a plain
  /// boolean would flicker the treatment on every child boundary — and
  /// Flutter's own DOM is nothing but child boundaries.
  int _depth = 0;
  _DropTarget? _hovered;

  /// The last resort against a treatment stuck up because a `dragleave`
  /// never came — a drag cancelled with Escape, a browser that drops an
  /// event. The drag-and-drop model runs its loop every 350ms while the
  /// pointer is over the page, so silence for twice that means the drag
  /// is over however it ended.
  Timer? _watchdog;

  void _add(_DropTarget target) => _targets.add(target);

  void _remove(_DropTarget target) {
    if (identical(_hovered, target)) {
      _hovered = null;
      target.onHover(false);
    }
    _targets.remove(target);
    if (_targets.isNotEmpty) return;

    _watchdog?.cancel();
    _watchdog = null;
    host
      ..removeEventListener('dragenter', _onEnter)
      ..removeEventListener('dragover', _onOver)
      ..removeEventListener('dragleave', _onLeave)
      ..removeEventListener('drop', _onDrop);
    _views.remove(viewId);
  }

  void _handleDragEnter(dom.DragEvent event) {
    if (!_carriesFiles(event)) return;
    _depth++;
    _setHovered(_targetAt(event));
  }

  void _handleDragOver(dom.DragEvent event) {
    if (!_carriesFiles(event)) return;
    final target = _targetAt(event);
    _setHovered(target);
    if (target == null) return;
    // Only inside a registered rectangle: elsewhere on the page the
    // browser's own handling — which is to navigate to the file — stays
    // the correct behaviour, and defaulting it away everywhere would be
    // the package overreaching past its own widget.
    event.preventDefault();
    // A target that is off still claims the drop — the alternative is the
    // browser navigating to the file — but says so with the cursor.
    event.dataTransfer?.dropEffect = target.isEnabled() ? 'copy' : 'none';
  }

  void _handleDragLeave(dom.DragEvent event) {
    if (!_carriesFiles(event)) return;
    _depth--;
    if (_depth > 0) return;
    _depth = 0;
    _setHovered(null);
  }

  void _handleDrop(dom.DragEvent event) {
    if (!_carriesFiles(event)) return;
    final target = _targetAt(event);
    _depth = 0;
    _setHovered(null);
    if (target == null) return;
    event.preventDefault();
    final files = _candidates(event.dataTransfer);
    if (files.isNotEmpty) target.onDrop(files);
  }

  /// The innermost registered rectangle under the pointer that will take
  /// the drop, taken as the smallest enabled one containing it.
  ///
  /// Targets nest — a composer's own drop area sits inside the chat
  /// surface's — and the inner one has to win, the way hit testing
  /// works. Area decides rather than registration order, which would be
  /// the same thing only until a target re-registers and moves to the
  /// back of the list. Ties go to the later registration.
  ///
  /// A target that is off yields to an enabled one around it, so a card
  /// switched off does not shadow a surface that still takes drops. It
  /// is only the answer when nothing enabled contains the point — where
  /// claiming the drop, to be swallowed, still beats handing it to the
  /// browser.
  _DropTarget? _targetAt(dom.DragEvent event) {
    if (_targets.isEmpty) return null;
    final rect = host.getBoundingClientRect();
    final point = Offset(event.clientX - rect.left, event.clientY - rect.top);

    _DropTarget? bestEnabled;
    _DropTarget? bestAny;
    var enabledArea = double.infinity;
    var anyArea = double.infinity;
    for (final target in _targets) {
      final bounds = target.bounds();
      if (bounds == null || !bounds.contains(point)) continue;
      final area = bounds.width * bounds.height;
      if (area <= anyArea) {
        bestAny = target;
        anyArea = area;
      }
      if (target.isEnabled() && area <= enabledArea) {
        bestEnabled = target;
        enabledArea = area;
      }
    }
    return bestEnabled ?? bestAny;
  }

  void _setHovered(_DropTarget? target) {
    if (target == null) {
      _watchdog?.cancel();
      _watchdog = null;
    } else {
      _watchdog?.cancel();
      _watchdog = Timer(_watchdogIdle, _giveUp);
    }
    if (identical(_hovered, target)) return;
    _hovered?.onHover(false);
    _hovered = target;
    target?.onHover(true);
  }

  void _giveUp() {
    _watchdog = null;
    _depth = 0;
    _setHovered(null);
  }
}

/// Whether the drag carries files at all. Dragging a text selection or a
/// link across the page must not raise the drop treatment, and during a
/// drag the browser exposes only the *types* on offer, never the data.
bool _carriesFiles(dom.DragEvent event) {
  final transfer = event.dataTransfer;
  if (transfer == null) return false;
  for (final type in transfer.types.toDart) {
    if (type.toDart == 'Files') return true;
  }
  return false;
}

List<FlowFileCandidate> _candidates(dom.DataTransfer? transfer) {
  final files = transfer?.files;
  if (files == null) return const <FlowFileCandidate>[];

  final candidates = <FlowFileCandidate>[];
  for (var i = 0; i < files.length; i++) {
    final file = files.item(i);
    if (file == null) continue;
    // The File handles outlive the event that carried them, unlike the
    // DataTransfer itself, so reading can wait until the intake asks.
    final type = file.type;
    candidates.add(
      FlowFileCandidate(
        name: file.name,
        size: file.size,
        mimeType: type.isEmpty ? null : type,
        read: () => _readBytes(file),
      ),
    );
  }
  return candidates;
}

Future<Uint8List> _readBytes(dom.File file) async {
  final buffer = await file.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}
