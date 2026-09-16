import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/flow_theme.dart';
import '../utils/flow_reveal_engine.dart';
import '../utils/flow_selection.dart';

/// Animated reveal for text that arrives incrementally.
///
/// Streaming is data, not streams: rebuild this widget with a progressively
/// longer [text] while [isStreaming] is true and the delta is revealed with a
/// smooth per-character fade. When [isStreaming] is false the text renders
/// statically with no animation cost, so the same widget is safe for history
/// messages.
///
/// The reveal runs at [charactersPerSecond] but speeds up automatically
/// whenever it would fall more than a beat behind the incoming text, so fast
/// streams never leave the animation lagging. If a new [text] does not extend
/// the previous one (a regenerate or branch switch), the reveal restarts.
///
/// Inside a selection area (a `FlowThread`'s, or a host's) the text is one
/// selectable block, so a copy across paragraphs keeps its line breaks.
class FlowStreamingText extends StatefulWidget {
  const FlowStreamingText({
    super.key,
    required this.text,
    this.isStreaming = true,
    this.style,
    this.charactersPerSecond = 300,
    this.textAlign,
  }) : assert(charactersPerSecond > 0, 'charactersPerSecond must be positive');

  /// The full text received so far.
  final String text;

  /// Whether more text may still arrive. While true the reveal animates;
  /// when it flips to false the remainder fast-forwards in. Defaults to
  /// true — pass false for settled history messages to skip all animation.
  final bool isStreaming;

  /// Merged over the default `bodyLarge` + `onSurface` style.
  final TextStyle? style;

  /// Baseline reveal speed. The widget adapts above this to keep up with
  /// fast streams.
  final double charactersPerSecond;

  final TextAlign? textAlign;

  @override
  State<FlowStreamingText> createState() => _FlowStreamingTextState();
}

class _FlowStreamingTextState extends State<FlowStreamingText>
    with SingleTickerProviderStateMixin {
  /// The counters live in the shared engine; this state owns the Ticker
  /// and the flat-string span construction.
  final FlowRevealEngine _engine = FlowRevealEngine();

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.isStreaming) {
      _ensureTicking();
    } else {
      _engine.snapToEnd(widget.text.length);
    }
  }

  @override
  void didUpdateWidget(FlowStreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    final extended =
        widget.text.length >= oldWidget.text.length &&
        widget.text.startsWith(oldWidget.text);
    if (!extended) {
      // Replacement: regenerate / branch switch.
      if (widget.isStreaming) {
        _engine.reset();
        _ensureTicking();
      } else {
        _snapToEnd();
      }
      return;
    }

    if (widget.isStreaming) {
      _engine.clearFastForward();
      if (_engine.revealed < widget.text.length) _ensureTicking();
    } else if (oldWidget.isStreaming) {
      // Stream completed: fast-forward whatever is left.
      if (_engine.revealed < widget.text.length || _engine.tailStillFading) {
        _engine.beginFastForward();
        _ensureTicking();
      }
    } else if (widget.text != oldWidget.text) {
      // Static text changed outside of streaming: no animation.
      _snapToEnd();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureTicking() {
    if (_ticker.isActive) return;
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _snapToEnd() {
    _ticker.stop();
    _engine.snapToEnd(widget.text.length);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    setState(() {
      if (!_engine.tick(dt, widget.text.length, widget.charactersPerSecond)) {
        _ticker.stop();
      }
    });
  }

  static bool _isHighSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xD800;
  static bool _isLowSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xDC00;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final style = context.flowTypography.bodyLarge
        .copyWith(color: colors.onSurface)
        .merge(widget.style);

    // Settled: history messages and completed streams render statically.
    if (!_ticker.isActive && _engine.revealed >= widget.text.length) {
      return FlowSelectionBlock(
        child: Text(widget.text, style: style, textAlign: widget.textAlign),
      );
    }

    final text = widget.text;
    var shown = math.min(_engine.revealedFloor, text.length);
    // Never split a surrogate pair at the reveal head.
    if (shown > 0 &&
        shown < text.length &&
        _isLowSurrogate(text.codeUnitAt(shown))) {
      shown--;
    }

    var fadeStart = shown;
    while (fadeStart > 0 &&
        shown - fadeStart < FlowRevealEngine.maxFadeSpans &&
        _engine.progressFor(fadeStart - 1) < 1) {
      fadeStart--;
    }
    if (fadeStart > 0 && _isLowSurrogate(text.codeUnitAt(fadeStart))) {
      fadeStart--;
    }

    final baseColor = style.color ?? colors.onSurface;
    final spans = <InlineSpan>[
      if (fadeStart > 0) TextSpan(text: text.substring(0, fadeStart)),
    ];
    var i = fadeStart;
    while (i < shown) {
      final end = _isHighSurrogate(text.codeUnitAt(i)) && i + 1 < shown
          ? i + 2
          : i + 1;
      spans.add(
        TextSpan(
          text: text.substring(i, end),
          style: TextStyle(
            color: baseColor.withValues(
              alpha: baseColor.a * _engine.progressFor(i),
            ),
          ),
        ),
      );
      i = end;
    }

    // Expose the full text once so screen readers aren't re-announced
    // on every animation frame.
    return FlowSelectionBlock(
      child: Semantics(
        label: widget.text,
        child: ExcludeSemantics(
          child: Text.rich(
            TextSpan(style: style, children: spans),
            textAlign: widget.textAlign,
          ),
        ),
      ),
    );
  }
}
