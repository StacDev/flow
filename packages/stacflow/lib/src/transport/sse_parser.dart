import 'dart:async';
import 'dart:convert';

final class SseFrame {
  const SseFrame({required this.data, this.event, this.id, this.retry});

  final String data;
  final String? event;
  final String? id;
  final int? retry;

  @override
  String toString() => 'SseFrame(event: $event, data: $data)';
}

final class SseDecoder extends StreamTransformerBase<List<int>, SseFrame> {
  const SseDecoder();

  @override
  Stream<SseFrame> bind(Stream<List<int>> stream) => stream
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .transform(const SseLineParser());
}

final class SseLineParser extends StreamTransformerBase<String, SseFrame> {
  const SseLineParser();

  @override
  Stream<SseFrame> bind(Stream<String> stream) {
    final builder = _FrameBuilder();
    return stream.expand(builder.feed);
  }
}

final class _FrameBuilder {
  final StringBuffer _data = StringBuffer();
  String? _event;
  String? _id;
  int? _retry;
  bool _first = true;

  static final RegExp _digits = RegExp(r'^\d+$');
  static final String _bom = String.fromCharCode(0xFEFF);
  static final String _nul = String.fromCharCode(0);

  Iterable<SseFrame> feed(String rawLine) {
    var line = rawLine;
    if (_first) {
      _first = false;
      if (line.startsWith(_bom)) line = line.substring(1);
    }
    if (line.isEmpty) return _dispatch();
    if (line.startsWith(':')) return const [];
    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'data':
        _data
          ..write(value)
          ..write('\n');
      case 'event':
        _event = value;
      case 'id':
        if (!value.contains(_nul)) _id = value;
      case 'retry':
        if (_digits.hasMatch(value)) _retry = int.parse(value);
    }
    return const [];
  }

  Iterable<SseFrame> _dispatch() {
    if (_data.isEmpty) {
      _event = null;
      return const [];
    }
    var data = _data.toString();
    if (data.endsWith('\n')) data = data.substring(0, data.length - 1);
    final frame = SseFrame(data: data, event: _event, id: _id, retry: _retry);
    _data.clear();
    _event = null;
    _id = null;
    _retry = null;
    return [frame];
  }
}
