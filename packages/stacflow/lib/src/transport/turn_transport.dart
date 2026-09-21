import 'package:stacflow/src/transport/sse_events.dart';
import 'package:stacflow/src/transport/turn_request.dart';

/// Where a turn's events come from: a provider today, a gateway later.
/// A run emits `start` first, exactly one `done` last, with `seq` strictly
/// increasing from 0.
abstract interface class TurnTransport {
  /// Runs one turn and streams its events.
  Stream<SseEvent> run(TurnRequest request);
}
