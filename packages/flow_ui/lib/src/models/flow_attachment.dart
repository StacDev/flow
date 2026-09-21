import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A file the host wants shown as a tile.
///
/// ```dart
/// FlowAttachment(
///   id: 'img-1',
///   thumbnail: NetworkImage(url),
///   kind: 'JPG',
///   label: 'sunset.jpg',
/// )
/// ```
///
/// [thumbnail] is any `ImageProvider`, so network, file, memory and asset
/// images all work — the package never loads anything itself. Leave it null
/// for a file with no image of its own, such as a document: the tile then
/// draws its ground and, when [kind] is set, the type pill.
///
/// Attachments the package produced — from the composer's picker or a
/// drop — also carry [bytes] and [mimeType], which is what a host uploads
/// with. Nothing in flow_ui reads them.
@immutable
class FlowAttachment {
  const FlowAttachment({
    required this.id,
    this.thumbnail,
    this.preview,
    this.kind,
    this.label,
    this.tooltip,
    this.bytes,
    this.mimeType,
  });

  /// Reported through `onTap` and `onRemove`.
  final String id;

  /// Drawn in the tile, decoded down to the tile's size. Null for an
  /// attachment with no image to show.
  final ImageProvider? thumbnail;

  /// Drawn full-screen by `FlowAttachmentPreview`; defaults to [thumbnail].
  /// Supply the full-resolution image here when [thumbnail] is a small crop.
  final ImageProvider? preview;

  /// Host-supplied type label for the tile's pill, e.g. 'PDF' or 'JPG'. Drawn
  /// verbatim — the package derives nothing from [label] — and a null [kind]
  /// leaves the pill off.
  final String? kind;

  /// Host-supplied name, e.g. 'sunset.jpg'. Used as the accessibility label
  /// and as the tooltip fallback; the square tile has no room to draw it.
  final String? label;

  /// Host-localized tooltip; falls back to [label].
  final String? tooltip;

  /// The file as it was read, when the package read it — filled in for
  /// anything picked through `FlowComposer.onAttachmentsPicked` or
  /// dropped, and null for an attachment the host built from a URL.
  ///
  /// Nothing in flow_ui touches this: the package draws [thumbnail] and
  /// stops. It is here because attaching a file is only half a feature
  /// without a way to send it, and reaching back through the
  /// [ImageProvider] to find the bytes again is not an API.
  ///
  /// The same list the [thumbnail] decodes from, so carrying it costs
  /// nothing beyond what the tile already holds — but it is the *encoded*
  /// file, so a pending strip holds every original in memory until it is
  /// sent or removed.
  final Uint8List? bytes;

  /// The type of [bytes], e.g. 'image/png'. Reported by the platform
  /// where it says, and otherwise derived from the file's extension, so
  /// that an upload has something to declare either way.
  final String? mimeType;

  /// The image to show full-screen: [preview] when supplied, otherwise
  /// [thumbnail]. Null when there is no image at all, which is what makes an
  /// attachment unopenable rather than merely thumbnail-less.
  ImageProvider? get previewImage => preview ?? thumbnail;
}
