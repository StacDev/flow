import 'package:file_selector/file_selector.dart';

import '../models/flow_attachment.dart';
import '../models/flow_attachment_options.dart';
import 'flow_attachment_intake.dart';

/// Opens the platform's file dialog and returns what came back, read and
/// decoded into [FlowAttachment]s.
///
/// The function behind `FlowComposer.onAttachmentsPicked`, public so the
/// same dialog can open from anywhere else — the design's "+" menu, a
/// host's own control:
///
/// ```dart
/// FlowMenu(
///   entries: const [FlowMenuOption(id: 'files', label: 'Add Files or Photos')],
///   onSelected: (id) {
///     if (id == 'files') {
///       showFlowAttachmentPicker(options: options, onRejected: reject)
///           .then((picked) => setState(() => pending.addAll(picked)));
///     }
///   },
/// )
/// ```
///
/// Resolves empty when the dialog was dismissed, when everything chosen
/// was refused — each refusal reported through [onRejected] first — and
/// when the dialog could not open at all, which is reported as
/// [FlowAttachmentRejection.unreadable] under an empty name. It never
/// throws. Holding the result is the host's: pass it back through
/// `FlowComposer.attachments`.
///
/// Call it **synchronously from the gesture** — inside `onSelected`, not
/// from a post-frame callback — because on the web the dialog needs the
/// user activation the tap carried, and an await in between can spend it.
/// There is no re-entrancy guard here; the composer keeps its own for
/// its button, and a menu closes on pick, so a double open is unlikely.
///
/// On macOS the app needs the
/// `com.apple.security.files.user-selected.read-only` entitlement in both
/// `DebugProfile.entitlements` and `Release.entitlements`, or the dialog
/// opens onto nothing.
///
/// This is the only place in the package that knows about file_selector:
/// [FlowAttachmentTypeGroup] exists so that no host naming a file type
/// has to depend on it too.
Future<List<FlowAttachment>> showFlowAttachmentPicker({
  FlowAttachmentOptions options = const FlowAttachmentOptions(),
  void Function(String name, FlowAttachmentRejection reason)? onRejected,
}) async {
  final groups = options.accept.map(_typeGroup).toList(growable: false);

  // The dialog call is the first await on purpose: on the web it must
  // run inside the user activation of the gesture that got us here.
  final List<XFile> files;
  try {
    if (options.allowMultiple) {
      files = await openFiles(
        acceptedTypeGroups: groups,
        initialDirectory: options.initialDirectory,
        confirmButtonText: options.confirmButtonText,
      );
    } else {
      final file = await openFile(
        acceptedTypeGroups: groups,
        initialDirectory: options.initialDirectory,
        confirmButtonText: options.confirmButtonText,
      );
      files = file == null ? const <XFile>[] : <XFile>[file];
    }
  } catch (_) {
    // A dialog that fails to open is not a crash and must not become an
    // unhandled async error — the tap would look like it did nothing.
    // The web reports an input error this way, and so does macOS without
    // the file-read entitlement, which is the failure hosts hit most.
    // There is no file to name, so the reason carries it.
    onRejected?.call('', FlowAttachmentRejection.unreadable);
    return const <FlowAttachment>[];
  }
  if (files.isEmpty) return const <FlowAttachment>[];

  // Sized together rather than one after another: picking ten photos
  // otherwise pays ten sequential round trips before the first byte is
  // read, with the attach button held disabled throughout. The reads
  // themselves stay sequential inside the intake, where that ordering is
  // what bounds peak memory and keeps rejections in a predictable order.
  final candidates = await Future.wait(
    files.map((file) => _candidate(file, options.maxFileSize != null)),
  );
  return flowIntakeAttachments(
    candidates,
    options: options,
    onRejected: onRejected,
  );
}

/// Sizing a file up front is a stat on native and a blob's length on the
/// web, so it is worth doing — but only when there is a cap to check it
/// against, and never at the cost of the pick when it fails. A null size
/// just moves the check after the read.
Future<FlowFileCandidate> _candidate(XFile file, bool measure) async {
  int? size;
  if (measure) {
    try {
      size = await file.length();
    } catch (_) {
      size = null;
    }
  }
  return FlowFileCandidate(
    name: file.name,
    size: size,
    mimeType: file.mimeType,
    read: file.readAsBytes,
  );
}

/// Every family crosses over, because each platform throws when the one
/// it reads is empty — see [FlowAttachmentTypeGroup].
XTypeGroup _typeGroup(FlowAttachmentTypeGroup group) => XTypeGroup(
  label: group.label,
  extensions: group.extensions,
  mimeTypes: group.mimeTypes,
  uniformTypeIdentifiers: group.uniformTypeIdentifiers,
  webWildCards: group.webWildCards,
);
