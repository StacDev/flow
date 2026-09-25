<p align="center">
  <img src="assets/flow_ui_logo.svg" width="76" alt="Flow UI logo">
</p>

<h1 align="center">flow_ui</h1>

<p align="center">
  <a href="https://pub.dev/packages/flow_ui"><img src="https://img.shields.io/pub/v/flow_ui.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/flow_ui/score"><img src="https://img.shields.io/pub/points/flow_ui" alt="pub points"></a>
  <a href="https://github.com/StacDev/flow"><img src="https://img.shields.io/github/stars/StacDev/flow?style=flat&logo=github&color=8250df" alt="github stars"></a>
  <a href="https://github.com/StacDev/flow/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

<p align="center">
  📚 <a href="https://flowui.stac.dev/">Documentation</a>
  · 🧩 <a href="https://flowui.stac.dev/playground">Playground</a>
  · 🤓 <a href="https://pub.dev/documentation/flow_ui/latest/">API Reference</a>
  · 🗺️ <a href="https://flowui.stac.dev/roadmap">Roadmap</a>
</p>

<p align="center">
<a href="https://flowui.stac.dev/">Flow UI</a> is an open-source Flutter UI library to build production-grade Chat &amp; AI assistant interfaces.
</p>

![The flow_ui chat surface](assets/chat_zero_light.png)

> [!IMPORTANT]
> flow_ui is pre-1.0. The API is still settling, and minor releases may
> carry breaking changes — pin a minor version and read the
> [changelog](CHANGELOG.md) when upgrading.

## What's in the box

| Component | What it does |
|---|---|
| [`FlowChatView`](https://flowui.stac.dev/components/chat-view) | The full chat surface: bounded thread over a composer, centred at a readable width, with a zero state (greeting, lifted composer, starters), a jump-to-latest button, and drag-and-drop with a washed invitation overlay (web) |
| [`FlowThread`](https://flowui.stac.dev/components/message-thread) | Scrollable conversation: reads from the top, anchoring to the newest message once it outgrows the viewport; text selects across turns and copies with its line breaks |
| [`FlowThreadList`](https://flowui.stac.dev/components/thread-list) | Conversation history for a side panel — host-labeled sections, single selection by id, unread and pinned marks |
| [`FlowMessage`](https://flowui.stac.dev/components/message-thread) | One turn — ink-wash user bubble, plain assistant, error bubble, typed content parts |
| [`FlowStreamingText`](https://flowui.stac.dev/components/streaming-text) | Animated text reveal while a reply arrives |
| [`FlowThinkingIndicator`](https://flowui.stac.dev/components/thinking-indicator) | Turning, breathing asterisk with a shimmering label |
| [`FlowShimmerText`](https://flowui.stac.dev/components/shimmer-text) | Sweeping text highlight, static once settled |
| [`FlowCodeBlock`](https://flowui.stac.dev/components/code-block) | Fenced code with built-in synchronous highlighting, a header label, and a copy affordance — languages host-extensible |
| [`FlowMarkdown`](https://flowui.stac.dev/components/markdown) | Assistant prose typeset from a built-in parser — headings, emphasis, lists, quotes, tables, links, and fences composing the code block; assistant turns render it by default and it streams gracefully |
| [`FlowErrorState`](https://flowui.stac.dev/components/error-state) | Failure card with a host-written message and retry pill — failed turns render it automatically |
| [`FlowConfirmation`](https://flowui.stac.dev/components/confirmation) | Approval card — an asterisk-marked request with approve and reject buttons that settles into the outcome; confirmation parts render it in a thread |
| [`FlowToast`](https://flowui.stac.dev/components/toast) | Floating notice: a glyph, one wrapping line and a cross on a frosted card; `showFlowToast` floats it in the nearest Overlay, stacked and auto-dismissing, with a handle to dismiss it early |
| [`FlowTool`](https://flowui.stac.dev/components/tool) | Tool-call card: one status mark that settles from a turning asterisk into a check or an error glyph, the call's title and primary argument, and its input and output behind a disclosure; tool parts render it in a thread |
| [`FlowMessageActions`](https://flowui.stac.dev/components/message-actions) | Copy / regenerate / edit / feedback row under a message |
| [`FlowComposer`](https://flowui.stac.dev/components/composer) | Multiline input with send/stop, attachments strip, the platform's file dialog (`showFlowAttachmentPicker` from your own menu, or a built-in attach button), image paste and card-scoped drop (web), and leading/trailing action slots; a full card, or a compact single-row pill that opens into it as the draft grows |
| [`FlowMenu`](https://flowui.stac.dev/components/menu) | Icon-triggered menu with groups, submenus, and toggles — anchored card on desktop, bottom sheet on phones |
| [`FlowModelSelector`](https://flowui.stac.dev/components/model-selector) | Model picker with effort and overflow submenus, sheet on phones |
| [`FlowPill`](https://flowui.stac.dev/components/pill) | Removable pill for an enabled tool or mode in the composer's action row — label auto-drops on phones |
| [`FlowAttachmentGroup`](https://flowui.stac.dev/components/attachments) | Image and file tiles with a type pill |
| [`FlowAttachmentPreview`](https://flowui.stac.dev/components/attachments) | Full-screen image viewer with zoom and paging |
| [`FlowDropTarget`](https://flowui.stac.dev/components/chat-view) | File-drop detection for any subtree (web) — decoded attachments out, hover state for your own treatment |
| [`FlowSuggestion`](https://flowui.stac.dev/components/suggestions) / [`FlowSuggestionGroup`](https://flowui.stac.dev/components/suggestions) | Prompt starters — plain or outlined; scroll, wrap, or column layouts |
| [`FlowGreeting`](https://flowui.stac.dev/components/greeting) | Zero-state headline |
| [`FlowTheme`](https://flowui.stac.dev/theming) | Design tokens (colors and typography) as a `ThemeExtension`, with light and dark presets |

## Getting started

```yaml
dependencies:
  flow_ui: ^0.4.0
```

Install the theme once (optional — without it, components fall back to a
preset matching the ambient brightness):

```dart
MaterialApp(
  theme: ThemeData(extensions: [FlowTheme.light()]),
  darkTheme: ThemeData(
    brightness: Brightness.dark,
    extensions: [FlowTheme.dark()],
  ),
)
```

The default typography — Google Sans and Google Sans Code — ships with the
package. Nothing is fetched, so there is no permission, no entitlement and
no fallback face on the first frame, and your app declares no font of its
own. Google Sans ships as a Latin subset, which keeps the whole set near a
megabyte; the scripts it leaves out fall back to the platform face, the way
CJK does. To set the scale in your own typeface instead:

```dart
FlowTheme(
  colors: FlowColors.light,
  typography: FlowTypography.standard.withFontFamily('Inter'),
)
```

## Build a chat screen

Messages are pure view models. Your app maps its own transport into
`FlowMessageData`, and streaming is data, not streams: while a reply arrives,
rebuild with `copyWith` carrying the grown text.

```dart
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController _scroll = ScrollController();
  List<FlowMessageData> _messages = const [];
  bool _generating = false;

  void _send(String text) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _messages = [
        ..._messages,
        FlowMessageData.text(id: id, role: FlowMessageRole.user, text: text),
        // An empty pending reply renders the thinking indicator.
        FlowMessageData(
          id: '$id-reply',
          role: FlowMessageRole.assistant,
          status: FlowMessageStatus.pending,
        ),
      ];
      _generating = true;
    });

    // Feed chunks from your backend as they arrive.
    var streamed = '';
    await for (final chunk in myBackend.reply(text)) {
      streamed += chunk;
      setState(() {
        _messages = [
          ..._messages.sublist(0, _messages.length - 1),
          _messages.last.copyWith(
            parts: [FlowTextPart(streamed)],
            status: FlowMessageStatus.streaming,
          ),
        ];
      });
    }

    setState(() {
      _messages = [
        ..._messages.sublist(0, _messages.length - 1),
        _messages.last.copyWith(status: FlowMessageStatus.complete),
      ];
      _generating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlowChatView(
        empty: _messages.isEmpty,
        greeting: const FlowGreeting(
          icon: Icons.wb_twilight,
          text: 'Good afternoon',
        ),
        suggestions: FlowSuggestionGroup(
          layout: FlowSuggestionLayout.column,
          suggestions: [
            FlowSuggestion(
              label: 'Write an essay about life and enjoyment',
              icon: Icons.edit_note,
              onTap: () => _send('Write an essay about life and enjoyment'),
            ),
            FlowSuggestion(
              label: 'Create a Monday briefing from my tasks',
              icon: Icons.event_available,
              onTap: () => _send('Create a Monday briefing from my tasks'),
            ),
          ],
        ),
        thread: FlowThread(
          messages: _messages,
          controller: _scroll,
          thinkingLabel: 'Thinking…',
        ),
        threadController: _scroll,
        jumpToLatestTooltip: 'Jump to latest',
        composer: FlowComposer(
          placeholder: 'How can I help you today?',
          isStreaming: _generating,
          onSend: _send,
          onStop: myBackend.stop,
          sendTooltip: 'Send',
          stopTooltip: 'Stop',
        ),
      ),
    );
  }
}
```

`FlowChatView` is body-only — it builds no `Scaffold` and no app bar, so
your app keeps the chrome, the background, and the keyboard inset. See
[`example/lib/main.dart`](example/lib/main.dart) for a complete runnable
version of this page, and the [live playground](https://flowui.stac.dev/playground)
for a demo of every component with variants and code snippets.

## Composer accessories

The composer takes leading and trailing action slots. Drop in a `FlowMenu`
(attachments, toggles) and a `FlowModelSelector` — both render an anchored
card on wide layouts and a bottom sheet on phones:

```dart
FlowComposer(
  onSend: _send,
  leadingActions: [
    FlowMenu(
      icon: Icons.add,
      tooltip: 'Add to chat',
      entries: const [
        FlowMenuOption(id: 'files', icon: Icons.attach_file, label: 'Add files'),
        FlowMenuDivider(),
        FlowMenuOption(id: 'web', icon: Icons.public, label: 'Web search', selected: true),
      ],
      onSelected: _handleMenu,
    ),
  ],
  trailingActions: [
    FlowModelSelector(
      models: const [
        FlowModelOption(id: 'fast', label: 'Fast', description: 'Quick answers'),
        FlowModelOption(id: 'smart', label: 'Smart', description: 'Hard problems'),
      ],
      selectedId: _modelId,
      onSelected: (id) => setState(() => _modelId = id),
    ),
  ],
)
```

## Message content is typed parts

A message holds an ordered list of sealed `FlowMessagePart`s —
`FlowTextPart`, `FlowAttachmentPart`, and `FlowCustomPart` for anything the
package doesn't know about. Custom parts render through a builder you supply,
so hosts can inject arbitrary widgets (tool cards, citations, charts) without
forking the message renderer:

```dart
FlowThread(
  messages: _messages,
  customPartBuilder: (context, message, part) {
    return switch (part.type) {
      'order-card' => OrderCard(order: part.data as Order),
      _ => null, // unknown parts are skipped
    };
  },
)
```

Attachments carry an `ImageProvider`, so network, file, memory, and asset
images all work. Build them yourself, or let the package hand them to you
ready-made — `showFlowAttachmentPicker` opens the platform's file dialog
from your own menu (or the composer's built-in button does), and on the
web the surface takes drops and the field takes pasted images:

```dart
FlowMessageData(
  id: 'm1',
  role: FlowMessageRole.user,
  parts: [
    FlowAttachmentPart([
      FlowAttachment(id: 'a1', thumbnail: NetworkImage(url), kind: 'JPG', label: 'sunset.jpg'),
    ]),
    FlowTextPart('What do you think of this shot?'),
  ],
)
```

## Theming

`FlowTheme` carries two token sets — colors and typography. Role names follow
Material 3's `ColorScheme`, so an existing scheme maps across, with one
addition: the design draws content at three ink levels (`onSurface`,
`onSurfaceVariant`, `onSurfaceMuted`) where M3 names two. Start from a preset
and override what your brand needs:

```dart
FlowTheme(
  colors: FlowColors.dark.copyWith(primary: const Color(0xFF6C5CE7)),
  typography: FlowTypography.standard,
)
```

Spacing and corner radii are deliberately not tokens. Following Material's
structure, each component bakes its own metrics from the Flow UI design file
and exposes per-widget overrides (`padding:`, `borderRadius:`) where hosts
retheme. Strings shown to the user (tooltips, placeholders, labels) are
host-supplied, so localization stays in your app — the one exception, the
model selector's `effortLabel` and `moreModelsLabel` English defaults, is
overridable the same way.

## Docs & playground

Full documentation lives at [flowui.stac.dev](https://flowui.stac.dev/), and
every component has a stage in the
[live playground](https://flowui.stac.dev/playground) — variant pills and
code snippets included. The playground is also
[in the repo](https://github.com/StacDev/flow/tree/main/playground) to run
locally:

```bash
cd playground && flutter run -d chrome
```

## License

Code is released under the [MIT License](LICENSE). The bundled Google Sans
and Google Sans Code fonts are licensed separately under the
[SIL Open Font License](https://openfontlicense.org) — see
[fonts/OFL.txt](fonts/OFL.txt) and
[fonts/OFL-GoogleSansCode.txt](fonts/OFL-GoogleSansCode.txt).
