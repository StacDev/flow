import 'package:material_ui/material_ui.dart';

/// A chrome text style in Google Sans — the face flow_ui bundles, addressed
/// by its package, so the playground declares no font of its own. The chrome
/// keeps its bespoke sizes from the Claude Design prototype and colors them
/// from flow_ui's tokens.
TextStyle shellText({
  double? size,
  FontWeight? weight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'GoogleSans',
    package: 'flow_ui',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}
