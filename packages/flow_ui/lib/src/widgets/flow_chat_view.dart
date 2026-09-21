import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../models/flow_attachment.dart';
import '../models/flow_attachment_options.dart';
import '../styles/flow_chat_view_style.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_circle_button.dart';
import 'flow_drop_target.dart';
import 'flow_thread.dart';

/// How far back through the history the thread must be before the
/// jump-to-latest button is worth offering — roughly one message.
///
/// Deliberately small: a short thread's whole scroll range can be only a
/// few hundred pixels, and a larger threshold would mean the button never
/// appears at all on one.
const double _jumpThreshold = 120;
const Duration _jumpReveal = Duration(milliseconds: 150);
const Duration _jumpScroll = Duration(milliseconds: 240);

/// The chat surface: a bounded thread above a composer, centred at a
/// readable width, with a zero state for the conversation that hasn't
/// started.
///
/// ```dart
/// FlowChatView(
///   empty: messages.isEmpty,
///   greeting: FlowGreeting(icon: Icons.wb_twilight, text: 'Good afternoon'),
///   suggestions: FlowSuggestionGroup(...),
///   thread: FlowThread(messages: messages, controller: controller),
///   composer: FlowComposer(onSend: send),
///   threadController: controller,
/// )
/// ```
///
/// Takes finished widgets rather than their data, so it stays correct as
/// `FlowThread` and `FlowComposer` grow. It supplies the bounded height a
/// `FlowThread` needs, which is the one thing every host would otherwise
/// have to know.
///
/// Body-only: it builds no [Scaffold] and no app bar, so drop it in a
/// scaffold body and the host keeps the chrome, the background, and the
/// keyboard inset.
class FlowChatView extends StatefulWidget {
  const FlowChatView({
    super.key,
    required this.composer,
    this.thread,
    this.header,
    this.aboveComposer,
    this.empty = false,
    this.greeting,
    this.suggestions,
    this.threadController,
    this.jumpToLatestTooltip,
    this.maxContentWidth = 760,
    this.emptyComposerWidth = 640,
    this.emptySuggestionsWidth = 480,
    this.padding,
    this.onAttachmentsDropped,
    this.attachmentOptions = const FlowAttachmentOptions(),
    this.onAttachmentRejected,
    this.attachmentsEnabled = true,
    this.dropActive = false,
    this.dropLabel,
    this.dropIcon,
    this.dropIconSize,
    this.style,
  }) : assert(
         thread != null ||
             composer != null ||
             header != null ||
             aboveComposer != null ||
             greeting != null ||
             suggestions != null,
         'FlowChatView was built with nothing to show, which renders a '
         'blank surface. Pass a thread, a composer, or the zero state '
         'pieces (greeting, suggestions) — see the class doc for the '
         'minimal usage.',
       ),
       assert(maxContentWidth > 0, 'maxContentWidth must be positive'),
       assert(emptyComposerWidth > 0, 'emptyComposerWidth must be positive'),
       assert(
         emptySuggestionsWidth > 0,
         'emptySuggestionsWidth must be positive',
       );

  /// The conversation, usually a [FlowThread]. Given the bounded height it
  /// needs, so it does not want a `SizedBox` of its own.
  ///
  /// Defaults to an empty [FlowThread] — a conversation nobody has spoken in
  /// yet is a real state of a chat, so the surface stands up on its own.
  final Widget? thread;

  /// The input, usually a `FlowComposer`. Required so a surface without an
  /// input is a decision rather than an omission: pass an explicit null for
  /// a read-only surface — an archived thread, a shared transcript.
  ///
  /// There is deliberately no default: a composer needs somewhere to send
  /// to, which is why `FlowComposer` makes `onSend` required, and a
  /// stand-in would swallow what the user typed.
  final Widget? composer;

  /// Optional bar above the thread, full-bleed — the design's mobile nav
  /// spans edge to edge. A host wanting a capped header constrains it
  /// itself.
  final Widget? header;

  /// Between the thread and the composer — a scrolling starter strip, a
  /// notice, anything the host wants pinned above the input.
  final Widget? aboveComposer;

  /// The zero state: no messages yet. The thread gives way to [greeting]
  /// and [suggestions] — on wide layouts the composer lifts to the vertical
  /// centre between them, per the design; on compact ones it stays docked
  /// with the suggestions just above it and the greeting floating centred.
  ///
  /// The host flips this (typically `messages.isEmpty`): the view takes
  /// finished widgets and cannot see into the thread.
  final bool empty;

  /// The zero state's headline, usually a `FlowGreeting`. Shown only while
  /// [empty].
  final Widget? greeting;

  /// The zero state's starters, usually a column `FlowSuggestionGroup`.
  /// Shown only while [empty]; the view places them — 48 below the
  /// composer on wide layouts, capped at [emptySuggestionsWidth], and 16
  /// above it on compact ones, stepped in a further 8.
  final Widget? suggestions;

  /// Enables the jump-to-latest button. Pass the **same** controller to the
  /// [thread]; taking finished widgets means this one cannot reach in and
  /// attach its own. Null leaves the button out entirely.
  final ScrollController? threadController;

  /// Host-localized label for the jump-to-latest button.
  final String? jumpToLatestTooltip;

  /// A conversation spanning a wide display is unreadable, so the thread
  /// and composer are centred and capped. The composer spans this rail in
  /// full where there is room; `FlowThread`'s own edge padding insets the
  /// bubbles 16 inside it. Defaults to the design's 760.
  final double maxContentWidth;

  /// The composer's rail in the wide zero state, where it sits narrower
  /// than in a running chat. Defaults to the design's 640.
  final double emptyComposerWidth;

  /// The [suggestions] rail in the wide zero state. Defaults to the
  /// design's 480.
  final double emptySuggestionsWidth;

  /// Around the composer block. Defaults to the design's 16 at the sides —
  /// kept *outside* [maxContentWidth], so the composer still reaches the
  /// full rail where there is room — with 40 below on wide layouts and 24
  /// on compact ones, measured from the bottom of the safe area so a home
  /// indicator's inset is absorbed rather than added to. An explicit value
  /// is used as given on both, safe area included.
  final EdgeInsetsGeometry? padding;

  /// Turns on the surface's own drag-and-drop and reports what lands on
  /// it, read and decoded per [attachmentOptions]. Null leaves drops to
  /// the browser, which is what makes the detection opt-in.
  ///
  /// The wider of the two places a drop can be wired: anywhere on the
  /// surface counts, including over the thread, which is the forgiving
  /// target most chat apps want. `FlowComposer.onAttachmentsDropped`
  /// scopes the same thing to the composer card instead, for an app
  /// where the rest of the page has its own meaning for a dropped file.
  /// Wiring both is fine — the innermost target under the pointer wins,
  /// so the card takes its own drops and this takes the rest.
  ///
  /// **The web only.** The Flutter SDK implements OS file drop nowhere
  /// else — not in the framework, not in the engine, on any target — so
  /// on desktop and mobile this callback compiles and never fires, and a
  /// debug build says so once. That is what [dropActive] stays writable
  /// for: a desktop host brings its own detection, flips that flag, and
  /// feeds the files back through the composer's `attachments`. The two
  /// coexist — the treatment shows while either is up.
  ///
  /// The attachments are the host's to hold, like the picker's: add them
  /// to state and pass them to `FlowComposer.attachments`.
  final ValueChanged<List<FlowAttachment>>? onAttachmentsDropped;

  /// What a dropped file must be, and how it is decoded. Defaults to
  /// images at sane decode caps. A drop never passes a dialog's filter,
  /// so [FlowAttachmentOptions.accept] is enforced on arrival — anything
  /// outside it goes to [onAttachmentRejected].
  final FlowAttachmentOptions attachmentOptions;

  /// A dropped file that [attachmentOptions] refused, with its name and
  /// the reason. The package ships no copy for these; saying so is the
  /// host's.
  final void Function(String name, FlowAttachmentRejection reason)?
  onAttachmentRejected;

  /// Whether the surface takes drops right now. [onAttachmentsDropped]
  /// says the feature is wired; this says it is available — false leaves
  /// the handler in place and stops it firing, with no treatment raised.
  /// The surface stays a drop zone as far as the browser is concerned, so
  /// a file dropped on it is swallowed rather than navigating the tab.
  /// The composer has the same switch for its own ways in; a host turns
  /// both off together. [dropActive] is unaffected, being the host's own
  /// override.
  final bool attachmentsEnabled;

  /// Raises the drop treatment by hand: a full-bleed tint over the
  /// surface with a centred card inviting the drop. Pure feedback, never
  /// a hit target.
  ///
  /// [onAttachmentsDropped] raises the same treatment on its own, so this
  /// is for the hosts it can't serve — desktop, where the SDK has no file
  /// drop and detection comes from a plugin whose enter/leave events flip
  /// this flag. It is an override, not a switch: the treatment is up
  /// while this is true *or* a drag is over the surface, and hosts that
  /// were driving it before keep working untouched. Colors come from the
  /// theme tokens.
  final bool dropActive;

  /// Host-localized invitation under the drop glyph, e.g. 'Drop files to
  /// add to chat'. Null draws the glyph alone.
  final String? dropLabel;

  /// The drop glyph. Defaults to an upload arrow
  /// (`Icons.file_upload_outlined`); its colour is
  /// [FlowChatViewStyle.dropIconColor].
  final IconData? dropIcon;

  /// The drop glyph's size. Defaults to the design's 48.
  final double? dropIconSize;

  /// Per-instance restyling of the drop treatment, merged over
  /// [FlowTheme.chatViewStyle]'s fields; nulls fall through to the theme
  /// tokens.
  final FlowChatViewStyle? style;

  @override
  State<FlowChatView> createState() => _FlowChatViewState();
}

class _FlowChatViewState extends State<FlowChatView> {
  /// The design's surface metrics. Compact begins below 600, Material's
  /// compact/medium boundary — read from this widget's own constraints, so
  /// a pane or a phone frame counts, not just a phone. The composer block
  /// floats 40 off the bottom on wide layouts and 24 on compact ones, the
  /// jump button 12 off the composer, starters 8 above it.
  static const double _compactBreakpoint = 600;
  static const double _sideInset = 16;
  static const double _bottomInsetWide = 40;
  static const double _bottomInsetCompact = 24;
  static const double _jumpInset = 12;

  /// The drop treatment: a vertical wash over the page, with the glyph
  /// and the invitation sitting straight on it — no card, so the whole
  /// surface reads as the target rather than a panel within it. The
  /// design's gradient runs from `surfaceBright` at 40% to `surface` at
  /// 80%, top to bottom, so the conversation stays legible through it
  /// without competing with the label — which sits on
  /// `titleSmallEmphasised`, a quiet one step above body — over the
  /// design's 12 blur of the page beneath. Revealed on the jump button's
  /// 150ms.
  static const double _dropWashTopOpacity = 0.40;
  static const double _dropWashBottomOpacity = 0.80;
  static const double _dropBlurSigma = 12;
  static const double _dropGlyphSize = 48;
  static const double _dropGlyphGap = 16;
  static const IconData _dropIcon = Icons.file_upload_outlined;
  static const Duration _dropReveal = Duration(milliseconds: 150);
  static const double _composerGap = 8;

  /// The jump button's lift: the composer's shadow, so the disc and the
  /// card it floats above share one.
  static const double _jumpShadowBlur = 12;

  /// The zero state's rhythm: greeting 32 above the composer; suggestions
  /// 48 below it on wide layouts, and on compact ones 16 above the docked
  /// composer, stepped in a further 8 — the design's 24 with the default
  /// padding.
  static const double _greetingGap = 32;
  static const double _suggestionsGapWide = 48;
  static const double _suggestionsGapCompact = 16;
  static const double _suggestionsExtraInset = 8;

  bool _showJump = false;
  Timer? _jumpDebounce;

  /// Whether the package's own detection has a file drag over the
  /// surface. Ors with [FlowChatView.dropActive] rather than replacing
  /// it, so a host driving the flag by hand keeps its treatment.
  bool _dropHover = false;

  @override
  void initState() {
    super.initState();
    widget.threadController?.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(FlowChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadController != widget.threadController) {
      oldWidget.threadController?.removeListener(_handleScroll);
      widget.threadController?.addListener(_handleScroll);
      _handleScroll();
    }
    // Entering the zero state unmounts the thread, and no scroll event
    // arrives from a detaching position — recompute, or a jump button shown
    // before the switch would still be showing when the thread returns.
    if (oldWidget.empty != widget.empty) _handleScroll();
  }

  @override
  void dispose() {
    _jumpDebounce?.cancel();
    widget.threadController?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    final controller = widget.threadController;
    // hasClients guards the frames before the thread has attached, and the
    // ones after it detaches.
    final over =
        controller != null &&
        controller.hasClients &&
        controller.offset > _jumpThreshold;
    if (!over) {
      _jumpDebounce?.cancel();
      _jumpDebounce = null;
      if (_showJump) setState(() => _showJump = false);
      return;
    }
    if (_showJump || _jumpDebounce != null) return;
    // The thread's follow glide can carry the offset past the threshold
    // for a beat while a block eases in — only a held position earns the
    // button, so it isn't mounted and torn down by every entrance.
    _jumpDebounce = Timer(const Duration(milliseconds: 250), () {
      _jumpDebounce = null;
      if (!mounted) return;
      final controller = widget.threadController;
      if (controller != null &&
          controller.hasClients &&
          controller.offset > _jumpThreshold) {
        setState(() => _showJump = true);
      }
    });
  }

  void _jumpToLatest() {
    final controller = widget.threadController;
    if (controller == null || !controller.hasClients) return;
    // The thread is a reversed ListView, so offset 0 is the *newest* message
    // at the bottom and maxScrollExtent is the oldest at the top. Animating
    // to maxScrollExtent here would fly to the start of history instead.
    controller.animateTo(0, duration: _jumpScroll, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    // Read above the SafeArea below, which consumes this padding: inside it
    // the value always reads zero. It is also the *applied* inset rather
    // than viewPadding, so it correctly drops to zero when the keyboard
    // covers the home indicator.
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    // Outside the SafeArea, so the drop rectangle is the whole surface —
    // the treatment is full-bleed and the target should match it. A plain
    // pass-through off the web, where it registers nothing.
    return FlowDropTarget(
      onDropped: widget.onAttachmentsDropped,
      enabled: widget.attachmentsEnabled,
      onHoverChanged: _handleDropHover,
      attachmentOptions: widget.attachmentOptions,
      onAttachmentRejected: widget.onAttachmentRejected,
      child: _buildSurface(context, safeBottom),
    );
  }

  /// The effective style: the widget's over the theme's, tokens beneath.
  FlowChatViewStyle? _styleOf(BuildContext context) =>
      context.flowTheme.chatViewStyle?.merge(widget.style) ?? widget.style;

  void _handleDropHover(bool hovering) {
    if (_dropHover == hovering) return;
    setState(() => _dropHover = hovering);
  }

  Widget _buildSurface(BuildContext context, double safeBottom) {
    return GestureDetector(
      // Taps that reach the surface itself — dead space, the thread, a
      // settled message — dismiss the keyboard, the chat convention.
      // Interactive children (the composer, links, buttons) win the
      // gesture arena first, so their taps behave as before. Touch
      // platforms only — on desktop clicking a page's background doesn't
      // blur the input, and a global unfocus would even reach fields
      // outside this view. The theme's platform, like the composer's and
      // the menus' resolution, so hosts and tests can steer it.
      behavior: HitTestBehavior.translucent,
      onTap: () {
        final platform = Theme.of(context).platform;
        if (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      // The drop treatment layers over everything, full-bleed while the
      // chrome stays inside the SafeArea — the attachment preview's rule.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < _compactBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.header != null) widget.header!,
                    if (widget.empty && !compact)
                      // The wide zero state: the composer leaves the bottom edge
                      // and the whole cluster centres itself instead.
                      Expanded(child: _emptyCentre(constraints.maxWidth))
                    else ...[
                      Expanded(
                        child: widget.empty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _sideInset,
                                  ),
                                  child: widget.greeting,
                                ),
                              )
                            : _threadArea(context),
                      ),
                      ..._composerZone(compact, safeBottom),
                    ],
                  ],
                );
              },
            ),
          ),
          Positioned.fill(child: _dropOverlay(context)),
        ],
      ),
    );
  }

  /// The drop treatment: a tint over the whole surface and a centred
  /// card inviting the drop. Always mounted so the reveal animates both
  /// ways, always ignoring the pointer — it is feedback, not a target —
  /// and out of the semantics tree until active, where the card
  /// announces as a live region.
  Widget _dropOverlay(BuildContext context) {
    final active = widget.dropActive || _dropHover;

    // Driven by a tween rather than an AnimatedOpacity so the treatment
    // can leave the tree entirely once it is hidden. A BackdropFilter
    // repaints the whole viewport for as long as it exists, and a
    // conversation nobody is dragging over should pay nothing for a
    // feature it is not using.
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: active ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _dropReveal,
        builder: (context, t, child) {
          if (t == 0) return const SizedBox.shrink();
          return Opacity(opacity: t, child: child);
        },
        child: ExcludeSemantics(
          excluding: !active,
          child: _dropTreatment(context),
        ),
      ),
    );
  }

  /// The blur, the wash over it, and the invitation on top of both.
  Widget _dropTreatment(BuildContext context) {
    final colors = context.flowColors;
    final style = _styleOf(context);
    final label = widget.dropLabel;

    final gradient =
        style?.dropGradient ??
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.surfaceBright.withValues(alpha: _dropWashTopOpacity),
            colors.surface.withValues(alpha: _dropWashBottomOpacity),
          ],
        );

    // ClipRect bounds the filter to the overlay, as the preview's does.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _dropBlurSigma,
          sigmaY: _dropBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _sideInset),
              child: Semantics(
                liveRegion: true,
                container: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.dropIcon ?? _dropIcon,
                      size: widget.dropIconSize ?? _dropGlyphSize,
                      color: style?.dropIconColor ?? colors.onSurface,
                    ),
                    if (label != null) ...[
                      const SizedBox(height: _dropGlyphGap),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: context.flowTypography.titleSmallEmphasised
                            .copyWith(color: colors.onSurface)
                            .merge(style?.dropLabelStyle),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The running chat: the thread on the content rail, with the
  /// jump-to-latest button floating over its bottom edge.
  Widget _threadArea(BuildContext context) {
    final colors = context.flowColors;

    // An empty thread rather than an empty box: the surface behaves the same
    // whether or not a host has wired one up yet.
    final thread = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
        child: widget.thread ?? const FlowThread(messages: []),
      ),
    );
    // The scrollable lives inside the centred rail, so left alone the
    // platform scrollbar hugs the rail's edge, floating mid-window on
    // wide layouts. Suppressing it and painting one out here instead —
    // fed by the thread's own notifications — puts the thumb at the
    // surface's edge, where readers expect it. Depth 0 keeps the
    // scrollers nested in messages (tables, code blocks) off it.
    final scrollArea = Scrollbar(
      controller: widget.threadController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: thread,
      ),
    );
    if (widget.threadController == null) return scrollArea;

    return Stack(
      children: [
        Positioned.fill(child: scrollArea),
        Positioned(
          bottom: _jumpInset,
          left: 0,
          right: 0,
          child: Center(
            // Opacity alone still hit-tests and still takes focus, so a
            // faded-out button would swallow taps meant for the thread.
            child: IgnorePointer(
              ignoring: !_showJump,
              child: AnimatedOpacity(
                opacity: _showJump ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : _jumpReveal,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: _jumpShadowBlur,
                      ),
                    ],
                  ),
                  // The hairline rides in front of the disc — behind it,
                  // the opaque circle would paint over the stroke.
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.outline),
                  ),
                  child: FlowCircleButton(
                    icon: Icons.arrow_downward,
                    // The opaque ground, not a translucent container wash —
                    // the button floats over the thread, and messages
                    // scrolling beneath must not read through it.
                    background: colors.surface,
                    foreground: colors.onSurface,
                    tooltip: widget.jumpToLatestTooltip,
                    onTap: _jumpToLatest,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The wide zero state's centred cluster: greeting, composer, starters,
  /// each on its own rail. Scrollable so a short window degrades gracefully
  /// instead of overflowing.
  Widget _emptyCentre(double viewportWidth) {
    final available = viewportWidth - _sideInset * 2;
    final composerWidth = math.min(widget.emptyComposerWidth, available);
    final suggestionsWidth = math.min(widget.emptySuggestionsWidth, available);

    final composerBlock = <Widget>[
      if (widget.aboveComposer != null) widget.aboveComposer!,
      if (widget.composer != null) ...[
        if (widget.aboveComposer != null) const SizedBox(height: _composerGap),
        widget.composer!,
      ],
    ];

    // Gaps only between the pieces actually present, so a host without a
    // greeting or without starters still gets a coherent centre.
    final cluster = <Widget>[];
    if (widget.greeting != null) cluster.add(widget.greeting!);
    if (composerBlock.isNotEmpty) {
      if (cluster.isNotEmpty) {
        cluster.add(const SizedBox(height: _greetingGap));
      }
      cluster.add(
        SizedBox(
          width: composerWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: composerBlock,
          ),
        ),
      );
    }
    if (widget.suggestions != null) {
      if (cluster.isNotEmpty) {
        cluster.add(const SizedBox(height: _suggestionsGapWide));
      }
      cluster.add(SizedBox(width: suggestionsWidth, child: widget.suggestions));
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_sideInset),
        child: Column(mainAxisSize: MainAxisSize.min, children: cluster),
      ),
    );
  }

  /// The docked composer block: starters and strip above the input, on the
  /// content rail, inside the surface padding. Skipped entirely when there
  /// is nothing to put below the thread, so a read-only surface doesn't
  /// carry a strip of padding where its composer would have been.
  List<Widget> _composerZone(bool compact, double safeBottom) {
    final suggestions = widget.empty ? widget.suggestions : null;
    if (widget.composer == null &&
        widget.aboveComposer == null &&
        suggestions == null) {
      return const [];
    }

    // The design's inset measures from the bottom of the *safe* area, so
    // it absorbs the home indicator's inset rather than stacking on top of
    // it — a phone would otherwise stand the composer 24 above a 34pt
    // indicator, which reads as a gap the design never drew. Simulated
    // phone frames report no inset and keep the full 24.
    final designBottom = compact ? _bottomInsetCompact : _bottomInsetWide;
    final padding =
        widget.padding ??
        EdgeInsetsDirectional.fromSTEB(
          _sideInset,
          0,
          _sideInset,
          math.max(0, designBottom - safeBottom),
        );

    final column = <Widget>[];
    if (suggestions != null) {
      column.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _suggestionsExtraInset,
          ),
          child: suggestions,
        ),
      );
    }
    if (widget.aboveComposer != null) {
      if (column.isNotEmpty) {
        column.add(const SizedBox(height: _suggestionsGapCompact));
      }
      column.add(widget.aboveComposer!);
    }
    if (widget.composer != null) {
      if (widget.aboveComposer != null) {
        column.add(const SizedBox(height: _composerGap));
      } else if (column.isNotEmpty) {
        column.add(const SizedBox(height: _suggestionsGapCompact));
      }
      column.add(widget.composer!);
    }

    return [
      Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: column,
            ),
          ),
        ),
      ),
    ];
  }
}
