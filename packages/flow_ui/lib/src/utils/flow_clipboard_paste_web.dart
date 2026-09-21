import 'dart:js_interop';
import 'dart:typed_data';

import 'flow_attachment_intake.dart';
import 'flow_web_dom.dart' as dom;

/// A live paste registration; [dispose] unhooks it.
class FlowPasteRegistration {
  FlowPasteRegistration._(this._target);

  final _PasteTarget _target;
  bool _disposed = false;

  /// Unhooks the registration. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister(_target);
  }
}

/// Hooks the clipboard's image paste up to a widget.
///
/// [isActive] decides whether this target is the one that should take the
/// paste — the composer answers with its own focus, so a Ctrl+V into some
/// other field on the page is left alone. It is read at paste time rather
/// than captured, so focus can change freely without re-registering.
///
/// [onPaste] receives only the files on the clipboard, and answers
/// whether it took any of them — which is what decides the browser's own
/// paste. A clipboard holding text is not this feature's business and is
/// left to the field's own paste, untouched.
FlowPasteRegistration? flowRegisterPasteTarget({
  required bool Function() isActive,
  required bool Function(List<FlowFileCandidate> files) onPaste,
}) {
  final target = _PasteTarget(isActive, onPaste);
  _register(target);
  return FlowPasteRegistration._(target);
}

class _PasteTarget {
  _PasteTarget(this.isActive, this.onPaste);

  final bool Function() isActive;
  final bool Function(List<FlowFileCandidate> files) onPaste;
}

final List<_PasteTarget> _targets = <_PasteTarget>[];
dom.EventListener? _listener;

void _register(_PasteTarget target) {
  _targets.add(target);
  if (_listener != null) return;

  // On the document rather than the Flutter view's host element, and in
  // the capture phase: the engine's hidden input for the focused text
  // field is not reliably inside that host, and capturing at the root
  // means the paste is seen before anything the engine does with it.
  // Scoping is [isActive]'s job instead of the DOM's, which is what lets
  // this stay correct wherever the engine puts that input.
  final listener = _handlePaste.toJS;
  _listener = listener;
  dom.document.addEventListener('paste', listener, true.toJS);
}

void _unregister(_PasteTarget target) {
  _targets.remove(target);
  final listener = _listener;
  if (_targets.isNotEmpty || listener == null) return;
  dom.document.removeEventListener('paste', listener, true.toJS);
  _listener = null;
}

void _handlePaste(dom.ClipboardEvent event) {
  _PasteTarget? target;
  for (final candidate in _targets) {
    if (candidate.isActive()) {
      target = candidate;
      break;
    }
  }
  if (target == null) return;

  final files = _candidates(event.clipboardData);
  if (files.isEmpty) return;

  // The target answers first, because a file on the clipboard is not the
  // same as a file this composer will take. Copying spreadsheet cells
  // puts an image *and* the text on the clipboard; suppressing the paste
  // before knowing the image passes would lose the text and attach
  // nothing. Only a file that will actually be taken earns the
  // suppression — which is what keeps the filename that rides along with
  // a copied file out of the draft.
  if (target.onPaste(files)) event.preventDefault();
}

List<FlowFileCandidate> _candidates(dom.DataTransfer? clipboard) {
  final files = clipboard?.files;
  if (files == null || files.length == 0) return const <FlowFileCandidate>[];

  final candidates = <FlowFileCandidate>[];
  for (var i = 0; i < files.length; i++) {
    final file = files.item(i);
    if (file == null) continue;
    final type = file.type;
    candidates.add(
      FlowFileCandidate(
        name: file.name,
        size: file.size,
        mimeType: type.isEmpty ? null : type,
        read: () => _readBytes(file),
      ),
    );
  }
  return candidates;
}

Future<Uint8List> _readBytes(dom.File file) async {
  final buffer = await file.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}
