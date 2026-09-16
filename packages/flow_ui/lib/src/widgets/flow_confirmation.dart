import 'package:material_ui/material_ui.dart';

import '../models/flow_message_part.dart';
import '../styles/flow_confirmation_style.dart';
import '../theme/flow_colors.dart';
import '../theme/flow_theme.dart';
import '../theme/flow_typography.dart';
import '../utils/flow_asterisk_painter.dart';
import '../utils/flow_selection.dart';

/// The approval card: an asterisk-marked request on a raised card, with
/// approve and reject buttons that settle into the outcome.
///
/// ```dart
/// FlowConfirmation(
///   title: 'Approval required',
///   message: 'Delete 3 files in drafts/. This cannot be undone.',
///   approveLabel: 'Approve',
///   rejectLabel: 'Reject',
///   onApprove: () => respond(true),
///   onReject: () => respond(false),
/// )
/// ```
///
/// In a thread this renders on its own: a `FlowConfirmationPart` in any
/// turn becomes this card, its buttons reporting through
/// `FlowThread.onConfirmationRespond`. Standalone it serves hosts that
/// gate an action outside a conversation.
///
/// The widget holds no state: a tap reports intent, and the card renders
/// settled only when the host re-renders with the new [status] — pending
/// shows the buttons, approved and rejected replace them with one settled
/// row of the same footprint, so the card's height holds. A pending card
/// with no button pair is a read-only notice, for chrome staged before
/// the request is answerable.
///
/// The asterisk header is the card's identity — the mark that
/// distinguishes the runtime's own chrome from content — so the glyphs
/// are not swappable; restyle their colors through
/// [FlowConfirmationStyle]. The package ships no strings: every label is
/// host-localized.
class FlowConfirmation extends StatelessWidget {
  const FlowConfirmation({
    super.key,
    this.title,
    this.message,
    this.status = FlowConfirmationStatus.pending,
    this.approveLabel,
    this.rejectLabel,
    this.approvedLabel,
    this.rejectedLabel,
    this.onApprove,
    this.onReject,
    this.padding,
    this.borderRadius,
    this.style,
  });

  /// Host-localized header label, e.g. 'Approval required'. Stays on the
  /// card in every state — the accent, not the words, carries the
  /// outcome. Null renders the asterisk alone.
  final String? title;

  /// The request, host-written and sentence-case. Announced to assistive
  /// tech as a live region, since requests arrive unprompted.
  final String? message;

  /// Drives the whole card: pending shows the buttons, approved and
  /// rejected replace them with the settled row.
  final FlowConfirmationStatus status;

  /// Host-localized label and accessible name of the filled button. The
  /// button renders only when both this and [onApprove] are set.
  final String? approveLabel;

  /// Host-localized label and accessible name of the outlined button. The
  /// button renders only when both this and [onReject] are set.
  final String? rejectLabel;

  /// Host-localized text of the settled row when approved, e.g.
  /// 'Approved'. Null shows the check alone — and announces nothing, so
  /// pass one where the outcome should be heard.
  final String? approvedLabel;

  /// Host-localized text of the settled row when rejected, e.g.
  /// 'Rejected'. Null shows the cross alone.
  final String? rejectedLabel;

  /// Approve intent. Null hides the button.
  final VoidCallback? onApprove;

  /// Reject intent. Null hides the button.
  final VoidCallback? onReject;

  /// Inside the card. Defaults to the design's 12 sides, 10 top, 12
  /// bottom.
  final EdgeInsetsGeometry? padding;

  /// The card's corner. Defaults to the design's 12.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.confirmationStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowConfirmationStyle? style;

  /// The card: the raised surface's 12px corner, the faint hairline and
  /// the ambient 2%-ink shadow — the same lift as the composer and the
  /// menu card, because this is chrome, not content.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(12));
  static const EdgeInsetsGeometry _cardPadding = EdgeInsets.fromLTRB(
    12,
    10,
    12,
    12,
  );
  static const double _shadowBlur = 12;

  /// The header: a 16px asterisk a 4px gap from the title, centred on the
  /// title's first line.
  static const double _glyphSize = 16;
  static const double _glyphGap = 4;

  /// Gaps: header to the request, content to the actions or settled row.
  static const double _messageGap = 6;
  static const double _actionsGap = 12;

  /// The buttons' row: right-aligned, 10 apart, wrapping onto an 8px-gapped
  /// second run when two long localized labels outgrow a phone bubble.
  static const double _buttonGap = 10;
  static const double _buttonRunGap = 8;

  /// The approve button's hover wash — its own ink at 8%, since the
  /// translucent surface washes vanish on the inverse fill.
  static const double _approveHoverOpacity = 0.08;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;

    final title = this.title;
    final message = this.message;

    final effective =
        context.flowTheme.confirmationStyle?.merge(style) ?? style;

    // One accent per state: the pending warning, then success or error.
    // It colors the marks — the asterisk, the settled glyph and its wash —
    // never the words: the light accents sit at 2.5–4.5:1 on the card,
    // under WCAG AA for text, so the title and the settled label read in
    // the ink ramp and the accent carries the state beside them.
    final accent = switch (status) {
      FlowConfirmationStatus.pending =>
        effective?.pendingColor ?? colors.warning,
      FlowConfirmationStatus.approved =>
        effective?.approvedColor ?? colors.success,
      FlowConfirmationStatus.rejected =>
        effective?.rejectedColor ?? colors.error,
    };

    final titleStyle = typography.labelSmallEmphasised
        .copyWith(color: colors.onSurfaceVariant)
        .merge(effective?.titleStyle);

    Widget? titleLabel;
    if (title != null) {
      titleLabel = FlowSelectionBlock(child: Text(title, style: titleStyle));
      if (message == null) {
        // The title is all the card says, and requests arrive unprompted:
        // announce it.
        titleLabel = Semantics(liveRegion: true, child: titleLabel);
      }
    }

    // The asterisk centres on the title's first line — the error card's
    // idiom, so a wrapped title keeps the glyph beside its opening line.
    final firstLineHeight =
        (titleStyle.fontSize ?? _glyphSize) * (titleStyle.height ?? 1);

    return Container(
      padding: padding ?? _cardPadding,
      decoration: BoxDecoration(
        color: effective?.backgroundColor ?? colors.surfaceBright,
        borderRadius: borderRadius ?? _radius,
        border: Border.all(color: effective?.borderColor ?? colors.outline),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: _shadowBlur)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: firstLineHeight,
                child: Center(
                  child: CustomPaint(
                    size: const Size.square(_glyphSize),
                    painter: FlowAsteriskPainter(
                      color: accent,
                      strokeWidth: _glyphSize / 9,
                    ),
                  ),
                ),
              ),
              if (titleLabel != null) ...[
                const SizedBox(width: _glyphGap),
                Flexible(child: titleLabel),
              ],
            ],
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: _messageGap),
              child: Semantics(
                liveRegion: true,
                child: FlowSelectionBlock(
                  child: Text(
                    message,
                    style: typography.bodyMedium
                        .copyWith(color: colors.onSurface)
                        .merge(effective?.messageStyle),
                  ),
                ),
              ),
            ),
          ..._buildFooter(colors, typography, effective, accent),
        ],
      ),
    );
  }

  /// The card's closing row: the buttons while pending, the settled chip
  /// after — or nothing, when a pending card has no button pair.
  List<Widget> _buildFooter(
    FlowColors colors,
    FlowTypography typography,
    FlowConfirmationStyle? effective,
    Color accent,
  ) {
    Widget footer;
    if (status == FlowConfirmationStatus.pending) {
      final approveLabel = this.approveLabel;
      final rejectLabel = this.rejectLabel;
      final approveForeground =
          effective?.approveButtonForegroundColor ?? colors.onInverseSurface;
      final buttons = <Widget>[
        if (rejectLabel != null && onReject != null)
          _ConfirmationButton(
            label: rejectLabel,
            onTap: onReject!,
            textStyle: typography.labelMediumEmphasised,
            background:
                effective?.rejectButtonColor ?? colors.surfaceContainerLowest,
            foreground:
                effective?.rejectButtonForegroundColor ??
                colors.onSurfaceVariant,
            hoverForeground: colors.onSurface,
            hoverColor: colors.surfaceContainerLow,
            borderColor:
                effective?.rejectButtonBorderColor ?? colors.outlineVariant,
          ),
        if (approveLabel != null && onApprove != null)
          _ConfirmationButton(
            label: approveLabel,
            onTap: onApprove!,
            textStyle: FlowTypography.recut(
              typography.labelMedium,
              fontWeight: FontWeight.w600,
            ),
            background: effective?.approveButtonColor ?? colors.inverseSurface,
            foreground: approveForeground,
            hoverForeground: approveForeground,
            hoverColor: approveForeground.withValues(
              alpha: _approveHoverOpacity,
            ),
          ),
      ];
      if (buttons.isEmpty) return const [];
      footer = SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: _buttonGap,
          runSpacing: _buttonRunGap,
          children: buttons,
        ),
      );
    } else {
      final approved = status == FlowConfirmationStatus.approved;
      footer = Align(
        alignment: AlignmentDirectional.centerEnd,
        child: _SettledRow(
          approved: approved,
          label: approved ? approvedLabel : rejectedLabel,
          accent: accent,
          foreground: colors.onSurface,
          textStyle: typography.labelMediumEmphasised,
        ),
      );
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: _actionsGap),
        child: footer,
      ),
    ];
  }
}

/// The card's action button in either cut — filled approve, outlined
/// reject — private until the design system's Button lands and absorbs
/// it, like the error card's retry pill.
class _ConfirmationButton extends StatefulWidget {
  const _ConfirmationButton({
    required this.label,
    required this.onTap,
    required this.textStyle,
    required this.background,
    required this.foreground,
    required this.hoverForeground,
    required this.hoverColor,
    this.borderColor,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle textStyle;
  final Color background;
  final Color foreground;
  final Color hoverForeground;
  final Color hoverColor;

  /// The outlined cut's hairline; null renders the filled cut.
  final Color? borderColor;

  @override
  State<_ConfirmationButton> createState() => _ConfirmationButtonState();
}

class _ConfirmationButtonState extends State<_ConfirmationButton> {
  /// The design's button: 32 tall on an 8px corner, padded 12 — the
  /// retry pill's frame.
  static const double _height = 32;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));
  static const EdgeInsetsGeometry _padding = EdgeInsets.symmetric(
    horizontal: 12,
  );

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.borderColor;
    final shape = RoundedRectangleBorder(
      borderRadius: _radius,
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor),
    );

    final button = Material(
      color: widget.background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        customBorder: shape,
        hoverColor: widget.hoverColor,
        child: SizedBox(
          height: _height,
          child: Padding(
            padding: _padding,
            child: Center(
              widthFactor: 1,
              // A button's label is chrome, not content: never part of a
              // selection sweeping the card.
              child: SelectionContainer.disabled(
                child: Text(
                  widget.label,
                  style: widget.textStyle.copyWith(
                    color: _hovered
                        ? widget.hoverForeground
                        : widget.foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Excluding the subtree keeps the label from reading twice, but it
    // drops the InkWell's tap action with it — the node re-owns
    // activation or assistive tech can announce the button yet not tap
    // it.
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: button,
    );
  }
}

/// The settled outcome: the pressed button's footprint, kept — a check or
/// cross in the accent beside the label in the ink, on the accent's wash,
/// non-interactive.
class _SettledRow extends StatelessWidget {
  const _SettledRow({
    required this.approved,
    required this.label,
    required this.accent,
    required this.foreground,
    required this.textStyle,
  });

  final bool approved;
  final String? label;

  /// The glyph and the wash.
  final Color accent;

  /// The label's ink — the full-strength `onSurface`, since the light
  /// accents fall short of AA on their own wash.
  final Color foreground;
  final TextStyle textStyle;

  /// The button's frame, and the accent at the status containers' 6% —
  /// so the default wash equals `successContainer` / `errorContainer`
  /// and a restyled accent still gets a matching fill.
  static const double _height = 32;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));
  static const EdgeInsetsGeometry _padding = EdgeInsets.symmetric(
    horizontal: 12,
  );
  static const double _fillOpacity = 0.06;
  static const double _glyphSize = 14;
  static const double _glyphGap = 6;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Container(
      height: _height,
      padding: _padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _fillOpacity),
        borderRadius: _radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              approved ? Icons.check : Icons.close,
              size: _glyphSize,
              color: accent,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: _glyphGap),
            // The outcome lands unprompted too — announce the flip.
            Semantics(
              liveRegion: true,
              // The outcome chip is chrome, like the buttons it replaces.
              child: SelectionContainer.disabled(
                child: Text(
                  label,
                  style: textStyle.copyWith(color: foreground),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
