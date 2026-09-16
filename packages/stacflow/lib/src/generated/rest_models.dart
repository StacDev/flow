// GENERATED CODE - DO NOT EDIT.
// Source: contracts/ - regenerate with `dart run tool/contracts_gen.dart`.
// coverage:ignore-file

/// REST component models (contracts/rest-api.openapi.yaml).
/// Request/response envelopes inline in path definitions are shaped by
/// the transport layer; only named components are generated.
library;

import 'sse_events.dart' show FailureClass;

enum CreateSessionRequestEnvironment {
  dev('dev'),
  prod('prod');

  const CreateSessionRequestEnvironment(this.wire);
  final String wire;
  static CreateSessionRequestEnvironment fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum ToolResultEntryStatus {
  ok('ok'),
  error('error'),
  declined('declined');

  const ToolResultEntryStatus(this.wire);
  final String wire;
  static ToolResultEntryStatus fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum ApprovalProvenance {
  humanConfirmation('human_confirmation'),
  biometric('biometric');

  const ApprovalProvenance(this.wire);
  final String wire;
  static ApprovalProvenance fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum CapabilityManifestToolsValuePermission {
  read('read'),
  write('write'),
  destructive('destructive');

  const CapabilityManifestToolsValuePermission(this.wire);
  final String wire;
  static CapabilityManifestToolsValuePermission fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum MessageRole {
  user('user'),
  assistant('assistant');

  const MessageRole(this.wire);
  final String wire;
  static MessageRole fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum ToolCallPartExecutor {
  client('client'),
  server('server');

  const ToolCallPartExecutor(this.wire);
  final String wire;
  static ToolCallPartExecutor fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum ToolCallPartPermissionClass {
  read('read'),
  write('write'),
  destructive('destructive');

  const ToolCallPartPermissionClass(this.wire);
  final String wire;
  static ToolCallPartPermissionClass fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum ToolCallPartStatus {
  pending('pending'),
  ok('ok'),
  error('error'),
  declined('declined');

  const ToolCallPartStatus(this.wire);
  final String wire;
  static ToolCallPartStatus fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

sealed class MessagePart {
  const MessagePart();

  factory MessagePart.fromJson(Map<String, dynamic> json) =>
      switch (json['type'] as String?) {
        'text' => TextPart.fromJson(json),
        'tool_call' => ToolCallPart.fromJson(json),
        'ui_surface' => UiSurfacePart.fromJson(json),
        _ => UnknownMessagePart(json),
      };

  Map<String, dynamic> toJson();
}

/// Passthrough for part types this build does not know (additive).
final class UnknownMessagePart extends MessagePart {
  const UnknownMessagePart(this.json);
  final Map<String, dynamic> json;
  @override
  Map<String, dynamic> toJson() => json;
}

final class ToolErrorUpstream {
  const ToolErrorUpstream({this.provider, this.status, this.code});

  factory ToolErrorUpstream.fromJson(Map<String, dynamic> json) =>
      ToolErrorUpstream(
        provider: json['provider'] as String?,
        status: json['status'] as int?,
        code: json['code'] as String?,
      );

  final String? provider;
  final int? status;
  final String? code;

  Map<String, dynamic> toJson() => <String, dynamic>{}
    ..addAll(
      provider == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'provider': provider},
    )
    ..addAll(
      status == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'status': status},
    )
    ..addAll(
      code == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'code': code},
    );
}

final class CapabilityManifestSdk {
  const CapabilityManifestSdk({required this.package, required this.version});

  factory CapabilityManifestSdk.fromJson(Map<String, dynamic> json) =>
      CapabilityManifestSdk(
        package: json['package'] as String,
        version: json['version'] as String,
      );

  final String package;
  final String version;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'package': package,
    'version': version,
  };
}

final class CapabilityManifestToolsValue {
  const CapabilityManifestToolsValue({
    required this.v,
    this.capabilityId,
    required this.permission,
    this.confirmation,
    this.biometric,
    this.description,
    this.argsSchema,
  });

  factory CapabilityManifestToolsValue.fromJson(Map<String, dynamic> json) =>
      CapabilityManifestToolsValue(
        v: json['v'] as int,
        capabilityId: json['capabilityId'] as String?,
        permission: CapabilityManifestToolsValuePermission.fromWire(
          json['permission'] as String,
        ),
        confirmation: json['confirmation'] as bool?,
        biometric: json['biometric'] as bool?,
        description: json['description'] as String?,
        argsSchema: (json['args_schema'] as Map?)?.cast<String, dynamic>(),
      );

  final int v;
  final String? capabilityId;
  final CapabilityManifestToolsValuePermission permission;
  final bool? confirmation;
  final bool? biometric;
  final String? description;
  final Map<String, dynamic>? argsSchema;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'v': v, 'permission': permission.wire}
        ..addAll(
          capabilityId == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'capabilityId': capabilityId},
        )
        ..addAll(
          confirmation == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'confirmation': confirmation},
        )
        ..addAll(
          biometric == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'biometric': biometric},
        )
        ..addAll(
          description == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'description': description},
        )
        ..addAll(
          argsSchema == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'args_schema': argsSchema},
        );
}

final class ErrorEnvelopeError {
  const ErrorEnvelopeError({
    required this.code,
    required this.failureClass,
    required this.message,
    required this.retryable,
    this.details,
  });

  factory ErrorEnvelopeError.fromJson(Map<String, dynamic> json) =>
      ErrorEnvelopeError(
        code: json['code'] as String,
        failureClass: FailureClass.fromWire(json['failure_class'] as String),
        message: json['message'] as String,
        retryable: json['retryable'] as bool,
        details: (json['details'] as Map?)?.cast<String, dynamic>(),
      );

  final String code;
  final FailureClass failureClass;
  final String message;
  final bool retryable;
  final Map<String, dynamic>? details;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
        'code': code,
        'failure_class': failureClass.wire,
        'message': message,
        'retryable': retryable,
      }..addAll(
        details == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'details': details},
      );
}

final class CreateSessionRequest {
  const CreateSessionRequest({
    required this.agentId,
    required this.environment,
    required this.externalUserId,
    this.anonymous,
    this.manifestHash,
  });

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) =>
      CreateSessionRequest(
        agentId: json['agent_id'] as String,
        environment: CreateSessionRequestEnvironment.fromWire(
          json['environment'] as String,
        ),
        externalUserId: json['external_user_id'] as String,
        anonymous: json['anonymous'] as bool?,
        manifestHash: json['manifest_hash'] as String?,
      );

  final String agentId;
  final CreateSessionRequestEnvironment environment;
  final String externalUserId;
  final bool? anonymous;
  final String? manifestHash;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
          'agent_id': agentId,
          'environment': environment.wire,
          'external_user_id': externalUserId,
        }
        ..addAll(
          anonymous == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'anonymous': anonymous},
        )
        ..addAll(
          manifestHash == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'manifest_hash': manifestHash},
        );
}

final class Session {
  const Session({
    required this.sessionId,
    required this.sessionToken,
    required this.expiresAt,
    required this.agentVersion,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    sessionId: json['session_id'] as String,
    sessionToken: json['session_token'] as String,
    expiresAt: json['expires_at'] as String,
    agentVersion: AgentVersionInfo.fromJson(
      (json['agent_version'] as Map).cast<String, dynamic>(),
    ),
  );

  final String sessionId;
  final String sessionToken;
  final String expiresAt;
  final AgentVersionInfo agentVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'session_id': sessionId,
    'session_token': sessionToken,
    'expires_at': expiresAt,
    'agent_version': agentVersion.toJson(),
  };
}

final class AgentVersionInfo {
  const AgentVersionInfo({
    required this.agentVersionId,
    required this.model,
    this.displayName,
  });

  factory AgentVersionInfo.fromJson(Map<String, dynamic> json) =>
      AgentVersionInfo(
        agentVersionId: json['agent_version_id'] as String,
        model: json['model'] as String,
        displayName: json['display_name'] as String?,
      );

  final String agentVersionId;
  final String model;
  final String? displayName;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'agent_version_id': agentVersionId, 'model': model}
        ..addAll(
          displayName == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'display_name': displayName},
        );
}

final class UserMessageBody {
  const UserMessageBody({
    this.threadId,
    required this.clientMsgId,
    required this.parts,
    required this.manifestHash,
  });

  factory UserMessageBody.fromJson(Map<String, dynamic> json) =>
      UserMessageBody(
        threadId: json['thread_id'] as String?,
        clientMsgId: json['client_msg_id'] as String,
        parts: (json['parts'] as List)
            .map((e) => UserPart.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        manifestHash: json['manifest_hash'] as String,
      );

  final String? threadId;
  final String clientMsgId;
  final List<UserPart> parts;
  final String manifestHash;
  String get kind => 'user_message';

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
        'kind': 'user_message',
        'client_msg_id': clientMsgId,
        'parts': parts.map((e) => e.toJson()).toList(),
        'manifest_hash': manifestHash,
      }..addAll(
        threadId == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'thread_id': threadId},
      );
}

final class UserPart {
  const UserPart({required this.text});

  factory UserPart.fromJson(Map<String, dynamic> json) =>
      UserPart(text: json['text'] as String);

  final String text;
  String get type => 'text';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'text',
    'text': text,
  };
}

final class ToolResultsBody {
  const ToolResultsBody({
    required this.threadId,
    required this.turnId,
    required this.results,
  });

  factory ToolResultsBody.fromJson(Map<String, dynamic> json) =>
      ToolResultsBody(
        threadId: json['thread_id'] as String,
        turnId: json['turn_id'] as String,
        results: (json['results'] as List)
            .map(
              (e) =>
                  ToolResultEntry.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  final String threadId;
  final String turnId;
  final List<ToolResultEntry> results;
  String get kind => 'tool_results';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'tool_results',
    'thread_id': threadId,
    'turn_id': turnId,
    'results': results.map((e) => e.toJson()).toList(),
  };
}

final class ToolResultEntry {
  const ToolResultEntry({
    required this.toolCallId,
    required this.status,
    this.result,
    this.error,
    this.approval,
  });

  factory ToolResultEntry.fromJson(
    Map<String, dynamic> json,
  ) => ToolResultEntry(
    toolCallId: json['tool_call_id'] as String,
    status: ToolResultEntryStatus.fromWire(json['status'] as String),
    result: (json['result'] as Map?)?.cast<String, dynamic>(),
    error: json['error'] == null
        ? null
        : ToolError.fromJson((json['error'] as Map).cast<String, dynamic>()),
    approval: json['approval'] == null
        ? null
        : Approval.fromJson((json['approval'] as Map).cast<String, dynamic>()),
  );

  final String toolCallId;
  final ToolResultEntryStatus status;
  final Map<String, dynamic>? result;
  final ToolError? error;
  final Approval? approval;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'tool_call_id': toolCallId, 'status': status.wire}
        ..addAll(
          result == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'result': result},
        )
        ..addAll(
          error == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'error': error!.toJson()},
        )
        ..addAll(
          approval == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'approval': approval!.toJson()},
        );
}

final class ToolError {
  const ToolError({
    required this.failureClass,
    required this.code,
    required this.message,
    this.upstream,
  });

  factory ToolError.fromJson(Map<String, dynamic> json) => ToolError(
    failureClass: FailureClass.fromWire(json['failure_class'] as String),
    code: json['code'] as String,
    message: json['message'] as String,
    upstream: json['upstream'] == null
        ? null
        : ToolErrorUpstream.fromJson(
            (json['upstream'] as Map).cast<String, dynamic>(),
          ),
  );

  final FailureClass failureClass;
  final String code;
  final String message;
  final ToolErrorUpstream? upstream;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
        'failure_class': failureClass.wire,
        'code': code,
        'message': message,
      }..addAll(
        upstream == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'upstream': upstream!.toJson()},
      );
}

final class Approval {
  const Approval({
    required this.provenance,
    required this.decisionFingerprint,
    required this.jti,
  });

  factory Approval.fromJson(Map<String, dynamic> json) => Approval(
    provenance: ApprovalProvenance.fromWire(json['provenance'] as String),
    decisionFingerprint: json['decision_fingerprint'] as String,
    jti: json['jti'] as String,
  );

  final ApprovalProvenance provenance;
  final String decisionFingerprint;
  final String jti;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'provenance': provenance.wire,
    'decision_fingerprint': decisionFingerprint,
    'jti': jti,
  };
}

final class CapabilityManifest {
  const CapabilityManifest({
    required this.sdk,
    this.catalogs,
    this.components,
    required this.tools,
    this.policies,
    this.capabilities,
    this.limits,
  });

  factory CapabilityManifest.fromJson(Map<String, dynamic> json) =>
      CapabilityManifest(
        sdk: CapabilityManifestSdk.fromJson(
          (json['sdk'] as Map).cast<String, dynamic>(),
        ),
        catalogs: json['catalogs'] == null
            ? null
            : List<String>.from(json['catalogs'] as List),
        components: json['components'] == null
            ? null
            : Map<String, int>.from(json['components'] as Map),
        tools: (json['tools'] as Map).map(
          (k, v) => MapEntry(
            k as String,
            CapabilityManifestToolsValue.fromJson(
              (v as Map).cast<String, dynamic>(),
            ),
          ),
        ),
        policies: json['policies'] == null
            ? null
            : Map<String, int>.from(json['policies'] as Map),
        capabilities: json['capabilities'] == null
            ? null
            : Map<String, int>.from(json['capabilities'] as Map),
        limits: json['limits'] == null
            ? null
            : Map<String, int>.from(json['limits'] as Map),
      );

  final CapabilityManifestSdk sdk;
  final List<String>? catalogs;
  final Map<String, int>? components;
  final Map<String, CapabilityManifestToolsValue> tools;
  final Map<String, int>? policies;
  final Map<String, int>? capabilities;
  final Map<String, int>? limits;
  int get manifestVersion => 1;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
          'manifestVersion': 1,
          'sdk': sdk.toJson(),
          'tools': tools.map((k, v) => MapEntry(k, v.toJson())),
        }
        ..addAll(
          catalogs == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'catalogs': catalogs},
        )
        ..addAll(
          components == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'components': components},
        )
        ..addAll(
          policies == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'policies': policies},
        )
        ..addAll(
          capabilities == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'capabilities': capabilities},
        )
        ..addAll(
          limits == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'limits': limits},
        );
}

final class Thread {
  const Thread({
    required this.threadId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
  });

  factory Thread.fromJson(Map<String, dynamic> json) => Thread(
    threadId: json['thread_id'] as String,
    title: json['title'] as String?,
    createdAt: json['created_at'] as String,
    updatedAt: json['updated_at'] as String,
    lastMessageAt: json['last_message_at'] as String?,
  );

  final String threadId;
  final String? title;
  final String createdAt;
  final String updatedAt;
  final String? lastMessageAt;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
          'thread_id': threadId,
          'created_at': createdAt,
          'updated_at': updatedAt,
        }
        ..addAll(
          title == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'title': title},
        )
        ..addAll(
          lastMessageAt == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'last_message_at': lastMessageAt},
        );
}

final class Message {
  const Message({
    required this.messageId,
    required this.threadId,
    required this.turnId,
    required this.role,
    required this.createdAt,
    required this.parts,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    messageId: json['message_id'] as String,
    threadId: json['thread_id'] as String,
    turnId: json['turn_id'] as String,
    role: MessageRole.fromWire(json['role'] as String),
    createdAt: json['created_at'] as String,
    parts: (json['parts'] as List)
        .map((e) => MessagePart.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final String messageId;
  final String threadId;
  final String turnId;
  final MessageRole role;
  final String createdAt;
  final List<MessagePart> parts;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'message_id': messageId,
    'thread_id': threadId,
    'turn_id': turnId,
    'role': role.wire,
    'created_at': createdAt,
    'parts': parts.map((e) => e.toJson()).toList(),
  };
}

final class TextPart extends MessagePart {
  const TextPart({required this.text});

  factory TextPart.fromJson(Map<String, dynamic> json) =>
      TextPart(text: json['text'] as String);

  final String text;
  String get type => 'text';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'text',
    'text': text,
  };
}

final class ToolCallPart extends MessagePart {
  const ToolCallPart({
    required this.toolCallId,
    required this.toolName,
    required this.executor,
    required this.permissionClass,
    required this.args,
    required this.status,
    this.result,
    this.error,
    this.approval,
  });

  factory ToolCallPart.fromJson(Map<String, dynamic> json) => ToolCallPart(
    toolCallId: json['tool_call_id'] as String,
    toolName: json['tool_name'] as String,
    executor: ToolCallPartExecutor.fromWire(json['executor'] as String),
    permissionClass: ToolCallPartPermissionClass.fromWire(
      json['permission_class'] as String,
    ),
    args: (json['args'] as Map).cast<String, dynamic>(),
    status: ToolCallPartStatus.fromWire(json['status'] as String),
    result: (json['result'] as Map?)?.cast<String, dynamic>(),
    error: json['error'] == null
        ? null
        : ToolError.fromJson((json['error'] as Map).cast<String, dynamic>()),
    approval: json['approval'] == null
        ? null
        : Approval.fromJson((json['approval'] as Map).cast<String, dynamic>()),
  );

  final String toolCallId;
  final String toolName;
  final ToolCallPartExecutor executor;
  final ToolCallPartPermissionClass permissionClass;
  final Map<String, dynamic> args;
  final ToolCallPartStatus status;
  final Map<String, dynamic>? result;
  final ToolError? error;
  final Approval? approval;
  String get type => 'tool_call';

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
          'type': 'tool_call',
          'tool_call_id': toolCallId,
          'tool_name': toolName,
          'executor': executor.wire,
          'permission_class': permissionClass.wire,
          'args': args,
          'status': status.wire,
        }
        ..addAll(
          result == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'result': result},
        )
        ..addAll(
          error == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'error': error!.toJson()},
        )
        ..addAll(
          approval == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'approval': approval!.toJson()},
        );
}

final class UiSurfacePart extends MessagePart {
  const UiSurfacePart({required this.surfaceId, required this.a2ui});

  factory UiSurfacePart.fromJson(Map<String, dynamic> json) => UiSurfacePart(
    surfaceId: json['surface_id'] as String,
    a2ui: (json['a2ui'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList(),
  );

  final String surfaceId;
  final List<Map<String, dynamic>> a2ui;
  String get type => 'ui_surface';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'ui_surface',
    'surface_id': surfaceId,
    'a2ui': a2ui,
  };
}

final class ErrorEnvelope {
  const ErrorEnvelope({required this.error});

  factory ErrorEnvelope.fromJson(Map<String, dynamic> json) => ErrorEnvelope(
    error: ErrorEnvelopeError.fromJson(
      (json['error'] as Map).cast<String, dynamic>(),
    ),
  );

  final ErrorEnvelopeError error;

  Map<String, dynamic> toJson() => <String, dynamic>{'error': error.toJson()};
}
