# stacflow example

The README's chat screen, runnable: a `StacFlowChat` on `GeminiProvider`
driving `StacFlowChatView`, with one tool, `set_theme`, so asking for
dark mode flips the app and shows the tool card. The selector in the
composer switches between two Gemini models and the plus button in the
app bar starts a new conversation. Streaming behind the thinking
indicator, stop, retry from the error card, regenerate, edit a turn,
images from the picker, a drop or a paste, copy and feedback all come
from the view; nothing here is wired by hand.

Grab a key from [Google AI Studio](https://aistudio.google.com/apikey), copy
`lib/env.example.dart` to `lib/env.dart` and paste it in. `lib/env.dart` is
gitignored, so the key never reaches the repository. Platform runners are
checked in, so it then runs directly:

```bash
cp lib/env.example.dart lib/env.dart
flutter run
```

A `--dart-define=GEMINI_API_KEY=AIza...` at launch overrides the file.

With an empty key the app still runs; sending answers with the error card.
On the web the key travels to the browser: fine for this demo, not for a
public site.

The example resolves through the repo's pub workspace (`resolution: workspace`
in its pubspec). To use it outside the repo, delete that line and depend on
`stacflow` from pub.dev.
