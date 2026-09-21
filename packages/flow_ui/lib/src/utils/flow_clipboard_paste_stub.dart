import 'flow_attachment_intake.dart';

/// A live paste registration; [dispose] unhooks it.
///
/// Never constructed off the web — [flowRegisterPasteTarget] returns null
/// there — but the type exists on every platform so the widget compiles
/// against one shape.
class FlowPasteRegistration {
  const FlowPasteRegistration._();

  /// Unhooks the registration. Safe to call more than once.
  void dispose() {}
}

/// Hooks the clipboard's image paste up to a widget, returning null where
/// the platform has no image clipboard — which is everywhere but the web.
FlowPasteRegistration? flowRegisterPasteTarget({
  required bool Function() isActive,
  required bool Function(List<FlowFileCandidate> files) onPaste,
}) => null;
