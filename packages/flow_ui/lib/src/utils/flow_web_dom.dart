// A stripped-down slice of `package:web`, hand-declared so that flow_ui's
// drag-and-drop needs no dependency for it. The framework does the same
// thing for the same reason — see `packages/flutter/lib/src/web.dart`,
// whose header explains the practice — and these types are erased at
// runtime, so a copy that omits unused supertypes is safe.
//
// Only reachable on the web: the sole importer is flow_file_drop_web.dart,
// which is itself behind a conditional export.
//
// ignore_for_file: public_member_api_docs
library;

import 'dart:js_interop';

typedef EventListener = JSFunction;

extension type EventTarget._(JSObject _) implements JSObject {
  // The trailing argument is the listener options — `true` for the
  // capture phase, which is how the paste listener sees an event before
  // whatever the engine does with it.
  external void addEventListener(
    String type,
    EventListener? callback, [
    JSAny options,
  ]);
  external void removeEventListener(
    String type,
    EventListener? callback, [
    JSAny options,
  ]);
}

extension type Node._(JSObject _) implements EventTarget, JSObject {}

@JS()
external Document get document;

extension type Document._(JSObject _) implements Node, JSObject {}

extension type Element._(JSObject _) implements Node, JSObject {
  external DOMRect getBoundingClientRect();
}

extension type HTMLElement._(JSObject _) implements Element, JSObject {}

extension type DOMRect._(JSObject _) implements JSObject {
  external double get left;
  external double get top;
  external double get width;
  external double get height;
}

extension type Event._(JSObject _) implements JSObject {
  external void preventDefault();
}

extension type MouseEvent._(JSObject _) implements Event, JSObject {
  external double get clientX;
  external double get clientY;
}

extension type DragEvent._(JSObject _) implements MouseEvent, JSObject {
  external DataTransfer? get dataTransfer;
}

extension type ClipboardEvent._(JSObject _) implements Event, JSObject {
  external DataTransfer? get clipboardData;
}

extension type DataTransfer._(JSObject _) implements JSObject {
  external JSArray<JSString> get types;
  external FileList? get files;
  external set dropEffect(String value);
}

extension type FileList._(JSObject _) implements JSObject {
  external int get length;
  external File? item(int index);
}

extension type File._(JSObject _) implements JSObject {
  external String get name;
  external int get size;
  external String get type;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}
