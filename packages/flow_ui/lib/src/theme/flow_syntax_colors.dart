import 'package:material_ui/material_ui.dart';

/// Syntax token colors for the code block.
///
/// Eight roles cover what the built-in highlighter distinguishes; plain
/// code takes the ambient ink (`FlowColors.onSurface`), so no role exists
/// for it. Unlike the ink ramp these are resolved, opaque colors — a hue
/// at an alpha would drift on the code block's washed ground.
///
/// The presets are drawn to sit with the shipped palettes: hues keyed to
/// the warm paper and rose accent of the light theme, the same set lifted
/// for dark.
@immutable
class FlowSyntaxColors {
  const FlowSyntaxColors({
    required this.keyword,
    required this.type,
    required this.function,
    required this.string,
    required this.number,
    required this.comment,
    required this.meta,
    required this.punctuation,
  });

  /// Reserved words and control flow — `class`, `if`, `return`.
  final Color keyword;

  /// Type names: uppercase identifiers and language primitives.
  final Color type;

  /// A call or declaration site — an identifier ahead of its `(`.
  final Color function;

  /// String literals, quotes included.
  final Color string;

  /// Numeric literals.
  final Color number;

  /// Comments.
  final Color comment;

  /// Annotations, decorators and shell variables — `@override`, `$HOME`.
  final Color meta;

  /// Brackets, separators and operators.
  final Color punctuation;

  /// Light preset: saturated inks on warm paper, the keyword in the
  /// palette's rose family.
  static const FlowSyntaxColors light = FlowSyntaxColors(
    keyword: Color(0xFFA62457),
    type: Color(0xFF96540A),
    function: Color(0xFF6E4DBE),
    string: Color(0xFF0E7264),
    number: Color(0xFF1F63BC),
    comment: Color(0xFF8C8579),
    meta: Color(0xFF5F6E8C),
    punctuation: Color(0xFF6F6A60),
  );

  /// Dark preset: the same hues lifted to read on the dark ground.
  static const FlowSyntaxColors dark = FlowSyntaxColors(
    keyword: Color(0xFFEF6E9F),
    type: Color(0xFFD9A054),
    function: Color(0xFFB49AEC),
    string: Color(0xFF5BC4AF),
    number: Color(0xFF74A9EC),
    comment: Color(0xFF8A8177),
    meta: Color(0xFF8FA3CE),
    punctuation: Color(0xFF938D82),
  );

  FlowSyntaxColors copyWith({
    Color? keyword,
    Color? type,
    Color? function,
    Color? string,
    Color? number,
    Color? comment,
    Color? meta,
    Color? punctuation,
  }) {
    return FlowSyntaxColors(
      keyword: keyword ?? this.keyword,
      type: type ?? this.type,
      function: function ?? this.function,
      string: string ?? this.string,
      number: number ?? this.number,
      comment: comment ?? this.comment,
      meta: meta ?? this.meta,
      punctuation: punctuation ?? this.punctuation,
    );
  }

  FlowSyntaxColors lerp(FlowSyntaxColors? other, double t) {
    if (other == null) return this;
    return FlowSyntaxColors(
      keyword: Color.lerp(keyword, other.keyword, t)!,
      type: Color.lerp(type, other.type, t)!,
      function: Color.lerp(function, other.function, t)!,
      string: Color.lerp(string, other.string, t)!,
      number: Color.lerp(number, other.number, t)!,
      comment: Color.lerp(comment, other.comment, t)!,
      meta: Color.lerp(meta, other.meta, t)!,
      punctuation: Color.lerp(punctuation, other.punctuation, t)!,
    );
  }
}
