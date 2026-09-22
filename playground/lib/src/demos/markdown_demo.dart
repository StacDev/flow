import 'dart:async';
import 'dart:math' as math;

import 'package:flow_ui/flow_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

String markdownSnippet([String? variant]) => switch (variant) {
  'streaming' => _streamingSnip,
  'tables' => _tablesSnip,
  'links' => _linksSnip,
  _ => _documentSnip,
};

const String _streamingSnip = '''
// Streaming is data: rebuild with a longer text and the trailing
// paragraph reveals character by character — fences, tables and rules
// ease in whole when the frontier reaches them. Input that ends
// mid-construct renders gracefully.
FlowMarkdown(
  text: receivedSoFar,
  isStreaming: generating, // false settles the reveal
  charactersPerSecond: 300,
)''';

const String _tablesSnip = '''
// Column alignment comes from the delimiter row; a table wider than
// its column scrolls horizontally inside the message rather than
// wrapping the page.
//
//   | Model   | Context | Strength       |
//   |:--------|--------:|:--------------:|
//   | Fable 5 |    400K | Deep reasoning |
FlowMarkdown(text: reply)''';

const String _linksSnip = '''
// Links report intent — the package never launches URLs, and a null
// onLinkTap renders them as plain prose. Bare https:// and www. URLs
// autolink with GFM's trimming rules.
FlowMarkdown(
  text: reply,
  onLinkTap: (href) => openInBrowser(href),
)

// In a thread the callback carries the message too:
FlowThread(
  messages: messages,
  onLinkTap: (message, href) => openInBrowser(href),
)''';

const String _documentSnip = '''
// Assistant text parts render markdown by default — pass
// markdown: false on FlowThread/FlowMessage for literal text.
FlowThread(
  messages: messages,
  onLinkTap: (message, href) => openInBrowser(href),
  codeCopyTooltip: 'Copy code',
  onCodeCopy: copyPart,
)

// Standalone, outside a thread:
FlowMarkdown(
  text: reply,
  isStreaming: generating,
  onLinkTap: openInBrowser,   // null renders links as plain prose
  onCodeCopy: copyPart,       // fences share FlowCodePart's contract
)''';

const String _document = '''
## Flow UI in one reply

flow_ui renders **state in** and reports *intent out* — nothing model-facing, no strings shipped, and now the assistant's prose is typeset instead of printed raw.

### What renders

1. Headings on the existing type ramp
2. Emphasis — **bold**, *italic*, ~~struck~~ — and `inline code`
3. Fenced code, through the code block you already have:

```dart
FlowMarkdown(
  text: reply,
  onLinkTap: (href) => open(href),
)
```

> A quote steps down to the secondary ink, behind the hairline bar.

Inline code wraps as one chip: `FlowMarkdown(text: reply, isStreaming: generating, onLinkTap: open)` keeps its rounded ends across the line break.

- Unordered lists nest
  - two levels in
  - and markers cycle by depth
- Back out again

---

Everything else — the [docs](https://flowui.stac.dev) have the full dialect, including what stays deliberately literal.
''';

const String _tables = '''
### Model lineup

| Model | Context | Strength |
|:------|--------:|:---------|
| Fable 5 | 1M | Deep reasoning |
| Opus 5.1 | 500K | Balanced daily driver |
| Haiku 4.5 | 200K | Fast and light |

Alignment comes from the delimiter row — left, right, left. Cells carry inline styling: **bold**, `code`, *italics*.

### Wide tables scroll

| Stage | Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday |
|---|---|---|---|---|---|---|---|
| Draft | done | done | — | done | — | done | — |
| Review | — | done | done | — | done | — | done |
| Publish | — | — | done | — | — | done | — |
''';

const String _links = '''
Links report **intent**: try [the docs](https://flowui.stac.dev), the [GitHub repo](https://github.com/StacDev/flow), or the autolink <https://stac.dev> — the package styles the label, hands the host the href, and launches nothing itself.

Bare URLs autolink with GFM's trimming: https://stac.dev/docs, the parenthesized https://en.wikipedia.org/wiki/Dart_(programming_language), and www.example.com; a trailing period stays prose: https://flutter.dev.

Without an `onLinkTap`, links render as plain prose — never a styled-but-dead affordance:
''';

const String _linksPlain = '''
The same [docs](https://flowui.stac.dev) link and the same [repo](https://github.com/StacDev/flow) link, with no handler wired.
''';

/// Stage demo for `FlowMarkdown` — the typeset document, the streaming
/// reveal over styled text, tables with alignment and overflow scroll,
/// and link intent made visible. The demo owns the clipboard write and
/// the tapped-href readout, the way a host would.
class MarkdownDemo extends StatefulWidget {
  const MarkdownDemo({super.key, this.variant});

  final String? variant;

  @override
  State<MarkdownDemo> createState() => _MarkdownDemoState();
}

class _MarkdownDemoState extends State<MarkdownDemo> {
  /// The real assistant cadence: bursts of 40–80 characters every 150ms
  /// (deterministic run to run), not a per-character trickle — this is
  /// the traffic shape the reveal queue exists to smooth.
  static const Duration _feedTick = Duration(milliseconds: 150);
  static const Duration _restartDelay = Duration(milliseconds: 1600);
  final math.Random _chunks = math.Random(42);

  FlowCodePart? _copiedPart;
  Timer? _copyReset;
  String? _tappedHref;

  /// Streaming variant: how much of [_document] has "arrived".
  int _fed = 0;
  bool _settled = false;
  Timer? _feed;

  @override
  void initState() {
    super.initState();
    if (widget.variant == 'streaming') _startFeed();
  }

  @override
  void dispose() {
    _feed?.cancel();
    _copyReset?.cancel();
    super.dispose();
  }

  void _startFeed() {
    _feed?.cancel();
    setState(() {
      _fed = 0;
      _settled = false;
    });
    _feed = Timer.periodic(_feedTick, (timer) {
      setState(() {
        _fed = (_fed + 40 + _chunks.nextInt(41)).clamp(0, _document.length);
        if (_fed == _document.length) {
          _settled = true;
          timer.cancel();
          _feed = Timer(_restartDelay, _startFeed);
        }
      });
    });
  }

  Future<void> _copy(FlowCodePart part) async {
    await Clipboard.setData(ClipboardData(text: part.code));
    if (!mounted) return;
    setState(() => _copiedPart = part);
    _copyReset?.cancel();
    _copyReset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copiedPart = null);
    });
  }

  void _openLink(String href) => setState(() => _tappedHref = href);

  /// The tapped-href readout under the interactive variants: the intent,
  /// made visible.
  Widget _linkReadout(BuildContext context) {
    final href = _tappedHref;
    if (href == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'onLinkTap → $href',
        style: context.flowTypography.bodyMedium.copyWith(
          color: context.flowColors.onSurfaceMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (widget.variant) {
      'streaming' => _StreamingTurn(
        text: _document.substring(0, _fed),
        settled: _settled,
        onCodeCopy: _copy,
        copiedCodePart: _copiedPart,
        onLinkTap: _openLink,
      ),
      'tables' => FlowMarkdown(text: _tables),
      'links' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FlowMarkdown(text: _links, onLinkTap: _openLink),
          const SizedBox(height: 8),
          const FlowMarkdown(text: _linksPlain),
          _linkReadout(context),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FlowMarkdown(
            text: _document,
            onLinkTap: _openLink,
            onCodeCopy: _copy,
            copiedCodePart: _copiedPart,
            codeCopyTooltip: 'Copy code',
          ),
          _linkReadout(context),
        ],
      ),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    );
  }
}

/// The streaming document, fed through the real message path so the
/// markdown reveal runs exactly as a host's thread would run it.
class _StreamingTurn extends StatelessWidget {
  const _StreamingTurn({
    required this.text,
    required this.settled,
    required this.onCodeCopy,
    required this.copiedCodePart,
    required this.onLinkTap,
  });

  final String text;
  final bool settled;
  final ValueChanged<FlowCodePart> onCodeCopy;
  final FlowCodePart? copiedCodePart;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
    return FlowMessage(
      FlowMessageData(
        id: 'markdown-stream',
        role: FlowMessageRole.assistant,
        status: settled
            ? FlowMessageStatus.complete
            : FlowMessageStatus.streaming,
        parts: [FlowTextPart(text)],
      ),
      onCodeCopy: onCodeCopy,
      copiedCodePart: copiedCodePart,
      codeCopyTooltip: 'Copy code',
      onLinkTap: onLinkTap,
    );
  }
}
