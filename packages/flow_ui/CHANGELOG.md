## 0.4.0 (unreleased)

- Bundles Google Sans and Google Sans Code with the package instead of fetching them through google_fonts, which is dropped as a dependency. Nothing is fetched at runtime, so hosts no longer need android.permission.INTERNET or com.apple.security.network.client, and there is no fallback face on the first frame. Google Sans ships as a Latin subset; the scripts it leaves out fall back to the platform face, as CJK already did.
- Makes `FlowTypography.standard` and `FlowTheme.typography` `const` again, and `FlowTypography.code` / `codeInline` plain fields with const defaults.
- Deprecates `FlowTypography.recut` in favour of `copyWith(fontWeight:, fontStyle:)` — the bundled families declare every cut, so the engine resolves it from the weight on the style. Removed in 0.6.0.
- Adds FlowTool, the tool-call card: one mark morphs with the call's status (a still asterisk while staged, turning while it runs, a check or an error glyph once settled), the host's title and primary argument sit on the row, and the input and output render as code blocks behind a disclosure, with a failure readable without a tap. FlowToolPart renders it in a thread, keyed by the provider's call id and copying through FlowThread.onCodeCopy; FlowToolStyle joins the component styles with a FlowTheme.toolStyle default. Metrics are provisional pending a design frame.

## 0.3.0

- Adds FlowToast and showFlowToast, a floating notice that stacks as a deck, dismisses itself after four seconds and pauses under the pointer.
- Makes text in a FlowThread selectable, the way a chat in a browser is, keeping line breaks on copy; FlowThread.selectable turns it off.
- Adds FlowConfirmation, the approval card, and FlowConfirmationPart to render it in a thread, answering through FlowThread.onConfirmationRespond.
- Adds FlowThreadList, the side panel's conversation history, with labeled sections, single selection, unread and pinned markers and a leading icon slot.
- Adds FlowImagePart, a large-format picture in a turn that shimmers until the image lands, opens the preview on tap and carries its bytes and mimeType.
- Adds built-in attachment input: the attach button opens the platform's file picker, on the web files drop onto the chat view and images paste into the field, FlowAttachmentOptions filters what is accepted and attachmentsEnabled switches it all off. A picture with no caption now sends on its own, so onSend can fire with empty text.
- Adds a style object to every major widget (FlowComposerStyle, FlowMessageStyle, FlowChatViewStyle and more), each with an app-wide default on FlowTheme.
- Switches to Google Sans and Google Sans Code, fetched at runtime by google_fonts, which needs android.permission.INTERNET and com.apple.security.network.client in a sandboxed macOS app.
- Adds file_selector (flutter.dev) as a dependency for the built-in picker; macOS apps that use it need the com.apple.security.files.user-selected.read-only entitlement.
- Breaking: outline and outlineVariant swap meaning, outline now the faint hairline and outlineVariant the firm one; FlowColors gains nine required roles, and markdown links default to secondary.
- Breaking: FlowMessagePart is sealed, so an exhaustive switch needs FlowImagePart and FlowConfirmationPart cases.
- Breaking: FlowTypography.standard is built at runtime, so use FlowTypography.recut instead of copyWith(fontWeight:); hosts naming Figtree or GeistMono should update.

## 0.2.0

- Adds FlowCodeBlock and a FlowCodePart message part with built-in highlighting for Dart, JSON, JavaScript, TypeScript, Python, shell, YAML, HTML, CSS and SQL; FlowCodeLanguage.register adds more.
- Adds FlowSyntaxColors theme tokens for the highlighting, and code and codeInline typography roles on a bundled Geist Mono.
- Adds FlowMarkdown, a built-in parser and renderer for assistant prose: headings, emphasis, inline code, links, lists, quotes, rules, tables and fenced code.
- Reveals streaming markdown through one sequenced frontier, so a thread pinned to the newest message moves continuously; reduced motion renders statically.
- Adds FlowErrorState and a FlowErrorPart message part, with onRetry, errorTitle and retryLabel on FlowMessage and FlowThread.
- Adds FlowPill, a removable pill for an enabled tool or mode in the composer's action row, dropping to icon-only on phones.
- Adds FlowThread.messageFooter to fill each message's footer slot without replacing the whole message.
- Adds emphasised cuts to the title and label typography roles and retunes sizes and line heights to the design file.
- Dismisses the keyboard on taps on the chat surface and on thread scroll (FlowThread.keyboardDismissBehavior).
- Reads a conversation that fits its viewport from the top instead of hugging the composer.
- Moves the chat view's scrollbar to the surface's edge and puts the jump-to-latest button on an outlined disc.
- Breaking: renames FlowChatScreen to FlowChatView; the API is unchanged.
- Breaking: assistant text parts render as markdown by default; pass `markdown: false` for literal text.
- Breaking: FlowTypography requires the new emphasised styles, and label sizes step up one rung to 16, 14 and 12.
- Breaking: FlowComposer.placeholder defaults to "How can I help you today?"; pass `placeholder: null` for an empty field.
- Breaking: FlowChatView.composer is required, still nullable, so a read-only surface passes `composer: null`.
- Breaking: a failed assistant turn keeps its normal ink and closes with an error card instead of an errorContainer bubble.
- Breaking: migrates from flutter/material.dart to material_ui; hosts run `dart fix --apply --code=migrate_design_widgets` on Flutter 3.44 or newer, or pin flow_ui 0.1.x.

## 0.1.0

- First public release: the assistant UI component library for Flutter, with no third-party dependencies and nothing model-facing.
- Adds FlowTheme design tokens as a ThemeExtension, with light and dark presets and a bundled Figtree typeface.
- Adds FlowMessage and FlowThread: an ink-wash user bubble, a plain assistant turn, typed content parts and a FlowCustomPart extension seam.
- Adds streaming text, a thinking indicator and shimmer text.
- Adds message actions with copy, regenerate, edit and feedback presets.
- Adds FlowComposer, a multiline input with send and stop, an attachments strip and action slots.
- Adds FlowMenu and FlowModelSelector, an anchored card on desktop and a sheet on phones.
- Adds attachment tiles for images and files, with a full-screen preview.
- Adds suggestions in scroll, wrap and column layouts, with FlowGreeting for the zero state.
- Adds FlowChatScreen, the composed surface with a centred rail, a zero state and jump-to-latest.

## 0.0.1

- Initial scaffold.
