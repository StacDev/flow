# stacflow example

The README's chat screen, runnable: a `StacFlowChat` on `GeminiProvider`
driving `StacFlowChatView`, with one tool, `set_theme`, so asking for
dark mode flips the app and shows the tool card. The selector in the
composer switches between two Gemini models and the plus button in the
app bar starts a new conversation. Streaming behind the thinking
indicator, stop, retry from the error card, regenerate, edit a turn,
images from the picker, a drop or a paste, copy and feedback all come
from the view; nothing here is wired by hand.

Grab a key from [Google AI Studio](https://aistudio.google.com/apikey) and
pass it at launch. Platform runners are checked in, so it runs directly:

```bash
flutter run --dart-define=GEMINI_API_KEY=AIza...
```

Or keep the key in a gitignored `env.json` next to this README and pass the
file instead:

```json
{ "GEMINI_API_KEY": "AIza..." }
```

```bash
flutter run --dart-define-from-file=env.json
```

With an empty key the app still runs; sending answers with the error card.
On the web the key travels to the browser: fine for this demo, not for a
public site.

The example resolves through the repo's pub workspace (`resolution: workspace`
in its pubspec). To use it outside the repo, delete that line and depend on
`stacflow` from pub.dev.
