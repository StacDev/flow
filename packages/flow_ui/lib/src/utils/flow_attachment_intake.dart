import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/flow_attachment.dart';
import '../models/flow_attachment_options.dart';

/// A file offered to the package, before it is anything renderable.
///
/// The one shape the intake understands, so the picker and the web drop
/// target agree without either knowing about the other: the picker wraps
/// an `XFile`, the drop target wraps a DOM `File`, and neither reads
/// bytes until [read] is called — which is what lets an oversized file be
/// refused without ever being pulled into memory.
@immutable
class FlowFileCandidate {
  const FlowFileCandidate({
    required this.name,
    required this.read,
    this.size,
    this.mimeType,
  });

  /// The file's name including its extension, e.g. 'sunset.jpg'. Becomes
  /// the attachment's label and the name a rejection is reported under.
  final String name;

  /// The encoded length in bytes when the platform knows it without
  /// reading. Null means the size check waits until the bytes land.
  final int? size;

  /// The platform's own type, e.g. 'image/jpeg', when it reports one.
  final String? mimeType;

  /// Pulls the encoded bytes into memory. Called at most once, and only
  /// after the type and (where known) the size have passed.
  final Future<Uint8List> Function() read;
}

/// Turns offered files into attachments, refusing what [options] does not
/// allow and reporting each refusal through [onRejected].
///
/// Refusals are per file: a drop of five images and one PDF under the
/// default options yields five attachments and one
/// [FlowAttachmentRejection.unsupportedType], not an empty result.
///
/// Images become tiles — [FlowAttachment.thumbnail] and
/// [FlowAttachment.preview] share one set of bytes, so the tile costs a
/// tile and the full-screen preview is only decoded if it is opened.
/// Everything else becomes a thumbnail-less attachment carrying its
/// extension as [FlowAttachment.kind], which is what the tile draws in
/// its pill.
Future<List<FlowAttachment>> flowIntakeAttachments(
  Iterable<FlowFileCandidate> candidates, {
  FlowAttachmentOptions options = const FlowAttachmentOptions(),
  void Function(String name, FlowAttachmentRejection reason)? onRejected,
}) async {
  final attachments = <FlowAttachment>[];

  for (final candidate in candidates) {
    // Enforced here rather than at each call site: a drop or a paste
    // carries whatever the pointer or the clipboard held, and every path
    // into the intake owes the same answer. The single slot goes to the
    // first file that *passes* — stopping at the first file offered
    // would let a refused one use up the slot while an acceptable one
    // sat behind it. The picker still honours the option earlier, by
    // opening a single-file dialog.
    if (!options.allowMultiple && attachments.isNotEmpty) break;

    if (!_accepts(options.accept, candidate)) {
      onRejected?.call(candidate.name, FlowAttachmentRejection.unsupportedType);
      continue;
    }

    final limit = options.maxFileSize;
    final declared = candidate.size;
    if (limit != null && declared != null && declared > limit) {
      onRejected?.call(candidate.name, FlowAttachmentRejection.tooLarge);
      continue;
    }

    final Uint8List bytes;
    try {
      bytes = await candidate.read();
    } catch (_) {
      onRejected?.call(candidate.name, FlowAttachmentRejection.unreadable);
      continue;
    }

    // The second size check catches the platforms that report no length
    // up front. It costs a read the first check would have saved, which
    // is the price of not stat-ing a file the package cannot see.
    if (limit != null && bytes.lengthInBytes > limit) {
      onRejected?.call(candidate.name, FlowAttachmentRejection.tooLarge);
      continue;
    }
    if (bytes.isEmpty) {
      onRejected?.call(candidate.name, FlowAttachmentRejection.unreadable);
      continue;
    }

    attachments.add(_attachmentFor(candidate, bytes, options));
  }

  return attachments;
}

/// Whether [candidate] passes the checks that can be made without
/// reading it — its type, and its size where the platform declared one.
///
/// For the caller that has to commit before the intake can finish: the
/// clipboard's paste handler must decide whether to suppress the
/// browser's own paste *during* the event, and cannot wait on bytes.
/// A true here is not a promise — the file may still fail once read —
/// but a false is reliable.
bool flowPreAccepts(
  FlowFileCandidate candidate,
  FlowAttachmentOptions options,
) {
  if (!_accepts(options.accept, candidate)) return false;
  final limit = options.maxFileSize;
  final declared = candidate.size;
  return limit == null || declared == null || declared <= limit;
}

FlowAttachment _attachmentFor(
  FlowFileCandidate candidate,
  Uint8List bytes,
  FlowAttachmentOptions options,
) {
  // The same list the tile decodes from, handed on so the host can
  // upload what it just attached without reaching back through the
  // ImageProvider for it.
  final mimeType = _mimeTypeOf(candidate);

  if (!_looksLikeImage(candidate)) {
    return FlowAttachment(
      id: _nextId(),
      kind: _kindOf(candidate.name),
      label: candidate.name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  // One MemoryImage behind both, so the bytes are held once and the two
  // decodes differ only in their cache key.
  //
  // The thumbnail goes out unbounded on purpose: the tile wraps whatever
  // it is handed in a ResizeImage of its own, sized to the tile and the
  // display's pixel ratio — which is a better cap than any constant here
  // — and ResizeImage cannot be nested, so capping it twice would assert
  // and paint the failure glyph instead of the picture. The preview has
  // no such cap of its own, so it keeps one.
  final source = MemoryImage(bytes);
  return FlowAttachment(
    id: _nextId(),
    thumbnail: source,
    preview: _bounded(source, options.previewMaxDimension),
    // No kind: a picture shows itself, and a pill over it would only
    // repeat what the tile already makes plain. Files keep theirs.
    label: candidate.name,
    bytes: bytes,
    mimeType: mimeType,
  );
}

/// The platform's own type where it reports one — the web does, from the
/// DOM File — and otherwise the extension's, because the native pickers
/// hand back a path and nothing else. A host uploading the file needs
/// something to declare, and 'the user picked a .png' is a better answer
/// than null.
String? _mimeTypeOf(FlowFileCandidate candidate) {
  final reported = candidate.mimeType;
  if (reported != null && reported.isNotEmpty) return reported.toLowerCase();
  final extension = _extensionOf(candidate.name);
  if (extension == null) return null;
  return _mimeTypesByExtension[extension];
}

/// The types Flutter's decoders handle, which is the set the picker
/// offers by default. Deliberately not a general-purpose table: anything
/// outside it comes back with a null [FlowAttachment.mimeType] rather
/// than a guess.
const Map<String, String> _mimeTypesByExtension = <String, String>{
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'heic': 'image/heic',
  'heif': 'image/heif',
};

/// Caps the decode at [maxDimension] on the longest edge. `fit` keeps the
/// aspect ratio, and refusing to upscale leaves a small image alone.
ImageProvider _bounded(ImageProvider source, int? maxDimension) {
  if (maxDimension == null) return source;
  return ResizeImage(
    source,
    width: maxDimension,
    height: maxDimension,
    policy: ResizeImagePolicy.fit,
    allowUpscaling: false,
  );
}

bool _accepts(
  List<FlowAttachmentTypeGroup> groups,
  FlowFileCandidate candidate,
) {
  if (groups.isEmpty) return true;

  final extension = _extensionOf(candidate.name);
  final mimeType = candidate.mimeType?.toLowerCase();

  // The effective type: reported by the platform, or derived from the
  // extension, so the UTI check below has something to judge against on
  // platforms whose pickers report nothing.
  final effectiveMime = _mimeTypeOf(candidate);

  for (final group in groups) {
    if (group.allowsAny) return true;
    if (extension != null && group.extensions.any((e) => _same(e, extension))) {
      return true;
    }
    if (mimeType != null) {
      if (group.mimeTypes.any((m) => _same(m, mimeType))) return true;
      if (group.webWildCards.any((w) => _matchesWildCard(w, mimeType))) {
        return true;
      }
    }
    // Uniform type identifiers — the family iOS requires — judged
    // through the root-type table below, so 'public.image' accepts what
    // `image/*` would. A group naming a UTI the table does not know, and
    // nothing else this function can read, defers to acceptance rather
    // than refusing: the group is well-formed by its own documentation,
    // and turning it into a total block on drops and pastes would be
    // worse than letting the odd file through. The deferral is per
    // group and only for the unjudgeable — a checkable group elsewhere
    // in the list neither widens nor narrows it.
    if (group.uniformTypeIdentifiers.isNotEmpty) {
      var sawUnknown = false;
      for (final uti in group.uniformTypeIdentifiers) {
        final prefixes = _utiMimePrefixes[uti.toLowerCase()];
        if (prefixes == null) {
          sawUnknown = true;
          continue;
        }
        if (effectiveMime != null && prefixes.any(effectiveMime.startsWith)) {
          return true;
        }
      }
      final judgeable =
          !sawUnknown &&
          effectiveMime != null &&
          group.uniformTypeIdentifiers.isNotEmpty;
      final hasOtherFamilies =
          group.extensions.isNotEmpty ||
          group.mimeTypes.isNotEmpty ||
          group.webWildCards.isNotEmpty;
      if (!judgeable && !hasOtherFamilies) return true;
    }
  }
  return false;
}

/// What the common uniform type identifiers accept, as MIME prefixes —
/// the empty prefix is the roots that accept anything, and a list because
/// some identifiers span more than one family: Apple's
/// `public.audiovisual-content` is the parent of both `public.movie` and
/// `public.audio`, so a group naming it takes either. Enough to judge the
/// groups hosts actually write; anything absent defers.
const Map<String, List<String>> _utiMimePrefixes = <String, List<String>>{
  'public.item': <String>[''],
  'public.data': <String>[''],
  'public.content': <String>[''],
  'public.image': <String>['image/'],
  'public.movie': <String>['video/'],
  'public.video': <String>['video/'],
  'public.audiovisual-content': <String>['video/', 'audio/'],
  'public.audio': <String>['audio/'],
  'public.text': <String>['text/'],
  'public.plain-text': <String>['text/plain'],
  'com.adobe.pdf': <String>['application/pdf'],
  'public.png': <String>['image/png'],
  'public.jpeg': <String>['image/jpeg'],
  'com.compuserve.gif': <String>['image/gif'],
  'public.heic': <String>['image/heic'],
  'public.heif': <String>['image/heif'],
  'org.webmproject.webp': <String>['image/webp'],
};

/// Whether the file is something Flutter's decoders can draw, which is
/// what decides tile-with-image against tile-with-pill.
///
/// Matched against the formats the framework actually decodes rather
/// than the `image/` prefix: SVG, TIFF and AVIF all announce themselves
/// as images and none of them opens. Treating those as files gives a
/// tile with a type pill, which is a truthful thing to look at — where
/// the prefix test gave a permanently blank one.
bool _looksLikeImage(FlowFileCandidate candidate) {
  final mimeType = candidate.mimeType?.toLowerCase();
  if (mimeType != null && mimeType.isNotEmpty) {
    return _mimeTypesByExtension.containsValue(mimeType);
  }
  final extension = _extensionOf(candidate.name);
  if (extension == null) return false;
  return _mimeTypesByExtension.containsKey(extension);
}

/// 'sunset.jpg' → 'JPG'. Null when the name carries no extension, or one
/// too long to read as a type — the pill has room for a few characters.
String? _kindOf(String name) {
  final extension = _extensionOf(name);
  if (extension == null || extension.length > 4) return null;
  return extension.toUpperCase();
}

String? _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toLowerCase();
}

bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();

/// 'image/*' against 'image/png'. A bare '*' or '*/*' matches anything.
bool _matchesWildCard(String wildCard, String mimeType) {
  final pattern = wildCard.toLowerCase();
  if (pattern == '*' || pattern == '*/*') return true;
  if (!pattern.endsWith('/*')) return _same(pattern, mimeType);
  return mimeType.startsWith(pattern.substring(0, pattern.length - 1));
}

int _sequence = 0;

/// Unique within the session, which is all an attachment id has to be:
/// the host reports it back through `onRemoveAttachment` and `onTap`.
String _nextId() => 'flow-attachment-${_sequence++}';
