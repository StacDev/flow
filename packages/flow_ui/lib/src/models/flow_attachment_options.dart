import 'package:flutter/foundation.dart';

/// What the built-in picker offers and how what comes back is decoded.
///
/// Passed to `FlowComposer.attachmentOptions`,
/// `FlowChatView.attachmentOptions` and `showFlowAttachmentPicker`; the
/// defaults accept images only, on
/// every platform, and cap the full-screen decode well inside a
/// rasteriser's budget.
///
/// ```dart
/// FlowComposer(
///   onAttachmentsPicked: (picked) => setState(() => _pending.addAll(picked)),
///   attachmentOptions: const FlowAttachmentOptions(
///     allowMultiple: false,
///     maxFileSize: 10 * 1024 * 1024,
///   ),
/// )
/// ```
@immutable
class FlowAttachmentOptions {
  const FlowAttachmentOptions({
    this.accept = const <FlowAttachmentTypeGroup>[
      FlowAttachmentTypeGroup.images,
    ],
    this.allowMultiple = true,
    this.previewMaxDimension = 2048,
    this.maxFileSize,
    this.initialDirectory,
    this.confirmButtonText,
  });

  /// Every type the platform will offer, and no rejection on type.
  ///
  /// Files with no image of their own arrive as thumbnail-less
  /// attachments carrying their extension as `FlowAttachment.kind`, which
  /// is what the tile draws in its pill.
  static const FlowAttachmentOptions any = FlowAttachmentOptions(
    accept: <FlowAttachmentTypeGroup>[],
  );

  /// The type filters the dialog opens with. Empty means any file.
  ///
  /// Also the bar a dropped or pasted file is held to — those never pass
  /// through a dialog, so a file outside these groups is refused and
  /// reported to `onAttachmentRejected` with
  /// [FlowAttachmentRejection.unsupportedType].
  final List<FlowAttachmentTypeGroup> accept;

  /// Whether the dialog lets more than one file be chosen. Drops and
  /// pastes always carry whatever the pointer or clipboard held; when
  /// this is false the single slot goes to the first file that passes
  /// the checks, and the refused ones ahead of it are still reported.
  final bool allowMultiple;

  /// The longest edge, in pixels, the full-screen preview is decoded to.
  /// Null decodes at full size — a 48MP photo then costs ~190MB of
  /// raster.
  ///
  /// There is deliberately no thumbnail equivalent: the tile sizes its
  /// own decode to the tile and the display's pixel ratio, which beats
  /// any constant set from out here, and a second cap on top of it would
  /// not compose — `ResizeImage` asserts rather than nests.
  final int? previewMaxDimension;

  /// The largest file accepted, in bytes. Null accepts any size — a cap
  /// is policy, and policy is the host's. Anything larger is reported to
  /// `onAttachmentRejected` with [FlowAttachmentRejection.tooLarge].
  final int? maxFileSize;

  /// The directory the dialog opens in, where the platform honours one.
  final String? initialDirectory;

  /// The dialog's confirm button, where the platform lets it be named.
  /// Unset leaves the platform's own wording, which is already localized.
  final String? confirmButtonText;
}

/// A named set of file types for the picker's filter.
///
/// The platforms disagree about how types are named, and each one throws
/// when the family it wants is empty: Apple platforms want
/// [uniformTypeIdentifiers], Windows wants [extensions], Linux and
/// Android take either [extensions] or [mimeTypes], and the web wants
/// [webWildCards]. A group meant to work everywhere fills in all four —
/// [images] does.
///
/// A group with all four families empty allows any file.
@immutable
class FlowAttachmentTypeGroup {
  const FlowAttachmentTypeGroup({
    this.label,
    this.extensions = const <String>[],
    this.mimeTypes = const <String>[],
    this.uniformTypeIdentifiers = const <String>[],
    this.webWildCards = const <String>[],
  });

  /// The images the platform decoders handle, named in all four
  /// families. `public.image` is the root Apple image type, so every
  /// format conforming to it is offered.
  static const FlowAttachmentTypeGroup images = FlowAttachmentTypeGroup(
    extensions: <String>[
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
    ],
    // Enumerated rather than 'image/*' because Linux hands these to
    // gtk_file_filter_add_mime_type(), which wants concrete types.
    mimeTypes: <String>[
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      'image/bmp',
      'image/heic',
      'image/heif',
    ],
    uniformTypeIdentifiers: <String>['public.image'],
    webWildCards: <String>['image/*'],
  );

  /// The group's name in the dialog's filter list, where the platform
  /// draws one. Null leaves it unnamed — the package ships no copy, so
  /// set this from the host's localizations to have it read well on
  /// Windows and Linux.
  final String? label;

  /// Extensions without the dot, e.g. `['png', 'jpg']`. Required by
  /// Windows; also what a dropped file's name is checked against.
  final List<String> extensions;

  /// Concrete MIME types, e.g. `['image/png']`. Used by Linux and
  /// Android.
  final List<String> mimeTypes;

  /// Apple uniform type identifiers, e.g. `['public.image']`. Required
  /// by iOS; used by macOS.
  final List<String> uniformTypeIdentifiers;

  /// Web accept wildcards, e.g. `['image/*']`. Used by the web.
  final List<String> webWildCards;

  /// Whether this group filters nothing out.
  bool get allowsAny =>
      extensions.isEmpty &&
      mimeTypes.isEmpty &&
      uniformTypeIdentifiers.isEmpty &&
      webWildCards.isEmpty;
}

/// Why a file the host offered was not turned into an attachment,
/// reported through `onAttachmentRejected` alongside the file's name.
///
/// The package has no copy to show for these — surfacing them is the
/// host's, which is also where the wording can be localized.
enum FlowAttachmentRejection {
  /// Larger than `FlowAttachmentOptions.maxFileSize`.
  tooLarge,

  /// Outside every group in `FlowAttachmentOptions.accept`. Only
  /// reachable for files that never passed through the dialog's filter —
  /// a drop, or a platform that lets the filter be overridden.
  unsupportedType,

  /// The bytes could not be read: the platform refused the file, or it
  /// came back empty. Also how a dialog that failed to open is reported,
  /// with an empty name, since there is no file to name.
  ///
  /// Not a decode check — nothing here opens the file. A format that
  /// announces itself as an image and cannot be decoded is accepted as a
  /// file instead, and its tile shows a type pill rather than a picture.
  unreadable,
}
