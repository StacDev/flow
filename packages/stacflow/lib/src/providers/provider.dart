import 'package:stacflow/src/transport/turn_transport.dart';

/// What every turn carries besides the conversation: the system
/// instructions and the sampling knobs. Unset fields are left out of the
/// request.
final class AgentConfig {
  const AgentConfig({
    this.instructions,
    this.temperature,
    this.maxOutputTokens,
  });

  final String? instructions;
  final double? temperature;
  final int? maxOutputTokens;
}

/// A model a provider can be pointed at, as a selector shows it.
final class ModelOption {
  const ModelOption({required this.id, required this.label, this.description});

  final String id;
  final String label;
  final String? description;
}

/// One model API spoken natively with the developer's own key.
abstract interface class StacFlowProvider implements TurnTransport {
  /// `gemini`, `openai` or `anthropic`; reported as the upstream provider
  /// on errors.
  String get id;

  /// The model sent on the wire.
  String get model;

  /// The models a selector can offer; always contains [model].
  List<ModelOption> get models;

  /// The same provider aimed at another model.
  StacFlowProvider withModel(String model);
}

/// The network failed before a response arrived, or the connection closed
/// mid-stream. Worth retrying; never carries headers or URLs.
final class ProviderTransportException implements Exception {
  const ProviderTransportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ProviderTransportException: $message';
}
