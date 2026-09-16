// GENERATED CODE - DO NOT EDIT.
// Source: contracts/ - regenerate with `dart run tool/contracts_gen.dart`.
// coverage:ignore-file

import 'sse_events.dart';

/// One entry of the error-code registry (contracts/error-codes.json).
final class ErrorCodeInfo {
  const ErrorCodeInfo({
    required this.failureClass,
    required this.http,
    required this.retryable,
    required this.description,
  });
  final FailureClass failureClass;
  final int http;
  final bool retryable;
  final String description;
}

/// The frozen, additively growing error-code registry.
abstract final class ErrorCodes {
  static const String invalidApiKey = 'invalid_api_key';
  static const String unauthorized = 'unauthorized';
  static const String forbidden = 'forbidden';
  static const String tokenExpired = 'token_expired';
  static const String unknownAgent = 'unknown_agent';
  static const String agentNotDeployed = 'agent_not_deployed';
  static const String unknownManifest = 'unknown_manifest';
  static const String duplicateMessage = 'duplicate_message';
  static const String threadNotFound = 'thread_not_found';
  static const String validationFailed = 'validation_failed';
  static const String quotaExceeded = 'quota_exceeded';
  static const String missingApproval = 'missing_approval';
  static const String jtiReused = 'jti_reused';
  static const String pendingToolsUnanswered = 'pending_tools_unanswered';
  static const String providerError = 'provider_error';
  static const String providerRateLimited = 'provider_rate_limited';
  static const String providerAuthFailed = 'provider_auth_failed';
  static const String segmentTimeout = 'segment_timeout';
  static const String cancelled = 'cancelled';
  static const String internal = 'internal';

  static const Map<String, ErrorCodeInfo> registry = {
    'invalid_api_key': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 401,
      retryable: false,
      description:
          'Publishable key missing, malformed, revoked, or hash mismatch.',
    ),
    'unauthorized': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 401,
      retryable: false,
      description: 'Missing or invalid credentials for this endpoint.',
    ),
    'forbidden': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 403,
      retryable: false,
      description: 'The authenticated member lacks permission for this action.',
    ),
    'token_expired': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 401,
      retryable: true,
      description: 'Session JWT expired; the SDK recreates the session transparently and retries.',
    ),
    'unknown_agent': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 404,
      retryable: false,
      description: 'agent_id does not exist in this project.',
    ),
    'agent_not_deployed': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 404,
      retryable: false,
      description: 'No deployment exists for (agent, environment).',
    ),
    'unknown_manifest': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 409,
      retryable: true,
      description: 'manifest_hash not registered; POST the body to /v1/manifests and retry.',
    ),
    'duplicate_message': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 409,
      retryable: false,
      description: 'client_msg_id already processed; details.turn_id carries the existing turn.',
    ),
    'thread_not_found': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 404,
      retryable: false,
      description: 'Thread does not exist or is not visible to this end user.',
    ),
    'validation_failed': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 422,
      retryable: false,
      description:
          'Request body failed contract validation; details carries locators.',
    ),
    'quota_exceeded': ErrorCodeInfo(
      failureClass: FailureClass.policy,
      http: 429,
      retryable: false,
      description: 'A project quota or plan cap tripped; a clear refusal, never a mystery 500.',
    ),
    'missing_approval': ErrorCodeInfo(
      failureClass: FailureClass.policy,
      http: 422,
      retryable: false,
      description: 'A destructive tool_results entry arrived without an approval object.',
    ),
    'jti_reused': ErrorCodeInfo(
      failureClass: FailureClass.policy,
      http: 409,
      retryable: false,
      description: 'Single-use authorization id was already consumed; the continuation is rejected.',
    ),
    'pending_tools_unanswered': ErrorCodeInfo(
      failureClass: FailureClass.policy,
      http: 422,
      retryable: false,
      description: 'The continuation left one or more pending tool calls without a result.',
    ),
    'provider_error': ErrorCodeInfo(
      failureClass: FailureClass.provider,
      http: 502,
      retryable: true,
      description: 'The model provider failed; upstream carries {provider, status, code}.',
    ),
    'provider_rate_limited': ErrorCodeInfo(
      failureClass: FailureClass.provider,
      http: 429,
      retryable: true,
      description: 'The developer\'s provider key is rate-limited or out of quota upstream.',
    ),
    'provider_auth_failed': ErrorCodeInfo(
      failureClass: FailureClass.provider,
      http: 502,
      retryable: false,
      description: 'The vaulted BYOK key was rejected by the provider; fix it in Console → Settings → provider keys.',
    ),
    'segment_timeout': ErrorCodeInfo(
      failureClass: FailureClass.timeout,
      http: 504,
      retryable: true,
      description: 'The provider stream stalled past the segment deadline.',
    ),
    'cancelled': ErrorCodeInfo(
      failureClass: FailureClass.cancelled,
      http: 499,
      retryable: false,
      description:
          'The client stopped the stream; the segment ends done{cancelled}.',
    ),
    'internal': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 500,
      retryable: true,
      description: 'Unattributed gateway fault; alarmed and triaged — never the catch-all for the classes above.',
    ),
  };
}
