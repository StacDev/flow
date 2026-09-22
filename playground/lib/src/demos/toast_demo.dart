import 'dart:async';

import 'package:flow_ui/flow_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

String toastSnippet([String? variant]) => switch (variant) {
  'error' => _errorSnip,
  'sticky' => _stickySnip,
  'stacked' => _stackedSnip,
  'card' => _cardSnip,
  _ => _defaultSnip,
};

const String _defaultSnip = '''
// One call floats the card in the nearest Overlay — no host widget to
// wire — and it leaves on its own after four seconds, or from its cross.
showFlowToast(
  context: context,
  icon: PhosphorIconsRegular.copySimple,
  message: 'Message copied to clipboard',
  dismissTooltip: 'Dismiss',
)''';

const String _errorSnip = '''
// The glyph carries the meaning: a failure is the warning circle in the
// error accent. The line stays in the ink ramp.
showFlowToast(
  context: context,
  icon: PhosphorIconsRegular.warningCircle,
  message: 'Image upload failed. Try again',
  dismissTooltip: 'Dismiss',
  style: FlowToastStyle(iconColor: context.flowColors.error),
)''';

const String _stickySnip = '''
// A null duration keeps the toast up until it is dismissed — the handle
// is how the host takes it down once the work is done.
final handle = showFlowToast(
  context: context,
  icon: PhosphorIconsRegular.uploadSimple,
  message: 'Uploading 3 files…',
  duration: null,
  dismissTooltip: 'Dismiss',
);
await upload(files);
handle.dismiss();
showFlowToast(
  context: context,
  icon: PhosphorIconsRegular.checkCircle,
  message: '3 files uploaded',
  dismissTooltip: 'Dismiss',
  style: FlowToastStyle(iconColor: context.flowColors.success),
)''';

const String _stackedSnip = '''
// Toasts stack as a deck: the newest in front, the rest peeking out
// behind it, three at most. Hovering fans the deck out and pauses
// every clock.
for (final notice in notices) {
  showFlowToast(
    context: context,
    icon: notice.icon,
    message: notice.message,
    dismissTooltip: 'Dismiss',
  );
}''';

const String _cardSnip = '''
// The card alone: state in, one intent out — for a host that owns the
// lifecycle (its own stack, its own clock) instead of showFlowToast.
FlowToast(
  icon: PhosphorIconsRegular.copySimple,
  message: 'Message copied to clipboard',
  dismissTooltip: 'Dismiss',
  onDismiss: hide,
)

FlowToast(
  icon: PhosphorIconsRegular.warningCircle,
  message: 'Image upload failed. Try again',
  dismissTooltip: 'Dismiss',
  onDismiss: hide,
  style: FlowToastStyle(iconColor: context.flowColors.error),
)''';

/// Stage demo for `FlowToast` — a surface with an Overlay of its own that
/// `showFlowToast` floats into: the neutral and failure notices, a sticky
/// one that settles when its work finishes, the stack and its eviction,
/// and the card on its own.
class ToastDemo extends StatefulWidget {
  const ToastDemo({super.key, this.variant});

  final String? variant;

  @override
  State<ToastDemo> createState() => _ToastDemoState();
}

class _ToastDemoState extends State<ToastDemo> {
  /// The card variant's width: the design's, so the cards read as drawn.
  static const double _cardWidth = 358;
  static const double _cardGap = 12;

  /// The sticky variant's pretend upload, and how long a dismissed card
  /// stays away before the card variant puts it back.
  static const Duration _uploadTime = Duration(seconds: 3);
  static const Duration _cardReturn = Duration(milliseconds: 1500);

  /// The stacked variant's notices, three per tap, round and round.
  static const List<(IconData, String)> _notices = [
    (PhosphorIconsRegular.copySimple, 'Message copied to clipboard'),
    (PhosphorIconsRegular.link, 'Link copied'),
    (PhosphorIconsRegular.floppyDisk, 'Draft saved'),
    (PhosphorIconsRegular.warningCircle, 'Image upload failed. Try again'),
    (PhosphorIconsRegular.checkCircle, '3 files uploaded'),
    (PhosphorIconsRegular.bellSimple, 'Notifications are on'),
  ];
  int _next = 0;

  Timer? _upload;

  /// Card variant: which cards are dismissed, and the clocks that bring
  /// them back so the stage is never left empty.
  final Set<int> _hidden = {};
  final Map<int, Timer> _returns = {};

  @override
  void dispose() {
    _upload?.cancel();
    for (final timer in _returns.values) {
      timer.cancel();
    }
    super.dispose();
  }

  /// [context] must sit inside the demo's Overlay — the Builder's below,
  /// not this state's, which would resolve to the playground's own.
  void _show(BuildContext context) {
    final colors = context.flowColors;
    switch (widget.variant) {
      case 'error':
        showFlowToast(
          context: context,
          icon: PhosphorIconsRegular.warningCircle,
          message: 'Image upload failed. Try again',
          dismissTooltip: 'Dismiss',
          style: FlowToastStyle(iconColor: colors.error),
        );
      case 'sticky':
        // Up until the work is done, the way a host would hold it; the
        // outcome takes its place.
        final handle = showFlowToast(
          context: context,
          icon: PhosphorIconsRegular.uploadSimple,
          message: 'Uploading 3 files…',
          duration: null,
          dismissTooltip: 'Dismiss',
        );
        _upload?.cancel();
        _upload = Timer(_uploadTime, () {
          _upload = null;
          if (!mounted || !context.mounted) return;
          handle.dismiss();
          showFlowToast(
            context: context,
            icon: PhosphorIconsRegular.checkCircle,
            message: '3 files uploaded',
            dismissTooltip: 'Dismiss',
            style: FlowToastStyle(iconColor: colors.success),
          );
        });
      case 'stacked':
        // Three at a time: the first tap fills the stack, the next one
        // pushes it through.
        for (var i = 0; i < 3; i++) {
          final (icon, message) = _notices[_next % _notices.length];
          _next++;
          showFlowToast(
            context: context,
            icon: icon,
            message: message,
            dismissTooltip: 'Dismiss',
            style: switch (icon) {
              PhosphorIconsRegular.warningCircle => FlowToastStyle(
                iconColor: colors.error,
              ),
              PhosphorIconsRegular.checkCircle => FlowToastStyle(
                iconColor: colors.success,
              ),
              _ => null,
            },
          );
        }
      default:
        showFlowToast(
          context: context,
          icon: PhosphorIconsRegular.copySimple,
          message: 'Message copied to clipboard',
          dismissTooltip: 'Dismiss',
        );
    }
  }

  void _hideCard(int index) {
    setState(() => _hidden.add(index));
    _returns[index]?.cancel();
    _returns[index] = Timer(_cardReturn, () {
      _returns.remove(index);
      if (mounted) setState(() => _hidden.remove(index));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == 'card') return _cards(context);

    final (icon, label) = switch (widget.variant) {
      'error' => (PhosphorIconsRegular.warningCircle, 'Fail an upload'),
      'sticky' => (PhosphorIconsRegular.uploadSimple, 'Upload 3 files'),
      'stacked' => (PhosphorIconsRegular.stack, 'Show three'),
      _ => (PhosphorIconsRegular.copySimple, 'Copy a message'),
    };

    // The live variants take the whole stage, so the toast floats where it
    // would on a real surface — the pane's top end corner on the web
    // canvas, the top of the screen in the phone, the iframe in the docs —
    // inside an Overlay of the demo's own: showFlowToast floats in the
    // nearest one, so the toasts land here rather than over the
    // playground's chrome.
    return Overlay.wrap(
      child: Center(
        child: Builder(
          builder: (context) => _TriggerPill(
            icon: icon,
            label: label,
            onTap: () => _show(context),
          ),
        ),
      ),
    );
  }

  /// The card on its own, in both drawn forms. Its cross reports intent
  /// and the demo hides the card, then brings it back a moment later.
  Widget _cards(BuildContext context) {
    final colors = context.flowColors;
    final cards = [
      FlowToast(
        icon: PhosphorIconsRegular.copySimple,
        message: 'Message copied to clipboard',
        dismissTooltip: 'Dismiss',
        onDismiss: () => _hideCard(0),
      ),
      FlowToast(
        icon: PhosphorIconsRegular.warningCircle,
        message: 'Image upload failed. Try again',
        dismissTooltip: 'Dismiss',
        onDismiss: () => _hideCard(1),
        style: FlowToastStyle(iconColor: colors.error),
      ),
    ];

    return Center(
      child: SizedBox(
        width: _cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, card) in cards.indexed) ...[
              if (i > 0) const SizedBox(height: _cardGap),
              if (_hidden.contains(i))
                // Hold the card's footprint so the other one stays put.
                const SizedBox(height: 46)
              else
                card,
            ],
          ],
        ),
      ),
    );
  }
}

/// The stage's trigger: the retry pill's frame — 32 tall on an 8px
/// corner, the firm hairline, the ink lifting on hover — private to the
/// demo until the design system's Button lands.
class _TriggerPill extends StatefulWidget {
  const _TriggerPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_TriggerPill> createState() => _TriggerPillState();
}

class _TriggerPillState extends State<_TriggerPill> {
  static const double _height = 32;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));
  static const EdgeInsetsGeometry _padding = EdgeInsets.symmetric(
    horizontal: 12,
  );
  static const double _glyphSize = 14;
  static const double _glyphGap = 6;

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;

    final foreground = _hovered ? colors.onSurface : colors.onSurfaceVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: _radius,
      side: BorderSide(color: colors.outlineVariant),
    );

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          customBorder: shape,
          hoverColor: colors.surfaceContainerLow,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: _padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: _glyphSize, color: foreground),
                  const SizedBox(width: _glyphGap),
                  Text(
                    widget.label,
                    style: typography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
