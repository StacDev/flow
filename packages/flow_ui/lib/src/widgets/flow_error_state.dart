import 'package:material_ui/material_ui.dart';

import '../styles/flow_error_state_style.dart';
import '../theme/flow_theme.dart';
import '../theme/flow_typography.dart';
import '../utils/flow_selection.dart';

/// A failure surface: an error glyph and a host-written explanation on a
/// hairline card, with an optional retry pill.
///
/// ```dart
/// FlowErrorState(
///   title: 'Connection error',
///   message: 'The API is overloaded right now. Retry in a moment.',
///   retryLabel: 'Retry',
///   onRetry: resend,
/// )
/// ```
///
/// In a thread this renders on its own: a `FlowErrorPart` in any turn
/// becomes this card, and a failed assistant turn closes with a default
/// one even when the host supplies no part. Standalone it serves the
/// other failure surfaces — a thread that failed to load, a connection
/// notice pinned in `FlowChatView.aboveComposer`, a failed send below
/// the composer.
///
/// Retry reports intent; what it means — re-run the turn, refetch,
/// reconnect — is the host's business. The affordance is a visible pill
/// rather than a hover-revealed action, because hover does not exist on
/// touch. The package ships no strings: [title], [message] and
/// [retryLabel] are host-localized, and [retryLabel] doubles as the
/// pill's accessible name.
class FlowErrorState extends StatelessWidget {
  const FlowErrorState({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.padding,
    this.borderRadius,
    this.style,
  });

  /// Host-localized headline, e.g. 'Connection error'. Null lets
  /// [message] take the glyph row; without a [message] the title itself
  /// announces as the live region.
  final String? title;

  /// The failure, host-written and sentence-case. Announced to assistive
  /// tech as a live region, since failures arrive unprompted.
  final String? message;

  /// Retry intent. Null hides the pill.
  final VoidCallback? onRetry;

  /// Host-localized pill label and accessible name; null renders the
  /// glyph alone.
  final String? retryLabel;

  /// Inside the card. Defaults to the design's 16/14.
  final EdgeInsetsGeometry? padding;

  /// The card's corner. Defaults to the design's 12.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.errorStateStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowErrorStateStyle? style;

  /// The card: the bubble's 12px corner on the resting container fill,
  /// edged in `error` at 40% — translucent, so it composites on the page
  /// and on a raised card alike.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(12));
  static const EdgeInsetsGeometry _cardPadding = EdgeInsets.fromLTRB(
    16,
    14,
    16,
    14,
  );
  static const double _borderOpacity = 0.4;

  /// The glyph, sized to the title's line so the pair reads as one row;
  /// the message and the pill align to the card's edge below, not to the
  /// text's indent.
  static const double _iconSize = 16;
  static const double _iconGap = 6;

  /// Gaps: glyph row to message, content to the retry pill.
  static const double _messageGap = 8;
  static const double _retryGap = 12;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;

    final title = this.title;
    final message = this.message;
    final onRetry = this.onRetry;

    // The title takes the glyph row when present and the message hangs
    // below; without one the message moves up beside the glyph.
    final rowText = title ?? message;
    final below = title == null ? null : message;

    final effective = context.flowTheme.errorStateStyle?.merge(style) ?? style;

    final rowStyle = title != null
        ? typography.bodyMediumEmphasised
              .copyWith(color: colors.onSurface)
              .merge(effective?.titleStyle)
        : typography.bodyMedium
              .copyWith(color: colors.onSurfaceVariant)
              .merge(effective?.messageStyle);

    Widget? rowLabel;
    if (rowText != null) {
      rowLabel = FlowSelectionBlock(child: Text(rowText, style: rowStyle));
      if (below == null) {
        // The row text is all the card says — a lone title as much as a
        // lone message — and failures arrive unprompted: announce it.
        rowLabel = Semantics(liveRegion: true, child: rowLabel);
      }
    }

    // The glyph centres on the text's *first line* — a box the line's own
    // height keeps it optically centred beside a one-line title and on
    // the opening line of a wrapping message alike.
    final firstLineHeight =
        (rowStyle.fontSize ?? _iconSize) * (rowStyle.height ?? 1);

    return Container(
      padding: padding ?? _cardPadding,
      decoration: BoxDecoration(
        color: effective?.backgroundColor ?? colors.surfaceContainerLowest,
        borderRadius: borderRadius ?? _radius,
        border: Border.all(
          color:
              effective?.borderColor ??
              colors.error.withValues(alpha: _borderOpacity),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: firstLineHeight,
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    size: _iconSize,
                    color: effective?.glyphColor ?? colors.error,
                  ),
                ),
              ),
              if (rowLabel != null) ...[
                const SizedBox(width: _iconGap),
                Flexible(child: rowLabel),
              ],
            ],
          ),
          if (below != null)
            Padding(
              padding: const EdgeInsets.only(top: _messageGap),
              child: Semantics(
                liveRegion: true,
                child: FlowSelectionBlock(
                  child: Text(
                    below,
                    style: typography.bodyMedium
                        .copyWith(color: colors.onSurfaceVariant)
                        .merge(effective?.messageStyle),
                  ),
                ),
              ),
            ),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: _retryGap),
              child: _RetryButton(onTap: onRetry, label: retryLabel),
            ),
        ],
      ),
    );
  }
}

/// The retry pill: a hairline border with no fill, the refresh glyph and
/// a semibold label — the failure surfaces' shared affordance, private
/// until the design system's Button lands and absorbs it.
class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.onTap, this.label});

  final VoidCallback onTap;
  final String? label;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  /// The design's pill: 32 tall on an 8px corner, padded 12, a 14px
  /// glyph a 6px gap from the label.
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

    // Rest at the secondary ink, lifting to full on hover — the
    // suggestion row's ladder on a control-sized frame.
    final foreground = _hovered ? colors.onSurface : colors.onSurfaceVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: _radius,
      side: BorderSide(color: colors.outlineVariant),
    );

    final label = widget.label;
    final button = Material(
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
                Icon(Icons.refresh, size: _glyphSize, color: foreground),
                if (label != null) ...[
                  const SizedBox(width: _glyphGap),
                  // A button's label is chrome, not content: never part
                  // of a selection sweeping the card.
                  SelectionContainer.disabled(
                    child: Text(
                      label,
                      style: FlowTypography.recut(
                        typography.labelMedium,
                        fontWeight: FontWeight.w600,
                      ).copyWith(color: foreground),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Excluding the subtree keeps the label from reading twice, but it
    // drops the InkWell's tap action with it — the node re-owns
    // activation or assistive tech can announce the pill yet not tap it.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: label != null,
      onTap: label == null ? null : widget.onTap,
      child: button,
    );
  }
}
