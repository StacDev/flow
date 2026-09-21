import 'dart:math' as math;

/// The streaming reveal's arithmetic, extracted from `FlowStreamingText`
/// so the markdown renderer's styled leaves share the exact machinery:
/// a fractional reveal count, per-character fade stamps, lag adaptation,
/// and the end-of-stream fast-forward. Widgets own the Ticker — they are
/// the TickerProviders and the ones calling setState — the engine owns
/// the counters, so both span-builders animate identically.
class FlowRevealEngine {
  /// How long a revealed character takes to fade to full opacity.
  static const double fadeSeconds = 0.25;

  /// Maximum time the reveal may lag behind the incoming text.
  static const double maxLagSeconds = 0.4;

  /// Catch-up window once streaming has completed.
  static const double fastForwardSeconds = 0.15;

  /// Upper bound on individually faded spans per frame.
  static const int maxFadeSpans = 60;

  /// Characters revealed so far (fractional between characters).
  double _revealed = 0;

  /// Monotonic clock in seconds, accumulated across ticker runs.
  double _clock = 0;

  /// Reveal timestamps: entry `i` is for character `_stampBase + i`.
  /// Characters below [_stampBase] were revealed without animation.
  final List<double> _revealedAt = <double>[];
  int _stampBase = 0;

  bool _fastForwarding = false;

  double get revealed => _revealed;

  int get revealedFloor => _revealed.floor();

  bool get tailStillFading =>
      _revealedAt.isNotEmpty && _clock - _revealedAt.last < fadeSeconds;

  /// Restarts the reveal from nothing — a replacement text.
  void reset() {
    _revealed = 0;
    _stampBase = 0;
    _revealedAt.clear();
    _fastForwarding = false;
  }

  /// Clamps the reveal back to [length] when the source shrank to a
  /// prefix of itself — a markdown block handing part of its tail to a
  /// newly recognized construct. Stamps are indexed by source offset, so
  /// the surviving prefix keeps its in-flight fades.
  void truncateTo(int length) {
    if (_revealed <= length) return;
    _revealed = length.toDouble();
    if (_stampBase > length) _stampBase = length;
    final keep = length - _stampBase;
    if (_revealedAt.length > keep) {
      _revealedAt.removeRange(keep, _revealedAt.length);
    }
  }

  /// Marks [length] characters revealed without animation.
  void snapToEnd(int length) {
    _revealed = length.toDouble();
    _revealedAt.clear();
    _stampBase = length;
    _fastForwarding = false;
  }

  /// Enters the completed-stream catch-up: the remainder reveals within
  /// [fastForwardSeconds] instead of trickling at the baseline speed.
  void beginFastForward() => _fastForwarding = true;

  void clearFastForward() => _fastForwarding = false;

  /// Advances the reveal by [dt] seconds toward [target] characters at
  /// [charactersPerSecond], adapting above it whenever the backlog would
  /// otherwise fall more than a beat behind. Returns false once the
  /// reveal has caught up and the tail has finished fading — the
  /// caller's cue to stop its ticker.
  bool tick(double dt, int target, double charactersPerSecond) {
    _clock += dt;

    var speed = charactersPerSecond;
    final backlog = target - _revealed;
    if (backlog > 0) {
      final window = _fastForwarding ? fastForwardSeconds : maxLagSeconds;
      speed = math.max(speed, backlog / window);
    }

    final before = _revealed.floor();
    _revealed = math.min(_revealed + speed * dt, target.toDouble());
    final count = _revealed.floor() - before;
    // Stamp newly revealed characters, spread across this frame's time.
    for (var i = 0; i < count; i++) {
      _revealedAt.add(_clock - dt + dt * (i + 1) / count);
    }

    if (_revealed >= target && !tailStillFading) {
      _fastForwarding = false;
      return false;
    }
    return true;
  }

  /// Fade-in progress (0–1) for the character at index [index].
  double progressFor(int index) {
    if (index < _stampBase) return 1;
    final i = index - _stampBase;
    if (i >= _revealedAt.length) return 0;
    return ((_clock - _revealedAt[i]) / fadeSeconds).clamp(0.0, 1.0).toDouble();
  }
}
