import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_ui/material_ui.dart';

import '../models/flow_message_data.dart';
import '../models/flow_message_part.dart';
import '../utils/flow_selection.dart';
import 'flow_message.dart';

/// The scrollable conversation, a list of [FlowMessageData]s.
///
/// A conversation that still fits its viewport reads from the top, the AI
/// apps' convention; once it grows past the viewport it anchors to the
/// bottom instead. Uses a reversed [ListView] underneath so the thread
/// naturally sticks to the newest message while a reply streams in, and
/// holds position when the user scrolls up to read history. Needs a
/// bounded height (an [Expanded] in a column, or a sized parent).
///
/// Text in the thread is selectable, the way a chat in a browser is: drag
/// across turns with a mouse, long-press on touch, then copy with the
/// platform's shortcut or menu. Paragraphs copy on their own lines and
/// turns a blank line apart; button labels, code headers and the thinking
/// line stay out of it. [selectable] false leaves selection to the host.
class FlowThread extends StatefulWidget {
  const FlowThread({
    super.key,
    required this.messages,
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
    this.controller,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.padding,
    this.itemSpacing,
    this.messageBuilder,
    this.messageFooter,
    this.charactersPerSecond = 300,
    this.thinkingLabel,
    this.selectable = true,
  });

  /// Oldest → newest; once the conversation outgrows the viewport, the
  /// thread anchors to the newest.
  final List<FlowMessageData> messages;

  /// Forwarded to each [FlowMessage].
  final FlowCustomPartBuilder? customPartBuilder;

  /// Called with the message the attachment belongs to and its id —
  /// attachment ids only need to be unique within their own message.
  ///
  /// Supplying this *replaces* the built-in full-screen preview for every
  /// attachment in the thread; call `showFlowAttachmentPreview` from the
  /// handler to keep it.
  final void Function(FlowMessageData message, String attachmentId)?
  onAttachmentTap;

  /// Host-localized label for the built-in preview's close button.
  final String? previewCloseTooltip;

  /// Copy intent from any code block in the thread, handed the tapped
  /// [FlowCodePart]. Forwarded to each [FlowMessage].
  final ValueChanged<FlowCodePart>? onCodeCopy;

  /// The part whose block shows the copied check — the instance received
  /// from [onCodeCopy], passed back while the host's confirmation lasts.
  final FlowCodePart? copiedCodePart;

  /// Host-localized label for the code blocks' copy affordance.
  final String? codeCopyTooltip;

  /// Whether assistant text parts render as markdown. Forwarded to each
  /// [FlowMessage]; pass false for hosts whose assistant text is literal.
  final bool markdown;

  /// Link intent from any markdown content in the thread, handed the
  /// message and the tapped href. Null renders links as plain prose.
  final void Function(FlowMessageData message, String href)? onLinkTap;

  /// Retry intent from a failed turn's error card, handed the message so
  /// the host can re-run it. Forwarded to each [FlowMessage].
  final void Function(FlowMessageData message)? onRetry;

  /// Host-localized headline for the thread's error cards, e.g.
  /// 'Connection error'.
  final String? errorTitle;

  /// Host-localized label for the error cards' retry pill; null renders
  /// the pill glyph-only.
  final String? retryLabel;

  /// Approve/reject intent from a [FlowConfirmationPart]'s card, handed
  /// the message, the part and the decision so the host can find the
  /// request it belongs to and re-render the part settled. Forwarded to
  /// each [FlowMessage]; null renders every pending card without buttons.
  final void Function(
    FlowMessageData message,
    FlowConfirmationPart part,
    bool approved,
  )?
  onConfirmationRespond;

  /// Host-localized labels for the thread's confirmation cards — the
  /// approve and reject buttons, and the settled row's approved and
  /// rejected text. A null button label hides that button; a null settled
  /// label leaves the outcome glyph alone.
  final String? approveLabel;
  final String? rejectLabel;
  final String? approvedLabel;
  final String? rejectedLabel;

  /// Host-localized section labels for the thread's tool cards — over
  /// each card's input and output blocks, e.g. 'Input' and 'Output'.
  /// Forwarded to each [FlowMessage]; null lets a block fall back to its
  /// language id.
  final String? toolInputLabel;
  final String? toolOutputLabel;

  /// Optional external scroll controller.
  final ScrollController? controller;

  /// How scrolling the thread treats an open keyboard. Defaults to
  /// dismissing it on drag — reading history and typing are different
  /// modes, the chat convention.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Around the whole conversation. Defaults to the design's 16 at the
  /// sides and 40 above and below.
  final EdgeInsetsGeometry? padding;

  /// Gap between messages; defaults to the design's 32.
  final double? itemSpacing;

  /// Per-message override; defaults to a [FlowMessage].
  final Widget Function(BuildContext context, FlowMessageData message)?
  messageBuilder;

  /// Builds each default message's footer slot — an actions row, a
  /// timestamp — without replacing the message the way [messageBuilder]
  /// does, so the thread's per-message wiring stays intact. Return null
  /// for no footer on that turn. Ignored when [messageBuilder] is set:
  /// the builder owns the whole message.
  final Widget? Function(FlowMessageData message)? messageFooter;

  /// Forwarded to [FlowMessage] for streaming text parts.
  final double charactersPerSecond;

  /// Forwarded to each [FlowMessage]: the label beside the thinking glyph
  /// on a pending message.
  final String? thinkingLabel;

  /// Whether the thread hosts its own selection area — one region across
  /// every turn, so a drag or a long-press selects prose, code and tables
  /// alike, and a copy joins paragraphs with line breaks and turns with a
  /// blank line, in the theme's selection colours. False leaves selection
  /// to the host: inside a host's [SelectionArea] the content joins it,
  /// code blocks included; with no area above, nothing in the thread
  /// selects, so long-press stays the host's.
  final bool selectable;

  @override
  State<FlowThread> createState() => _FlowThreadState();
}

class _FlowThreadState extends State<FlowThread> {
  /// The design's thread metrics: edge padding and the gap between turns.
  /// The side 16 is mirrored by `FlowChatView`'s composer-block padding,
  /// which promises its edges line up with the thread's; the vertical 40
  /// keeps the opening turn off the viewport edge and the last one
  /// breathing against the composer.
  static const EdgeInsetsGeometry _defaultPadding =
      EdgeInsetsDirectional.fromSTEB(16, 40, 16, 40);
  static const double _defaultGap = 32;

  /// How far beyond the viewport messages get real layouts. A lazy list
  /// estimates its total extent from the items laid out so far, and chat
  /// turns vary wildly in height — a one-line bubble to a whole document
  /// — so a small cache makes the scrollbar thumb resize and jump as the
  /// estimate swings with every scroll. A few viewports of cache gives a
  /// typical conversation exact extents (a steady thumb) while a long
  /// history still lays out lazily.
  static const ScrollCacheExtent _cacheExtent = ScrollCacheExtent.viewport(3);

  /// Whether the conversation still fits its viewport. A fitting thread
  /// lays out shrink-wrapped so the top alignment can take effect; once
  /// content overflows, the lazy bottom-anchored form takes over. The flip
  /// is read off the scroll metrics, and at the frame it happens content
  /// equals the viewport, so nothing visibly moves. Shrink-wrapping lays
  /// out every message, so the mount starts from the lazy form — a
  /// restored long conversation must never pay a full layout on open —
  /// and the first metrics reading flips a short thread to the top read
  /// a frame later.
  bool _fits = false;
  Timer? _fitsHold;

  /// Whether any message is mid-turn, read each build. The fit flip is
  /// frozen while streaming: swapping the list's viewport type remounts
  /// the whole subtree, resetting every reveal — mid-stream that reset
  /// shrank the content back under the viewport and flipped the fit
  /// again, a grow-collapse flicker loop until the stream settled. A
  /// shrink-wrapped list whose content overflows still clamps to its
  /// constraints and scrolls, so deferring the flip only defers the
  /// laziness, not correctness.
  bool _streaming = false;

  /// The latest observed fit, applied when the freeze lifts.
  bool? _metricsFits;

  @override
  void dispose() {
    _fitsHold?.cancel();
    super.dispose();
  }

  void _handleMetrics(ScrollMetrics metrics) {
    final fits = metrics.maxScrollExtent <= 0;
    final first = _metricsFits == null;
    _metricsFits = fits;
    // The first reading escapes the streaming freeze: a conversation
    // opened by sending a message mounts mid-stream, and its opening turn
    // must read from the top from the start, not after the reply settles.
    // One flip this early cannot oscillate — the freeze guards the
    // grow-shrink loop of a reveal already underway.
    if (_streaming && !first) return;
    if (fits == _fits) {
      _fitsHold?.cancel();
      _fitsHold = null;
      return;
    }
    if (first) {
      // The mount starts lazy; the very first reading that fits flips
      // right away — the hold below guards later shrink-backs, not the
      // initial settle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_fits && _metricsFits == true) {
          setState(() => _fits = true);
        }
      });
      return;
    }
    if (!fits) {
      // Overflow takes the lazy form immediately.
      _fitsHold?.cancel();
      _fitsHold = null;
      // Metrics arrive during layout; flipping shrinkWrap there would
      // rebuild the tree mid-layout, so the flip waits for the frame's
      // end.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fits && !_streaming) setState(() => _fits = false);
      });
      return;
    }
    // Shrinking back to fitting must hold before the flip, so transient
    // zero-extent readings — a block still easing in — don't bounce the
    // viewport type.
    _fitsHold ??= Timer(const Duration(milliseconds: 250), () {
      _fitsHold = null;
      if (mounted && !_fits && !_streaming) setState(() => _fits = true);
    });
  }

  /// Called from build: freezes the flip during a stream and applies the
  /// deferred state once the stream ends.
  void _syncStreaming(List<FlowMessageData> messages) {
    final streamingNow = messages.any(
      (message) =>
          message.status == FlowMessageStatus.streaming ||
          message.status == FlowMessageStatus.pending,
    );
    if (_streaming && !streamingNow) {
      final fits = _metricsFits;
      if (fits != null && fits != _fits) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _metricsFits;
          if (mounted && !_streaming && target != null && target != _fits) {
            setState(() => _fits = target);
          }
        });
      }
    }
    _streaming = streamingNow;
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.itemSpacing ?? _defaultGap;
    final onAttachmentTap = widget.onAttachmentTap;
    final onRetry = widget.onRetry;
    final onConfirmationRespond = widget.onConfirmationRespond;
    final onLinkTap = widget.onLinkTap;
    final messages = widget.messages;
    _syncStreaming(messages);

    final list = Align(
      alignment: AlignmentDirectional.topCenter,
      child: ListView.builder(
        controller: widget.controller,
        reverse: true,
        shrinkWrap: _fits,
        scrollCacheExtent: _cacheExtent,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        padding: widget.padding ?? _defaultPadding,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          // Reversed list: index 0 is the newest (bottom) message.
          final message = messages[messages.length - 1 - index];
          final isOldest = index == messages.length - 1;
          return Padding(
            key: ValueKey(message.id),
            padding: EdgeInsets.only(top: isOldest ? 0 : gap),
            // A block per turn, so a copy spanning turns puts a blank line
            // between them — the paragraphs inside supply their own line
            // breaks. Host-built messages get the same.
            child: FlowSelectionBlock(
              child:
                  widget.messageBuilder?.call(context, message) ??
                  FlowMessage(
                    message,
                    customPartBuilder: widget.customPartBuilder,
                    onAttachmentTap: onAttachmentTap == null
                        ? null
                        : (attachmentId) =>
                              onAttachmentTap(message, attachmentId),
                    previewCloseTooltip: widget.previewCloseTooltip,
                    onCodeCopy: widget.onCodeCopy,
                    copiedCodePart: widget.copiedCodePart,
                    codeCopyTooltip: widget.codeCopyTooltip,
                    markdown: widget.markdown,
                    onLinkTap: onLinkTap == null
                        ? null
                        : (href) => onLinkTap(message, href),
                    onRetry: onRetry == null ? null : () => onRetry(message),
                    errorTitle: widget.errorTitle,
                    retryLabel: widget.retryLabel,
                    onConfirmationRespond: onConfirmationRespond == null
                        ? null
                        : (part, approved) =>
                              onConfirmationRespond(message, part, approved),
                    approveLabel: widget.approveLabel,
                    rejectLabel: widget.rejectLabel,
                    approvedLabel: widget.approvedLabel,
                    rejectedLabel: widget.rejectedLabel,
                    toolInputLabel: widget.toolInputLabel,
                    toolOutputLabel: widget.toolOutputLabel,
                    charactersPerSecond: widget.charactersPerSecond,
                    thinkingLabel: widget.thinkingLabel,
                    footer: widget.messageFooter?.call(message),
                  ),
            ),
          );
        },
      ),
    );

    final Widget content;
    if (widget.selectable) {
      // The area wraps the whole bounded box, not just the list, so a
      // drag that starts in the empty space under a short thread still
      // selects. The scrollable joins it on its own — edge autoscroll and
      // select-all come with it — and the metrics filter below is
      // unaffected: the area is not a viewport.
      content = FlowSelectionArea(child: list);
    } else if (SelectionContainer.maybeOf(context) != null) {
      // A host area above: the content joins it, code blocks included.
      content = list;
    } else {
      // No area anywhere: nothing in the thread selects. A code block
      // hosts its own area only outside every scope, and a disabled one
      // is a scope — so long-press stays the host's, fences included.
      content = SelectionContainer.disabled(child: list);
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        // Depth 0 is the thread's own list — scrollers nested inside
        // messages (attachment strips, code blocks) report deeper and
        // must not steer the fit.
        if (notification.depth == 0) _handleMetrics(notification.metrics);
        return false;
      },
      child: content,
    );
  }
}
