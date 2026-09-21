import 'package:material_ui/material_ui.dart';

/// Semantic color tokens for flow_ui components.
///
/// Role names follow Material 3's [ColorScheme] (primary / secondary /
/// tertiary / error groups, surface containers, outline, inverse), so a host
/// can map an existing M3 scheme onto flow_ui — with one inversion: here
/// [outline] is the *faint* hairline and [outlineVariant] the *firm* one,
/// the reverse of M3's weights. Flow adds a third ink level,
/// [onSurfaceMuted], [success] and [warning] groups beside [error], and
/// a [shadow] role — the ink at 2%, alpha included.
///
/// The presets come from the Flow UI design file. Three things about them
/// are worth knowing before overriding one:
///
/// * **The ink ramp is translucent.** [onSurfaceVariant] (75%),
///   [onSurfaceMuted] (50%), [outline] (7%, 8% in dark),
///   [outlineVariant] (12%) and [shadow] (2%) are
///   the foreground ink at an alpha, not resolved colors. The design uses the
///   same label and the same hairline on the page *and* on the raised card,
///   which only works if they composite.
/// * **The container ladder is translucent too.** `surfaceContainerLowest`
///   through `Highest` are ink washes at rising alphas, so the same fill
///   reads correctly on the page and on the raised card. Only [surface]
///   and [surfaceBright] — the grounds everything else sits on — are
///   opaque.
/// * **Accent containers are washes of their accent.** Each `Container` is
///   its accent at an alpha — 8% for primary, secondary and tertiary, 6%
///   for error, success and warning — and each `onContainer` is the accent
///   itself.
@immutable
class FlowColors {
  const FlowColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.surface,
    required this.surfaceBright,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceMuted,
    required this.onSurfaceDisabled,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.shadow,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
  });

  // Primary — brand / interactive accent: the rose, at the same value in
  // both themes.
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  // Secondary — supporting accent: the hotter pink beside the rose;
  // markdown links.
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  // Tertiary — indigo, lifted to a blue in dark.
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  // Error — destructive intent and failure states.
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  // Success — completed, approved, confirmed.
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  // Warning — caution and pending attention.
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  // Surface — backgrounds and the content on them.

  /// The page.
  final Color surface;

  /// The brightest surface: the raised card — the composer, menus, sheets.
  /// The one surface that lifts *off* the page in both themes, sitting
  /// outside the container tint ladder below.
  final Color surfaceBright;

  /// Content ink at full strength: prose, the model name, an active label.
  final Color onSurface;

  /// Ink at 75% — secondary content: row labels and their icons at rest.
  final Color onSurfaceVariant;

  /// Ink at 50% — muted chrome: placeholders, carets, message-action icons.
  final Color onSurfaceMuted;

  /// Ink at 30% — disabled content, like the send button that can't send.
  final Color onSurfaceDisabled;

  /// The tint ladder's faintest rung — the ink at its lowest wash, rising
  /// through the containers below.
  final Color surfaceContainerLowest;

  /// Faintest fill — the user bubble, a bare attachment tile; a suggestion
  /// row's hover.
  final Color surfaceContainerLow;

  /// Resting fill — a selected row, the error card, inline code.
  final Color surfaceContainer;

  /// Deeper fill — behind a photo tile; the code block's copy affordance
  /// on hover.
  final Color surfaceContainerHigh;

  /// Pressed, and the ground behind a failed attachment.
  final Color surfaceContainerHighest;

  // Outline — borders and separators.

  /// Faint hairline — 7% ink in light, 8% in dark: rules and table
  /// dividers, a pill or code block at rest.
  final Color outline;

  /// Firm hairline — 12% ink in both themes: the edge of a tile, a menu
  /// rule, the sheet's edge, a retry pill, the send disc at rest.
  final Color outlineVariant;

  // Shadow — the ambient lift under a raised card, tile or disc.

  /// The ink at 2%, alpha included: a component pairs it with its own blur
  /// and no offset, so one value lifts or kills every shadow in the library.
  final Color shadow;

  // Inverse — elements on the opposite brightness (snackbars, tooltips).
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;

  /// Light preset: warm paper, near-black ink, rose accent.
  static const FlowColors light = FlowColors(
    primary: Color(0xFFE071A7),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0x14E071A7),
    onPrimaryContainer: Color(0xFFE071A7),
    secondary: Color(0xFFFF67B0),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0x14FF67B0),
    onSecondaryContainer: Color(0xFFFF67B0),
    tertiary: Color(0xFF3730A3),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0x143730A3),
    onTertiaryContainer: Color(0xFF3730A3),
    error: Color(0xFFC14A4A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0x0FC14A4A),
    onErrorContainer: Color(0xFFC14A4A),
    success: Color(0xFF249655),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0x0F249655),
    onSuccessContainer: Color(0xFF249655),
    warning: Color(0xFFEE8D34),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0x0FEE8D34),
    onWarningContainer: Color(0xFFEE8D34),
    surface: Color(0xFFF9F9F7),
    surfaceBright: Color(0xFFFFFFFF),
    onSurface: Color(0xFF111110),
    onSurfaceVariant: Color(0xBF111110),
    onSurfaceMuted: Color(0x80111110),
    onSurfaceDisabled: Color(0x4D111110),
    surfaceContainerLowest: Color(0x05111110),
    surfaceContainerLow: Color(0x0A111110),
    surfaceContainer: Color(0x0F111110),
    surfaceContainerHigh: Color(0x14111110),
    surfaceContainerHighest: Color(0x1A111110),
    outline: Color(0x12111110),
    outlineVariant: Color(0x1F111110),
    shadow: Color(0x05111110),
    inverseSurface: Color(0xFF111110),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFFF5E9EE),
  );

  /// Dark preset: white ink on `#171717`, the accents lifted to hold on it
  /// and carrying the raised card's `#1E1E1E` as their `on` ink.
  static const FlowColors dark = FlowColors(
    primary: Color(0xFFE071A7),
    onPrimary: Color(0xFF1E1E1E),
    primaryContainer: Color(0x14E071A7),
    onPrimaryContainer: Color(0xFFE071A7),
    secondary: Color(0xFFFF67B0),
    onSecondary: Color(0xFF1E1E1E),
    secondaryContainer: Color(0x14FF67B0),
    onSecondaryContainer: Color(0xFFFF67B0),
    tertiary: Color(0xFF77A8FD),
    onTertiary: Color(0xFF1E1E1E),
    tertiaryContainer: Color(0x1477A8FD),
    onTertiaryContainer: Color(0xFF77A8FD),
    error: Color(0xFFFF6565),
    onError: Color(0xFF1E1E1E),
    errorContainer: Color(0x0FFF6565),
    onErrorContainer: Color(0xFFFF6565),
    success: Color(0xFF50D59D),
    onSuccess: Color(0xFF1E1E1E),
    successContainer: Color(0x0F50D59D),
    onSuccessContainer: Color(0xFF50D59D),
    warning: Color(0xFFFF9A3E),
    onWarning: Color(0xFF1E1E1E),
    warningContainer: Color(0x0FFF9A3E),
    onWarningContainer: Color(0xFFFF9A3E),
    surface: Color(0xFF171717),
    surfaceBright: Color(0xFF1E1E1E),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xBFFFFFFF),
    onSurfaceMuted: Color(0x80FFFFFF),
    onSurfaceDisabled: Color(0x4DFFFFFF),
    surfaceContainerLowest: Color(0x05FFFFFF),
    surfaceContainerLow: Color(0x0AFFFFFF),
    surfaceContainer: Color(0x0FFFFFFF),
    surfaceContainerHigh: Color(0x14FFFFFF),
    surfaceContainerHighest: Color(0x1AFFFFFF),
    outline: Color(0x14FFFFFF),
    outlineVariant: Color(0x1FFFFFFF),
    shadow: Color(0x05FFFFFF),
    inverseSurface: Color(0xFFFFFFFF),
    onInverseSurface: Color(0xFF1E1E1E),
    inversePrimary: Color(0xFF2B2025),
  );

  FlowColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? surface,
    Color? surfaceBright,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? onSurfaceMuted,
    Color? onSurfaceDisabled,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? outline,
    Color? outlineVariant,
    Color? shadow,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? inversePrimary,
  }) {
    return FlowColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      surface: surface ?? this.surface,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      onSurfaceDisabled: onSurfaceDisabled ?? this.onSurfaceDisabled,
      surfaceContainerLowest:
          surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      shadow: shadow ?? this.shadow,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      inversePrimary: inversePrimary ?? this.inversePrimary,
    );
  }

  FlowColors lerp(FlowColors? other, double t) {
    if (other == null) return this;
    return FlowColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      onTertiary: Color.lerp(onTertiary, other.onTertiary, t)!,
      tertiaryContainer: Color.lerp(
        tertiaryContainer,
        other.tertiaryContainer,
        t,
      )!,
      onTertiaryContainer: Color.lerp(
        onTertiaryContainer,
        other.onTertiaryContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer: Color.lerp(
        onErrorContainer,
        other.onErrorContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      onSurfaceDisabled: Color.lerp(
        onSurfaceDisabled,
        other.onSurfaceDisabled,
        t,
      )!,
      surfaceContainerLowest: Color.lerp(
        surfaceContainerLowest,
        other.surfaceContainerLowest,
        t,
      )!,
      surfaceContainerLow: Color.lerp(
        surfaceContainerLow,
        other.surfaceContainerLow,
        t,
      )!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      surfaceContainerHighest: Color.lerp(
        surfaceContainerHighest,
        other.surfaceContainerHighest,
        t,
      )!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
      onInverseSurface: Color.lerp(
        onInverseSurface,
        other.onInverseSurface,
        t,
      )!,
      inversePrimary: Color.lerp(inversePrimary, other.inversePrimary, t)!,
    );
  }
}
