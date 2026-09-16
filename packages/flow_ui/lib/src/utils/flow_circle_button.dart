import 'package:material_ui/material_ui.dart';

// Internal chrome shared by the composer, the attachment tiles and the
// attachment preview. Not exported from the package barrel.

/// A round icon button on a filled disc.
///
/// One definition so the send button, the attachment remove button and the
/// preview's close button can't drift apart in ink, clip or hover treatment.
class FlowCircleButton extends StatelessWidget {
  /// The disc padding used when [padding] is null — public within the
  /// package so layouts that mirror a default-sized disc (the menu sheet's
  /// nav balance) can derive from it instead of copying the number.
  static const double defaultPadding = 8;

  const FlowCircleButton({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
    this.onFocusChange,
    this.tooltip,
    this.iconSize = 18,
    this.padding,
    this.hoverColor,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  /// Null renders the disc inert.
  final VoidCallback? onTap;

  /// Reported so a caller that reveals the button on hover can also keep it
  /// on screen while it holds keyboard focus.
  final ValueChanged<bool>? onFocusChange;

  /// Host-localized; also the button's accessible name. Null leaves the
  /// framework's own semantics in place.
  final String? tooltip;

  final double iconSize;

  /// Around the icon; defaults to the design's 8.
  final double? padding;

  /// Defaults to the ambient ink treatment, which tints rather than replaces
  /// [background] — the right behaviour when the disc is translucent.
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onFocusChange: onFocusChange,
        customBorder: const CircleBorder(),
        hoverColor: hoverColor,
        child: Padding(
          padding: EdgeInsets.all(padding ?? defaultPadding),
          child: Icon(icon, size: iconSize, color: foreground),
        ),
      ),
    );

    // Tooltip already contributes the message to the semantics node, so it
    // is the label as well — a separate Semantics(label:) would announce it
    // twice.
    final message = tooltip;
    if (message != null) {
      button = Tooltip(message: message, child: button);
    }
    return button;
  }
}
