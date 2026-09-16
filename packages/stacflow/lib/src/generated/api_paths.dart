// GENERATED CODE - DO NOT EDIT.
// Source: contracts/ - regenerate with `dart run tool/contracts_gen.dart`.
// coverage:ignore-file

/// Path constants/builders for the /v1 surface.
abstract final class ApiPaths {
  static const String sessions = '/v1/sessions';
  static String sessionsMessagesBySessionId(String sessionId) =>
      '/v1/sessions/$sessionId/messages';
  static const String manifests = '/v1/manifests';
  static const String threads = '/v1/threads';
  static String threadsByThreadId(String threadId) => '/v1/threads/$threadId';
}
