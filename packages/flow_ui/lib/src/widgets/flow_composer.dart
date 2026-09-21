import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/flow_attachment.dart';
import '../models/flow_attachment_options.dart';
import '../styles/flow_composer_style.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_attachment_intake.dart';
import '../utils/flow_circle_button.dart';
import '../utils/flow_clipboard_paste.dart';
import '../utils/flow_file_picker.dart';
import '../utils/flow_gradient_outline.dart';
import '../utils/flow_selection.dart';
import 'flow_attachment_group.dart';
import 'flow_drop_target.dart';
import 'flow_pill.dart';

/// The message input area: an auto-growing text field with an action bar
/// and a send button that morphs into stop while [isStreaming].
///
/// ```dart
/// FlowComposer(
///   placeholder: 'Message…',
///   isStreaming: generating,
///   onSend: (text) => startGeneration(text),
///   onStop: cancelGeneration,
///   // Renders the attach button and opens the platform's file dialog.
///   onAttachmentsPicked: (picked) => setState(() => pending.addAll(picked)),
///   attachTooltip: 'Attach files',
///   attachments: pending,
///   onRemoveAttachment: (id) => setState(() => pending.removeWhere(...)),
///   leadingActions: [FlowMenu(...)],
///   trailingActions: [FlowModelSelector(...)],
/// )
/// ```
///
/// On hardware keyboards Enter sends and Shift+Enter inserts a newline
/// (when [submitOnEnter]); mobile soft keyboards keep their newline key and
/// use the send button.
///
/// ## Attaching
///
/// The attach button appears when the composer is told who picks — and
/// which callback that is decides where the dialog comes from:
///
/// * [onAttachmentsPicked] — the package picks. It opens the platform's
///   own file dialog, reads and decodes what comes back, and hands over
///   ready-made [FlowAttachment]s. [attachmentOptions] says what is
///   accepted; [onAttachmentRejected] reports what wasn't.
/// * [onAttach] — the host picks. The button becomes a plain intent, for
///   a photo sheet, a camera, a menu of sources, or anything else the
///   package has no business knowing about.
///
/// Passing neither leaves the button off, which is the opt-out; passing
/// both asserts, since one button cannot have two owners. To open the
/// same dialog from somewhere other than the built-in button — the
/// design's "+" menu, say — call [showFlowAttachmentPicker] and pass the
/// result back through [attachments]. Either way the pending strip is
/// still the host's state, fed back through [attachments] and pruned
/// through [onRemoveAttachment] — the composer holds nothing.
///
/// The button's own icon color is [FlowComposerStyle.attachIconColor].
///
/// [onAttachmentsDropped] and [onAttachmentsPasted] are the other two
/// ways in, and both stack with either of the above. The first makes the
/// card a drop target, lighting it up while a file is over it — scope is
/// the only choice to make there, since
/// `FlowChatView.onAttachmentsDropped` catches a drop anywhere on the
/// surface and this one only over the card, and wiring both is fine
/// because the innermost target under the pointer wins. The second takes
/// an image pasted into the field.
///
/// Both are web-only — the SDK has no OS file drop and no image
/// clipboard anywhere else — so the attach button is what carries the
/// feature on every other platform, and most hosts point all of these at
/// the same handler. [attachmentsEnabled] turns every way in off at once
/// without unwiring any of them.
///
/// Once something is pending, an empty field is no longer nothing to
/// send: [onSend] fires with an empty string, because a picture with no
/// caption is a message.
class FlowComposer extends StatefulWidget {
  const FlowComposer({
    super.key,
    required this.onSend,
    this.onStop,
    this.isStreaming = false,
    this.controller,
    this.focusNode,
    this.placeholder = 'How can I help you today?',
    this.enabled = true,
    this.clearOnSend = true,
    this.submitOnEnter = true,
    this.maxLines = 6,
    this.attachments = const [],
    this.onRemoveAttachment,
    this.onAttachmentTap,
    this.removeAttachmentTooltip,
    this.previewCloseTooltip,
    this.onAttach,
    this.onAttachmentsPicked,
    this.onAttachmentsDropped,
    this.onAttachmentsPasted,
    this.attachmentOptions = const FlowAttachmentOptions(),
    this.onAttachmentRejected,
    this.attachmentsEnabled = true,
    this.attachTooltip,
    this.onContentInserted,
    this.errorMessage,
    this.errorIcon,
    this.onErrorDismiss,
    this.errorDismissTooltip,
    this.leadingActions = const [],
    this.trailingActions = const [],
    this.padding,
    this.borderRadius,
    this.style,
  }) : assert(maxLines > 0, 'maxLines must be positive'),
       assert(
         onAttach == null || onAttachmentsPicked == null,
         'Pass onAttach or onAttachmentsPicked, not both: there is one '
         'attach button and it can only have one owner. onAttach means the '
         'host picks; onAttachmentsPicked means the package does.',
       );

  /// Called with the trimmed text — empty only when [attachments] is not,
  /// since a picture with no caption is still a message.
  final ValueChanged<String> onSend;

  /// Stop generation; wired to the button while [isStreaming].
  final VoidCallback? onStop;

  /// While true the send button becomes a stop button.
  final bool isStreaming;

  /// Optional external controller; an internal one is used when null.
  final TextEditingController? controller;

  /// Optional external focus node; an internal one is used when null.
  final FocusNode? focusNode;

  /// Hint text in the empty field. Defaults to the design's greeting —
  /// the one string the package ships, so localized hosts should pass
  /// their own copy. An explicit null renders no hint at all.
  final String? placeholder;

  final bool enabled;

  /// Clear the field after a successful send.
  final bool clearOnSend;

  /// Enter sends, Shift+Enter newlines (hardware keyboards).
  final bool submitOnEnter;

  /// Auto-grow cap; the field scrolls beyond it.
  final int maxLines;

  /// Pending attachments, shown above the input. Empty renders nothing.
  final List<FlowAttachment> attachments;

  /// Called with the id of the attachment whose remove button was tapped.
  final ValueChanged<String>? onRemoveAttachment;

  /// Called with the tapped attachment's id, *instead of* opening the
  /// built-in full-screen preview. Call `showFlowAttachmentPreview` from the
  /// handler to keep it alongside your own handling.
  final ValueChanged<String>? onAttachmentTap;

  /// Host-localized label for the remove button on each attachment.
  final String? removeAttachmentTooltip;

  /// Host-localized label for the built-in preview's close button.
  final String? previewCloseTooltip;

  /// Renders the attach button and reports its taps, leaving the picking
  /// to the host — a photo sheet, a camera, a menu of sources.
  ///
  /// The escape hatch from [onAttachmentsPicked], and strictly more
  /// powerful than it: whatever the host gathers goes back through
  /// [attachments] like anything else. Mutually exclusive with
  /// [onAttachmentsPicked]; null for both leaves the button off.
  final VoidCallback? onAttach;

  /// Renders the attach button and picks with it: tapping opens the
  /// platform's file dialog, and this is called with everything chosen,
  /// already read and decoded per [attachmentOptions].
  ///
  /// Never called with an empty list — a dismissed dialog is silence, and
  /// a file that fails [attachmentOptions] goes to
  /// [onAttachmentRejected] instead. The attachments are still the host's
  /// to hold: add them to state and pass them back through [attachments].
  ///
  /// Mutually exclusive with [onAttach].
  ///
  /// The dialog is the platform's own, with what that implies: on iOS and
  /// Android it is the system file browser rather than the photo gallery,
  /// and a gallery sheet is exactly the case [onAttach] is for. On macOS
  /// the app needs the `com.apple.security.files.user-selected.read-only`
  /// entitlement in both `DebugProfile.entitlements` and
  /// `Release.entitlements`, or the dialog opens onto nothing.
  final ValueChanged<List<FlowAttachment>>? onAttachmentsPicked;

  /// Scopes drag-and-drop to the card and reports what lands on it, read
  /// and decoded per [attachmentOptions]. While a file is over the card
  /// it lights up — the hairline goes solid and the fill takes a wash,
  /// both in [FlowComposerStyle.dropHighlightColor].
  ///
  /// The narrower of the two places a drop can be wired.
  /// `FlowChatView.onAttachmentsDropped` takes the whole surface, which
  /// is the more forgiving target; this one asks the user to aim, and
  /// leaves the rest of the page to the browser. Wiring both is fine —
  /// the innermost target under the pointer wins, so the card takes its
  /// own drops and the surface takes the rest.
  ///
  /// **The web only**, like every drop in the package: the Flutter SDK
  /// implements OS file drop nowhere else. A debug build says so once if
  /// this is wired where it cannot fire.
  final ValueChanged<List<FlowAttachment>>? onAttachmentsDropped;

  /// Takes images pasted into the field — Ctrl+V or Cmd+V — and reports
  /// them read and decoded per [attachmentOptions].
  ///
  /// Fires only while the field has focus, so a paste meant for some
  /// other input on the page is left alone, and only when the clipboard
  /// actually holds a file: pasting text is the field's own business and
  /// is untouched. A clipboard carrying both — which is what copying a
  /// file in a desktop file manager produces — attaches the file and
  /// suppresses the filename that would otherwise land in the draft.
  ///
  /// **The web only.** Flutter's own `Clipboard` reads plain text and
  /// nothing else on every platform — `ClipboardData` has one variant and
  /// its documentation says images may come "in the future" — so there is
  /// nothing to read from off the web, and this never fires there. A
  /// debug build says so once.
  ///
  /// Android is the near miss: media pasted through the keyboard rather
  /// than the system clipboard arrives on [onContentInserted] instead,
  /// which is worth wiring alongside this for that reason.
  final ValueChanged<List<FlowAttachment>>? onAttachmentsPasted;

  /// What the built-in picker offers and how what comes back is decoded.
  /// Also the bar a *dropped* or *pasted* file is held to, which is a real gate
  /// rather than a filter — a drop never passed through a dialog.
  /// Ignored only when the host owns every way in — [onAttach] for the
  /// button, with neither [onAttachmentsDropped] nor
  /// [onAttachmentsPasted] wired.
  final FlowAttachmentOptions attachmentOptions;

  /// A file the picker, [onAttachmentsDropped] or [onAttachmentsPasted]
  /// refused, with its name and the reason. The package ships no copy for these, so
  /// surfacing them — a snack bar, an inline note — is the host's, and
  /// so is their wording.
  final void Function(String name, FlowAttachmentRejection reason)?
  onAttachmentRejected;

  /// Whether the ways in are on right now. Presence of a callback says
  /// the feature is *wired*; this says it is *available* — off for a plan
  /// tier, a model that takes no images, a thread that has closed.
  ///
  /// False leaves every handler in place and stops them firing: the
  /// attach button is not rendered, the card swallows a drop rather than
  /// handing it to the browser, the field takes no paste, and the
  /// keyboard offers no media. Attachments
  /// already pending stay in the strip and can still be removed — they
  /// are the host's state, and hiding them would lose what the user
  /// already did. A host's own control that calls
  /// [showFlowAttachmentPicker] is the host's to hide alongside this.
  ///
  /// [enabled] is the wider switch: false there refuses every way in as
  /// well as typing and sending.
  final bool attachmentsEnabled;

  /// Host-localized label for the attach button; also its accessible
  /// name.
  final String? attachTooltip;

  /// Raises the error banner: the design's tab above the card, in the
  /// error wash with a warning glyph and this line. Null draws nothing.
  ///
  /// The words are the host's — a refused attachment
  /// ([onAttachmentRejected] says which and why), a failed send, anything
  /// the composer should own up to — and so is when it clears: the banner
  /// stays until [onErrorDismiss] fires from its cross or the host sets
  /// this back to null. The line sits left of the tab beside the glyph
  /// and wraps from it when long. The banner's inks are
  /// [FlowComposerStyle.errorBackgroundColor] and
  /// [FlowComposerStyle.errorForegroundColor].
  final String? errorMessage;

  /// The banner's glyph. Defaults to the design's warning diamond, drawn
  /// by the package; pass an icon to use your own set's.
  final IconData? errorIcon;

  /// Draws a cross at the banner's trailing edge and reports its tap —
  /// the host clears [errorMessage] in response. Null draws no cross,
  /// for a banner the host clears on its own terms.
  final VoidCallback? onErrorDismiss;

  /// Host-localized label for the banner's cross; also its accessible
  /// name.
  final String? errorDismissTooltip;

  /// Called when the software keyboard inserts media — Android's IME
  /// rich-content path, e.g. an image picked inside Gboard. Null leaves
  /// keyboard insertion off. The host converts the content's bytes into
  /// a [FlowAttachment] and passes it back through [attachments]. The
  /// SDK delivers this on Android only; it is not clipboard paste.
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

  /// Bottom-left slot, e.g. a `FlowMenu`.
  final List<Widget> leadingActions;

  /// Bottom-right slot before the send button, e.g. a `FlowModelSelector`.
  final List<Widget> trailingActions;

  /// Inside the card, around the field and action bar. Defaults to the
  /// design's 16 at the start and 8 elsewhere.
  final EdgeInsetsGeometry? padding;

  /// The card's corner. Defaults to the design's 24.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.composerStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowComposerStyle? style;

  @override
  State<FlowComposer> createState() => _FlowComposerState();
}

/// One warning per process, not one per composer: a thread of them would
/// bury whatever the developer was actually reading.
bool _warnedPasteUnsupported = false;

class _FlowComposerState extends State<FlowComposer> {
  /// The design's card: 24px corners padded 19 above and 11 below (the
  /// outline's 1px included), its content — attachment strip and field —
  /// inset 18 further from the sides while the action row tucks in at 10,
  /// under a soft ambient shadow.
  static const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(24));
  static const EdgeInsetsGeometry _cardPadding = EdgeInsetsDirectional.fromSTEB(
    1,
    19,
    1,
    11,
  );
  static const double _contentInset = 18;
  static const double _actionInset = 10;
  static const double _attachmentGap = 12;
  static const double _fieldGap = 16;
  static const double _leadingGap = 4;
  static const double _trailingGap = 8;

  /// Between two neighbouring pills in the action row — the design's 8,
  /// closing to 6 on phones.
  static const double _pillGap = 8;
  static const double _mobilePillGap = 6;

  /// The field's floor, sized so an empty composer stands at the design's
  /// 116px: 19 + 38 + 16 (gap) + 32 (action row) + 11.
  static const double _fieldMinHeight = 38;

  /// The design's outline: a 1px hairline over the ink, sweeping from the
  /// top-left toward the bottom-right where it thins — 14% → 8% at rest,
  /// 20% → 12% while the composer is hovered or focused.
  static const double _outlineRestAlpha = 0.14;
  static const double _outlineRestFadeAlpha = 0.08;
  static const double _outlineActiveAlpha = 0.20;
  static const double _outlineActiveFadeAlpha = 0.12;

  /// Send and stop are the design's ringed button: a 26px disc inside a
  /// surface-colored gap and a 1px ring, on a 32px frame.
  static const double _buttonFrame = 32;
  static const double _buttonDisc = 26;

  /// Centers the stop glyph on the disc (26 = 18 + 2 × 4).
  static const double _stopPadding = 4;

  /// The attach affordance: the menus' trigger metrics — an 18px glyph
  /// padded 7 onto a 32px disc.
  static const double _attachIconSize = 18;
  static const double _attachPadding = 7;

  /// The card's lift: the theme's shadow ink at the composer's tighter blur.
  static const double _shadowBlur = 12;

  /// The drop wash over the card's ground — light enough that the field's
  /// text keeps its contrast, heavy enough to read as a state change
  /// alongside the solid hairline.
  static const double _dropWashAlpha = 0.06;

  /// The error banner, the design's tab tucked behind the card: inset 20
  /// from the card's edges under 20px top corners, padded 16 leading, 8
  /// trailing and 6 vertical, an 18px glyph 8 from 14px medium text,
  /// lifted on the tiles' 24px shadow.
  /// It grows in over the jump button's 150ms.
  ///
  /// The cross is a 16px glyph on a 24px disc; the tab's vertical padding
  /// gives up the difference so the banner keeps its 30px height with or
  /// without it.
  static const double _errorInset = 20;
  static const double _errorLeadingPadding = 16;
  static const double _errorTrailingPadding = 8;
  static const double _errorVerticalPadding = 6;
  static const double _errorGap = 8;
  static const double _errorDismissIconSize = 16;
  static const double _errorDismissPadding = 4;
  static const Radius _errorRadius = Radius.circular(20);
  static const double _errorIconSize = 18;
  static const double _errorShadowBlur = 24;
  static const double _errorTextHeight = 1.3;
  static const Duration _errorReveal = Duration(milliseconds: 150);

  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  late FocusNode _attachedFocusNode;
  bool _focused = false;
  bool _hovered = false;
  bool _attachHovered = false;
  bool _picking = false;
  bool _dropHover = false;
  bool _disposed = false;
  FlowPasteRegistration? _pasteRegistration;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _attachedFocusNode = _focusNode..addListener(_handleFocusChange);
    _registerPaste();
  }

  @override
  void didUpdateWidget(FlowComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode != _attachedFocusNode) {
      _attachedFocusNode.removeListener(_handleFocusChange);
      _attachedFocusNode = _focusNode..addListener(_handleFocusChange);
      _handleFocusChange();
    }
    if ((widget.onAttachmentsPasted == null) !=
        (oldWidget.onAttachmentsPasted == null)) {
      _registerPaste();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pasteRegistration?.dispose();
    _attachedFocusNode.removeListener(_handleFocusChange);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _registerPaste() {
    _pasteRegistration?.dispose();
    _pasteRegistration = null;
    if (widget.onAttachmentsPasted == null) return;

    _pasteRegistration = flowRegisterPasteTarget(
      // Read at paste time, not captured, so focus and enablement can
      // change without the registration having to keep up.
      isActive: () =>
          !_disposed &&
          mounted &&
          widget.enabled &&
          widget.attachmentsEnabled &&
          _focused,
      onPaste: _handlePaste,
    );

    assert(() {
      if (_pasteRegistration == null && !_warnedPasteUnsupported) {
        _warnedPasteUnsupported = true;
        debugPrint(
          'FlowComposer was given an onAttachmentsPasted callback on a '
          'platform with no image clipboard. Flutter reads plain text and '
          'nothing else from the clipboard everywhere but the web, so this '
          'callback will never fire here. On Android, keyboard-inserted '
          'media arrives on onContentInserted instead.',
        );
      }
      return true;
    }());
  }

  /// Answers, during the paste event, whether anything on the clipboard
  /// will be taken — which decides whether the field's own paste is
  /// suppressed — and starts the intake either way, so a refusal is still
  /// reported rather than swallowed.
  bool _handlePaste(List<FlowFileCandidate> files) {
    final options = widget.attachmentOptions;
    final willTake = files.any((file) => flowPreAccepts(file, options));
    unawaited(_intakePaste(files, options));
    return willTake;
  }

  Future<void> _intakePaste(
    List<FlowFileCandidate> files,
    FlowAttachmentOptions options,
  ) async {
    final attachments = await flowIntakeAttachments(
      files,
      options: options,
      onRejected: widget.onAttachmentRejected,
    );
    if (!mounted || attachments.isEmpty) return;
    widget.onAttachmentsPasted?.call(attachments);
  }

  void _handleFocusChange() {
    if (_focused != _attachedFocusNode.hasFocus) {
      setState(() => _focused = _attachedFocusNode.hasFocus);
    }
  }

  /// The effective style: the widget's over the theme's, tokens beneath.
  FlowComposerStyle? _styleOf(BuildContext context) =>
      context.flowTheme.composerStyle?.merge(widget.style) ?? widget.style;

  /// The theme's platform rather than the real one, like the menus' sheet
  /// resolution, so hosts and tests can steer it without a device.
  static bool _isMobile(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  /// Whether there is anything to send. Pending attachments count on
  /// their own: a picture with no caption is a message, so an empty field
  /// under a full strip arms the button and sends empty text.
  bool _canSend(String trimmedText) =>
      widget.enabled &&
      (trimmedText.isNotEmpty || widget.attachments.isNotEmpty);

  void _send() {
    final text = _controller.text.trim();
    if (!_canSend(text)) return;
    widget.onSend(text);
    if (widget.clearOnSend) _controller.clear();
  }

  void _setAttachHovered(bool value) {
    if (_attachHovered == value) return;
    setState(() => _attachHovered = value);
  }

  void _handleDropHover(bool hovering) {
    if (_dropHover == hovering) return;
    setState(() => _dropHover = hovering);
  }

  /// Opens the platform's dialog and hands back what it decoded. Guarded
  /// against a second tap: some platforms will happily stack two dialogs,
  /// and the second one's result would arrive over the first's.
  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      // Never throws: a dialog that fails to open comes back as a
      // rejection under an empty name.
      final picked = await showFlowAttachmentPicker(
        options: widget.attachmentOptions,
        onRejected: widget.onAttachmentRejected,
      );
      if (!mounted || picked.isEmpty) return;
      widget.onAttachmentsPicked?.call(picked);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.submitOnEnter || widget.isStreaming) {
      return KeyEventResult.ignored;
    }
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (event is KeyDownEvent &&
        isEnter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The design's button anatomy: the disc floats inside a gap of the
  /// card's own surface, enclosed by a hairline ring — the ring muted while
  /// the button can't act, so the geometry never jumps on enable.
  Widget _ringed(
    BuildContext context, {
    required bool active,
    required Widget disc,
  }) {
    final colors = context.flowColors;
    final style = _styleOf(context);
    return Container(
      width: _buttonFrame,
      height: _buttonFrame,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: style?.backgroundColor ?? colors.surfaceBright,
        shape: CircleBorder(
          side: BorderSide(
            color: active
                ? (style?.sendBackgroundColor ?? colors.primary)
                : colors.outlineVariant,
          ),
        ),
      ),
      child: SizedBox.square(dimension: _buttonDisc, child: disc),
    );
  }

  /// The attach affordance: the menus' trigger idiom — an 18px glyph on
  /// a 32px disc washed with `surfaceContainer` on hover — not the send
  /// button's ringed disc. Attach is editing, so [FlowComposer.enabled]
  /// gates it like attachment removal, and so does an open dialog.
  Widget _buildAttachButton(BuildContext context) {
    final colors = context.flowColors;
    final style = _styleOf(context);
    final enabled = widget.enabled && !_picking;
    final rest = style?.attachIconColor ?? colors.onSurfaceVariant;
    final Color foreground;
    if (!enabled) {
      foreground = colors.onSurfaceDisabled;
    } else if (_attachHovered) {
      foreground = colors.onSurface;
    } else {
      foreground = rest;
    }

    // Its own Material, the idiom every other InkWell in the package
    // follows: ink needs one, and the nearest ancestor's sits *under* the
    // card's opaque ground, where the hover wash would never be seen.
    Widget button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enabled ? (widget.onAttach ?? _pick) : null,
        // Wired even while disabled, so a pointer leaving during an open
        // dialog is still heard — otherwise the glyph stays lit with the
        // pointer nowhere near it.
        onHover: (value) => _setAttachHovered(value),
        customBorder: const CircleBorder(),
        hoverColor: colors.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(_attachPadding),
          child: Icon(
            Icons.attach_file,
            size: _attachIconSize,
            color: foreground,
          ),
        ),
      ),
    );

    // Tooltip contributes the accessible name too — a separate Semantics
    // label would announce it twice, per FlowCircleButton's precedent.
    final tooltip = widget.attachTooltip;
    if (tooltip != null) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildSendStopButton(BuildContext context) {
    final colors = context.flowColors;
    final style = _styleOf(context);
    final discColor = style?.sendBackgroundColor ?? colors.primary;
    final glyphColor = style?.sendForegroundColor ?? colors.onPrimary;
    if (widget.isStreaming) {
      return _ringed(
        context,
        active: true,
        disc: FlowCircleButton(
          icon: Icons.stop_rounded,
          background: discColor,
          foreground: glyphColor,
          padding: _stopPadding,
          onTap: widget.onStop,
        ),
      );
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final canSend = _canSend(value.text.trim());
        return _ringed(
          context,
          active: canSend,
          disc: Material(
            // Disabled keeps the arrow's ink and only drains the disc:
            // primary gives way to the 30% disabled wash.
            color: canSend ? discColor : colors.onSurfaceDisabled,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: canSend ? _send : null,
              customBorder: const CircleBorder(),
              child: CustomPaint(
                // The design's arrow is a thin stroke, not the chunky
                // Material glyph.
                painter: _ArrowUpPainter(color: glyphColor),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The error banner: a tab in the error wash with matching hairline,
  /// open at the bottom where it meets the card. The line starts beside
  /// the glyph and wraps from it when long.
  Widget _buildErrorBanner(BuildContext context, String message) {
    final colors = context.flowColors;
    final style = _styleOf(context);
    final background = style?.errorBackgroundColor ?? colors.errorContainer;
    final foreground = style?.errorForegroundColor ?? colors.onErrorContainer;
    final icon = widget.errorIcon;
    final onDismiss = widget.onErrorDismiss;
    const dismissDisc = _errorDismissIconSize + _errorDismissPadding * 2;
    final verticalPadding = onDismiss == null
        ? _errorVerticalPadding
        : _errorVerticalPadding - (dismissDisc - _errorIconSize) / 2;

    final content = Row(
      children: [
        if (icon != null)
          Icon(icon, size: _errorIconSize, color: foreground)
        else
          CustomPaint(
            size: const Size.square(_errorIconSize),
            painter: _WarningDiamondPainter(color: foreground),
          ),
        const SizedBox(width: _errorGap),
        Flexible(
          child: Text(
            message,
            // The emphasised cut: the design sets the line in the medium
            // weight, which on this ramp is the label's emphasised form.
            style: context.flowTypography.labelMediumEmphasised.copyWith(
              color: foreground,
              height: _errorTextHeight,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _errorInset),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: EdgeInsetsDirectional.only(
            start: _errorLeadingPadding,
            end: _errorTrailingPadding,
            top: verticalPadding,
            bottom: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: background,
            // The design's hairline is the wash itself, one pixel wider;
            // uniform so it can carry the radius, its bottom run hidden
            // under the card's own outline.
            border: Border.all(color: background),
            borderRadius: const BorderRadius.vertical(top: _errorRadius),
            boxShadow: [
              BoxShadow(color: colors.shadow, blurRadius: _errorShadowBlur),
            ],
          ),
          // The cross pins to the trailing edge; the glyph and line take
          // what is left, from the leading edge.
          child: onDismiss == null
              ? content
              : Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: _errorGap),
                    FlowCircleButton(
                      icon: Icons.close,
                      background: const Color(0x00000000),
                      foreground: foreground,
                      hoverColor: background,
                      iconSize: _errorDismissIconSize,
                      padding: _errorDismissPadding,
                      tooltip: widget.errorDismissTooltip,
                      onTap: onDismiss,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = widget.errorMessage;

    // The banner sits above the card and outside the drop target: it is
    // not somewhere to drop a file. AnimatedSize grows it in from the
    // card's top edge, so the thread above eases up rather than jumping.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : _errorReveal,
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: errorMessage == null
              ? const SizedBox.shrink()
              : _buildErrorBanner(context, errorMessage),
        ),
        _buildCard(context),
      ],
    );
  }

  /// The card: outline, ground, strip, field and action row, wrapped as
  /// the composer's drop target.
  Widget _buildCard(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;

    final active = widget.enabled && (_focused || _hovered);
    final radius = widget.borderRadius ?? _cardRadius;
    final style = _styleOf(context);
    // A style's outline flattens the default gradient to one solid color
    // in every state, like the menu card's border override does.
    final outline = style?.outlineColor;

    // A file over the card outranks both the rest and active outlines,
    // and outranks a style's flattened one too: the drop state has to
    // read, and a host that recolored the hairline still wants to see
    // where the file is going.
    final highlight = style?.dropHighlightColor ?? colors.primary;
    final ground = style?.backgroundColor ?? colors.surfaceBright;

    // Wraps the card so the drop rectangle is the card, not the slot it
    // sits in — the point of scoping a drop here rather than on the chat
    // surface. A plain pass-through when nothing is wired, and off the
    // web.
    return FlowDropTarget(
      // Gated like the picker, the paste and attachment removal: while
      // the composer is disabled a drag must not light the card up or
      // deliver anything — but the target stays registered, so the
      // browser does not navigate to the file instead.
      onDropped: widget.onAttachmentsDropped,
      enabled: widget.enabled && widget.attachmentsEnabled,
      onHoverChanged: _handleDropHover,
      attachmentOptions: widget.attachmentOptions,
      onAttachmentRejected: widget.onAttachmentRejected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        // The whole card is the field's hit target: a click on the padding,
        // the gap under the field or the empty stretch of the action row
        // brings the caret in, as it would on a plain text box, and the
        // pointer reads as a text cursor over all of it to say so. The
        // buttons, the tiles and the field itself sit deeper in the tree,
        // so their own taps still win the arena and their own cursors
        // still show.
        cursor: widget.enabled
            ? SystemMouseCursors.text
            : SystemMouseCursors.basic,
        // The card joins the field's tap region. The field drops focus on a
        // pointer *down* outside its region (desktop, web, and any mouse
        // press), so without this a click on the padding would blur on the
        // down and refocus on the up — cancelling IME composition and firing
        // the host's focus listeners twice. It has to be the field's *default*
        // group, not a private one: the selection handles and the Copy/Paste
        // toolbar live in that default group, and a field moved out of it
        // would blur on a press on its own toolbar.
        child: TextFieldTapRegion(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _focusNode.requestFocus : null,
            child: CustomPaint(
              // The outline is painted rather than a layout border so the
              // card never shifts as it swaps between its rest and active
              // gradients.
              foregroundPainter: FlowGradientOutlinePainter(
                radius: radius,
                start: _dropHover
                    ? highlight
                    : outline ??
                          colors.onSurface.withValues(
                            alpha: active
                                ? _outlineActiveAlpha
                                : _outlineRestAlpha,
                          ),
                end: _dropHover
                    ? highlight
                    : outline ??
                          colors.onSurface.withValues(
                            alpha: active
                                ? _outlineActiveFadeAlpha
                                : _outlineRestFadeAlpha,
                          ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  // The composer is the design's raised card: it sits above the
                  // page rather than tinting it, in both themes, under a
                  // barely-there ambient lift. The drop wash blends into the
                  // ground rather than layering over it, so the card stays the
                  // one opaque surface even while lit.
                  color: _dropHover
                      ? Color.alphaBlend(
                          highlight.withValues(alpha: _dropWashAlpha),
                          ground,
                        )
                      : ground,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(color: colors.shadow, blurRadius: _shadowBlur),
                  ],
                ),
                padding: widget.padding ?? _cardPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.attachments.isNotEmpty) ...[
                      // The inset rides inside the strip's scroll view rather
                      // than around it: at rest nothing moves, but once the
                      // strip overflows the tiles scroll under the gutter and
                      // the last one is cut at the card's edge — the cue that
                      // there is more, with no counter to draw.
                      FlowAttachmentGroup(
                        attachments: widget.attachments,
                        padding: const EdgeInsets.symmetric(
                          horizontal: _contentInset,
                        ),
                        onTap: widget.onAttachmentTap,
                        // Editing is what `enabled` gates; viewing an attachment
                        // that is already pending stays available, as does the
                        // send button while streaming.
                        onRemove: widget.enabled
                            ? widget.onRemoveAttachment
                            : null,
                        removeTooltip: widget.removeAttachmentTooltip,
                        previewCloseTooltip: widget.previewCloseTooltip,
                      ),
                      const SizedBox(height: _attachmentGap),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _contentInset,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: _fieldMinHeight,
                        ),
                        alignment: AlignmentDirectional.topStart,
                        child: Focus(
                          onKeyEvent: _handleKeyEvent,
                          // The caret and the highlight in the theme's
                          // selection colours, matching the thread's; a
                          // host's own textSelectionTheme still wins.
                          child: TextSelectionTheme(
                            data: flowTextSelectionTheme(context),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              enabled: widget.enabled,
                              minLines: 1,
                              maxLines: widget.maxLines,
                              // The design's compressed composer: body face on
                              // the 1.3 control line, so the empty card stands
                              // at 116.
                              style: typography.bodyLarge
                                  .copyWith(
                                    height: 1.3,
                                    color: colors.onSurface,
                                  )
                                  .merge(style?.textStyle),
                              // Android's IME rich-content path, the one media
                              // input the SDK covers without a plugin.
                              contentInsertionConfiguration:
                                  widget.onContentInserted == null ||
                                      !widget.attachmentsEnabled
                                  ? null
                                  : ContentInsertionConfiguration(
                                      onContentInserted:
                                          widget.onContentInserted!,
                                    ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: widget.placeholder,
                                hintStyle: typography.bodyLarge.copyWith(
                                  height: 1.3,
                                  color:
                                      style?.hintColor ?? colors.onSurfaceMuted,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _actionInset,
                      ),
                      child: Row(
                        children: [
                          // The built-in attach affordance leads the row; being
                          // outside the loop keeps the pill-pair gap logic
                          // reading only the host's actions.
                          if (widget.attachmentsEnabled &&
                              (widget.onAttach != null ||
                                  widget.onAttachmentsPicked != null)) ...[
                            _buildAttachButton(context),
                            const SizedBox(width: _leadingGap),
                          ],
                          for (
                            var i = 0;
                            i < widget.leadingActions.length;
                            i++
                          ) ...[
                            widget.leadingActions[i],
                            // Two neighbouring pills read as a set and take the
                            // design's wider step — 8, closing to 6 on phones —
                            // while everything else keeps the action row's 4.
                            SizedBox(
                              width:
                                  i + 1 < widget.leadingActions.length &&
                                      widget.leadingActions[i] is FlowPill &&
                                      widget.leadingActions[i + 1] is FlowPill
                                  ? (_isMobile(context)
                                        ? _mobilePillGap
                                        : _pillGap)
                                  : _leadingGap,
                            ),
                          ],
                          const Spacer(),
                          for (final action in widget.trailingActions) ...[
                            action,
                            const SizedBox(width: _trailingGap),
                          ],
                          _buildSendStopButton(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The send arrow: a thin rounded stroke, matching the design's 1.5-weight
/// mark rather than the Material icon's filled glyph. Drawn to scale with
/// the disc it sits on.
class _ArrowUpPainter extends CustomPainter {
  const _ArrowUpPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide / 17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final center = size.center(Offset.zero);
    // The design's proportions on its 26px disc: a 12-tall stem with a
    // 10-wide head.
    final stem = size.shortestSide * (12 / 26) / 2;
    final head = size.shortestSide * (10 / 26) / 2;
    final top = Offset(center.dx, center.dy - stem);
    canvas.drawLine(top, Offset(center.dx, center.dy + stem), paint);
    final path = Path()
      ..moveTo(center.dx - head, top.dy + head)
      ..lineTo(top.dx, top.dy)
      ..lineTo(center.dx + head, top.dy + head);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowUpPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's warning diamond, drawn to scale: a rounded square on its
/// corner with an exclamation inside, stroked at the send arrow's weight.
/// Painted rather than fetched so the package ships no icon font.
class _WarningDiamondPainter extends CustomPainter {
  const _WarningDiamondPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide / 12;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final center = size.center(Offset.zero);
    // The diamond's half-diagonal, inset for the stroke; its side follows.
    final half = size.shortestSide / 2 - stroke;
    final side = half * math.sqrt2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        Radius.circular(size.shortestSide / 9),
      ),
      paint,
    );
    canvas.restore();

    // The exclamation: a stem above centre and a dot below it.
    final stem = size.shortestSide * (4.5 / 18);
    canvas.drawLine(
      Offset(center.dx, center.dy - stem),
      Offset(center.dx, center.dy + stem * 0.15),
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + size.shortestSide * (3.5 / 18)),
      stroke * 0.7,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_WarningDiamondPainter oldDelegate) =>
      oldDelegate.color != color;
}
