import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/flow_typography.dart';
import 'flow_selection.dart';

/// Internal — not exported from the package barrel.
///
/// The inline-code chip, painted rather than composed: Flutter gives a
/// text span exactly one decoration slot (`TextStyle.background`, a
/// single Paint — no radius, no padding), and the usual `WidgetSpan`
/// chip can't wrap, breaks the streaming reveal, and sits off the
/// baseline. Instead the span stays plain text tagged as a chip, and a
/// paragraph render object paints rounded rects behind the glyph boxes —
/// so chips wrap across lines, ride the reveal, and stay selectable.

/// The chip's metrics — provisional, pending a Figma frame for the
/// inline-code chip.
const double _chipRadius = 4;
const double _chipHPad = 3;

/// A text span whose glyph boxes get a chip painted behind them by
/// [FlowChipText]'s render object. Construct with [text] only — the
/// offset walk counts the span's own text.
class FlowChipSpan extends TextSpan {
  const FlowChipSpan({
    required String super.text,
    super.style,
    super.recognizer,
    required this.fill,
  });

  final Color fill;

  // TextSpan's own equality and comparison don't know about [fill]; a
  // fill-only change must still compare unequal and repaint, or
  // RenderParagraph's text setter short-circuits and keeps the old wash.
  @override
  RenderComparison compareTo(InlineSpan other) {
    final result = super.compareTo(other);
    if (result == RenderComparison.identical &&
        !identical(this, other) &&
        (other as FlowChipSpan).fill != fill) {
      return RenderComparison.paint;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      super == other && other is FlowChipSpan && other.fill == fill;

  @override
  int get hashCode => Object.hash(super.hashCode, fill);
}

/// `Text.rich`, chip-aware: renders [span] through a paragraph that
/// paints [FlowChipSpan] chips before the glyphs. Mirrors `Text.rich`'s
/// ambient wiring — default style, bold text, text scaling, selection
/// registration — so it is a drop-in swap. Inside a selection area the
/// paragraph is a [FlowSelectionBlock], so a copy across paragraphs keeps
/// its line breaks.
class FlowChipText extends StatelessWidget {
  const FlowChipText(this.span, {super.key});

  final InlineSpan span;

  @override
  Widget build(BuildContext context) {
    // The block is the registrar the paragraph must see, so the ambient
    // reads happen a level down.
    return FlowSelectionBlock(child: _ChipParagraph(span));
  }
}

class _ChipParagraph extends StatelessWidget {
  const _ChipParagraph(this.span);

  final InlineSpan span;

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    var style = defaults.style;
    if (MediaQuery.boldTextOf(context)) {
      style = FlowTypography.recut(style, fontWeight: FontWeight.bold);
    }
    final registrar = SelectionContainer.maybeOf(context);
    final selectionStyle = DefaultSelectionStyle.of(context);
    Widget result = _ChipRichText(
      text: TextSpan(style: style, children: [span]),
      textAlign: defaults.textAlign ?? TextAlign.start,
      softWrap: defaults.softWrap,
      overflow: defaults.overflow,
      maxLines: defaults.maxLines,
      textWidthBasis: defaults.textWidthBasis,
      textHeightBehavior:
          defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      selectionRegistrar: registrar,
      selectionColor:
          selectionStyle.selectionColor ?? DefaultSelectionStyle.defaultColor,
    );
    if (registrar != null) {
      result = MouseRegion(
        cursor:
            DefaultSelectionStyle.of(context).mouseCursor ??
            SystemMouseCursors.text,
        child: result,
      );
    }
    return result;
  }
}

class _ChipRichText extends RichText {
  _ChipRichText({
    required super.text,
    required super.textAlign,
    required super.softWrap,
    required super.overflow,
    super.maxLines,
    required super.textWidthBasis,
    super.textHeightBehavior,
    required super.textScaler,
    super.locale,
    super.selectionRegistrar,
    super.selectionColor,
  });

  @override
  RenderParagraph createRenderObject(BuildContext context) {
    return _ChipRenderParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      registrar: selectionRegistrar,
      selectionColor: selectionColor,
    );
  }
}

class _ChipRenderParagraph extends RenderParagraph {
  _ChipRenderParagraph(
    super.text, {
    required super.textAlign,
    required super.textDirection,
    required super.softWrap,
    required super.overflow,
    required super.textScaler,
    super.maxLines,
    super.strutStyle,
    required super.textWidthBasis,
    super.textHeightBehavior,
    super.locale,
    super.registrar,
    super.selectionColor,
  });

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintChips(context.canvas, offset);
    // Painting first keeps the fill under the glyphs and under the
    // selection highlight.
    super.paint(context, offset);
  }

  void _paintChips(Canvas canvas, Offset offset) {
    // Walk the span tree with a plain-text cursor, collecting the tagged
    // ranges. Adjacent same-fill ranges coalesce, which folds the
    // reveal's per-character spans of one code run back into one chip.
    final ranges = <_ChipRange>[];
    var cursor = 0;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        final text = span.text;
        if (text != null && text.isNotEmpty) {
          if (span is FlowChipSpan) {
            final last = ranges.isEmpty ? null : ranges.last;
            if (last != null && last.end == cursor && last.fill == span.fill) {
              last.end = cursor + text.length;
            } else {
              ranges.add(_ChipRange(cursor, cursor + text.length, span.fill));
            }
          }
          cursor += text.length;
        }
        final children = span.children;
        if (children != null) {
          children.forEach(walk);
        }
      } else {
        // A placeholder occupies one object-replacement code unit. None
        // exist in markdown spans today; the rule keeps the offsets
        // honest the day one does.
        cursor += 1;
      }
    }

    walk(text);
    if (ranges.isEmpty) return;

    for (final range in ranges) {
      final boxes = getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      if (boxes.isEmpty) continue;

      // Fold boxes into line fragments by vertical overlap — boxes come
      // one per style run and in text order, so a wrap starts a new
      // fragment and grouping stays order-agnostic within a line (RTL
      // safe).
      final fragments = <Rect>[];
      for (final box in boxes) {
        final rect = box.toRect();
        if (rect.width <= 0) continue;
        if (fragments.isNotEmpty &&
            rect.top < fragments.last.bottom &&
            rect.bottom > fragments.last.top) {
          fragments[fragments.length - 1] = fragments.last.expandToInclude(
            rect,
          );
        } else {
          fragments.add(rect);
        }
      }
      if (fragments.isEmpty) continue;

      final rtl = boxes.first.direction == TextDirection.rtl;
      final paint = Paint()..color = range.fill;
      const radius = Radius.circular(_chipRadius);
      for (var i = 0; i < fragments.length; i++) {
        final rect = fragments[i].shift(offset).inflateHorizontally(_chipHPad);
        // Only the outer corners of a wrapped run round, so a chip
        // broken across lines reads as one run.
        final startRounded = i == 0;
        final endRounded = i == fragments.length - 1;
        final leftRounded = rtl ? endRounded : startRounded;
        final rightRounded = rtl ? startRounded : endRounded;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: leftRounded ? radius : Radius.zero,
            bottomLeft: leftRounded ? radius : Radius.zero,
            topRight: rightRounded ? radius : Radius.zero,
            bottomRight: rightRounded ? radius : Radius.zero,
          ),
          paint,
        );
      }
    }
  }
}

class _ChipRange {
  _ChipRange(this.start, this.end, this.fill);

  final int start;
  int end;
  final Color fill;
}

extension on Rect {
  Rect inflateHorizontally(double delta) =>
      Rect.fromLTRB(left - delta, top, right + delta, bottom);
}
