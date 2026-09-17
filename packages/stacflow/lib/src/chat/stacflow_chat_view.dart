import 'dart:async';

import 'package:flow_ui/flow_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stacflow/src/chat/chat_state.dart';
import 'package:stacflow/src/chat/stacflow_chat.dart';
import 'package:stacflow/src/strings.dart';
import 'package:stacflow/src/tools/tool.dart';

/// Builds the content shown under a tool card for [record], or null for
/// none; called for every call in every status.
typedef ToolBodyBuilder = Widget? Function(
  BuildContext context,
  ToolCallRecord record,
);

/// The finished chat screen for a [StacFlowChat]: thread, composer,
/// attachments, message actions, tool cards and model selector. Body-only;
/// put it in a Scaffold under material_ui's MaterialApp.
class StacFlowChatView extends StatefulWidget {
  const StacFlowChatView({
    required this.chat,
    super.key,
    this.greeting,
    this.suggestions = const <String>[],
    this.suggestionsLayout = FlowSuggestionLayout.column,
    this.header,
    this.strings,
    this.showModelSelector = true,
    this.showActions = true,
    this.showEditAction = false,
    this.onLinkTap,
    this.toolBodyBuilder,
    this.leadingActions = const <Widget>[],
    this.trailingActions = const <Widget>[],
    this.maxContentWidth = 760,
    this.style,
    this.composerStyle,
  });

  /// The chat this screen shows and drives.
  final StacFlowChat chat;

  /// Renders content under a tool card, e.g. a table for a query result.
  final ToolBodyBuilder? toolBodyBuilder;

  /// Shown above the composer while the thread is empty.
  final Widget? greeting;

  /// Prompt starters shown while the thread is empty; a tap sends one.
  final List<String> suggestions;

  final FlowSuggestionLayout suggestionsLayout;

  /// A full-width bar above the thread.
  final Widget? header;

  /// Overrides the chat's strings for this screen.
  final FlowStrings? strings;

  /// Shows a model selector when the provider offers more than one model.
  final bool showModelSelector;

  /// Shows copy, feedback and regenerate under settled replies.
  final bool showActions;

  /// Shows an edit action under user turns; sending then replaces that
  /// turn and everything after it.
  final bool showEditAction;

  /// Called with the href of a tapped link; links render as prose when
  /// null.
  final ValueChanged<String>? onLinkTap;

  /// Extra composer actions before the attach button.
  final List<Widget> leadingActions;

  /// Extra composer actions before the model selector.
  final List<Widget> trailingActions;

  final double maxContentWidth;
  final FlowChatViewStyle? style;
  final FlowComposerStyle? composerStyle;

  @override
  State<StacFlowChatView> createState() => _StacFlowChatViewState();
}

class _StacFlowChatViewState extends State<StacFlowChatView> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _text = TextEditingController();
  String? _editingId;

  StacFlowChat get _chat => widget.chat;

  FlowStrings get _strings => widget.strings ?? _chat.strings;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_onTextChanged)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_editingId != null && _text.text.isEmpty) {
      setState(() => _editingId = null);
    }
  }

  void _send(String text) {
    final editingId = _editingId;
    if (editingId != null) {
      _editingId = null;
      unawaited(_chat.editAndResend(editingId, text));
    } else {
      unawaited(_chat.send(text));
    }
  }

  void _insertContent(KeyboardInsertedContent content) {
    final data = content.data;
    if (data == null || data.isEmpty) return;
    _chat.addAttachments([
      FlowAttachment(
        id: 'kbd_${DateTime.now().microsecondsSinceEpoch}',
        thumbnail: MemoryImage(data),
        label: 'keyboard image',
        bytes: data,
        mimeType: content.mimeType,
      ),
    ]);
  }

  void _edit(FlowMessageData message) {
    _text.text = [
      for (final part in message.parts)
        if (part is FlowTextPart) part.text,
    ].join('\n');
    setState(() => _editingId = message.id);
  }

  void _copy(BuildContext context, FlowMessageData message) {
    unawaited(_chat.copy(message));
    showFlowToast(
      context: context,
      icon: Icons.copy_outlined,
      message: _strings.copied,
      dismissTooltip: _strings.dismiss,
    );
  }

  Widget? _actions(
    BuildContext context,
    ChatState state,
    FlowMessageData message,
  ) {
    final strings = _strings;
    if (message.role == FlowMessageRole.user) {
      if (!widget.showEditAction) return null;
      return FlowMessageActions(
        actions: [
          FlowMessageAction.edit(
            tooltip: strings.edit,
            onPressed: state.isGenerating ? null : () => _edit(message),
          ),
        ],
      );
    }
    if (!widget.showActions ||
        message.role != FlowMessageRole.assistant ||
        message.status != FlowMessageStatus.complete) {
      return null;
    }
    final feedback = state.feedback[message.id];
    final isLatest = message.id == state.messages.last.id;
    return FlowMessageActions(
      actions: [
        FlowMessageAction.copy(
          tooltip: strings.copy,
          onPressed: () => _copy(context, message),
        ),
        FlowMessageAction.thumbUp(
          tooltip: strings.goodResponse,
          selected: feedback == true,
          onPressed: () => _chat.setFeedback(message.id, positive: true),
        ),
        FlowMessageAction.thumbDown(
          tooltip: strings.badResponse,
          selected: feedback == false,
          onPressed: () => _chat.setFeedback(message.id, positive: false),
        ),
        if (isLatest)
          FlowMessageAction.regenerate(
            tooltip: strings.regenerate,
            onPressed: state.isGenerating
                ? null
                : () => unawaited(_chat.regenerate()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ChatState>(
    valueListenable: _chat.state,
    builder: (context, state, _) {
      final strings = _strings;
      final models = _chat.provider.models;
      final onLinkTap = widget.onLinkTap;
      return FlowChatView(
        header: widget.header,
        empty: state.messages.isEmpty,
        greeting: widget.greeting,
        suggestions: widget.suggestions.isEmpty
            ? null
            : FlowSuggestionGroup(
                layout: widget.suggestionsLayout,
                suggestions: [
                  for (final suggestion in widget.suggestions)
                    FlowSuggestion(
                      label: suggestion,
                      onTap: () => _send(suggestion),
                    ),
                ],
              ),
        thread: FlowThread(
          messages: state.messages,
          controller: _scroll,
          thinkingLabel: strings.thinking,
          errorTitle: strings.errorTitle,
          retryLabel: strings.retry,
          onRetry: (message) => unawaited(_chat.retry(message)),
          onLinkTap: onLinkTap == null
              ? null
              : (message, href) => onLinkTap(href),
          onCodeCopy: (part) => unawaited(_chat.copyCode(part)),
          copiedCodePart: state.copiedCodePart,
          codeCopyTooltip: strings.copyCode,
          onConfirmationRespond: (message, part, approved) =>
              _chat.respondToConfirmation(message, part, approved: approved),
          approveLabel: strings.approve,
          rejectLabel: strings.reject,
          approvedLabel: strings.approved,
          rejectedLabel: strings.rejected,
          toolInputLabel: strings.toolInput,
          toolOutputLabel: strings.toolOutput,
          customPartBuilder: (context, message, part) {
            if (part.type != StacFlowChat.toolPartType) return null;
            final record = part.data;
            return record is ToolCallRecord
                ? widget.toolBodyBuilder?.call(context, record)
                : null;
          },
          messageFooter: widget.showActions || widget.showEditAction
              ? (message) => _actions(context, state, message)
              : null,
        ),
        threadController: _scroll,
        jumpToLatestTooltip: strings.jumpToLatest,
        maxContentWidth: widget.maxContentWidth,
        onAttachmentsDropped: _chat.addAttachments,
        onAttachmentRejected: _chat.rejectAttachment,
        attachmentOptions: _chat.attachmentOptions,
        dropLabel: strings.dropFiles,
        style: widget.style,
        composer: FlowComposer(
          isStreaming: state.isGenerating,
          onSend: _send,
          onStop: _chat.stop,
          controller: _text,
          placeholder: strings.placeholder,
          attachments: state.pendingAttachments,
          onRemoveAttachment: _chat.removeAttachment,
          removeAttachmentTooltip: strings.removeAttachment,
          onAttachmentsPicked: _chat.addAttachments,
          onAttachmentsDropped: _chat.addAttachments,
          onAttachmentsPasted: _chat.addAttachments,
          onAttachmentRejected: _chat.rejectAttachment,
          attachmentOptions: _chat.attachmentOptions,
          attachTooltip: strings.attach,
          errorMessage: state.attachmentError,
          onErrorDismiss: _chat.dismissAttachmentError,
          errorDismissTooltip: strings.dismiss,
          onContentInserted: _insertContent,
          leadingActions: widget.leadingActions,
          trailingActions: [
            ...widget.trailingActions,
            if (widget.showModelSelector && models.length > 1)
              FlowModelSelector(
                models: [
                  for (final option in models)
                    FlowModelOption(
                      id: option.id,
                      label: option.label,
                      description: option.description,
                    ),
                ],
                selectedId: state.model,
                onSelected: _chat.selectModel,
              ),
          ],
          style: widget.composerStyle,
        ),
      );
    },
  );
}
