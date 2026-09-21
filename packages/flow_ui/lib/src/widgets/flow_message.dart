import 'package:material_ui/material_ui.dart';

import '../models/flow_attachment.dart';
import '../models/flow_message_data.dart';
import '../models/flow_message_part.dart';
import '../styles/flow_message_style.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_attachment_error.dart';
import '../utils/flow_selection.dart';
import '../utils/flow_shimmer_sweep.dart';
import 'flow_attachment_group.dart';
import 'flow_attachment_preview.dart';
import 'flow_code_block.dart';
import 'flow_confirmation.dart';
import 'flow_error_state.dart';
import 'flow_markdown.dart';
import 'flow_streaming_text.dart';
import 'flow_thinking_indicator.dart';
import 'flow_tool.dart';

/// Renders a [FlowCustomPart]; return null to skip it.
///
/// A full renderer registry waits for the Chat View surface — this
/// callback is the extension seam until then.
typedef FlowCustomPartBuilder =
    Widget? Function(
      BuildContext context,
      FlowMessageData message,
      FlowCustomPart part,
    );

/// Renders a single [FlowMessageData] with role-appropriate presentation:
///
/// - **user** — right-aligned bubble, a wash of ink over the page.
/// - **assistant** — plain full-width content, no bubble.
/// - **system** — centered muted text (notices, dividers).
///
/// [FlowMessageStatus.pending] assistant messages show a
/// [FlowThinkingIndicator]; [FlowMessageStatus.streaming] animates the last
/// text part via [FlowStreamingText]. A [FlowMessageStatus.error] assistant
/// turn keeps its parts in normal ink and closes with a [FlowErrorState]
/// card — the message's own [FlowErrorPart], or a default one when the host
/// supplies none; an error user bubble recolors to the error container.
/// A [FlowConfirmationPart] renders a [FlowConfirmation] card, its buttons
/// reporting through [onConfirmationRespond]; a [FlowToolPart] renders a
/// [FlowTool] card, its blocks copying through [onCodeCopy] like any code
/// part.
class FlowMessage extends StatelessWidget {
  const FlowMessage(
    this.message, {
    super.key,
    this.customPartBuilder,
    this.onAttachmentTap,
    this.previewCloseTooltip,
    this.onCodeCopy,
    this.copiedCodePart,
    this.codeCopyTooltip,
    this.markdown = true,
    this.onLinkTap,
    this.onRetry,
    this.errorTitle,
    this.retryLabel,
    this.onConfirmationRespond,
    this.approveLabel,
    this.rejectLabel,
    this.approvedLabel,
    this.rejectedLabel,
    this.toolInputLabel,
    this.toolOutputLabel,
    this.leading,
    this.footer,
    this.maxBubbleWidthFraction = 0.75,
    this.textStyle,
    this.charactersPerSecond = 300,
    this.thinkingLabel,
    this.bubbleRadius,
    this.bubblePadding,
    this.style,
  }) : assert(
         maxBubbleWidthFraction > 0 && maxBubbleWidthFraction <= 1,
         'maxBubbleWidthFraction must be in (0, 1]',
       );

  /// The view model to render.
  final FlowMessageData message;

  /// Hook for [FlowCustomPart] content.
  final FlowCustomPartBuilder? customPartBuilder;

  /// Called with the tapped attachment's id, *instead of* opening the
  /// built-in full-screen preview. Sent attachments are never removable, so
  /// this is the only intent they report — and a host that just wants to
  /// observe the tap should call `showFlowAttachmentPreview` from the
  /// handler, or the images stop opening.
  final ValueChanged<String>? onAttachmentTap;

  /// Host-localized label for the built-in preview's close button.
  final String? previewCloseTooltip;

  /// Copy intent from a [FlowCodePart]'s block, handed the part so the
  /// host knows which code to write to the clipboard. Null hides every
  /// block's copy affordance.
  final ValueChanged<FlowCodePart>? onCodeCopy;

  /// The part whose block shows the copied check — pass back the instance
  /// received from [onCodeCopy] for as long as the confirmation should
  /// last; the host owns the timing.
  final FlowCodePart? copiedCodePart;

  /// Host-localized label for each code block's copy affordance.
  final String? codeCopyTooltip;

  /// Retry intent from the turn's error card — the default card a failed
  /// assistant turn renders, or any [FlowErrorPart]'s (unless the part
  /// says `retryable: false`). Null hides every retry affordance.
  final VoidCallback? onRetry;

  /// Whether assistant text parts render as markdown (`FlowMarkdown`).
  /// User bubbles and system notices always render plain — what the user
  /// typed is a transcription, not prose to typeset. Pass false for
  /// hosts whose assistant text is literal.
  final bool markdown;

  /// Link intent from markdown content, handed the tapped href. Null
  /// renders links as plain prose; the package never launches URLs.
  final ValueChanged<String>? onLinkTap;

  /// Host-localized headline for the error cards, e.g. 'Connection
  /// error'. Null lets each card's message take the glyph row.
  final String? errorTitle;

  /// Host-localized label for the error cards' retry pill; null renders
  /// the pill glyph-only.
  final String? retryLabel;

  /// Approve/reject intent from a [FlowConfirmationPart]'s card, handed
  /// the part and the decision. Null renders every pending card without
  /// buttons — a read-only notice.
  final void Function(FlowConfirmationPart part, bool approved)?
  onConfirmationRespond;

  /// Host-localized labels for the confirmation cards — the approve and
  /// reject buttons, and the settled row's approved and rejected text. A
  /// null button label hides that button; a null settled label leaves the
  /// outcome glyph alone.
  final String? approveLabel;
  final String? rejectLabel;
  final String? approvedLabel;
  final String? rejectedLabel;

  /// Host-localized section labels over a tool card's input and output
  /// blocks, e.g. 'Input' and 'Output'. Null lets each block fall back to
  /// its language id, as a fence does.
  final String? toolInputLabel;
  final String? toolOutputLabel;

  /// Slot beside the content, e.g. an avatar.
  final Widget? leading;

  /// Slot below the content, e.g. message actions.
  final Widget? footer;

  /// User-bubble max width as a fraction of the available width.
  final double maxBubbleWidthFraction;

  /// Override for text parts; merged over `bodyLarge` + the role foreground.
  final TextStyle? textStyle;

  /// Forwarded to [FlowStreamingText] while streaming.
  final double charactersPerSecond;

  /// Host-localized label beside the thinking glyph on a pending message,
  /// e.g. 'Thinking…'. Null shows the glyph alone — the package ships no
  /// strings.
  final String? thinkingLabel;

  /// Corner radius of the user bubble, its error state included.
  /// Defaults to the design's 12.
  final BorderRadius? bubbleRadius;

  /// Inside the user bubble. Defaults to the design's 16/10.
  final EdgeInsetsGeometry? bubblePadding;

  /// Per-instance restyling, merged over [FlowTheme.messageStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowMessageStyle? style;

  /// The design draws the bubble at 16/10 — ten sits between the spacing
  /// steps, like the attachment pill's one-pixel inset.
  static const double _bubbleVerticalPadding = 10;

  /// The design's bubble: 12px corners on 16px side padding.
  static const BorderRadius _bubbleRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const double _bubbleHorizontalPadding = 16;

  /// Gaps: between a message's parts, under a user bubble, under assistant
  /// content before its actions, and beside a leading slot.
  static const double _partGap = 8;
  static const double _userFooterGap = 4;
  static const double _assistantFooterGap = 12;
  static const double _leadingGap = 12;

  /// A sent image, lifted out of the user bubble to sit above it: a 116
  /// square tile with the picture cover-cropped inside, under the
  /// bubble's 12px corner and an `outline` hairline — the faint one —
  /// that firms up to `outlineVariant` while the pointer is over it.
  /// Tiles run in a row
  /// from the trailing edge with the bubble world's 8 between them,
  /// wrapping when a turn carries more than fit, and sit 12 above the
  /// bubble.
  static const double _sentImageSize = 116;
  static const double _sentImageSpacing = 8;
  static const double _sentAttachmentsGap = 12;

  /// A large-format image part: capped at 320 wide on the bubble world's
  /// 12px corner, the landed picture fading in as it decodes.
  static const double _imageMaxWidth = 320;

  /// The failure glyph on a large-format picture, sized up from the
  /// tile's 24 to suit the frame it sits in.
  static const double _imageErrorGlyph = 32;
  static const BorderRadius _imageRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const Duration _imageFade = Duration(milliseconds: 180);

  bool get _isError => message.status == FlowMessageStatus.error;

  @override
  Widget build(BuildContext context) {
    return switch (message.role) {
      FlowMessageRole.user => _buildUser(context),
      FlowMessageRole.assistant => _buildAssistant(context),
      FlowMessageRole.system => _buildSystem(context),
    };
  }

  Widget _buildUser(BuildContext context) {
    final colors = context.flowColors;
    final effective = context.flowTheme.messageStyle?.merge(style) ?? style;

    // Attachments lift out of the bubble and sit above it as cards, the
    // way the picture and the caption read as two things in a chat: the
    // file, then what was said about it. A turn that is only a picture
    // draws no bubble at all.
    final sent = [
      for (final part in message.parts)
        if (part is FlowAttachmentPart) ...part.attachments,
    ];
    final hasBubble = message.parts.any((part) => part is! FlowAttachmentPart);

    final bubble = Container(
      padding:
          bubblePadding ??
          const EdgeInsets.symmetric(
            horizontal: _bubbleHorizontalPadding,
            vertical: _bubbleVerticalPadding,
          ),
      decoration: BoxDecoration(
        // A failed turn keeps the error treatment regardless of style.
        color: _isError
            ? colors.errorContainer
            : effective?.bubbleColor ?? colors.surfaceContainerLow,
        borderRadius: bubbleRadius ?? _bubbleRadius,
      ),
      child: _buildParts(
        context,
        _isError
            ? colors.onErrorContainer
            : effective?.bubbleTextColor ?? colors.onSurface,
        liftAttachments: true,
      ),
    );

    final column = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth * maxBubbleWidthFraction
            : double.infinity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sent.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _buildSentAttachments(context, sent, effective),
              ),
            if (sent.isNotEmpty && hasBubble)
              const SizedBox(height: _sentAttachmentsGap),
            if (hasBubble)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: bubble,
              ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: _userFooterGap),
                child: footer,
              ),
          ],
        );
      },
    );

    if (leading == null) return column;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: column),
        const SizedBox(width: _leadingGap),
        leading!,
      ],
    );
  }

  Widget _buildAssistant(BuildContext context) {
    final colors = context.flowColors;

    Widget content;
    if (message.status == FlowMessageStatus.pending && message.parts.isEmpty) {
      content = FlowThinkingIndicator(label: thinkingLabel);
    } else if (_isError &&
        !message.parts.any((part) => part is FlowErrorPart)) {
      // A failure must not swallow what the user has already read: parts
      // keep their normal ink, and a default card closes the turn when
      // the host supplied no FlowErrorPart of its own.
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.parts.isNotEmpty) ...[
            _buildParts(context, colors.onSurface),
            const SizedBox(height: _partGap),
          ],
          FlowErrorState(
            title: errorTitle,
            retryLabel: retryLabel,
            onRetry: onRetry,
          ),
        ],
      );
    } else {
      content = _buildParts(context, colors.onSurface);
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(top: _assistantFooterGap),
            child: footer,
          ),
      ],
    );

    if (leading == null) return column;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading!,
        const SizedBox(width: _leadingGap),
        Expanded(child: column),
      ],
    );
  }

  Widget _buildSystem(BuildContext context) {
    final colors = context.flowColors;
    final style = context.flowTypography.bodySmall
        .copyWith(color: colors.onSurfaceVariant)
        .merge(textStyle);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final part in message.parts)
            switch (part) {
              FlowTextPart(:final text) => FlowSelectionBlock(
                child: Text(text, style: style, textAlign: TextAlign.center),
              ),
              // System messages are centered notices; attachments, images,
              // code, failures, confirmations and tool calls belong to
              // user and assistant turns.
              FlowAttachmentPart() ||
              FlowImagePart() ||
              FlowCodePart() ||
              FlowErrorPart() ||
              FlowConfirmationPart() ||
              FlowToolPart() => const SizedBox.shrink(),
              FlowCustomPart() =>
                customPartBuilder?.call(context, message, part) ??
                    const SizedBox.shrink(),
            },
        ],
      ),
    );
  }

  /// A large-format image, or its generating placeholder: the same
  /// rounded frame at the part's aspect ratio, shimmering with the
  /// container washes until the host re-renders with the picture set.
  /// Tapping a landed image opens the full-screen preview, reusing the
  /// attachments' viewer.
  Widget _buildImagePart(BuildContext context, FlowImagePart part) {
    final colors = context.flowColors;
    final image = part.image;

    final Widget child;
    if (image == null) {
      // Opaque under the mask — the sweep multiplies by the child's
      // alpha, so the washes carry the translucency themselves.
      child = FlowShimmerSweep(
        baseColor: colors.surfaceContainerLow,
        highlightColor: colors.surfaceContainerHigh,
        child: const ColoredBox(
          color: Color(0xFFFFFFFF),
          child: SizedBox.expand(),
        ),
      );
    } else {
      Widget picture = Image(
        image: image,
        fit: BoxFit.cover,
        // The package's rule for host-supplied images: a dead provider
        // draws the shared failure treatment, never the framework's red
        // error box, and never an unhandled exception per rebuild.
        errorBuilder: flowAttachmentErrorBuilder(iconSize: _imageErrorGlyph),
        // The frame holds the part's shape while the image decodes and
        // fades in, so the layout never jumps.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : _imageFade,
            child: child,
          );
        },
      );
      picture = GestureDetector(
        onTap: () => showFlowAttachmentPreview(
          context: context,
          attachments: [
            FlowAttachment(
              id: 'image',
              thumbnail: image,
              label: part.semanticLabel,
            ),
          ],
          closeTooltip: previewCloseTooltip,
        ),
        child: picture,
      );
      child = ColoredBox(color: colors.surfaceContainerLow, child: picture);
    }

    return Semantics(
      label: part.semanticLabel,
      image: image != null,
      // Tapping a landed picture opens the full-screen preview, so it is
      // a button as well as an image — otherwise the preview is
      // undiscoverable to a screen reader.
      button: image != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _imageMaxWidth),
        child: ClipRRect(
          borderRadius: _imageRadius,
          child: AspectRatio(aspectRatio: part.aspectRatio, child: child),
        ),
      ),
    );
  }

  /// The sent-attachments block above a user bubble: every image as a
  /// card, anything without a picture of its own as the tile it always
  /// was, wrapping from the trailing edge.
  Widget _buildSentAttachments(
    BuildContext context,
    List<FlowAttachment> attachments,
    FlowMessageStyle? effective,
  ) {
    final images = [
      for (final attachment in attachments)
        if (attachment.previewImage != null) attachment,
    ];
    final files = [
      for (final attachment in attachments)
        if (attachment.previewImage == null) attachment,
    ];

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: _sentImageSpacing,
      runSpacing: _sentImageSpacing,
      children: [
        for (var i = 0; i < images.length; i++)
          _buildSentImage(context, images, i, effective),
        if (files.isNotEmpty)
          FlowAttachmentGroup(
            attachments: files,
            layout: FlowAttachmentLayout.wrap,
            onTap: onAttachmentTap,
            previewCloseTooltip: previewCloseTooltip,
          ),
      ],
    );
  }

  Widget _buildSentImage(
    BuildContext context,
    List<FlowAttachment> images,
    int index,
    FlowMessageStyle? effective,
  ) {
    final colors = context.flowColors;
    final attachment = images[index];
    final onAttachmentTap = this.onAttachmentTap;
    return _SentImageTile(
      // The thumbnail, not previewImage: the package's own attachments
      // carry a preview bounded for the full-screen viewer, and drawing
      // that in a 116 tile would decode the picture at 2048.
      image: attachment.thumbnail ?? attachment.preview!,
      label: attachment.tooltip ?? attachment.label,
      groundColor: effective?.attachmentCardColor,
      borderColor: effective?.attachmentCardBorderColor ?? colors.outline,
      hoverBorderColor:
          effective?.attachmentCardHoverBorderColor ?? colors.outlineVariant,
      // The host's handler replaces the preview, as it does on the
      // tiles; otherwise the built-in viewer opens on this picture with
      // the turn's others a page away.
      onTap: onAttachmentTap != null
          ? () => onAttachmentTap(attachment.id)
          : () => showFlowAttachmentPreview(
              context: context,
              attachments: images,
              initialIndex: index,
              closeTooltip: previewCloseTooltip,
            ),
    );
  }

  /// The message's parts as a column, text parts in [foreground].
  Widget _buildParts(
    BuildContext context,
    Color foreground, {
    bool liftAttachments = false,
  }) {
    final typography = context.flowTypography;
    final style = typography.bodyLarge
        .copyWith(color: foreground)
        .merge(textStyle);
    final onCodeCopy = this.onCodeCopy;
    final onConfirmationRespond = this.onConfirmationRespond;

    // Only text parts get the streaming reveal; a message that ends in a
    // code part streams its code without one (FlowCodeBlock renders each
    // delivery whole).
    final lastTextIndex = message.parts.lastIndexWhere(
      (part) => part is FlowTextPart,
    );

    final children = <Widget>[];
    for (var i = 0; i < message.parts.length; i++) {
      final part = message.parts[i];
      final child = switch (part) {
        // Assistant prose typesets as markdown by default; the user's
        // words render exactly as typed.
        FlowTextPart(:final text)
            when markdown && message.role == FlowMessageRole.assistant =>
          FlowMarkdown(
            text: text,
            isStreaming:
                message.status == FlowMessageStatus.streaming &&
                i == lastTextIndex,
            style: style,
            charactersPerSecond: charactersPerSecond,
            onLinkTap: onLinkTap,
            onCodeCopy: onCodeCopy,
            copiedCodePart: copiedCodePart,
            codeCopyTooltip: codeCopyTooltip,
          ),
        FlowTextPart(:final text) => FlowStreamingText(
          text: text,
          isStreaming:
              message.status == FlowMessageStatus.streaming &&
              i == lastTextIndex,
          style: style,
          charactersPerSecond: charactersPerSecond,
        ),
        // Wraps rather than scrolls: a bubble is capped well below the width
        // of a long strip, and content already sent must not be hidden
        // behind a scroll with no scrollbar. Null, not an empty box, so an
        // empty list doesn't leave a gap before the next part.
        // Lifted out of the user bubble by [_buildUser], which draws
        // them above it instead.
        FlowAttachmentPart() when liftAttachments => null,
        FlowAttachmentPart(:final attachments) =>
          attachments.isEmpty
              ? null
              : FlowAttachmentGroup(
                  attachments: attachments,
                  layout: FlowAttachmentLayout.wrap,
                  onTap: onAttachmentTap,
                  previewCloseTooltip: previewCloseTooltip,
                ),
        FlowImagePart() => _buildImagePart(context, part),
        FlowCodePart(:final code, :final language, :final filename) =>
          FlowCodeBlock(
            code: code,
            language: language,
            filename: filename,
            onCopy: onCodeCopy == null ? null : () => onCodeCopy(part),
            copyTooltip: codeCopyTooltip,
            copied: identical(part, copiedCodePart),
            // Streaming only while it's the growing tail — a part with
            // content after it is already complete.
            isStreaming:
                message.status == FlowMessageStatus.streaming &&
                i == message.parts.length - 1,
          ),
        // `message` names the FlowMessageData here, so the part's text
        // binds under its own name.
        FlowErrorPart(message: final errorMessage, :final retryable) =>
          FlowErrorState(
            title: errorTitle,
            message: errorMessage,
            retryLabel: retryLabel,
            onRetry: retryable ? onRetry : null,
          ),
        // Bound whole rather than destructured: the closures hand the
        // part back so the host can find the request it belongs to.
        FlowConfirmationPart confirmation => FlowConfirmation(
          title: confirmation.title,
          message: confirmation.message,
          status: confirmation.status,
          approveLabel: approveLabel,
          rejectLabel: rejectLabel,
          approvedLabel: approvedLabel,
          rejectedLabel: rejectedLabel,
          onApprove: onConfirmationRespond == null
              ? null
              : () => onConfirmationRespond(confirmation, true),
          onReject: onConfirmationRespond == null
              ? null
              : () => onConfirmationRespond(confirmation, false),
        ),
        // Bound whole for the same reason; the blocks' copy intent goes
        // through [onCodeCopy] like any code part's.
        FlowToolPart tool => FlowTool(
          name: tool.name,
          title: tool.title,
          detail: tool.detail,
          status: tool.status,
          input: tool.input,
          inputLanguage: tool.inputLanguage,
          output: tool.output,
          outputLanguage: tool.outputLanguage,
          errorMessage: tool.errorMessage,
          semanticLabel: tool.semanticLabel,
          inputLabel: toolInputLabel,
          outputLabel: toolOutputLabel,
          onCodeCopy: onCodeCopy,
          copiedCodePart: copiedCodePart,
          codeCopyTooltip: codeCopyTooltip,
        ),
        FlowCustomPart() => customPartBuilder?.call(context, message, part),
      };
      if (child == null) continue;
      // One wrapper type for every part, so the column matches unkeyed
      // parts by position and a keyed one by its key — which must sit on
      // the outermost child, where the column sees it. A tool card is
      // keyed by its call id so its disclosure survives the turn's parts
      // changing shape; a PageStorageKey rather than a ValueKey, since
      // the thread remounts its list at the viewport flip and the card
      // reads its disclosure back through PageStorage.
      final id = part is FlowToolPart ? part.id : null;
      children.add(
        Padding(
          key: id == null ? null : PageStorageKey<String>(id),
          padding: children.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.only(top: _partGap),
          child: child,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// One sent image above a user bubble: a square tile, the picture
/// cover-cropped inside, under a hairline that changes colour while the
/// pointer is over it — the one bit of state the tile owns.
class _SentImageTile extends StatefulWidget {
  const _SentImageTile({
    required this.image,
    required this.label,
    required this.groundColor,
    required this.borderColor,
    required this.hoverBorderColor,
    required this.onTap,
  });

  final ImageProvider image;
  final String? label;
  final Color? groundColor;
  final Color borderColor;
  final Color hoverBorderColor;
  final VoidCallback onTap;

  @override
  State<_SentImageTile> createState() => _SentImageTileState();
}

class _SentImageTileState extends State<_SentImageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: FlowMessage._imageRadius,
      side: BorderSide(
        color: _hovered ? widget.hoverBorderColor : widget.borderColor,
      ),
    );

    return Semantics(
      label: widget.label,
      image: true,
      button: true,
      // Transparent by default: the picture fills the tile, and a ground
      // would only show through a transparent PNG. Material animates the
      // shape change, so the hairline eases between its two inks.
      child: Material(
        color: widget.groundColor ?? const Color(0x00000000),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: widget.onTap,
          onHover: (value) {
            if (_hovered == value) return;
            setState(() => _hovered = value);
          },
          child: SizedBox.square(
            dimension: FlowMessage._sentImageSize,
            child: Image(
              // Decoded at tile resolution, as the attachment tiles are —
              // unless the host already bounded it, since ResizeImage
              // asserts rather than nesting.
              image: widget.image is ResizeImage
                  ? widget.image
                  : ResizeImage.resizeIfNeeded(
                      (FlowMessage._sentImageSize *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                      null,
                      widget.image,
                    ),
              fit: BoxFit.cover,
              errorBuilder: flowAttachmentErrorBuilder(),
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : FlowMessage._imageFade,
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
