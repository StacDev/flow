import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowMarkdown]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Text styles merge over their role's base, so a
/// field can change one property without restating the rest. Install one
/// on [FlowTheme.markdownStyle] to restyle every markdown surface —
/// assistant turns in a thread included; a widget's own `style` object
/// wins field by field:
///
/// ```dart
/// FlowMarkdown(
///   text: reply,
///   onLinkTap: open,
///   markdownStyle: const FlowMarkdownStyle(
///     linkColor: Color(0xFF3366CC),
///     h1Style: TextStyle(fontSize: 26),
///   ),
/// )
/// ```
@immutable
class FlowMarkdownStyle {
  const FlowMarkdownStyle({
    this.h1Style,
    this.h2Style,
    this.h3Style,
    this.h4Style,
    this.h5Style,
    this.h6Style,
    this.linkColor,
    this.inlineCodeStyle,
    this.codeChipColor,
    this.quoteColor,
    this.quoteBarColor,
    this.tableHeaderStyle,
    this.tableCellStyle,
    this.tableBorderColor,
    this.tableDividerColor,
    this.ruleColor,
  });

  /// Merged over `# `'s default `titleLargeEmphasised`.
  final TextStyle? h1Style;

  /// Merged over `## `'s default `titleMediumEmphasised`.
  final TextStyle? h2Style;

  /// Merged over `### `'s default `titleSmallEmphasised`.
  final TextStyle? h3Style;

  /// Merged over `#### `'s default `bodyLargeDark`.
  final TextStyle? h4Style;

  /// Merged over `##### `'s default `bodyMediumDark`.
  final TextStyle? h5Style;

  /// Merged over `###### `'s default `bodyMediumDark` +
  /// `onSurfaceVariant`.
  final TextStyle? h6Style;

  /// Link labels and their underline. Defaults to `secondary`.
  final Color? linkColor;

  /// Merged over inline code's default `codeInline` face.
  final TextStyle? inlineCodeStyle;

  /// The rounded chip painted under inline code. Defaults to
  /// `surfaceContainer`.
  final Color? codeChipColor;

  /// A quote's prose ink. Defaults to `onSurfaceVariant`.
  final Color? quoteColor;

  /// A quote's leading bar. Defaults to `outlineVariant`.
  final Color? quoteBarColor;

  /// Merged over a table header cell's default `bodyMediumDark`.
  final TextStyle? tableHeaderStyle;

  /// Merged over a table body cell's default `bodyMedium`.
  final TextStyle? tableCellStyle;

  /// The hairline under a table's header row. Defaults to `outlineVariant`.
  final Color? tableBorderColor;

  /// The hairline between a table's body rows. Defaults to
  /// `outline`.
  final Color? tableDividerColor;

  /// A horizontal rule. Defaults to `outline`.
  final Color? ruleColor;

  /// A copy where [other]'s fields win over this style's.
  FlowMarkdownStyle merge(FlowMarkdownStyle? other) {
    if (other == null) return this;
    return FlowMarkdownStyle(
      h1Style: other.h1Style ?? h1Style,
      h2Style: other.h2Style ?? h2Style,
      h3Style: other.h3Style ?? h3Style,
      h4Style: other.h4Style ?? h4Style,
      h5Style: other.h5Style ?? h5Style,
      h6Style: other.h6Style ?? h6Style,
      linkColor: other.linkColor ?? linkColor,
      inlineCodeStyle: other.inlineCodeStyle ?? inlineCodeStyle,
      codeChipColor: other.codeChipColor ?? codeChipColor,
      quoteColor: other.quoteColor ?? quoteColor,
      quoteBarColor: other.quoteBarColor ?? quoteBarColor,
      tableHeaderStyle: other.tableHeaderStyle ?? tableHeaderStyle,
      tableCellStyle: other.tableCellStyle ?? tableCellStyle,
      tableBorderColor: other.tableBorderColor ?? tableBorderColor,
      tableDividerColor: other.tableDividerColor ?? tableDividerColor,
      ruleColor: other.ruleColor ?? ruleColor,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowMarkdownStyle lerp(FlowMarkdownStyle? other, double t) {
    if (other == null) return this;
    return FlowMarkdownStyle(
      h1Style: TextStyle.lerp(h1Style, other.h1Style, t),
      h2Style: TextStyle.lerp(h2Style, other.h2Style, t),
      h3Style: TextStyle.lerp(h3Style, other.h3Style, t),
      h4Style: TextStyle.lerp(h4Style, other.h4Style, t),
      h5Style: TextStyle.lerp(h5Style, other.h5Style, t),
      h6Style: TextStyle.lerp(h6Style, other.h6Style, t),
      linkColor: Color.lerp(linkColor, other.linkColor, t),
      inlineCodeStyle: TextStyle.lerp(
        inlineCodeStyle,
        other.inlineCodeStyle,
        t,
      ),
      codeChipColor: Color.lerp(codeChipColor, other.codeChipColor, t),
      quoteColor: Color.lerp(quoteColor, other.quoteColor, t),
      quoteBarColor: Color.lerp(quoteBarColor, other.quoteBarColor, t),
      tableHeaderStyle: TextStyle.lerp(
        tableHeaderStyle,
        other.tableHeaderStyle,
        t,
      ),
      tableCellStyle: TextStyle.lerp(tableCellStyle, other.tableCellStyle, t),
      tableBorderColor: Color.lerp(tableBorderColor, other.tableBorderColor, t),
      tableDividerColor: Color.lerp(
        tableDividerColor,
        other.tableDividerColor,
        t,
      ),
      ruleColor: Color.lerp(ruleColor, other.ruleColor, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowMarkdownStyle &&
        other.h1Style == h1Style &&
        other.h2Style == h2Style &&
        other.h3Style == h3Style &&
        other.h4Style == h4Style &&
        other.h5Style == h5Style &&
        other.h6Style == h6Style &&
        other.linkColor == linkColor &&
        other.inlineCodeStyle == inlineCodeStyle &&
        other.codeChipColor == codeChipColor &&
        other.quoteColor == quoteColor &&
        other.quoteBarColor == quoteBarColor &&
        other.tableHeaderStyle == tableHeaderStyle &&
        other.tableCellStyle == tableCellStyle &&
        other.tableBorderColor == tableBorderColor &&
        other.tableDividerColor == tableDividerColor &&
        other.ruleColor == ruleColor;
  }

  @override
  int get hashCode => Object.hash(
    h1Style,
    h2Style,
    h3Style,
    h4Style,
    h5Style,
    h6Style,
    linkColor,
    inlineCodeStyle,
    codeChipColor,
    quoteColor,
    quoteBarColor,
    tableHeaderStyle,
    tableCellStyle,
    tableBorderColor,
    tableDividerColor,
    ruleColor,
  );
}
