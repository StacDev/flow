# flow_ui example

A live chat screen built with flow_ui: a zero state with a greeting, a
streaming Gemini reply behind the thinking indicator, stop, and retry on
the error card. Images go both ways — attach one from the file dialog, a
drop or a paste and it rides up with the turn; pick the image model in
the selector, ask for a picture, and it comes back through
`FlowImagePart`, shimmering until the bytes land. flow_ui renders the
state; `gemini_api.dart` is the host-side transport it never sees.

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

With an empty key the app still runs — sending just answers with the
error card explaining what's missing.

For a live tour of every component — with variants and code snippets — open
the hosted [playground](https://flowui.stac.dev/playground), or run it from
[the repo](https://github.com/StacDev/flow/tree/main/playground):

```bash
cd playground && flutter run -d chrome   # from the repo root
```

The example resolves through the repo's pub workspace (`resolution: workspace`
in its pubspec). To use it outside the repo, delete that line and depend on
`flow_ui` from pub.dev.
