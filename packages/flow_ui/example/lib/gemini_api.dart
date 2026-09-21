import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flow_ui/flow_ui.dart';
import 'package:http/http.dart' as http;

/// One piece of a streamed reply: a run of text, or a whole picture.
///
/// Gemini streams text in fragments but delivers an image in one chunk,
/// so a reply is a sequence of these rather than a string.
sealed class GeminiDelta {
  const GeminiDelta();
}

/// A fragment of the reply's text, to be appended to what came before.
class GeminiTextDelta extends GeminiDelta {
  const GeminiTextDelta(this.text);

  final String text;
}

/// A generated picture, complete.
class GeminiImageDelta extends GeminiDelta {
  const GeminiImageDelta(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

/// Minimal Gemini client for the example app — the host-side transport.
///
/// flow_ui never sees it: the conversation goes in as the screen's
/// [FlowMessageData] list, and the reply comes back as a stream of text
/// deltas the screen folds into its own state. Everything model-facing
/// stays on this side of the boundary.
class GeminiApi {
  GeminiApi({
    required this.apiKey,
    this.model = 'gemini-3.6-flash',
    this.imageOutput = false,
  });

  final String apiKey;
  final String model;

  /// Ask for pictures as well as text. Only the image models honour it;
  /// a text model refuses the request outright, so the screen sets this
  /// from the model it picked rather than always asking.
  final bool imageOutput;

  static const String _host = 'generativelanguage.googleapis.com';

  /// Streams the reply to [history] as [GeminiDelta]s: text fragments as
  /// they arrive, and a [GeminiImageDelta] for each picture an image
  /// model generates.
  ///
  /// [history] is the conversation so far, oldest first; user turns are
  /// sent as `user`, assistant turns as `model`, and everything that
  /// isn't a successful turn (system turns, failed turns) is skipped.
  ///
  /// Attached images ride along as `inlineData`: flow_ui hands back the
  /// bytes it read, this encodes them. Throws a [GeminiApiException] with
  /// the API's own message when the request is refused.
  Stream<GeminiDelta> streamReply(List<FlowMessageData> history) async* {
    if (apiKey.isEmpty) {
      throw GeminiApiException(
        'No API key. Pass one with --dart-define=GEMINI_API_KEY=... '
        '(see example/README.md).',
      );
    }

    final client = http.Client();
    try {
      final request =
          http.Request(
              'POST',
              Uri.https(_host, '/v1beta/models/$model:streamGenerateContent', {
                'alt': 'sse',
              }),
            )
            ..headers['x-goog-api-key'] = apiKey
            ..headers['content-type'] = 'application/json'
            ..body = jsonEncode({
              'contents': _contentsFrom(history),
              if (imageOutput)
                'generationConfig': {
                  'responseModalities': ['TEXT', 'IMAGE'],
                },
            });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw GeminiApiException(
          _errorMessage(
            await response.stream.bytesToString(),
            response.statusCode,
          ),
        );
      }

      // The SSE stream: one `data: {json}` line per chunk.
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        for (final delta in _deltasFrom(line.substring(6))) {
          yield delta;
        }
      }
    } finally {
      client.close();
    }
  }

  static List<Map<String, Object?>> _contentsFrom(
    List<FlowMessageData> history,
  ) {
    final contents = <Map<String, Object?>>[];
    for (final message in history) {
      // A failed turn can carry the partial text streamed before the
      // error; replaying it as a successful `model` message would make
      // Gemini continue from its own aborted reply.
      if (message.role == FlowMessageRole.system ||
          message.status == FlowMessageStatus.error) {
        continue;
      }
      final parts = _partsOf(message);
      if (parts.isEmpty) continue;
      contents.add({
        'role': message.role == FlowMessageRole.user ? 'user' : 'model',
        'parts': parts,
      });
    }
    return contents;
  }

  /// A turn's text and its images, in Gemini's shape.
  ///
  /// The bytes come straight off the [FlowAttachment]s flow_ui built when
  /// the user picked or dropped the file — the package reads and decodes,
  /// and leaves both the original bytes and their type on the attachment
  /// for exactly this. Anything without bytes, or without an image type,
  /// is display-only and skipped.
  static List<Map<String, Object?>> _partsOf(FlowMessageData message) {
    final parts = <Map<String, Object?>>[];

    // Walked in order, so what the model reads matches what the bubble
    // shows: the picture first and the caption under it, the way the
    // turn was composed.
    for (final part in message.parts) {
      switch (part) {
        case FlowTextPart(:final text) when text.isNotEmpty:
          parts.add({'text': text});
        case FlowAttachmentPart(:final attachments):
          for (final attachment in attachments) {
            _addImage(parts, attachment.bytes, attachment.mimeType);
          }
        // A picture the model generated goes back up with the history,
        // so a follow-up can be about it — 'make it warmer' needs the
        // model to see what it drew.
        case FlowImagePart(:final bytes, :final mimeType):
          _addImage(parts, bytes, mimeType);
        default:
          break;
      }
    }
    return parts;
  }

  /// The deltas in one SSE chunk, in the order the model put them. Text
  /// arrives as `text` parts; a picture as `inlineData`, base64 in the
  /// JSON, decoded here so the screen only ever sees bytes.
  static List<GeminiDelta> _deltasFrom(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>? ?? const [];
      if (candidates.isEmpty) return const [];
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>? ?? const [];
      return [
        for (final part in parts)
          if (part case {'text': final String text} when text.isNotEmpty)
            GeminiTextDelta(text)
          else if (part case {
            'inlineData': {
              'mimeType': final String mimeType,
              'data': final String base64,
            },
          })
            GeminiImageDelta(base64Decode(base64), mimeType),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// One `inlineData` part, when there is a picture to send. inlineData
  /// is capped by the request size (~20MB) and base64 inflates by a
  /// third, which the composer's 10MB ceiling keeps well inside.
  static void _addImage(
    List<Map<String, Object?>> parts,
    Uint8List? bytes,
    String? mimeType,
  ) {
    if (bytes == null || mimeType == null) return;
    if (!mimeType.startsWith('image/')) return;
    parts.add({
      'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
    });
  }

  static String _errorMessage(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['error'] case {'message': final String message}) {
        return message;
      }
    } on FormatException {
      // Fall through to the generic message.
    }
    return 'Gemini returned HTTP $statusCode.';
  }
}

/// A refused request, carrying the API's message for the error card.
class GeminiApiException implements Exception {
  GeminiApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
