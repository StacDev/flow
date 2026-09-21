/// The Gemini key, passed at launch so it never lands in a commit:
///   flutter run --dart-define=GEMINI_API_KEY=AIza...
/// or from a gitignored file: flutter run --dart-define-from-file=env.json
/// Empty when neither is given: the app runs and sending shows the error card.
const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
