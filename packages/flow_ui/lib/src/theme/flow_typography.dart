import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Google Sans for prose and Google Sans Code for code, served by
/// `google_fonts`: each cut is fetched on first use and cached, or read from
/// a `google_fonts/` asset folder when the host ships one.
///
/// google_fonts registers each cut as its own font family (`GoogleSans_600`,
/// …), so roles are built through the package and re-weighted with
/// [FlowTypography.recut] rather than `copyWith(fontWeight:)`.
const String _fontFamily = 'GoogleSans';
const String _monoFontFamily = 'GoogleSansCode';

TextStyle _sans(double size, FontWeight weight, double height) =>
    GoogleFonts.googleSans(fontSize: size, fontWeight: weight, height: height);

TextStyle _mono(double size, FontWeight weight, double height) =>
    GoogleFonts.googleSansCode(
      fontSize: size,
      fontWeight: weight,
      height: height,
    );

/// Defaults for the mono roles, resolved by the [FlowTypography.code] and
/// [FlowTypography.codeInline] getters.
final TextStyle _standardCode = _mono(13, FontWeight.w400, 1.6);
final TextStyle _standardCodeInline = _mono(13, FontWeight.w400, 1.5);

/// Text style tokens for flow_ui components.
///
/// Follows the Material 3 type scale (display / headline / title / body /
/// label, each in large / medium / small), so a host can map an existing M3
/// text theme across. Styles are colorless — components combine them with
/// [FlowColors] tokens (e.g.
/// `typography.bodyLarge.copyWith(color: colors.onSurface)`).
///
/// Sizes, weights and line heights come from the Flow UI design file. Two
/// habits of that design carry through the whole scale: no letter-spacing,
/// and one of two line heights — 1.5 where text wraps into paragraphs, 1.3
/// where it sits on a single line in a row or a control.
@immutable
class FlowTypography {
  const FlowTypography({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleLargeEmphasised,
    required this.titleMedium,
    required this.titleMediumEmphasised,
    required this.titleSmall,
    required this.titleSmallEmphasised,
    required this.bodyLarge,
    required this.bodyLargeEmphasised,
    required this.bodyLargeDark,
    required this.bodyMedium,
    required this.bodyMediumEmphasised,
    required this.bodyMediumDark,
    required this.bodySmall,
    required this.bodySmallEmphasised,
    required this.bodySmallDark,
    required this.labelLarge,
    required this.labelLargeEmphasised,
    required this.labelMedium,
    required this.labelMediumEmphasised,
    required this.labelSmall,
    required this.labelSmallEmphasised,
    this._code,
    this._codeInline,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;

  /// Headings — single-line at 1.3. Each size pairs the regular cut
  /// (w400) with an emphasised one (w600).
  final TextStyle titleLarge;
  final TextStyle titleLargeEmphasised;
  final TextStyle titleMedium;
  final TextStyle titleMediumEmphasised;
  final TextStyle titleSmall;
  final TextStyle titleSmallEmphasised;

  /// Prose and composer input — the design's 16/1.5 body.
  /// Each size carries three inks: regular (w400), emphasised (w500) and
  /// dark (w600).
  final TextStyle bodyLarge;
  final TextStyle bodyLargeEmphasised;
  final TextStyle bodyLargeDark;
  final TextStyle bodyMedium;
  final TextStyle bodyMediumEmphasised;
  final TextStyle bodyMediumDark;
  final TextStyle bodySmall;
  final TextStyle bodySmallEmphasised;
  final TextStyle bodySmallDark;

  /// Controls — the design's 16/14/12 on the tight 1.3 line. Each size
  /// pairs the regular cut (w400) with an emphasised one (w500), like the
  /// body roles.
  final TextStyle labelLarge;
  final TextStyle labelLargeEmphasised;
  final TextStyle labelMedium;
  final TextStyle labelMediumEmphasised;
  final TextStyle labelSmall;
  final TextStyle labelSmallEmphasised;

  final TextStyle? _code;
  final TextStyle? _codeInline;

  /// The code block's body, in Google Sans Code: 13 on a taller line
  /// (1.6), so a block reads as inset material, not a continuing
  /// paragraph.
  TextStyle get code => _code ?? _standardCode;

  /// The mono face a step under prose size, for inline code spans.
  TextStyle get codeInline => _codeInline ?? _standardCodeInline;

  /// The Flow type scale: Google Sans, with the code roles in Google Sans
  /// Code.
  static final FlowTypography standard = FlowTypography(
    displayLarge: _sans(52, FontWeight.w400, 1.15),
    displayMedium: _sans(46, FontWeight.w400, 1.15),
    displaySmall: _sans(40, FontWeight.w400, 1.15),
    headlineLarge: _sans(36, FontWeight.w400, 1.2),
    // The greeting: 32 regular.
    headlineMedium: _sans(32, FontWeight.w400, 1.2),
    headlineSmall: _sans(28, FontWeight.w400, 1.2),
    titleLarge: _sans(24, FontWeight.w400, 1.3),
    titleLargeEmphasised: _sans(24, FontWeight.w600, 1.3),
    titleMedium: _sans(21, FontWeight.w400, 1.3),
    titleMediumEmphasised: _sans(21, FontWeight.w600, 1.3),
    titleSmall: _sans(18, FontWeight.w400, 1.3),
    titleSmallEmphasised: _sans(18, FontWeight.w600, 1.3),
    bodyLarge: _sans(16, FontWeight.w400, 1.5),
    bodyLargeEmphasised: _sans(16, FontWeight.w500, 1.5),
    bodyLargeDark: _sans(16, FontWeight.w600, 1.5),
    bodyMedium: _sans(14, FontWeight.w400, 1.5),
    bodyMediumEmphasised: _sans(14, FontWeight.w500, 1.5),
    bodyMediumDark: _sans(14, FontWeight.w600, 1.5),
    bodySmall: _sans(12, FontWeight.w400, 1.5),
    bodySmallEmphasised: _sans(12, FontWeight.w500, 1.5),
    bodySmallDark: _sans(12, FontWeight.w600, 1.5),
    labelLarge: _sans(16, FontWeight.w400, 1.3),
    labelLargeEmphasised: _sans(16, FontWeight.w500, 1.3),
    labelMedium: _sans(14, FontWeight.w400, 1.3),
    labelMediumEmphasised: _sans(14, FontWeight.w500, 1.3),
    labelSmall: _sans(12, FontWeight.w400, 1.3),
    labelSmallEmphasised: _sans(12, FontWeight.w500, 1.3),
  );

  /// The same scale set in [fontFamily] instead of Google Sans.
  /// The mono roles keep their own face — swap those with
  /// [withCodeFontFamily].
  ///
  /// Pass [package] when the font ships inside a package rather than the app.
  /// Each style is rebuilt from the four things the scale carries — size,
  /// weight, line height and tracking — so anything else set on a customised
  /// style is dropped rather than half-kept.
  FlowTypography withFontFamily(String fontFamily, {String? package}) {
    TextStyle reface(TextStyle style) => TextStyle(
      fontFamily: fontFamily,
      package: package,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      height: style.height,
      letterSpacing: style.letterSpacing,
    );

    return FlowTypography(
      displayLarge: reface(displayLarge),
      displayMedium: reface(displayMedium),
      displaySmall: reface(displaySmall),
      headlineLarge: reface(headlineLarge),
      headlineMedium: reface(headlineMedium),
      headlineSmall: reface(headlineSmall),
      titleLarge: reface(titleLarge),
      titleLargeEmphasised: reface(titleLargeEmphasised),
      titleMedium: reface(titleMedium),
      titleMediumEmphasised: reface(titleMediumEmphasised),
      titleSmall: reface(titleSmall),
      titleSmallEmphasised: reface(titleSmallEmphasised),
      bodyLarge: reface(bodyLarge),
      bodyLargeEmphasised: reface(bodyLargeEmphasised),
      bodyLargeDark: reface(bodyLargeDark),
      bodyMedium: reface(bodyMedium),
      bodyMediumEmphasised: reface(bodyMediumEmphasised),
      bodyMediumDark: reface(bodyMediumDark),
      bodySmall: reface(bodySmall),
      bodySmallEmphasised: reface(bodySmallEmphasised),
      bodySmallDark: reface(bodySmallDark),
      labelLarge: reface(labelLarge),
      labelLargeEmphasised: reface(labelLargeEmphasised),
      labelMedium: reface(labelMedium),
      labelMediumEmphasised: reface(labelMediumEmphasised),
      labelSmall: reface(labelSmall),
      labelSmallEmphasised: reface(labelSmallEmphasised),
      code: code,
      codeInline: codeInline,
    );
  }

  /// The same scale with only [code] and [codeInline] set in [fontFamily] —
  /// for hosts swapping the mono face while keeping the prose one.
  ///
  /// Rebuilt from size, weight and line height, like [withFontFamily].
  FlowTypography withCodeFontFamily(String fontFamily, {String? package}) {
    TextStyle reface(TextStyle style) => TextStyle(
      fontFamily: fontFamily,
      package: package,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      height: style.height,
      letterSpacing: style.letterSpacing,
    );

    return copyWith(code: reface(code), codeInline: reface(codeInline));
  }

  /// [style] at [fontWeight] and/or [fontStyle], in the matching cut.
  ///
  /// google_fonts registers each cut as its own font family, so `copyWith`
  /// on a token would leave the engine faking the weight; this loads the
  /// real cut. Styles in any other face pass through `copyWith`.
  static TextStyle recut(
    TextStyle style, {
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) {
    // google_fonts names each cut `<family>_<variant>`.
    final family = style.fontFamily ?? '';
    if (family.startsWith('${_fontFamily}_')) {
      return GoogleFonts.googleSans(
        textStyle: style,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
      );
    }
    if (family.startsWith('${_monoFontFamily}_')) {
      return GoogleFonts.googleSansCode(
        textStyle: style,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
      );
    }
    return style.copyWith(fontWeight: fontWeight, fontStyle: fontStyle);
  }

  FlowTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleLargeEmphasised,
    TextStyle? titleMedium,
    TextStyle? titleMediumEmphasised,
    TextStyle? titleSmall,
    TextStyle? titleSmallEmphasised,
    TextStyle? bodyLarge,
    TextStyle? bodyLargeEmphasised,
    TextStyle? bodyLargeDark,
    TextStyle? bodyMedium,
    TextStyle? bodyMediumEmphasised,
    TextStyle? bodyMediumDark,
    TextStyle? bodySmall,
    TextStyle? bodySmallEmphasised,
    TextStyle? bodySmallDark,
    TextStyle? labelLarge,
    TextStyle? labelLargeEmphasised,
    TextStyle? labelMedium,
    TextStyle? labelMediumEmphasised,
    TextStyle? labelSmall,
    TextStyle? labelSmallEmphasised,
    TextStyle? code,
    TextStyle? codeInline,
  }) {
    return FlowTypography(
      displayLarge: displayLarge ?? this.displayLarge,
      displayMedium: displayMedium ?? this.displayMedium,
      displaySmall: displaySmall ?? this.displaySmall,
      headlineLarge: headlineLarge ?? this.headlineLarge,
      headlineMedium: headlineMedium ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? this.headlineSmall,
      titleLarge: titleLarge ?? this.titleLarge,
      titleLargeEmphasised: titleLargeEmphasised ?? this.titleLargeEmphasised,
      titleMedium: titleMedium ?? this.titleMedium,
      titleMediumEmphasised:
          titleMediumEmphasised ?? this.titleMediumEmphasised,
      titleSmall: titleSmall ?? this.titleSmall,
      titleSmallEmphasised: titleSmallEmphasised ?? this.titleSmallEmphasised,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyLargeEmphasised: bodyLargeEmphasised ?? this.bodyLargeEmphasised,
      bodyLargeDark: bodyLargeDark ?? this.bodyLargeDark,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodyMediumEmphasised: bodyMediumEmphasised ?? this.bodyMediumEmphasised,
      bodyMediumDark: bodyMediumDark ?? this.bodyMediumDark,
      bodySmall: bodySmall ?? this.bodySmall,
      bodySmallEmphasised: bodySmallEmphasised ?? this.bodySmallEmphasised,
      bodySmallDark: bodySmallDark ?? this.bodySmallDark,
      labelLarge: labelLarge ?? this.labelLarge,
      labelLargeEmphasised: labelLargeEmphasised ?? this.labelLargeEmphasised,
      labelMedium: labelMedium ?? this.labelMedium,
      labelMediumEmphasised:
          labelMediumEmphasised ?? this.labelMediumEmphasised,
      labelSmall: labelSmall ?? this.labelSmall,
      labelSmallEmphasised: labelSmallEmphasised ?? this.labelSmallEmphasised,
      code: code ?? this.code,
      codeInline: codeInline ?? this.codeInline,
    );
  }

  FlowTypography lerp(FlowTypography? other, double t) {
    if (other == null) return this;
    return FlowTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
      displaySmall: TextStyle.lerp(displaySmall, other.displaySmall, t)!,
      headlineLarge: TextStyle.lerp(headlineLarge, other.headlineLarge, t)!,
      headlineMedium: TextStyle.lerp(headlineMedium, other.headlineMedium, t)!,
      headlineSmall: TextStyle.lerp(headlineSmall, other.headlineSmall, t)!,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleLargeEmphasised: TextStyle.lerp(
        titleLargeEmphasised,
        other.titleLargeEmphasised,
        t,
      )!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      titleMediumEmphasised: TextStyle.lerp(
        titleMediumEmphasised,
        other.titleMediumEmphasised,
        t,
      )!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      titleSmallEmphasised: TextStyle.lerp(
        titleSmallEmphasised,
        other.titleSmallEmphasised,
        t,
      )!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyLargeEmphasised: TextStyle.lerp(
        bodyLargeEmphasised,
        other.bodyLargeEmphasised,
        t,
      )!,
      bodyLargeDark: TextStyle.lerp(bodyLargeDark, other.bodyLargeDark, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodyMediumEmphasised: TextStyle.lerp(
        bodyMediumEmphasised,
        other.bodyMediumEmphasised,
        t,
      )!,
      bodyMediumDark: TextStyle.lerp(bodyMediumDark, other.bodyMediumDark, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      bodySmallEmphasised: TextStyle.lerp(
        bodySmallEmphasised,
        other.bodySmallEmphasised,
        t,
      )!,
      bodySmallDark: TextStyle.lerp(bodySmallDark, other.bodySmallDark, t)!,
      labelLarge: TextStyle.lerp(labelLarge, other.labelLarge, t)!,
      labelLargeEmphasised: TextStyle.lerp(
        labelLargeEmphasised,
        other.labelLargeEmphasised,
        t,
      )!,
      labelMedium: TextStyle.lerp(labelMedium, other.labelMedium, t)!,
      labelMediumEmphasised: TextStyle.lerp(
        labelMediumEmphasised,
        other.labelMediumEmphasised,
        t,
      )!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
      labelSmallEmphasised: TextStyle.lerp(
        labelSmallEmphasised,
        other.labelSmallEmphasised,
        t,
      )!,
      code: TextStyle.lerp(code, other.code, t)!,
      codeInline: TextStyle.lerp(codeInline, other.codeInline, t)!,
    );
  }
}
