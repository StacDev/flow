import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stacflow/src/generated/sse_events.dart';
import 'package:stacflow/src/providers/anthropic_provider.dart';
import 'package:stacflow/src/providers/gemini_provider.dart';
import 'package:stacflow/src/providers/openai_provider.dart';
import 'package:stacflow/src/providers/provider.dart';
import 'package:stacflow/src/tools/tool.dart';
import 'package:stacflow/src/tools/tool_loop.dart';
import 'package:stacflow/src/transport/turn_ids.dart';
import 'package:stacflow/src/transport/turn_request.dart';

const String _providerName = String.fromEnvironment(
  'PROVIDER',
  defaultValue: 'gemini',
);
const String _prompt = String.fromEnvironment(
  'PROMPT',
  defaultValue: 'Say hello in five words.',
);
const String _imagePath = String.fromEnvironment('IMAGE');
const String _openAiBaseUrl = String.fromEnvironment('OPENAI_BASE_URL');
const bool _abortAfterFirstDelta = bool.fromEnvironment(
  'ABORT_AFTER_FIRST_DELTA',
);
const bool _tools = bool.fromEnvironment('TOOLS');
const String _toolPermission = String.fromEnvironment(
  'TOOL_PERMISSION',
  defaultValue: 'read',
);
const bool _decline = bool.fromEnvironment('DECLINE');

Future<void> main() async {
  final provider = switch (_providerName) {
    'gemini' => GeminiProvider(
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    ),
    'anthropic' => AnthropicProvider(
      apiKey: const String.fromEnvironment('ANTHROPIC_API_KEY'),
    ),
    'openai' => OpenAIProvider(
      apiKey: const String.fromEnvironment('OPENAI_API_KEY'),
      baseUrl: _openAiBaseUrl.isEmpty
          ? 'https://api.openai.com/v1'
          : _openAiBaseUrl,
    ),
    _ => throw ArgumentError.value(_providerName, 'PROVIDER'),
  };
  final ids = IdGenerator();
  final abort = Completer<void>();
  final parts = <WirePart>[
    if (_imagePath.isNotEmpty)
      WireImagePart(
        bytes: File(_imagePath).readAsBytesSync(),
        mimeType: _imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg',
      ),
    const WireTextPart(_prompt),
  ];
  final tools = [
    if (_tools)
      Tool(
        name: 'get_time',
        description: 'The current local date and time.',
        permission: switch (_toolPermission) {
          'write' => ToolPermission.write,
          'destructive' => ToolPermission.destructive,
          _ => ToolPermission.read,
        },
        run: (call) => {'now': DateTime.now().toIso8601String()},
      ),
  ];
  final request = TurnRequest(
    history: [WireMessage(role: WireRole.user, parts: parts)],
    agent: const AgentConfig(),
    ids: TurnIds.generate(threadId: ids.thread(), ids: ids),
    abortTrigger: abort.future,
    tools: tools,
  );
  stdout.writeln('provider: $provider');
  final started = DateTime.now();
  int elapsed() => DateTime.now().difference(started).inMilliseconds;
  final stream = runToolLoop(
    transport: provider,
    request: request,
    approve: (record) async => !_decline,
    onCall: (record) => stdout.writeln(
      '[${elapsed()}ms] tool ${record.id} ${record.name} '
      '${record.status.name} args=${jsonEncode(record.args)} '
      'result=${jsonEncode(record.result)} error=${record.error?.message}',
    ),
  );
  try {
    await for (final event in stream) {
      stdout.writeln('[${elapsed()}ms] ${_describe(event)}');
      if (_abortAfterFirstDelta && event is DeltaEvent && !abort.isCompleted) {
        abort.complete();
      }
    }
  } on ProviderTransportException catch (error) {
    stdout.writeln('transport failure: $error');
  }
}

String _describe(SseEvent event) => switch (event) {
  StartEvent() => 'start ${jsonEncode(event.toJson())}',
  DeltaEvent() => 'delta ${jsonEncode(event.text)}',
  UsageEvent() => 'usage ${jsonEncode(event.toJson())}',
  ErrorEvent() => 'error ${jsonEncode(event.toJson())}',
  DoneEvent() => 'done ${jsonEncode(event.toJson())}',
  UiPayloadEvent() => 'ui_payload ${jsonEncode(event.toJson())}',
  ToolCallStartEvent() =>
    'tool_call start ${event.toolCallId} ${event.toolName} '
        '${event.permissionClass.wire}',
  ToolCallDeltaEvent() =>
    'tool_call delta ${event.toolCallId} ${jsonEncode(event.argsDelta)}',
  ToolCallEndEvent() =>
    'tool_call end ${event.toolCallId} ${jsonEncode(event.args)}',
  SseUnknownEvent() => 'unknown ${event.event}',
};
