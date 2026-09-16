import 'package:material_ui/material_ui.dart';

import '../styles/flow_toast_style.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_circle_button.dart';

/// The floating notice: a glyph, one line that wraps, and a cross on the
/// raised card — "Message copied to clipboard", "Image upload failed".
///
/// ```dart
/// FlowToast(
///   icon: Icons.copy_outlined,
///   message: 'Message copied to clipboard',
///   dismissTooltip: 'Dismiss',
///   onDismiss: hide,
/// )
/// ```
///
/// This is the card alone. It renders state and reports one intent,
/// dismiss; where it floats, how long it stays and what happens when
/// three arrive at once is a lifecycle, and `showFlowToast` owns it — one
/// call floats the card in the nearest `Overlay` and hands back a handle.
/// Build the card directly to own that lifecycle yourself: in a stack of
/// the host's own, an `AnimatedSwitcher`, an `Overlay` it scopes.
///
/// The glyph is the host's, and carries the meaning — a copy icon for the
/// clipboard, a warning circle for a failed upload — recolored through
/// [FlowToastStyle.iconColor]. The line stays in the ink ramp whatever the
/// glyph says: the light accents fall short of WCAG AA for text on the
/// card, the confirmation card's rule. The package ships no strings:
/// [message] and [dismissTooltip] are host-localized.
class FlowToast extends StatelessWidget {
  const FlowToast({
    super.key,
    required this.message,
    this.icon,
    this.onDismiss,
    this.dismissTooltip,
    this.padding,
    this.borderRadius,
    this.style,
  });

  /// The notice, host-written and sentence-case; wraps when long.
  /// Announced to assistive tech as a live region, since notices arrive
  /// unprompted.
  final String message;

  /// The leading glyph. Null draws none, and the line starts at the
  /// card's edge.
  final IconData? icon;

  /// Dismiss intent. Null draws no cross.
  final VoidCallback? onDismiss;

  /// Host-localized label for the cross, e.g. 'Dismiss'; also its
  /// accessible name.
  final String? dismissTooltip;

  /// Inside the card. Defaults to the design's 16 at the start, 12
  /// elsewhere.
  final EdgeInsetsGeometry? padding;

  /// The card's corner. Defaults to the design's 12.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.toastStyle]'s fields;
  /// nulls fall through to the theme tokens.
  final FlowToastStyle? style;

  /// The card: the raised surface at 80%, so the page reads through it,
  /// under the firm hairline on a 12px corner, with the composer's error
  /// tab's lift — the theme's shadow at a 24 blur. Padded 16 at the start
  /// and 12 elsewhere, 10 between glyph, line and cross. The frost the
  /// design draws beneath belongs to whoever floats the card (see
  /// `showFlowToast`): a blur inside the card would sit inside its fade,
  /// and a BackdropFilter under an Opacity samples the fade's own layer,
  /// not the page.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(12));
  static const EdgeInsetsGeometry _cardPadding = EdgeInsetsDirectional.fromSTEB(
    16,
    12,
    12,
    12,
  );
  static const double _fillOpacity = 0.8;
  static const double _shadowBlur = 24;

  /// The glyph, the design's 18, centred on the line's first row; the
  /// cross is the composer banner's — a 16 glyph on a 4 pad, a 24 disc
  /// centred on the same row.
  static const double _iconSize = 18;
  static const double _gap = 10;
  static const double _dismissIconSize = 16;
  static const double _dismissPadding = 4;
  static const double _dismissDisc = _dismissIconSize + _dismissPadding * 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;
    final icon = this.icon;
    final onDismiss = this.onDismiss;

    final effective = context.flowTheme.toastStyle?.merge(style) ?? style;

    final lineStyle = typography.labelMediumEmphasised
        .copyWith(color: colors.onSurface)
        .merge(effective?.messageStyle);

    // The glyph and the cross centre on the line's *first* row — a box
    // the row's own height keeps them optically centred beside a one-line
    // notice and on the opening line of a wrapping one alike.
    final firstLineHeight =
        (lineStyle.fontSize ?? _iconSize) * (lineStyle.height ?? 1);

    final line = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          SizedBox(
            height: firstLineHeight,
            child: Center(
              child: ExcludeSemantics(
                child: Icon(
                  icon,
                  size: _iconSize,
                  color: effective?.iconColor ?? colors.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: _gap),
        ],
        // Notices arrive unprompted: announce the line.
        Flexible(
          child: Semantics(
            liveRegion: true,
            child: Text(message, style: lineStyle),
          ),
        ),
      ],
    );

    // The cross pins to the end edge from outside the row, so the padding
    // is split by hand — start on the line, end after the disc — kept
    // directional so RTL swaps them, the pill's idiom.
    final direction = Directionality.of(context);
    final resolved = (padding ?? _cardPadding).resolve(direction);
    final startInset = direction == TextDirection.ltr
        ? resolved.left
        : resolved.right;
    final endInset = direction == TextDirection.ltr
        ? resolved.right
        : resolved.left;

    final Widget content;
    if (onDismiss == null) {
      content = Padding(padding: resolved, child: line);
    } else {
      // The disc is taller than the row it centres on, so it sits outside
      // the row: the line reserves its width, and the disc is pinned from
      // the end edge, lifted half the difference above the row's top. The
      // card keeps the design's height for one line and for three, and
      // the whole disc stays inside it, so all of it takes a tap.
      content = Stack(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: startInset,
              end: endInset + _dismissDisc + _gap,
              top: resolved.top,
              bottom: resolved.bottom,
            ),
            child: line,
          ),
          PositionedDirectional(
            end: endInset,
            top: resolved.top - (_dismissDisc - firstLineHeight) / 2,
            child: FlowCircleButton(
              icon: Icons.close,
              background: const Color(0x00000000),
              foreground:
                  effective?.dismissIconColor ?? colors.onSurfaceVariant,
              hoverColor: colors.surfaceContainer,
              iconSize: _dismissIconSize,
              padding: _dismissPadding,
              tooltip: dismissTooltip,
              onTap: onDismiss,
            ),
          ),
        ],
      );
    }

    // A Container rather than a DecoratedBox: it insets the content by the
    // hairline, so the padding measures from inside the stroke as on the
    // other cards.
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color:
              effective?.backgroundColor ??
              colors.surfaceBright.withValues(alpha: _fillOpacity),
          borderRadius: borderRadius ?? _radius,
          border: Border.all(
            color: effective?.borderColor ?? colors.outlineVariant,
          ),
          boxShadow: [BoxShadow(color: colors.shadow, blurRadius: _shadowBlur)],
        ),
        child: content,
      ),
    );
  }
}
