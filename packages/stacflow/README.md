<p align="center">
  <img src="https://raw.githubusercontent.com/StacDev/flow_ui/main/packages/flow_ui/assets/flow_ui_logo.svg" width="76" alt="Flow UI logo">
</p>

<h1 align="center">stacflow</h1>

<p align="center">
  📚 <a href="https://flowui.stac.dev/stacflow/getting-started/">Documentation</a>
  · 🎨 <a href="https://pub.dev/packages/flow_ui">flow_ui</a>
  · 🧩 <a href="https://flowui.stac.dev/playground">Playground</a>
</p>

<p align="center">
Streaming AI chat for Flutter, built on flow_ui, talking to Gemini, OpenAI or Claude with your own API key.
</p>

> [!IMPORTANT]
> stacflow is pre-1.0. The API is still settling, and minor releases may
> carry breaking changes: pin a minor version and read the changelog when
> upgrading.

## Quickstart

```yaml
dependencies:
  stacflow: ^0.1.0
```

```dart
import 'package:material_ui/material_ui.dart';
import 'package:stacflow/stacflow.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(extensions: [FlowTheme.light()]),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      extensions: [FlowTheme.dark()],
    ),
    home: const ChatScreen(),
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final chat = StacFlowChat(
    provider: GeminiProvider(
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    ),
  );

  @override
  void dispose() {
    chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: StacFlowChatView(chat: chat));
}
```

```bash
flutter run --dart-define=GEMINI_API_KEY=AIza...
```

That is the whole integration. The view streams replies with a thinking
indicator, renders markdown and code, stops mid-reply, retries failed
turns, regenerates, takes image attachments from the picker, a drop or a
paste, copies replies, records feedback, offers a model selector when
the provider lists more than one model, and runs the tools you register,
asking first when a tool is destructive. One import brings flow_ui along,
so every widget it exports is available too.

## Example

[`example/`](https://github.com/StacDev/flow_ui/tree/main/packages/stacflow/example)
is this screen, runnable against Gemini:

```bash
cd example && flutter run --dart-define=GEMINI_API_KEY=AIza...
```

## Providers

| Provider | Class | Default model | Key |
|---|---|---|---|
| Gemini | `GeminiProvider` | `gemini-3.6-flash` | An AI Studio API key |
| OpenAI, and any compatible server | `OpenAIProvider` | `gpt-5-mini` | An OpenAI API key; set `baseUrl` for Ollama, Groq, OpenRouter, LM Studio or vLLM |
| Claude | `AnthropicProvider` | `claude-opus-5` | An Anthropic API key; `claude-sonnet-5` is the cheaper model |

Every provider takes `model`, `baseUrl`, extra `headers`, an `httpClient`,
the `models` a selector should offer, and first-byte and idle timeouts.
Instructions and sampling live on the chat:

```dart
StacFlowChat(
  provider: AnthropicProvider(
    apiKey: key,
    models: const [
      ModelOption(id: 'claude-opus-5', label: 'Claude Opus 5'),
      ModelOption(id: 'claude-sonnet-5', label: 'Claude Sonnet 5'),
    ],
  ),
  agent: const AgentConfig(instructions: 'You are a concise assistant.'),
)
```

## Tools

A tool is an action the app lets the model take. Register it on the chat
with a name, a description the model reads, a JSON Schema for its
arguments and the handler that runs it:

```dart
StacFlowChat(
  provider: GeminiProvider(apiKey: key),
  tools: [
    Tool(
      name: 'set_theme',
      description: 'Switches the app between light and dark mode.',
      parameters: const {
        'type': 'object',
        'properties': {
          'mode': {'type': 'string', 'enum': ['light', 'dark', 'system']},
        },
        'required': ['mode'],
      },
      label: 'Set theme',
      detail: (args) => args['mode'] as String?,
      run: (call) {
        themeMode.value = ThemeMode.values.byName(call.args['mode'] as String);
        return {'mode': call.args['mode']};
      },
    ),
  ],
)
```

When the model calls it, the thread shows a tool card that moves from
pending to complete, with the arguments and the result behind a
disclosure, and the model finishes its reply with the result in hand. A
handler returns any JSON-encodable value; throw a `ToolException` to fail
in your own words, and check `call.isAborted` in long handlers, since a
stop, a timeout or the end of the turn cancels the call.

Every tool carries a permission: `read` runs silently, `write` (the
default) runs unless the tool sets `confirm: true`, and `destructive`
always shows a confirmation card first. The card's question comes from
`confirmation`, or "Allow <label> to run?" by default; a decline goes back
to the model as a declined result so it can respond. `toolBodyBuilder` on
the view renders content under a card, such as a table for a query
result. A turn may call tools in up to `maxToolRounds` segments (8 by
default) before it fails with a retryable error. Calls and results are
replayed to the model in later turns, so it keeps knowing what it did.

## Keys, plainly

A key compiled into a shipped app can be extracted from the binary. Use
`--dart-define` or `--dart-define-from-file=env.json` while developing.
For production, put the key behind a server you own and point
`OpenAIProvider(baseUrl: ...)` or the other providers' `baseUrl` at it, or
wait for StacFlow Cloud. On the web, Claude requests carry the header
Anthropic requires for direct browser calls, which means the key travels
to the browser: fine for a demo, not for a public site.

## Headless

`StacFlowChat` works without the view. `chat.state` is a
`ValueListenable<ChatState>` with the messages, the pending attachments,
the last error and the last turn's timing and token counts; `send`,
`stop`, `retry`, `regenerate`, `editAndResend`, `addAttachments`,
`selectModel` and `newConversation` drive it. Any flow_ui layout, or your
own, renders `state.messages`.

## Strings

Every string the SDK shows comes from `FlowStrings`, with English
defaults. Subclass it, override what you need, and pass it to the chat or
the view.

## Not in 0.1

Thread persistence, generative UI and image generation. The `SseEvent`
types, `TurnTransport` and `TurnRequest` are public so a custom provider
can be written today; a hosted gateway that speaks the same events comes
later.

## License

MIT. Part of the [flow_ui](https://github.com/StacDev/flow_ui) repository.
