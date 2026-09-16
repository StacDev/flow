import 'dart:ui';

import 'flow_attachment_intake.dart';

/// A live drop registration; [dispose] unhooks it.
///
/// Never constructed off the web — [flowRegisterDropTarget] returns null
/// there — but the type exists on every platform so the widget compiles
/// against one shape.
class FlowDropRegistration {
  const FlowDropRegistration._();

  /// Unhooks the registration. Safe to call more than once.
  void dispose() {}
}

/// Hooks a rectangle of the given Flutter view up to the platform's file
/// drop, returning null where the platform has none — which is
/// everywhere but the web.
FlowDropRegistration? flowRegisterDropTarget({
  required int viewId,
  required Rect? Function() bounds,
  required bool Function() isEnabled,
  required void Function(bool hovering) onHover,
  required void Function(List<FlowFileCandidate> files) onDrop,
}) => null;
