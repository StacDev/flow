import 'dart:convert';
import 'dart:math';

/// Mints the `thr_`, `trn_`, `msg_` and `tc_` ids a chat uses. Inject one
/// with a seeded [Random] for reproducible ids.
class IdGenerator {
  new({Random? random}) : _random = random ?? Random.secure();

  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  final Random _random;

  /// [prefix] followed by 16 base62 characters.
  String next(String prefix) {
    final buffer = StringBuffer(prefix);
    for (var i = 0; i < 16; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// A fresh thread id.
  String thread() => next('thr_');

  /// A fresh turn id.
  String turn() => next('trn_');

  /// A fresh message id.
  String message() => next('msg_');

  /// A fresh tool-call id, for a call the provider did not name.
  String toolCall() => next('tc_x');
}

/// A tool-call id that carries [providerCallId], recoverable through
/// [providerCallIdOf].
String toolCallIdFor(String providerCallId) {
  final buffer = StringBuffer('tc_');
  for (final byte in utf8.encode(providerCallId)) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// The provider's own call id inside an id from [toolCallIdFor]; null for
/// ids the SDK minted.
String? providerCallIdOf(String toolCallId) {
  if (!toolCallId.startsWith('tc_')) return null;
  final hex = toolCallId.substring(3);
  if (hex.isEmpty || hex.length.isOdd || !_hexPattern.hasMatch(hex)) {
    return null;
  }
  final bytes = [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
  return utf8.decode(bytes, allowMalformed: true);
}

final RegExp _hexPattern = RegExp(r'^[0-9a-f]+$');

/// The identity of one turn on the wire.
final class TurnIds {
  const new({
    required this.turnId,
    required this.messageId,
    required this.threadId,
  });

  /// Fresh turn and message ids under [threadId].
  factory generate({required String threadId, IdGenerator? ids}) {
    final generator = ids ?? IdGenerator();
    return TurnIds(
      turnId: generator.turn(),
      messageId: generator.message(),
      threadId: threadId,
    );
  }

  /// The agent version reported when no agent is deployed anywhere.
  static const String agentVersionId = 'agv_direct';

  final String turnId;
  final String messageId;
  final String threadId;
}
