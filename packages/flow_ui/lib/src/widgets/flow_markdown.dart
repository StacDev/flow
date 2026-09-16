import 'dart:math' as math;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../models/flow_message_part.dart';
import '../styles/flow_markdown_style.dart';
import '../theme/flow_colors.dart';
import '../theme/flow_theme.dart';
import '../theme/flow_typography.dart';
import '../utils/flow_chip_text.dart';
import '../utils/flow_markdown_parser.dart';
import '../utils/flow_reveal_engine.dart';
import 'flow_code_block.dart';

/// Markdown rendered in the package's own voice: assistant prose, typeset.
///
/// ```dart
/// FlowMarkdown(
///   text: reply,
///   isStreaming: generating,
///   onLinkTap: (href) => openInBrowser(href),
/// )
/// ```
///
/// The dialect is what assistants emit — headings, emphasis, inline code,
/// fenced code (rendered by `FlowCodeBlock`, highlighting and copy intent
/// included), links, nested lists, quotes, rules, and tables. Deferred
/// syntax (images, task lists, footnotes, HTML) renders as the literal
/// text it is.
///
/// Streaming is data, as everywhere: rebuild with a longer [text] and the
/// trailing paragraph reveals with the same per-character fade plain text
/// gets. The parser tolerates input that ends mid-construct — unclosed
/// emphasis stays literal until its closer arrives (and restyles without
/// re-fading), a half-typed link shows its label and hides the URL, an
/// unterminated fence is a code block still in progress, and a table only
/// appears once its delimiter row lands.
///
/// Everything reports intent out and ships no strings: [onLinkTap] hands
/// the host the tapped href (null renders links as plain prose — never a
/// dead affordance), and fences flow through the same `FlowCodePart`
/// copy contract code parts use. Fills the width it's given, so it needs
/// a bounded width.
class FlowMarkdown extends StatefulWidget {
  const FlowMarkdown({
    super.key,
    required this.text,
    this.isStreaming = false,
    this.style,
    this.charactersPerSecond = 300,
    this.onLinkTap,
    this.onCodeCopy,
    this.copiedCodePart,
    this.codeCopyTooltip,
    this.markdownStyle,
  }) : assert(charactersPerSecond > 0, 'charactersPerSecond must be positive');

  /// The markdown source received so far.
  final String text;

  /// Whether more text may still arrive. While true the trailing text
  /// block animates its reveal; fences, tables and rules render whole.
  final bool isStreaming;

  /// Merged over the default `bodyLarge` + `onSurface` prose style.
  /// Headings keep their own scale but follow this style's color.
  final TextStyle? style;

  /// Per-element restyling — heading cuts, the link color, the inline
  /// code chip, quote and table inks — merged over
  /// [FlowTheme.markdownStyle]'s fields; nulls fall through to the theme
  /// tokens.
  final FlowMarkdownStyle? markdownStyle;

  /// Baseline reveal speed while streaming.
  final double charactersPerSecond;

  /// Link intent, handed the tapped href. Null renders links as plain
  /// prose — a styled-but-dead link would look tappable and do nothing.
  /// The package never launches URLs itself.
  final ValueChanged<String>? onLinkTap;

  /// Copy intent from fenced code, handed a `FlowCodePart` synthesized
  /// for the fence — the same contract `FlowCodePart` parts use, so one
  /// host handler serves both. Null hides every fence's copy affordance.
  final ValueChanged<FlowCodePart>? onCodeCopy;

  /// The part whose fence shows the copied check — the instance received
  /// from [onCodeCopy], passed back while the host's confirmation lasts.
  final FlowCodePart? copiedCodePart;

  /// Host-localized label for the fences' copy affordance.
  final String? codeCopyTooltip;

  @override
  State<FlowMarkdown> createState() => _FlowMarkdownState();
}

class _FlowMarkdownState extends State<FlowMarkdown> {
  /// The markdown rhythm, inside the message world's 8px part gap and
  /// 32px turn gap: blocks sit a part gap apart, headings breathe a
  /// little more above, list rows half a gap, and a quote's bar insets
  /// its content the design's 16.
  static const double _blockGap = 8;
  static const double _headingExtraLarge = 8;
  static const double _headingExtraSmall = 4;
  static const double _listItemGap = 4;
  static const double _listIndent = 24;
  static const double _quoteBarWidth = 3;
  static const double _quoteGap = 13;
  static const double _ruleThickness = 1;
  static const EdgeInsetsGeometry _tableCellPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8);

  String? _parsedText;
  List<FlowMarkdownBlock> _blocks = const [];

  /// The reveal queue: every leaf, fence, table and rule, in document
  /// order. Rebuilt each parse — ordinal stability comes from the unit
  /// list being append-only while the source grows, not from the maps
  /// (the growing tail's inner instances churn every delta).
  List<FlowMarkdownBlock> _units = const [];
  Map<FlowMarkdownBlock, int> _ordinalOf = Map.identity();
  Map<Object, int> _firstOrdinalOf = Map.identity();

  /// The frontier: the unit currently revealing. While streaming,
  /// nothing beyond it is built, so the document physically ends where
  /// the animation is — content never pops in below the reading
  /// position.
  int _cursor = 0;
  bool _cursorDone = false;
  int _cursorDoneLength = 0;

  /// The streaming semantics label's folded settled prefix: the joined
  /// text of the first [_labelUnits] units, all below the cursor and so
  /// immutable while the source only grows.
  String _labelPrefix = '';
  int _labelUnits = 0;

  /// The cursor at the moment streaming ended — units beyond it mount
  /// with one soft group fade instead of a terminal pop.
  int? _flipOrdinal;
  late bool _wasStreaming = widget.isStreaming;

  /// Settled spans cached per block/cell instance, so a delta's build
  /// cost follows the frontier rather than the whole document. Spans,
  /// deliberately not widgets: reusing a widget instance across frames
  /// invites the semantics tree to re-adopt attached nodes, which
  /// asserts — spans rebuild their paragraphs cheaply and safely.
  final Map<Object, List<InlineSpan>> _settledCache = Map.identity();
  final Set<Object> _liveSettled = Set.identity();
  FlowColors? _cacheColors;
  FlowTypography? _cacheTypography;
  TextStyle? _cacheStyle;
  FlowMarkdownStyle? _cacheMarkdownStyle;
  ValueChanged<String>? _cacheOnLinkTap;

  /// The effective markdown style this build — the widget's over the
  /// theme's — resolved once at the top of [build].
  FlowMarkdownStyle? _mdStyle;

  /// Link recognizers, keyed by their owning leaf/cell instance and run
  /// index. Instance reuse across deltas keeps settled keys stable, so
  /// the sweep only ever churns the streaming tail.
  final Map<(Object, int), TapGestureRecognizer> _recognizers = {};
  final Set<(Object, int)> _liveRecognizers = {};

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  /// Reparse on new text, reusing parsed block instances (and their run
  /// caches, fade stamps and synthesized code parts) for the unchanged
  /// prefix of a growing source, then re-derive the reveal queue and
  /// clamp the cursor into it.
  void _ensureParsed() {
    if (_parsedText == widget.text) return;
    final fresh = FlowMarkdownParser.parseBlocks(widget.text);
    final previous = _parsedText;
    final isExtension = previous != null && widget.text.startsWith(previous);
    if (isExtension) {
      for (var i = 0; i < fresh.length && i < _blocks.length; i++) {
        final old = _blocks[i];
        final neu = fresh[i];
        if (old.runtimeType == neu.runtimeType &&
            old.start == neu.start &&
            old.end == neu.end) {
          fresh[i] = old;
        } else {
          break;
        }
      }
    }
    _blocks = fresh;
    _parsedText = widget.text;
    _rebuildQueue();

    if (previous != null && !isExtension) {
      // Replacement: regenerate / branch switch — the reveal restarts.
      _cursor = 0;
      _cursorDone = false;
      _cursorDoneLength = 0;
      _flipOrdinal = null;
    } else if (_units.isNotEmpty) {
      _cursor = math.min(_cursor, _units.length - 1);
      if (_cursorDone) {
        final unit = _units[_cursor];
        // Growth (or a type change) re-arms the cursor unit; instance
        // churn alone must not — the tail's instances churn on every
        // delta, and resetting on churn would deadlock the queue.
        if (unit is! FlowMarkdownLeafBlock ||
            unit.source.length > _cursorDoneLength) {
          _cursorDone = false;
        }
      }
    } else {
      _cursor = 0;
      _cursorDone = false;
    }
    _syncCursor();
  }

  /// Walks the block tree into the linear reveal order: leaves and
  /// atomic blocks become units; containers record where they begin so
  /// their chrome (quote bar, list marker) appears with their first
  /// unit.
  void _rebuildQueue() {
    final units = <FlowMarkdownBlock>[];
    final ordinalOf = Map<FlowMarkdownBlock, int>.identity();
    final firstOrdinalOf = Map<Object, int>.identity();

    void walk(List<FlowMarkdownBlock> blocks) {
      for (final block in blocks) {
        switch (block) {
          case FlowMarkdownLeafBlock():
          case FlowMarkdownFence():
          case FlowMarkdownRuleBlock():
          case FlowMarkdownTable():
            ordinalOf[block] = units.length;
            units.add(block);
          case FlowMarkdownQuote(:final children):
            firstOrdinalOf[block] = units.length;
            walk(children);
          case FlowMarkdownList(:final items):
            firstOrdinalOf[block] = units.length;
            for (final item in items) {
              firstOrdinalOf[item] = units.length;
              walk(item.children);
            }
        }
      }
    }

    walk(_blocks);
    _units = units;
    _ordinalOf = ordinalOf;
    _firstOrdinalOf = firstOrdinalOf;
  }

  /// Advances the cursor past finished units. Atomic units mount fading
  /// and the cursor moves on in the same build, so the following text
  /// reveals while they fade. The cursor holds on: the last unit (the
  /// armed tail, re-armed by extension) and a still-growing fence.
  void _syncCursor() {
    if (!widget.isStreaming || _units.isEmpty) return;
    while (true) {
      final unit = _units[_cursor];
      final last = _cursor == _units.length - 1;
      if (unit is FlowMarkdownLeafBlock) {
        if (!_cursorDone || last) return;
      } else {
        final growing = unit is FlowMarkdownFence && !unit.closed;
        if (growing || last) return;
      }
      _cursor++;
      _cursorDone = false;
    }
  }

  /// The frontier leaf reports itself fully revealed — from its ticker's
  /// phase, so advancing the queue here renders the same frame.
  void _onUnitRevealed(int ordinal) {
    if (!mounted || ordinal != _cursor || _cursor >= _units.length) return;
    final unit = _units[_cursor];
    if (unit is! FlowMarkdownLeafBlock) return;
    setState(() {
      _cursorDone = true;
      _cursorDoneLength = unit.source.length;
      _syncCursor();
    });
  }

  /// Text characters queued beyond the cursor — the global backlog the
  /// frontier leaf folds into its pacing. Atomic units reveal in
  /// constant time and count nothing, so a large fence in the queue
  /// doesn't rush the paragraph before it.
  int _pendingBeyondCursor() {
    var pending = 0;
    for (var i = _cursor + 1; i < _units.length; i++) {
      final unit = _units[i];
      if (unit is FlowMarkdownLeafBlock) pending += unit.source.length;
    }
    return pending;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;
    // The settled cache is valid for exactly one theme/style epoch. The
    // link callback's *identity* is deliberately not part of the epoch —
    // hosts (FlowThread included) build a fresh closure every build, and
    // keying on it would clear the cache on every delta. Only the
    // null/non-null flip restyles spans; a changed closure is rebound
    // onto the cached recognizers in [_markLive].
    _mdStyle =
        context.flowTheme.markdownStyle?.merge(widget.markdownStyle) ??
        widget.markdownStyle;
    if (!identical(colors, _cacheColors) ||
        !identical(typography, _cacheTypography) ||
        widget.style != _cacheStyle ||
        _mdStyle != _cacheMarkdownStyle ||
        (widget.onLinkTap == null) != (_cacheOnLinkTap == null)) {
      _settledCache.clear();
      _cacheColors = colors;
      _cacheTypography = typography;
      _cacheStyle = widget.style;
      _cacheMarkdownStyle = _mdStyle;
    }
    _cacheOnLinkTap = widget.onLinkTap;
    final base = typography.bodyLarge
        .copyWith(color: colors.onSurface)
        .merge(widget.style);

    _ensureParsed();

    if (_wasStreaming && !widget.isStreaming) {
      // Stream ended: whatever the frontier hadn't reached mounts under
      // one soft group fade — bounded by the pacing to ≲0.4s of content
      // — instead of a terminal pop.
      _flipOrdinal = _cursor;
    } else if (!_wasStreaming && widget.isStreaming) {
      // Resuming on a live surface: nothing re-hides or replays; the
      // tail arms and new appends reveal from the end.
      _flipOrdinal = null;
      _cursor = _units.isEmpty ? 0 : _units.length - 1;
      final unit = _units.isEmpty ? null : _units.last;
      _cursorDone = unit is FlowMarkdownLeafBlock;
      _cursorDoneLength = unit is FlowMarkdownLeafBlock
          ? unit.source.length
          : 0;
      _syncCursor();
    }
    _wasStreaming = widget.isStreaming;

    _liveRecognizers.clear();
    _liveSettled.clear();
    final children = _blockColumn(
      context,
      _blocks,
      base: base,
      depth: 0,
      itemGap: _blockGap,
    );
    _sweepCaches();

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (!widget.isStreaming) return column;
    // While streaming, the whole document is one quiet semantics block:
    // assistive tech reads the text received so far as a single label,
    // and the semantics tree stays structurally still — no per-frame
    // node churn from the reveal, the gating mounts, or the entrances —
    // until the stream settles and the real tree mounts once. Links are
    // inert during the reveal anyway, so nothing interactive is hidden.
    return Semantics(
      container: true,
      // Concatenating the document on every delta is O(n²) over a
      // stream, so the label is only built while an accessibility
      // service is actually reading it.
      label: MediaQuery.accessibleNavigationOf(context)
          ? _streamingLabel()
          : null,
      child: ExcludeSemantics(child: column),
    );
  }

  /// The visible text so far, marker-free — leaf runs joined, fences as
  /// their code. Units below the cursor are settled, so their text folds
  /// into a cached prefix and a delta re-joins only the frontier unit.
  String _streamingLabel() {
    if (_labelUnits > _cursor) {
      // The cursor moved backwards — a replacement reset — so the folded
      // prefix no longer matches.
      _labelPrefix = '';
      _labelUnits = 0;
    }
    while (_labelUnits < _cursor && _labelUnits < _units.length) {
      _labelPrefix = _labelJoin(_labelPrefix, _units[_labelUnits]);
      _labelUnits++;
    }
    return _cursor < _units.length
        ? _labelJoin(_labelPrefix, _units[_cursor])
        : _labelPrefix;
  }

  static String _labelJoin(String prefix, FlowMarkdownBlock unit) {
    final text = switch (unit) {
      FlowMarkdownLeafBlock() => [for (final run in unit.runs) run.text].join(),
      FlowMarkdownFence() => unit.code,
      _ => null,
    };
    if (text == null) return prefix;
    return prefix.isEmpty ? text : '$prefix\n$text';
  }

  void _sweepCaches() {
    _recognizers.removeWhere((key, recognizer) {
      if (_liveRecognizers.contains(key)) return false;
      recognizer.dispose();
      return true;
    });
    _settledCache.removeWhere((owner, _) => !_liveSettled.contains(owner));
  }

  // ---------------------------------------------------------------- gating

  bool get _gated => widget.isStreaming;

  bool _blockVisible(FlowMarkdownBlock block) {
    if (!_gated) return true;
    return switch (block) {
      FlowMarkdownQuote() ||
      FlowMarkdownList() => (_firstOrdinalOf[block] ?? 0) <= _cursor,
      _ => (_ordinalOf[block] ?? 0) <= _cursor,
    };
  }

  bool _itemVisible(FlowMarkdownListItem item) =>
      !_gated || (_firstOrdinalOf[item] ?? 0) <= _cursor;

  // ---------------------------------------------------------------- blocks

  List<Widget> _blockColumn(
    BuildContext context,
    List<FlowMarkdownBlock> blocks, {
    required TextStyle base,
    required int depth,
    required double itemGap,
  }) {
    final children = <Widget>[];
    for (final block in blocks) {
      // Beyond the frontier: not built at all — the gap mounts with the
      // block when its turn comes, so growth happens at the frontier.
      if (!_blockVisible(block)) continue;
      if (children.isNotEmpty) {
        var gap = itemGap;
        if (block is FlowMarkdownHeading) {
          gap += block.level <= 2 ? _headingExtraLarge : _headingExtraSmall;
        }
        children.add(SizedBox(height: gap));
      }
      children.add(_buildBlock(context, block, base: base, depth: depth));
    }
    return children;
  }

  Widget _buildBlock(
    BuildContext context,
    FlowMarkdownBlock block, {
    required TextStyle base,
    required int depth,
  }) {
    final colors = context.flowColors;
    final typography = context.flowTypography;

    switch (block) {
      case FlowMarkdownParagraph():
        return _leaf(context, block, base);

      case FlowMarkdownHeading(:final level):
        final scale = switch (level) {
          1 => typography.titleLargeEmphasised,
          2 => typography.titleMediumEmphasised,
          3 => typography.titleSmallEmphasised,
          4 => typography.bodyLargeDark,
          _ => typography.bodyMediumDark,
        };
        final override = switch (level) {
          1 => _mdStyle?.h1Style,
          2 => _mdStyle?.h2Style,
          3 => _mdStyle?.h3Style,
          4 => _mdStyle?.h4Style,
          5 => _mdStyle?.h5Style,
          _ => _mdStyle?.h6Style,
        };
        final style = scale
            .copyWith(color: level == 6 ? colors.onSurfaceVariant : base.color)
            .merge(override);
        return _leaf(context, block, style);

      case FlowMarkdownFence():
        final onCodeCopy = widget.onCodeCopy;
        return _atomic(
          block,
          FlowCodeBlock(
            code: block.code,
            language: block.language,
            isStreaming: widget.isStreaming && !block.closed,
            onCopy: onCodeCopy == null ? null : () => onCodeCopy(block.part),
            copied: identical(block.part, widget.copiedCodePart),
            copyTooltip: widget.codeCopyTooltip,
          ),
        );

      case FlowMarkdownQuote(:final children):
        return Container(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: _mdStyle?.quoteBarColor ?? colors.outlineVariant,
                width: _quoteBarWidth,
              ),
            ),
          ),
          padding: const EdgeInsetsDirectional.only(start: _quoteGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _blockColumn(
              context,
              children,
              // Quoted material steps down to the secondary ink.
              base: base.copyWith(
                color: _mdStyle?.quoteColor ?? colors.onSurfaceVariant,
              ),
              depth: depth,
              itemGap: _blockGap,
            ),
          ),
        );

      case FlowMarkdownList(:final ordered, :final startNumber, :final items):
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          // The whole row — marker included — waits for its first unit.
          if (!_itemVisible(items[i])) continue;
          if (rows.isNotEmpty) rows.add(const SizedBox(height: _listItemGap));
          final marker = ordered
              ? '${startNumber + i}.'
              : switch (depth % 3) {
                  0 => '•',
                  1 => '◦',
                  _ => '▪',
                };
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _listIndent,
                  // Markers stay out of a selection, as a browser's do: a
                  // copied list is its items, not `•item` run together.
                  child: SelectionContainer.disabled(
                    child: Text(marker, style: base),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: _blockColumn(
                      context,
                      items[i].children,
                      base: base,
                      depth: depth + 1,
                      itemGap: _listItemGap,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );

      case FlowMarkdownRuleBlock():
        return _atomic(
          block,
          Container(
            height: _ruleThickness,
            color: _mdStyle?.ruleColor ?? colors.outline,
          ),
        );

      case FlowMarkdownTable():
        return _atomic(block, _table(context, block, base));
    }
  }

  /// Growth eases instead of stepping: the revealing paragraph gains
  /// each wrapped line over a beat, a growing fence its rows — so a
  /// thread pinned to the newest message moves continuously rather than
  /// jumping a line-height at a time. Layout-space smoothing, on
  /// purpose: scroll-offset tricks fight the viewport's own
  /// corrections.
  Widget _smoothGrowth(BuildContext context, Widget child) {
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: child,
    );
  }

  /// Atomic units enter with a short fade when the frontier reaches them
  /// — and the post-flip stragglers do the same. The wrapper is
  /// permanent (a finished fade is free), so the child's element and its
  /// caches survive settling.
  Widget _atomic(FlowMarkdownBlock block, Widget child) {
    final ordinal = _ordinalOf[block] ?? 0;
    final flip = _flipOrdinal;
    return _FlowMarkdownBlockFadeIn(
      key: ValueKey(ordinal),
      animate: widget.isStreaming || (flip != null && ordinal > flip),
      child: _smoothGrowth(context, child),
    );
  }

  Widget _leaf(
    BuildContext context,
    FlowMarkdownLeafBlock leaf,
    TextStyle style,
  ) {
    final ordinal = _ordinalOf[leaf] ?? 0;
    final isCursor = _gated && ordinal == _cursor;
    // The fade wrapper is permanent, like _atomic's: a leaf the frontier
    // never reached before the stream ended enters with the settle group
    // instead of popping, and one that did animates its own reveal (the
    // entrance decision is made once, on mount). Wrapping conditionally
    // would change the child's type when the flip clears — remounting
    // the reveal element and replaying the whole paragraph.
    final flip = _flipOrdinal;
    return _FlowMarkdownBlockFadeIn(
      key: ValueKey(ordinal),
      animate: flip != null && ordinal > flip,
      child: _smoothGrowth(
        context,
        _FlowMarkdownRevealText(
          source: leaf.source,
          runs: leaf.runs,
          baseStyle: style,
          styleFor: (run) => _runStyle(context, run, style),
          chipFill:
              _mdStyle?.codeChipColor ?? context.flowColors.surfaceContainer,
          isStreaming: isCursor,
          charactersPerSecond: widget.charactersPerSecond,
          extraBacklog: isCursor ? _pendingBeyondCursor().toDouble() : 0,
          onRevealed: isCursor ? () => _onUnitRevealed(ordinal) : null,
          settled: _settledLeaf(leaf, style),
        ),
      ),
    );
  }

  /// The settled form of a leaf, its spans cached per instance.
  Widget _settledLeaf(FlowMarkdownLeafBlock leaf, TextStyle style) {
    return FlowChipText(
      TextSpan(style: style, children: _settledSpans(leaf, leaf.runs, style)),
    );
  }

  List<InlineSpan> _settledSpans(
    Object owner,
    List<FlowMarkdownRun> runs,
    TextStyle style,
  ) {
    final cached = _settledCache[owner];
    if (cached != null) {
      _markLive(owner, runs);
      _liveSettled.add(owner);
      return cached;
    }
    final built = _spansFor(runs, style, owner: owner, tappable: true);
    _settledCache[owner] = built;
    _liveSettled.add(owner);
    return built;
  }

  /// Marks a cached subtree's recognizers live without rebuilding its
  /// spans — the sweep must never dispose a recognizer a cached span
  /// still holds — and rebinds them to this build's callback, since the
  /// callback's identity is not part of the cache epoch.
  void _markLive(Object owner, List<FlowMarkdownRun> runs) {
    final onLinkTap = widget.onLinkTap;
    if (onLinkTap == null) return;
    for (var i = 0; i < runs.length; i++) {
      final href = runs[i].linkHref;
      if (href != null) {
        final key = (owner, i);
        _liveRecognizers.add(key);
        _recognizers[key]?.onTap = () => onLinkTap(href);
      }
    }
  }

  Widget _table(BuildContext context, FlowMarkdownTable table, TextStyle base) {
    final colors = context.flowColors;
    final typography = context.flowTypography;
    final headerStyle = typography.bodyMediumDark
        .copyWith(color: base.color)
        .merge(_mdStyle?.tableHeaderStyle);
    // Table material reads a step under the prose, like code does.
    final cellStyle = typography.bodyMedium
        .copyWith(color: base.color)
        .merge(_mdStyle?.tableCellStyle);

    Widget cell(FlowMarkdownTableCell cell, TextStyle style, int column) {
      final alignment = switch (column < table.alignments.length
          ? table.alignments[column]
          : null) {
        FlowMarkdownAlign.center => AlignmentDirectional.topCenter,
        FlowMarkdownAlign.right => AlignmentDirectional.topEnd,
        _ => AlignmentDirectional.topStart,
      };
      return Container(
        padding: _tableCellPadding,
        alignment: alignment,
        child: FlowChipText(
          TextSpan(
            style: style,
            children: _settledSpans(cell, cell.runs, style),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _mdStyle?.tableBorderColor ?? colors.outlineVariant,
                ),
              ),
            ),
            children: [
              for (var c = 0; c < table.header.length; c++)
                cell(table.header[c], headerStyle, c),
            ],
          ),
          for (var r = 0; r < table.rows.length; r++)
            TableRow(
              decoration: r == table.rows.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _mdStyle?.tableDividerColor ?? colors.outline,
                        ),
                      ),
                    ),
              children: [
                for (var c = 0; c < table.header.length; c++)
                  cell(table.rows[r][c], cellStyle, c),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- inlines

  TextStyle _runStyle(
    BuildContext context,
    FlowMarkdownRun run,
    TextStyle base,
  ) {
    final colors = context.flowColors;
    final typography = context.flowTypography;

    var style = base;
    if (run.code) {
      // The mono face at prose size. The wash paints as a rounded chip
      // in FlowChipText — the span stays plain text, so wrapping and
      // the reveal keep working.
      style = typography.codeInline
          .copyWith(color: base.color)
          .merge(_mdStyle?.inlineCodeStyle);
    }
    if (run.bold) {
      style = FlowTypography.recut(style, fontWeight: FontWeight.w600);
    }
    if (run.italic) {
      style = FlowTypography.recut(style, fontStyle: FontStyle.italic);
    }

    final linked = run.linkHref != null && widget.onLinkTap != null;
    final decorations = <TextDecoration>[
      if (run.strike) TextDecoration.lineThrough,
      if (linked) TextDecoration.underline,
    ];
    if (linked) {
      final linkColor = _mdStyle?.linkColor ?? colors.secondary;
      style = style.copyWith(color: linkColor, decorationColor: linkColor);
    }
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }
    return style;
  }

  List<InlineSpan> _spansFor(
    List<FlowMarkdownRun> runs,
    TextStyle base, {
    required Object owner,
    required bool tappable,
  }) {
    final onLinkTap = widget.onLinkTap;
    final chipFill =
        _mdStyle?.codeChipColor ?? context.flowColors.surfaceContainer;
    final spans = <InlineSpan>[];
    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      TapGestureRecognizer? recognizer;
      final href = run.linkHref;
      if (href != null && onLinkTap != null && tappable) {
        final key = (owner, i);
        recognizer = _recognizers.putIfAbsent(key, TapGestureRecognizer.new)
          ..onTap = () => onLinkTap(href);
        _liveRecognizers.add(key);
      }
      final style = _runStyle(context, run, base);
      spans.add(
        run.code
            ? FlowChipSpan(
                text: run.text,
                style: style,
                recognizer: recognizer,
                fill: chipFill,
              )
            : TextSpan(text: run.text, style: style, recognizer: recognizer),
      );
    }
    return spans;
  }
}

/// One-shot entrance for atomic blocks: a short ease of height and
/// opacity together as the unit reaches the frontier, so fences, tables
/// and rules arrive rather than landing at full height in one frame —
/// the layout grows as smoothly as the text does. The decision is made
/// once, on first dependencies — later prop changes never replay the
/// entrance, and disabled animations render statically.
class _FlowMarkdownBlockFadeIn extends StatefulWidget {
  const _FlowMarkdownBlockFadeIn({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<_FlowMarkdownBlockFadeIn> createState() =>
      _FlowMarkdownBlockFadeInState();
}

class _FlowMarkdownBlockFadeInState extends State<_FlowMarkdownBlockFadeIn>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 200);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  );
  late final CurvedAnimation _ease = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ease.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _ease,
      // topStart, not topCenter: the transition's Align spans the rail,
      // so its cross-axis alignment is the *document's* — anything else
      // centers every block narrower than the line.
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

/// The rich half of the streaming reveal: `FlowStreamingText`'s clock over
/// styled runs. Every text leaf renders through this widget — settled ones
/// snap to the end and short-circuit to [settled], the frontier leaf
/// fades characters in, and a leaf that stops being the frontier fast-
/// forwards its remainder, which is what hands the reveal from one block
/// to the next without a pop.
///
/// The reveal is stamped by *source* offset (the run mapping's invariant),
/// so text that restyles when its closing delimiter arrives keeps its
/// stamps and never re-fades.
class _FlowMarkdownRevealText extends StatefulWidget {
  const _FlowMarkdownRevealText({
    required this.source,
    required this.runs,
    required this.baseStyle,
    required this.styleFor,
    required this.chipFill,
    required this.isStreaming,
    required this.charactersPerSecond,
    required this.settled,
    this.onRevealed,
    this.extraBacklog = 0,
  });

  final String source;
  final List<FlowMarkdownRun> runs;
  final TextStyle baseStyle;
  final TextStyle Function(FlowMarkdownRun run) styleFor;

  /// The inline-code chip fill, for the code runs this leaf reveals.
  final Color chipFill;
  final bool isStreaming;
  final double charactersPerSecond;

  /// The parent-built settled form — spans with live link recognizers.
  final Widget settled;

  /// Fired once every character is revealed (the tail may still be
  /// fading) — the queue's cue to advance. Always called from the
  /// ticker's phase, never during a build.
  final VoidCallback? onRevealed;

  /// Source characters queued beyond this leaf. Folded into the pacing
  /// so the whole document honors the reveal's lag bound, not just the
  /// leaf at the frontier.
  final double extraBacklog;

  @override
  State<_FlowMarkdownRevealText> createState() =>
      _FlowMarkdownRevealTextState();
}

class _FlowMarkdownRevealTextState extends State<_FlowMarkdownRevealText>
    with SingleTickerProviderStateMixin {
  final FlowRevealEngine _engine = FlowRevealEngine();

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  /// Whether [_FlowMarkdownRevealText.onRevealed] has fired for the
  /// current source; extension re-arms it. Notification only ever runs
  /// from [_onTick] — a build-phase caller schedules a tick instead.
  bool _notifiedRevealed = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.isStreaming) {
      _ensureTicking();
    } else {
      _engine.snapToEnd(widget.source.length);
    }
  }

  @override
  void didUpdateWidget(_FlowMarkdownRevealText oldWidget) {
    super.didUpdateWidget(oldWidget);

    final extended =
        widget.source.length >= oldWidget.source.length &&
        widget.source.startsWith(oldWidget.source);
    if (!extended) {
      // A shrunken-to-prefix source is the tail handing characters to a
      // newly recognized construct (a table's delimiter row landing) —
      // clamp, keeping the surviving prefix's fades, instead of the
      // full re-fade a true replacement gets.
      final truncated = oldWidget.source.startsWith(widget.source);
      if (truncated && widget.isStreaming) {
        _engine.truncateTo(widget.source.length);
        _notifiedRevealed = false;
        _ensureTicking();
        return;
      }
      if (widget.isStreaming) {
        _engine.reset();
        _notifiedRevealed = false;
        _ensureTicking();
      } else {
        _snapToEnd();
      }
      return;
    }

    if (widget.isStreaming) {
      _engine.clearFastForward();
      if (_engine.revealed < widget.source.length) {
        _notifiedRevealed = false;
        _ensureTicking();
      } else if (!_notifiedRevealed && widget.onRevealed != null) {
        // Already caught up but the parent hasn't heard — deliver from
        // the ticker's phase, never from this build.
        _ensureTicking();
      }
    } else if (oldWidget.isStreaming) {
      if (_engine.revealed < widget.source.length || _engine.tailStillFading) {
        _engine.beginFastForward();
        _ensureTicking();
      } else {
        _snapToEnd();
      }
    } else if (widget.source != oldWidget.source) {
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
    _engine.snapToEnd(widget.source.length);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    // The document's remaining characters, not just this leaf's, set the
    // pace — one frontier moving at the global lag bound.
    final cps = math.max(
      widget.charactersPerSecond,
      (widget.source.length - _engine.revealed + widget.extraBacklog) /
          FlowRevealEngine.maxLagSeconds,
    );
    setState(() {
      if (!_engine.tick(dt, widget.source.length, cps)) {
        _ticker.stop();
      }
    });
    _maybeNotify();
  }

  void _maybeNotify() {
    final onRevealed = widget.onRevealed;
    if (!widget.isStreaming || onRevealed == null) return;
    if (_engine.revealed >= widget.source.length && !_notifiedRevealed) {
      _notifiedRevealed = true;
      onRevealed();
    }
  }

  static bool _isHighSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xD800;
  static bool _isLowSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xDC00;

  @override
  Widget build(BuildContext context) {
    // One persistent semantics container spans the animating and settled
    // forms, so the swap replaces the children of a stable node instead
    // of restructuring the semantics boundary mid-stream.
    if (!_ticker.isActive && _engine.revealed >= widget.source.length) {
      return Semantics(container: true, child: widget.settled);
    }

    final source = widget.source;
    var shown = math.min(_engine.revealedFloor, source.length);
    if (shown > 0 &&
        shown < source.length &&
        _isLowSurrogate(source.codeUnitAt(shown))) {
      shown--;
    }

    var fadeStart = shown;
    while (fadeStart > 0 &&
        shown - fadeStart < FlowRevealEngine.maxFadeSpans &&
        _engine.progressFor(fadeStart - 1) < 1) {
      fadeStart--;
    }
    if (fadeStart > 0 && _isLowSurrogate(source.codeUnitAt(fadeStart))) {
      fadeStart--;
    }

    final spans = <InlineSpan>[];
    for (final run in widget.runs) {
      if (run.sourceStart >= shown) break;
      final visible = math.min(run.text.length, shown - run.sourceStart);
      final style = widget.styleFor(run);
      final color = style.color ?? widget.baseStyle.color;

      // Code runs stay tagged through the fade, so the chip paints
      // under exactly the revealed characters.
      InlineSpan spanOf(String text, TextStyle style) => run.code
          ? FlowChipSpan(text: text, style: style, fill: widget.chipFill)
          : TextSpan(text: text, style: style);

      final solid = (fadeStart - run.sourceStart).clamp(0, visible);
      if (solid > 0) {
        spans.add(spanOf(run.text.substring(0, solid), style));
      }
      var i = solid;
      while (i < visible) {
        final end = _isHighSurrogate(run.text.codeUnitAt(i)) && i + 1 < visible
            ? i + 2
            : i + 1;
        spans.add(
          spanOf(
            run.text.substring(i, end),
            color == null
                ? style
                : style.copyWith(
                    color: color.withValues(
                      alpha: color.a * _engine.progressFor(run.sourceStart + i),
                    ),
                  ),
          ),
        );
        i = end;
      }
    }

    // Expose the full text once so screen readers aren't re-announced
    // on every animation frame.
    final label = [for (final run in widget.runs) run.text].join();
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: FlowChipText(TextSpan(style: widget.baseStyle, children: spans)),
    );
  }
}
