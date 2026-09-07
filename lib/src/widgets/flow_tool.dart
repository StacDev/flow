import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../models/flow_message_part.dart';
import '../styles/flow_tool_style.dart';
import '../theme/flow_colors.dart';
import '../theme/flow_theme.dart';
import 'flow_code_block.dart';
import 'flow_shimmer_text.dart';
import 'flow_thinking_indicator.dart';

/// The tool-call card: one mark for the call's status, its title and
/// primary argument on a row, and the raw input and output behind a
/// disclosure.
///
/// ```dart
/// FlowTool(
///   name: 'search_docs',
///   title: 'Searched the docs',
///   detail: 'draft persistence',
///   status: FlowToolStatus.complete,
///   input: '{"query": "draft persistence"}',
///   output: '{"count": 2}',
///   inputLabel: 'Input',
///   outputLabel: 'Output',
/// )
/// ```
///
/// In a thread this renders on its own: a `FlowToolPart` in any turn
/// becomes this card, its blocks copying through `FlowThread.onCodeCopy`
/// like any code part and the section labels thread-level. Standalone it
/// serves hosts that show a call outside a conversation.
///
/// The widget renders state; the host owns every status transition and
/// re-renders with the next one — the card never advances on its own.
/// Status is the header's mark, never words: a still asterisk while
/// [FlowToolStatus.pending], the thinking line's turning asterisk beside
/// a shimmering title while [FlowToolStatus.running], a check once
/// [FlowToolStatus.complete], the error glyph on [FlowToolStatus.error] —
/// so there is no status vocabulary to localize. The disclosure is the
/// one thing the card owns: collapsed unless [initiallyExpanded], toggled
/// by the header, reported through [onExpandedChanged].
///
/// The chrome is the code block's flat one, not the confirmation's raised
/// card: a tool call is a record of the runtime's work, where the
/// confirmation is the host's gate that asks for an answer. A failure
/// reads without a tap — [errorMessage] hangs under the header, outside
/// the disclosure. The package ships no strings: the title, the detail,
/// the message and the section labels are host-written. Metrics are
/// provisional pending a design frame.
class FlowTool extends StatefulWidget {
  const FlowTool({
    super.key,
    required this.name,
    this.title,
    this.detail,
    this.status = FlowToolStatus.pending,
    this.input,
    this.inputLanguage = 'json',
    this.output,
    this.outputLanguage,
    this.errorMessage,
    this.inputLabel,
    this.outputLabel,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    this.onCodeCopy,
    this.copiedCodePart,
    this.codeCopyTooltip,
    this.semanticLabel,
    this.padding,
    this.borderRadius,
    this.style,
  });

  /// The tool's identifier as the model called it, e.g. 'search_docs'.
  /// Shown in the code face when there is no [title].
  final String name;

  /// Host-written label, e.g. 'Searching the docs' — re-rendered in a
  /// settled tense when the call lands. Null shows [name].
  final String? title;

  /// A one-line summary of the input, usually its primary argument, shown
  /// as a chip beside the title so the collapsed card still says what the
  /// call was about.
  final String? detail;

  /// Drives the mark and the blocks' streaming treatment.
  final FlowToolStatus status;

  /// The arguments as raw text, usually JSON. Rendered streaming while
  /// [status] is pending; null renders no input block.
  final String? input;

  /// `FlowCodeLanguage` id or alias for [input]; `'plain'` for none.
  final String inputLanguage;

  /// The result as raw text. Rendered streaming while [status] is
  /// running; null renders no output block.
  final String? output;

  /// `FlowCodeLanguage` id or alias for [output]. Null renders plain.
  final String? outputLanguage;

  /// Why the call failed, host-written and sentence-case. Rendered under
  /// the header whenever set, outside the disclosure, and announced as a
  /// live region.
  final String? errorMessage;

  /// Host-localized header of the input block, e.g. 'Input'. Null falls
  /// back to the block's language id, as a fence does.
  final String? inputLabel;

  /// Host-localized header of the output block, e.g. 'Output'. Null falls
  /// back to the language id, and with neither the block keeps only its
  /// copy affordance.
  final String? outputLabel;

  /// Whether the body starts open. Read once, when the card mounts —
  /// changing it later does nothing, `ExpansionTile`'s contract; the
  /// disclosure is the user's from then on.
  final bool initiallyExpanded;

  /// The disclosure toggled by the user, handed the new state. Not called
  /// on mount or restore.
  final ValueChanged<bool>? onExpandedChanged;

  /// Copy intent from either block, handed a `FlowCodePart` carrying that
  /// block's text — the same handler that serves code parts and fences,
  /// so one host clipboard routine covers them all. Null hides both copy
  /// affordances.
  final ValueChanged<FlowCodePart>? onCodeCopy;

  /// The part whose block shows the copied check — pass back the instance
  /// received from [onCodeCopy] for as long as the confirmation should
  /// last; the host owns the timing.
  final FlowCodePart? copiedCodePart;

  /// Host-localized label for the blocks' copy affordance.
  final String? codeCopyTooltip;

  /// Read to assistive tech in place of the title and detail, e.g.
  /// 'Searched the docs, complete'. The mark carries status with no
  /// words, so this is the only spoken form of it; null reads [title] (or
  /// [name]) and [detail].
  final String? semanticLabel;

  /// Around the body's blocks. Defaults to the design's 12.
  final EdgeInsetsGeometry? padding;

  /// The card's corner. Defaults to the design's 12.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.toolStyle]'s fields;
  /// nulls fall through to the theme tokens.
  final FlowToolStyle? style;

  @override
  State<FlowTool> createState() => _FlowToolState();
}

class _FlowToolState extends State<FlowTool>
    with SingleTickerProviderStateMixin {
  /// The card: the code block's 12px corner on the lowest wash, under the
  /// faint hairline that firms while hovered.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(12));

  /// The header row: at least 36 tall — the code block header's height,
  /// a minimum so large type grows it — inset 12 at the start, 10 at the
  /// end where the chevron's own frame pads it, 6 above and below.
  static const double _headerMinHeight = 36;
  static const EdgeInsetsGeometry _headerPadding =
      EdgeInsetsDirectional.fromSTEB(12, 6, 10, 6);

  /// The mark: a 16px slot, the confirmation's asterisk size, a 6 gap
  /// from the title — the error card's glyph rhythm — and the same 6
  /// before the chip and the chevron.
  static const double _markSize = 16;
  static const double _gap = 6;

  /// The chip: the markdown inline-code chip's 4px corner, padded 4/1.
  static const BorderRadius _chipRadius = BorderRadius.all(Radius.circular(4));
  static const EdgeInsetsGeometry _chipPadding = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 1,
  );

  /// The chevron: the menus' 18, making a half turn as the body opens.
  static const double _chevronSize = 18;
  static const double _chevronTurns = 0.5;

  /// The error line, hung under the header and inset to its text.
  static const EdgeInsetsGeometry _errorPadding =
      EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10);

  /// The body: a rule above it, 12 around the blocks, 8 between them —
  /// the message's part gap — and the blocks' corner a step under the
  /// card's.
  static const double _dividerThickness = 1;
  static const EdgeInsetsGeometry _bodyPadding = EdgeInsets.all(12);
  static const double _blockGap = 8;
  static const BorderRadius _blockRadius = BorderRadius.all(Radius.circular(8));

  /// The body's reveal and the chevron's turn share one clock — the
  /// markdown's growth beat — and the mark crossfades at the image
  /// fade's.
  static const Duration _bodyDuration = Duration(milliseconds: 140);
  static const Duration _markDuration = Duration(milliseconds: 180);

  late final AnimationController _controller;
  late final CurvedAnimation _eased;
  late bool _expanded;
  bool _hovered = false;

  /// The disclosure's slot in the route's PageStorage: the chain of
  /// PageStorageKeys from this card up to the bucket — the framework's
  /// own identity for the spot — under a private type, so it can never
  /// collide with what the blocks' scrollables keep at the same chain (a
  /// scroll offset, read back as a double that a bool would break). Null
  /// with no key in the chain: standalone use keeps the flag local.
  _DisclosureId? _storageId;

  /// The blocks' synthesized parts, kept while their text holds so the
  /// host's `identical` copied check finds them — the markdown fence's
  /// idiom. A grown streaming input yields a new instance, clearing a
  /// stale check.
  FlowCodePart? _inputPart;
  FlowCodePart? _outputPart;

  @override
  void initState() {
    super.initState();
    // The thread remounts its list when a conversation crosses the
    // viewport — which opening this card can cause — so the flag lives in
    // the route's PageStorage under the part's key, where a remount finds
    // it. Without a key up the tree (standalone use) the bucket reads
    // null and writes nothing, and the flag is simply local.
    final storageId = _storageId = _computeStorageId();
    _expanded =
        (storageId == null
            ? null
            : PageStorage.maybeOf(
                    context,
                  )?.readState(context, identifier: storageId)
                  as bool?) ??
        widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: _bodyDuration,
      value: _expanded ? 1 : 0,
    );
    _eased = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _bodyDuration;
  }

  @override
  void dispose() {
    _eased.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      // Rebuild once dismissed so the body unmounts — its blocks stop
      // costing layout, and nothing hidden stays focusable.
      _controller.reverse().then((_) {
        if (mounted) setState(() {});
      });
    }
    final storageId = _storageId;
    if (storageId != null) {
      PageStorage.maybeOf(
        context,
      )?.writeState(context, _expanded, identifier: storageId);
    }
    widget.onExpandedChanged?.call(_expanded);
  }

  /// The PageStorageKeys from this widget up to the nearest PageStorage,
  /// the walk the bucket itself makes to name a context's entry.
  _DisclosureId? _computeStorageId() {
    final keys = <PageStorageKey<dynamic>>[];
    void collect(Widget widget) {
      final key = widget.key;
      if (key is PageStorageKey) keys.add(key);
    }

    collect(widget);
    context.visitAncestorElements((element) {
      collect(element.widget);
      return element.widget is! PageStorage;
    });
    return keys.isEmpty ? null : _DisclosureId(keys);
  }

  FlowCodePart get _inputCodePart {
    final input = widget.input!;
    final cached = _inputPart;
    if (cached != null &&
        cached.code == input &&
        cached.language == widget.inputLanguage) {
      return cached;
    }
    return _inputPart = FlowCodePart(input, language: widget.inputLanguage);
  }

  FlowCodePart get _outputCodePart {
    final output = widget.output!;
    final cached = _outputPart;
    if (cached != null &&
        cached.code == output &&
        cached.language == widget.outputLanguage) {
      return cached;
    }
    return _outputPart = FlowCodePart(output, language: widget.outputLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;
    final style =
        context.flowTheme.toolStyle?.merge(widget.style) ?? widget.style;

    final status = widget.status;
    final title = widget.title;
    final detail = widget.detail;
    final errorMessage = widget.errorMessage;
    final hasBody = widget.input != null || widget.output != null;
    final running = status == FlowToolStatus.running;
    final settled =
        status == FlowToolStatus.complete || status == FlowToolStatus.error;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // The mark: one 16px slot the status morphs in. Pending and running
    // share the thinking line's asterisk under one key — still, then
    // turning — so the flip starts the spin from upright without a
    // remount; the settled glyphs crossfade in at the same size.
    final Widget mark = switch (status) {
      FlowToolStatus.pending || FlowToolStatus.running => FlowThinkingIndicator(
        key: const ValueKey('asterisk'),
        active: running,
        size: _markSize,
        color: running
            ? style?.runningColor ?? colors.onSurfaceMuted
            : style?.pendingColor ?? colors.onSurfaceMuted,
      ),
      FlowToolStatus.complete => Icon(
        Icons.check,
        key: const ValueKey('complete'),
        size: _markSize,
        color: style?.completeColor ?? colors.success,
      ),
      FlowToolStatus.error => Icon(
        Icons.error_outline,
        key: const ValueKey('error'),
        size: _markSize,
        color: style?.errorColor ?? colors.error,
      ),
    };

    // The title: muted while the runtime holds the call, sweeping muted
    // to full while it runs, the ramp's variant once settled — the state
    // ink rides the shimmer's base, since the sweep draws with its own
    // inks and a style colour only shows while static.
    final titleStyle = title != null
        ? typography.labelMedium.merge(style?.titleStyle)
        : typography.codeInline.merge(style?.nameStyle);
    final Widget titleText = DefaultTextStyle.merge(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: FlowShimmerText(
        text: title ?? widget.name,
        enabled: running,
        style: titleStyle,
        baseColor: settled ? colors.onSurfaceVariant : colors.onSurfaceMuted,
      ),
    );

    // The header is chrome, like the code block's: the title already
    // stays out of a thread's selection (the shimmer text always does),
    // and the chip follows it.
    Widget? chip;
    if (detail != null) {
      chip = Container(
        padding: _chipPadding,
        decoration: BoxDecoration(
          color: style?.detailChipColor ?? colors.surfaceContainer,
          borderRadius: _chipRadius,
        ),
        child: SelectionContainer.disabled(
          child: Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.codeInline
                .copyWith(color: colors.onSurfaceVariant, height: 1.3)
                .merge(style?.detailStyle),
          ),
        ),
      );
    }

    // The chevron rides the body's clock, so one reduced-motion gate
    // covers both.
    Widget? chevron;
    if (hasBody) {
      chevron = RotationTransition(
        turns: _eased.drive(Tween<double>(begin: 0, end: _chevronTurns)),
        child: Icon(
          Icons.expand_more,
          size: _chevronSize,
          color: colors.onSurfaceMuted,
        ),
      );
    }

    Widget header = Container(
      constraints: const BoxConstraints(minHeight: _headerMinHeight),
      padding: _headerPadding,
      child: Row(
        children: [
          SizedBox.square(
            dimension: _markSize,
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : _markDuration,
              child: mark,
            ),
          ),
          const SizedBox(width: _gap),
          // The title and chip share the row's middle, each giving way
          // at half of it under pressure, and the chevron holds the
          // trailing edge.
          Expanded(
            child: Row(
              children: [
                Flexible(child: titleText),
                if (chip != null) ...[
                  const SizedBox(width: _gap),
                  Flexible(child: chip),
                ],
              ],
            ),
          ),
          if (chevron != null) ...[const SizedBox(width: _gap), chevron],
        ],
      ),
    );
    // A transparent Material inside the decorated card, so the row's ink
    // paints over the fill rather than under it — the copy button's
    // idiom; the card's clip rounds the wash's corners.
    header = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: hasBody ? _toggle : null,
        hoverColor: style?.hoverColor ?? colors.surfaceContainerLow,
        child: header,
      ),
    );
    // Excluding the subtree keeps the title from reading twice, but it
    // drops the InkWell's tap action with it — the node re-owns
    // activation, and says whether the body is open.
    header = Semantics(
      button: hasBody,
      expanded: hasBody ? _expanded : null,
      label: widget.semanticLabel ?? [title ?? widget.name, ?detail].join(', '),
      excludeSemantics: true,
      onTap: hasBody ? _toggle : null,
      child: header,
    );

    Widget? errorLine;
    if (errorMessage != null) {
      errorLine = Padding(
        padding: _errorPadding,
        // A failure lands unprompted — announce it.
        child: Semantics(
          liveRegion: true,
          child: Text(
            errorMessage,
            style: typography.bodyMedium
                .copyWith(color: colors.onSurfaceVariant)
                .merge(style?.errorMessageStyle),
          ),
        ),
      );
    }

    Widget? body;
    if (hasBody) {
      // The disclosure: a clipped box whose height factor eases between
      // shut and open, the framework's own structure — AnimatedSize would
      // drop the content on the first frame of a collapse. The body is
      // built only while open or closing, so nothing hidden costs layout
      // or takes focus.
      final closed = !_expanded && _controller.isDismissed;
      body = AnimatedBuilder(
        animation: _eased,
        builder: (context, child) => ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: _eased.value,
            child: child,
          ),
        ),
        child: closed ? null : _buildBody(colors, style),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: style?.backgroundColor ?? colors.surfaceContainerLowest,
          borderRadius: widget.borderRadius ?? _radius,
          // Hover lives on the edge, the code block's idiom: the hairline
          // firms from `outline` to `outlineVariant`, and a style's
          // borderColor holds through hover unless the style names its
          // own hover edge.
          border: Border.all(
            color: _hovered
                ? (style?.hoverBorderColor ??
                      style?.borderColor ??
                      colors.outlineVariant)
                : (style?.borderColor ?? colors.outline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [header, ?errorLine, ?body],
        ),
      ),
    );
  }

  /// The open body: the rule, then the blocks — input streaming while
  /// the call is still being assembled, output while it runs.
  Widget _buildBody(FlowColors colors, FlowToolStyle? style) {
    final input = widget.input;
    final output = widget.output;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: _dividerThickness,
          color: style?.dividerColor ?? colors.outline,
        ),
        Padding(
          padding: widget.padding ?? _bodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (input != null)
                _buildBlock(
                  part: _inputCodePart,
                  label: widget.inputLabel,
                  streaming: widget.status == FlowToolStatus.pending,
                ),
              if (input != null && output != null)
                const SizedBox(height: _blockGap),
              if (output != null)
                _buildBlock(
                  part: _outputCodePart,
                  label: widget.outputLabel,
                  streaming: widget.status == FlowToolStatus.running,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// One block, wrapping rather than scrolling: a horizontal scroll
  /// inside a disclosure inside a thread is a scroll too many, and a
  /// result already delivered must not hide past an edge.
  Widget _buildBlock({
    required FlowCodePart part,
    required String? label,
    required bool streaming,
  }) {
    final onCodeCopy = widget.onCodeCopy;
    return FlowCodeBlock(
      code: part.code,
      language: part.language,
      filename: label,
      wrap: true,
      borderRadius: _blockRadius,
      isStreaming: streaming,
      onCopy: onCodeCopy == null ? null : () => onCodeCopy(part),
      copied: identical(part, widget.copiedCodePart),
      copyTooltip: widget.codeCopyTooltip,
    );
  }
}

/// A tool card's PageStorage identifier: the key chain the bucket would
/// compute for the card's context, in a type of its own.
@immutable
class _DisclosureId {
  const _DisclosureId(this.keys);

  final List<PageStorageKey<dynamic>> keys;

  @override
  bool operator ==(Object other) =>
      other is _DisclosureId && listEquals(other.keys, keys);

  @override
  int get hashCode => Object.hashAll(keys);
}
