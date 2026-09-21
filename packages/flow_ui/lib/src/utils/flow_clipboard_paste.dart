/// Pasting an image into the composer, where the platform allows it.
///
/// Only the web does. Flutter's [Clipboard] reads and writes plain text
/// and nothing else — its own doc says so, and `ClipboardData.text` is
/// the only variant there is — so on every other target this is the
/// stub: it registers nothing and reports nothing.
library;

export 'flow_clipboard_paste_stub.dart'
    if (dart.library.js_interop) 'flow_clipboard_paste_web.dart';
