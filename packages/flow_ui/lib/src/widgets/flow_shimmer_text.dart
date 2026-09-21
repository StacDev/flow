import 'package:material_ui/material_ui.dart';

import '../theme/flow_theme.dart';
import '../utils/flow_shimmer_sweep.dart';

/// Text with a soft highlight sweeping through it — the waiting treatment
/// for a label whose work is still in flight, e.g. a thinking line or a
/// tool call in progress.
///
/// ```dart
/// FlowShimmerText(text: 'Searching the web…')
/// ```
///
/// The glyphs rest in [baseColor] while a band of [highlightColor] slides
/// across; with [enabled] false — or reduced motion on — the text renders
/// statically in the base ink, so the same widget can stay in place once
/// the work settles.
///
/// Never part of a selection around it: a waiting line is status, not
/// content.
class FlowShimmerText extends StatelessWidget {
  const FlowShimmerText({
    super.key,
    required this.text,
    this.enabled = true,
    this.style,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 2400),
    this.textAlign,
  });

  /// The text to draw.
  final String text;

  /// Whether the highlight sweeps. False renders plain static text.
  final bool enabled;

  /// Merged over the default `bodyLarge` + [baseColor] style. Its color,
  /// if set, only shows while static — which includes reduced motion —
  /// since the sweep draws with [baseColor] and [highlightColor].
  final TextStyle? style;

  /// Resting ink. Defaults to `onSurfaceMuted`.
  final Color? baseColor;

  /// The sweeping band. Defaults to `onSurface`.
  final Color? highlightColor;

  /// One full sweep across the text.
  final Duration duration;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final resolvedBase = baseColor ?? colors.onSurfaceMuted;
    final baseStyle = context.flowTypography.bodyLarge.copyWith(
      color: resolvedBase,
    );
    final resolvedStyle = style == null ? baseStyle : baseStyle.merge(style);

    // Reduced motion settles here rather than inside the sweep. The
    // sweep's static branch recolours whatever child it was handed, which
    // is right for a shape but wrong for a label: it would discard a
    // caller's [style] colour, and cost a saveLayer, for the readers
    // least able to spare either.
    // Status, not content: the line stays out of any selection around it
    // — and the sweep's mask would tint a highlight painted under the
    // glyphs, so the static form opts out too, for one behaviour.
    if (!enabled || MediaQuery.disableAnimationsOf(context)) {
      return SelectionContainer.disabled(
        child: Text(text, style: resolvedStyle, textAlign: textAlign),
      );
    }

    // The sweep masks the glyphs, so they paint opaque: a translucent ink
    // there would dim the whole line a second time on top of the mask's
    // own alpha.
    return SelectionContainer.disabled(
      child: FlowShimmerSweep(
        baseColor: resolvedBase,
        highlightColor: highlightColor ?? colors.onSurface,
        duration: duration,
        child: Text(
          text,
          style: resolvedStyle.copyWith(color: const Color(0xFFFFFFFF)),
          textAlign: textAlign,
        ),
      ),
    );
  }
}
