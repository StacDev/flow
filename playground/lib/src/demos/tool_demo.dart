import 'dart:async';
import 'dart:math' as math;

import 'package:flow_ui/flow_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

String toolSnippet([String? variant]) => switch (variant) {
  'complete' => _completeSnip,
  'running' => _runningSnip,
  'error' => _errorSnip,
  'thread' => _threadSnip,
  _ => _liveSnip,
};

const String _liveSnip = '''
// The card renders state and never advances on its own: the host
// re-renders the part as its provider reports each step.

// 1. Staged: the arguments still arriving, the input block streaming.
FlowTool(
  name: 'search_docs',
  title: 'Searching the docs',
  status: FlowToolStatus.pending,
  input: '{"query": "draft pers',
)

// 2. Executing: the asterisk turns and the title shimmers.
FlowTool(
  name: 'search_docs',
  title: 'Searching the docs',
  detail: 'draft persistence',
  status: FlowToolStatus.running,
  input: '{"query": "draft persistence"}',
)

// 3. Settled: the check lands and the output joins the disclosure.
FlowTool(
  name: 'search_docs',
  title: 'Searched the docs',
  detail: 'draft persistence',
  status: FlowToolStatus.complete,
  input: '{"query": "draft persistence"}',
  output: '{"count": 2, "best": "/components/composer#drafts"}',
  inputLabel: 'Input',
  outputLabel: 'Output',
)''';

const String _completeSnip = '''
// The full anatomy, landed open: the settled check, the host's title
// and the call's primary argument on the row, then the input and
// output as code blocks behind the disclosure. Copy hands back a
// FlowCodePart, the same contract as any code block.
FlowTool(
  name: 'search_docs',
  title: 'Searched the docs',
  detail: 'draft persistence',
  status: FlowToolStatus.complete,
  input: '{"query": "draft persistence"}',
  output: '{"count": 2, "best": "/components/composer#drafts"}',
  inputLabel: 'Input',
  outputLabel: 'Output',
  initiallyExpanded: true,
  codeCopyTooltip: 'Copy',
  copiedCodePart: copied,
  onCodeCopy: (part) => copy(part),
)''';

const String _runningSnip = '''
// Executing: the thinking line's asterisk turns and the title shimmers.
// Status is the mark, never words, so there is nothing to localize.
FlowTool(
  name: 'search_docs',
  title: 'Searching the docs',
  detail: 'draft persistence',
  status: FlowToolStatus.running,
  input: '{"query": "draft persistence"}',
  inputLabel: 'Input',
)''';

const String _errorSnip = '''
// A failed call: the error glyph, and the host's message under the
// header where it reads without a tap. The input stays behind the
// disclosure for whoever wants to see what was asked.
FlowTool(
  name: 'fetch_weather',
  title: 'Fetching the forecast',
  detail: 'Berlin',
  status: FlowToolStatus.error,
  input: '{"city": "Berlin", "units": "metric"}',
  errorMessage: 'The weather service timed out after 10 seconds.',
  inputLabel: 'Input',
)''';

const String _threadSnip = '''
// In a thread the card renders on its own: a FlowToolPart in any turn
// becomes it. The section labels are thread-level, copy goes through
// the same handler as every code block, and the part's id keys the
// card so its disclosure survives the turn growing.
FlowThread(
  messages: messages,
  toolInputLabel: 'Input',
  toolOutputLabel: 'Output',
  codeCopyTooltip: 'Copy',
  copiedCodePart: copied,
  onCodeCopy: (part) => copy(part),
)

FlowMessageData(
  id: 'a1',
  role: FlowMessageRole.assistant,
  parts: [
    FlowTextPart('Let me check the docs and the forecast.'),
    FlowToolPart(
      id: 'call_1',
      name: 'search_docs',
      title: 'Searched the docs',
      detail: 'draft persistence',
      status: FlowToolStatus.complete,
      input: '{"query": "draft persistence"}',
      output: '{"count": 2, "best": "/components/composer#drafts"}',
    ),
    FlowToolPart(
      id: 'call_2',
      name: 'fetch_weather',
      title: 'Fetching the forecast',
      detail: 'Berlin',
      status: FlowToolStatus.error,
      input: '{"city": "Berlin", "units": "metric"}',
      errorMessage: 'The weather service timed out after 10 seconds.',
    ),
    FlowTextPart('Drafts persist per thread. I could not reach the '
        'weather service.'),
  ],
)''';

const String _searchInput = '''
{
  "query": "draft persistence",
  "limit": 5
}''';

const String _searchOutput = '''
{
  "count": 2,
  "results": [
    {"title": "Composer drafts", "path": "/components/composer#drafts"},
    {"title": "Restoring a thread", "path": "/components/message-thread#restore"}
  ]
}''';

const String _weatherInput = '''
{
  "city": "Berlin",
  "units": "metric"
}''';

const String _weatherError = 'The weather service timed out after 10 seconds.';

/// Stage demo for `FlowTool` — a live run replayed on a loop, the three
/// settled forms, and a turn in a thread carrying two calls, one of which
/// failed.
class ToolDemo extends StatefulWidget {
  const ToolDemo({super.key, this.variant});

  final String? variant;

  @override
  State<ToolDemo> createState() => _ToolDemoState();
}

class _ToolDemoState extends State<ToolDemo> {
  /// The live run's clock: the input fed three characters a beat while
  /// staged, then the two settles, a pause, and around again.
  static const Duration _feedTick = Duration(milliseconds: 45);
  static const int _feedStep = 3;
  static const Duration _runDelay = Duration(milliseconds: 600);
  static const Duration _settleDelay = Duration(milliseconds: 1400);
  static const Duration _restartDelay = Duration(milliseconds: 2400);
  static const Duration _copiedHold = Duration(milliseconds: 1500);

  FlowToolStatus _status = FlowToolStatus.pending;
  int _fed = 0;
  Timer? _feed;
  Timer? _step;
  Timer? _copiedReset;
  FlowCodePart? _copied;

  bool get _live => widget.variant == null || widget.variant == 'live';

  @override
  void initState() {
    super.initState();
    if (_live) _startRun();
  }

  @override
  void dispose() {
    _feed?.cancel();
    _step?.cancel();
    _copiedReset?.cancel();
    super.dispose();
  }

  void _startRun() {
    _feed?.cancel();
    _step?.cancel();
    _status = FlowToolStatus.pending;
    _fed = 0;
    _feed = Timer.periodic(_feedTick, (timer) {
      if (!mounted) return;
      setState(() => _fed = math.min(_fed + _feedStep, _searchInput.length));
      if (_fed < _searchInput.length) return;
      timer.cancel();
      _step = Timer(_runDelay, () {
        if (!mounted) return;
        setState(() => _status = FlowToolStatus.running);
        _step = Timer(_settleDelay, () {
          if (!mounted) return;
          setState(() => _status = FlowToolStatus.complete);
          _step = Timer(_restartDelay, () {
            if (mounted) setState(_startRun);
          });
        });
      });
    });
  }

  void _copy(FlowCodePart part) {
    Clipboard.setData(ClipboardData(text: part.code));
    _copiedReset?.cancel();
    setState(() => _copied = part);
    _copiedReset = Timer(_copiedHold, () {
      if (mounted) setState(() => _copied = null);
    });
  }

  /// Thread variant: a turn that made two calls, one of which failed,
  /// and the prose that follows them — the shape of an agent's turn.
  List<FlowMessageData> get _messages => [
    FlowMessageData.text(
      id: 'u1',
      role: FlowMessageRole.user,
      text:
          'Do drafts persist between sessions? And is it raining in '
          'Berlin?',
    ),
    const FlowMessageData(
      id: 'a1',
      role: FlowMessageRole.assistant,
      parts: [
        FlowTextPart('Let me check the docs and the forecast.'),
        FlowToolPart(
          id: 'call_1',
          name: 'search_docs',
          title: 'Searched the docs',
          detail: 'draft persistence',
          status: FlowToolStatus.complete,
          input: _searchInput,
          output: _searchOutput,
        ),
        FlowToolPart(
          id: 'call_2',
          name: 'fetch_weather',
          title: 'Fetching the forecast',
          detail: 'Berlin',
          status: FlowToolStatus.error,
          input: _weatherInput,
          errorMessage: _weatherError,
        ),
        FlowTextPart(
          'Drafts persist per thread: the composer keeps what you typed '
          'and restores it when you come back. I could not reach the '
          'weather service, so I cannot say whether it is raining.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final complete = _status == FlowToolStatus.complete;
    final pending = _status == FlowToolStatus.pending;
    final child = switch (widget.variant) {
      'complete' => FlowTool(
        name: 'search_docs',
        title: 'Searched the docs',
        detail: 'draft persistence',
        status: FlowToolStatus.complete,
        input: _searchInput,
        output: _searchOutput,
        inputLabel: 'Input',
        outputLabel: 'Output',
        initiallyExpanded: true,
        codeCopyTooltip: 'Copy',
        copiedCodePart: _copied,
        onCodeCopy: _copy,
      ),
      'running' => const FlowTool(
        name: 'search_docs',
        title: 'Searching the docs',
        detail: 'draft persistence',
        status: FlowToolStatus.running,
        input: _searchInput,
        inputLabel: 'Input',
      ),
      'error' => const FlowTool(
        name: 'fetch_weather',
        title: 'Fetching the forecast',
        detail: 'Berlin',
        status: FlowToolStatus.error,
        input: _weatherInput,
        errorMessage: _weatherError,
        inputLabel: 'Input',
      ),
      'thread' => SizedBox(
        height: 420,
        child: FlowThread(
          messages: _messages,
          toolInputLabel: 'Input',
          toolOutputLabel: 'Output',
          codeCopyTooltip: 'Copy',
          copiedCodePart: _copied,
          onCodeCopy: _copy,
        ),
      ),
      _ => FlowTool(
        name: 'search_docs',
        title: complete ? 'Searched the docs' : 'Searching the docs',
        detail: pending ? null : 'draft persistence',
        status: _status,
        input: !pending
            ? _searchInput
            : _fed == 0
            ? null
            : _searchInput.substring(0, _fed),
        output: complete ? _searchOutput : null,
        inputLabel: 'Input',
        outputLabel: 'Output',
        codeCopyTooltip: 'Copy',
        copiedCodePart: _copied,
        onCodeCopy: _copy,
      ),
    };

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.variant == 'thread' ? 560 : 480,
        ),
        child: child,
      ),
    );
  }
}
