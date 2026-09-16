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
  static const String validationFailed = 'validation_failed';
  static const String providerError = 'provider_error';
  static const String providerRateLimited = 'provider_rate_limited';
  static const String providerAuthFailed = 'provider_auth_failed';
  static const String segmentTimeout = 'segment_timeout';
  static const String cancelled = 'cancelled';

  static const Map<String, ErrorCodeInfo> registry = {
    'validation_failed': ErrorCodeInfo(
      failureClass: FailureClass.gateway,
      http: 422,
      retryable: false,
      description: 'The request failed validation before it was sent.',
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
      description: 'The provider rejected the API key.',
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
  };
}
