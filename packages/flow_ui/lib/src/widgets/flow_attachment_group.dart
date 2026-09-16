import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

import '../models/flow_attachment.dart';
import '../theme/flow_theme.dart';
import '../theme/flow_typography.dart';
import '../utils/flow_attachment_error.dart';
import '../utils/flow_circle_button.dart';
import 'flow_attachment_preview.dart';

/// How a [FlowAttachmentGroup] arranges its tiles.
enum FlowAttachmentLayout {
  /// One row that scrolls horizontally, without a scrollbar. Keeps a long
  /// set to a single line — the usual treatment inside a composer.
  scroll,

  /// Wraps onto as many lines as needed; nothing scrolls. The right choice
  /// wherever content must not be hidden, such as a sent message.
  wrap,
}

/// A group of attachment tiles, each optionally removable:
///
/// ```dart
/// FlowAttachmentGroup(
///   attachments: [
///     FlowAttachment(id: 'a', thumbnail: FileImage(picked), kind: 'JPG'),
///     FlowAttachment(id: 'b', kind: 'PDF', label: 'contract.pdf'),
///   ],
///   onRemove: (id) => detach(id),
///   removeTooltip: 'Remove attachment',
/// )
/// ```
///
/// A tile draws its attachment's thumbnail when it has one and a bare ground
/// when it doesn't, with `FlowAttachment.kind` — 'PDF', 'JPG' — in a pill in
/// the bottom corner.
///
/// Callbacks report the attachment's own id, never an index, so the ids in
/// [attachments] must be unique within the group — asserted in debug. A null
/// [onRemove] renders the tiles without a remove button, and an empty
/// [attachments] list takes no space, so a host can pass whatever it has
/// without guarding.
///
/// Tapping a tile opens a [FlowAttachmentPreview] over the whole group,
/// starting on the tapped image; an attachment with no image at all is inert.
/// Passing [onTap] replaces that entirely — call [showFlowAttachmentPreview]
/// from the handler to keep it.
class FlowAttachmentGroup extends StatefulWidget {
  const FlowAttachmentGroup({
    super.key,
    required this.attachments,
    this.onTap,
    this.onRemove,
    this.removeTooltip,
    this.previewCloseTooltip,
    this.layout = FlowAttachmentLayout.scroll,
    this.size,
    this.tileRadius,
    this.spacing,
    this.padding,
  }) : assert(size == null || size > 0, 'size must be positive');

  /// Rendered in order; ids must be unique within the list.
  final List<FlowAttachment> attachments;

  /// Called with the tapped attachment's id, *instead of* opening the
  /// built-in preview.
  final ValueChanged<String>? onTap;

  /// Called with the id of the attachment whose remove button was tapped.
  /// Null renders the tiles without a remove button.
  final ValueChanged<String>? onRemove;

  /// Host-localized label for the remove button, e.g. 'Remove attachment'.
  final String? removeTooltip;

  /// Host-localized label for the preview's close button; defaults to the
  /// framework's own.
  final String? previewCloseTooltip;

  final FlowAttachmentLayout layout;

  /// Edge length of each square tile. Defaults to the design's 80 — 64 on
  /// phones, resolved from the theme's platform so hosts and tests can
  /// steer it without a device.
  final double? size;

  /// Corner radius of each tile. Defaults to the design's 16 — 12 on
  /// phones, alongside [size].
  final BorderRadius? tileRadius;

  /// Gap between tiles, and between lines when wrapping. Defaults to the
  /// design's 8.
  final double? spacing;

  /// Around the whole group; defaults to none. In the scrolling layout it
  /// scrolls with the tiles, so the first and last clear the edge.
  final EdgeInsetsGeometry? padding;

  @override
  State<FlowAttachmentGroup> createState() => _FlowAttachmentGroupState();
}

class _FlowAttachmentGroupState extends State<FlowAttachmentGroup> {
  /// Whether the user is currently driving the UI with a device that can
  /// hover. The framework already tracks this and *revises* it — a hybrid
  /// laptop flips back to touch the moment a finger is used — which a latch
  /// set by the first mouse enter cannot do: it would leave the remove
  /// button invisible and, behind [IgnorePointer], untappable for the rest
  /// of the session. The platform is the wrong signal for the same reason.
  late bool _hoverCapable;

  @override
  void initState() {
    super.initState();
    assert(_idsAreUnique(widget.attachments), _duplicateIdMessage);
    _hoverCapable = _hoverCapableNow;
    FocusManager.instance.addHighlightModeListener(_handleHighlightModeChange);
  }

  @override
  void didUpdateWidget(FlowAttachmentGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(_idsAreUnique(widget.attachments), _duplicateIdMessage);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(
      _handleHighlightModeChange,
    );
    super.dispose();
  }

  bool get _hoverCapableNow =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _handleHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted) return;
    final value = mode == FocusHighlightMode.traditional;
    if (_hoverCapable != value) setState(() => _hoverCapable = value);
  }

  /// The host's handler if it has one, otherwise the built-in preview.
  ///
  /// Takes the index rather than the id: an id lookup would land on the
  /// first match, so a group holding two tiles with the same id would open
  /// on the wrong one.
  void _handleTap(int index) {
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap(widget.attachments[index].id);
      return;
    }
    showFlowAttachmentPreview(
      context: context,
      attachments: widget.attachments,
      initialIndex: index,
      closeTooltip: widget.previewCloseTooltip,
    );
  }

  Widget _tile(int index) {
    final attachment = widget.attachments[index];
    final onRemove = widget.onRemove;
    // The phone tile is a step smaller and tighter, per the design; the
    // theme's platform rather than the real one, like the menus' sheet
    // resolution.
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    // Without a host handler the tap opens the built-in preview, which needs
    // something to show — so an attachment with no image of its own, like a
    // document, is inert rather than opening an empty viewer.
    final tappable = widget.onTap != null || attachment.previewImage != null;
    return _AttachmentTile(
      // Keyed by id so removing one from the middle unmounts that tile
      // instead of shifting every later tile's hover/focus state — and its
      // image stream — onto its neighbour.
      key: ValueKey(attachment.id),
      attachment: attachment,
      size: widget.size ?? (mobile ? _mobileTileSize : _tileSize),
      radius: widget.tileRadius ?? (mobile ? _mobileTileRadius : _tileRadius),
      removeTooltip: widget.removeTooltip,
      alwaysShowRemove: !_hoverCapable,
      onTap: tappable ? () => _handleTap(index) : null,
      onRemove: onRemove == null ? null : () => onRemove(attachment.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();

    final gap = widget.spacing ?? _defaultGap;
    final padding = widget.padding;
    final tiles = [
      for (var i = 0; i < widget.attachments.length; i++) _tile(i),
    ];

    switch (widget.layout) {
      case FlowAttachmentLayout.scroll:
        return ScrollConfiguration(
          // No scrollbar over the tiles, and draggable with a mouse so the
          // row works on desktop without a horizontal wheel.
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: PointerDeviceKind.values.toSet(),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: tiles,
            ),
          ),
        );
      case FlowAttachmentLayout.wrap:
        final wrap = Wrap(spacing: gap, runSpacing: gap, children: tiles);
        return padding == null ? wrap : Padding(padding: padding, child: wrap);
    }
  }
}

const String _duplicateIdMessage =
    'FlowAttachmentGroup: attachment ids must be unique within a group — '
    'onTap and onRemove report ids, not indices.';

bool _idsAreUnique(List<FlowAttachment> attachments) =>
    attachments.map((a) => a.id).toSet().length == attachments.length;

/// The reveal is short enough to feel like part of the hover itself.
const Duration _revealDuration = Duration(milliseconds: 120);

/// The design's tile: 80 on 16px corners — 64 on 12 on phones — an 8px gap
/// between tiles, the remove disc inset 4 from its corner, and the type
/// pill inset 8 from its own.
const double _tileSize = 80;
const double _mobileTileSize = 64;
const BorderRadius _tileRadius = BorderRadius.all(Radius.circular(16));
const BorderRadius _mobileTileRadius = BorderRadius.all(Radius.circular(12));
const double _defaultGap = 8;
const double _removeInset = 4;

/// Inside the remove disc — the same 4 as its inset today, but a separate
/// decision: retuning the disc's position must not resize it.
const double _removeDiscPadding = 4;
const double _pillInset = 8;
const BorderRadius _pillRadius = BorderRadius.all(Radius.circular(6));
const EdgeInsetsGeometry _pillPadding = EdgeInsets.symmetric(
  horizontal: 4,
  vertical: 1,
);

/// The ambient lift under a tile: the theme's shadow ink, wide and offsetless.
const double _shadowBlur = 24;

/// The type pill's frosting, over whatever the thumbnail puts behind it.
const double _pillBlur = 2;

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({
    super.key,
    required this.attachment,
    required this.size,
    required this.radius,
    required this.alwaysShowRemove,
    this.removeTooltip,
    this.onTap,
    this.onRemove,
  });

  final FlowAttachment attachment;
  final double size;
  final BorderRadius radius;

  /// Set on touch, where there is no hover to reveal the button.
  final bool alwaysShowRemove;

  final String? removeTooltip;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _hovered = false;
  bool _removeFocused = false;

  @override
  void didUpdateWidget(_AttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The button is unmounted outright when onRemove goes away, and Focus
    // drops its listener before detaching, so its onFocusChange(false) never
    // arrives — without this the reveal would stick on forever.
    if (widget.onRemove == null && (_removeFocused || _hovered)) {
      _removeFocused = false;
      _hovered = false;
    }
  }

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  void _setRemoveFocused(bool value) {
    if (_removeFocused != value) setState(() => _removeFocused = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final attachment = widget.attachment;
    final tooltip = attachment.tooltip ?? attachment.label;

    final thumbnail = attachment.thumbnail;
    final kind = attachment.kind;
    final onRemove = widget.onRemove;

    final shape = RoundedRectangleBorder(
      borderRadius: widget.radius,
      side: BorderSide(color: colors.outlineVariant),
    );

    // Decode at tile resolution — a full-size photo behind an 80dp tile costs
    // orders of magnitude more memory than it can ever show.
    final cachePixels = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .round();

    Widget tile = Material(
      // Deeper behind a photo: the wash reads as the image's edge while
      // it decodes, and as the tile itself without one.
      color: thumbnail == null
          ? colors.surfaceContainerLow
          : colors.surfaceContainerHigh,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        customBorder: shape,
        // Nothing to draw over the ground when the attachment has no image of
        // its own — the pill carries what a document tile says.
        child: thumbnail == null
            ? null
            : Image(
                // Unless the host already bounded it: ResizeImage asserts
                // rather than nesting, and a second cap here would turn
                // a perfectly good provider into the failure glyph.
                image: thumbnail is ResizeImage
                    ? thumbnail
                    : ResizeImage.resizeIfNeeded(cachePixels, null, thumbnail),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                // A dead provider must not paint the framework's red error box.
                errorBuilder: flowAttachmentErrorBuilder(),
              ),
      ),
    );

    // A button, not an image, whenever it is tappable: announcing an
    // actionable tile as an image leaves the preview unreachable. The name
    // comes from the tooltip, which already contributes it to the node — a
    // Semantics label here would only announce it twice.
    tile = Semantics(
      button: widget.onTap != null,
      image: widget.onTap == null && thumbnail != null,
      child: tile,
    );
    if (tooltip != null) {
      tile = Tooltip(message: tooltip, child: tile);
    }

    final showRemove = widget.alwaysShowRemove || _hovered || _removeFocused;

    Widget result = DecoratedBox(
      // Outside the Material, which clips its own contents away.
      decoration: BoxDecoration(
        borderRadius: widget.radius,
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: _shadowBlur)],
      ),
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            tile,
            if (kind != null)
              PositionedDirectional(
                bottom: _pillInset,
                start: _pillInset,
                child: _TypePill(kind: kind),
              ),
            if (onRemove != null)
              PositionedDirectional(
                top: _removeInset,
                end: _removeInset,
                // Opacity alone still hit-tests and still takes focus, so a
                // faded-out button would quietly eat corner taps.
                child: IgnorePointer(
                  ignoring: !showRemove,
                  child: AnimatedOpacity(
                    opacity: showRemove ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : _revealDuration,
                    child: FlowCircleButton(
                      icon: Icons.close,
                      // The type pill's dress: 75% ink over host pixels the
                      // package can't see, the glyph cut from the card
                      // surface.
                      background: colors.onSurfaceVariant,
                      foreground: colors.surfaceBright,
                      iconSize: 16,
                      padding: _removeDiscPadding,
                      tooltip: widget.removeTooltip,
                      onTap: onRemove,
                      onFocusChange: _setRemoveFocused,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onRemove == null) {
      // No hover plumbing on a read-only tile — which is every attachment in
      // every sent message — since nothing would read the result.
      return result;
    }

    return MouseRegion(
      // Hover comes from here, not from InkWell.onHover: an InkWell only
      // reports hover while it has a tap callback, and these tiles very
      // often have none.
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: result,
    );
  }
}

/// The file-type chip in a tile's bottom corner — 'PDF', 'JPG'.
class _TypePill extends StatelessWidget {
  const _TypePill({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;

    return ExcludeSemantics(
      // The tile is already named after the file, which says the same thing:
      // announcing 'PDF' after 'contract.pdf' is noise.
      child: ClipRRect(
        borderRadius: _pillRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _pillBlur, sigmaY: _pillBlur),
          child: ColoredBox(
            // The design's dark chip: the 75% ink over host pixels the
            // package can't see, its label cut from the card surface.
            color: colors.onSurfaceVariant,
            child: Padding(
              padding: _pillPadding,
              // Chrome over the tile, not content: never part of a
              // selection sweeping the message.
              child: SelectionContainer.disabled(
                child: Text(
                  kind,
                  style: FlowTypography.recut(
                    context.flowTypography.labelSmall,
                    fontWeight: FontWeight.w600,
                  ).copyWith(color: colors.surfaceBright),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
