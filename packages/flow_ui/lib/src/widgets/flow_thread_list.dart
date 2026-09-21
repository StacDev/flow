import 'package:material_ui/material_ui.dart';

import '../styles/flow_thread_list_style.dart';
import '../theme/flow_theme.dart';

/// One conversation in a [FlowThreadList].
///
/// A pure, immutable view model — hosts map their own thread summaries
/// into this, the way `FlowMessageData` carries a turn.
@immutable
class FlowThreadListItem {
  const FlowThreadListItem({
    required this.id,
    required this.title,
    this.icon,
    this.pinned = false,
    this.unread = false,
    this.tooltip,
    this.semanticLabel,
  });

  /// Reported through `onThreadSelected` and matched against
  /// `selectedId`; must be unique across the whole list (asserted in
  /// debug).
  final String id;

  /// Host-supplied, on one line — it ellipsizes rather than wrapping.
  final String title;

  /// Optional leading glyph, e.g. a project or agent mark; without one
  /// the row starts at the title.
  final IconData? icon;

  /// Draws the muted pin at the row's end. Grouping pinned threads into
  /// their own section is the host's move — the glyph only marks the row.
  final bool pinned;

  /// Draws the primary dot at the row's end and sets the title in the
  /// emphasised cut.
  final bool unread;

  /// Host-localized tooltip, e.g. the full text of a long title.
  final String? tooltip;

  /// What assistive tech announces for the row; null falls back to
  /// [title]. The pin and the dot are visual and excluded from
  /// semantics, so this is where a host says 'Trip planning, unread' in
  /// its own locale's word order — the package ships no strings.
  final String? semanticLabel;
}

/// A run of threads under one optional header in a [FlowThreadList].
@immutable
class FlowThreadListSection {
  const FlowThreadListSection({this.label, required this.items});

  /// Host-localized header — 'Pinned', 'Today'. Null renders the
  /// section's rows without one.
  final String? label;

  /// Rendered in order. An empty section takes no space, header
  /// included — no orphaned labels.
  final List<FlowThreadListItem> items;
}

/// The conversation history: sections of thread rows, one of them
/// selected — the list an assistant app hangs in its side panel.
///
/// ```dart
/// FlowThreadList(
///   sections: [
///     FlowThreadListSection(label: 'Pinned', items: pinned),
///     FlowThreadListSection(label: 'Today', items: today),
///   ],
///   selectedId: openThreadId,
///   onThreadSelected: openThread,
/// )
/// ```
///
/// Rows render passed-in state and report intent out, as everywhere in
/// the package: tapping a row hands [onThreadSelected] the thread's id,
/// and actually opening the conversation is the host's move. Section
/// labels, tooltips and semantic labels are host-localized — the package
/// ships no strings, and derives nothing (grouping by date, ordering,
/// pinning are all data the host passes in).
///
/// Lazy underneath, so a long history is cheap; needs a bounded height
/// (an [Expanded] in a column, or a sized parent). For a host panel that
/// scrolls on its own — nav above, a footer below — [shrinkWrap] swaps
/// to the embedded form: measured by content and non-scrolling.
class FlowThreadList extends StatefulWidget {
  const FlowThreadList({
    super.key,
    required this.sections,
    this.selectedId,
    this.onThreadSelected,
    this.controller,
    this.shrinkWrap = false,
    this.padding,
    this.itemSpacing,
    this.rowPadding,
    this.rowRadius,
    this.style,
  });

  /// Convenience for the ungrouped case: [items] as one label-less
  /// section.
  FlowThreadList.flat({
    Key? key,
    required List<FlowThreadListItem> items,
    String? selectedId,
    ValueChanged<String>? onThreadSelected,
    ScrollController? controller,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? itemSpacing,
    EdgeInsetsGeometry? rowPadding,
    BorderRadius? rowRadius,
    FlowThreadListStyle? style,
  }) : this(
         key: key,
         sections: [FlowThreadListSection(items: items)],
         selectedId: selectedId,
         onThreadSelected: onThreadSelected,
         controller: controller,
         shrinkWrap: shrinkWrap,
         padding: padding,
         itemSpacing: itemSpacing,
         rowPadding: rowPadding,
         rowRadius: rowRadius,
         style: style,
       );

  /// Rendered in order; thread ids must be unique across all sections.
  /// Empty sections — and an entirely empty list — take no space, so a
  /// host can pass whatever it has without guarding.
  final List<FlowThreadListSection> sections;

  /// The open conversation's id; that row draws the resting fill. Null —
  /// or an id no thread carries — selects nothing.
  final String? selectedId;

  /// Called with the tapped thread's id; opening the conversation is the
  /// host's move. Null renders the rows inert but *not* grayed: the
  /// titles are content worth reading either way, and the selection fill
  /// still shows — the attachment tiles' precedent, not a disabled
  /// control's.
  final ValueChanged<String>? onThreadSelected;

  /// Optional external scroll controller.
  final ScrollController? controller;

  /// The embedded form: measured by content and non-scrolling, for a
  /// host panel that scrolls on its own. The default form scrolls
  /// itself, lazily, and needs a bounded height.
  final bool shrinkWrap;

  /// Around the whole list; defaults to none — the host's panel owns its
  /// insets.
  final EdgeInsetsGeometry? padding;

  /// Gap between rows; defaults to the design's 2.
  final double? itemSpacing;

  /// Inside each row. Defaults to the design's 10 at the sides; section
  /// headers align to it.
  final EdgeInsetsGeometry? rowPadding;

  /// Each row's corner. Defaults to the design's 8.
  final BorderRadius? rowRadius;

  /// Per-instance restyling, merged over [FlowTheme.threadListStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowThreadListStyle? style;

  @override
  State<FlowThreadList> createState() => _FlowThreadListState();
}

/// The list's metrics — provisional, pending a Figma frame for the
/// thread list: the suggestion row's 36-tall, 8px-corner, 10-padded
/// frame, with the menu row's 18px glyph a 12 gap from the label.
const double _rowHeight = 36;
const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(8));
const EdgeInsetsGeometry _rowPadding = EdgeInsetsDirectional.symmetric(
  horizontal: 10,
);
const double _rowGap = 2;
const double _iconSize = 18;
const double _iconGap = 12;

/// The trailing cluster: 8 clears the title, 6 sits between the pin and
/// the dot.
const double _trailingGap = 8;
const double _pinDotGap = 6;
const double _pinSize = 14;
const double _dotSize = 6;

/// A section header stands 16 above its rows — none when it opens the
/// list — and 4 over them.
const double _sectionGapAbove = 16;
const double _sectionGapBelow = 4;

const String _duplicateIdMessage =
    'FlowThreadList: thread ids must be unique across the list — '
    'onThreadSelected and selectedId work with ids, not indices.';

bool _idsAreUnique(List<FlowThreadListSection> sections) {
  final seen = <String>{};
  for (final section in sections) {
    for (final item in section.items) {
      if (!seen.add(item.id)) return false;
    }
  }
  return true;
}

class _FlowThreadListState extends State<FlowThreadList> {
  @override
  void initState() {
    super.initState();
    assert(_idsAreUnique(widget.sections), _duplicateIdMessage);
  }

  @override
  void didUpdateWidget(FlowThreadList oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(_idsAreUnique(widget.sections), _duplicateIdMessage);
  }

  @override
  Widget build(BuildContext context) {
    // Flattened render order: headers and rows in one list, so laziness,
    // spacing and index math stay flat too. Skipping empty sections here
    // is what keeps their headers from orphaning.
    final entries = <_Entry>[];
    for (final section in widget.sections) {
      if (section.items.isEmpty) continue;
      final label = section.label;
      if (label != null) entries.add(_HeaderEntry(label));
      for (final item in section.items) {
        entries.add(_ItemEntry(item));
      }
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    final style =
        context.flowTheme.threadListStyle?.merge(widget.style) ?? widget.style;
    final gap = widget.itemSpacing ?? _rowGap;
    final rowPadding = widget.rowPadding ?? _rowPadding;
    // Headers keep their text in column with the rows' under a host's
    // padding override too, so the inset is the row padding's resolved
    // sides rather than the spec constant.
    final resolvedRowPadding = rowPadding.resolve(Directionality.of(context));
    final onThreadSelected = widget.onThreadSelected;

    return ListView.builder(
      controller: widget.controller,
      shrinkWrap: widget.shrinkWrap,
      // The embedded form is one coherent thing: measured by content and
      // not a scrolling region of its own — the host's panel scrolls.
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      // Resolved, never null: a null ListView padding silently absorbs
      // the MediaQuery's safe-area insets, and this list's edges belong
      // to the host's panel.
      padding: widget.padding ?? EdgeInsets.zero,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        switch (entries[index]) {
          case _HeaderEntry(:final label):
            return Padding(
              // Physical, not directional: the row padding is already
              // resolved above, and re-entering directional space would
              // apply the text direction a second time — mirroring the
              // header's insets against the rows' in RTL.
              padding: EdgeInsets.only(
                left: resolvedRowPadding.left,
                right: resolvedRowPadding.right,
                top: index == 0 ? 0 : _sectionGapAbove,
                bottom: _sectionGapBelow,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.flowTypography.labelSmall
                      .copyWith(color: context.flowColors.onSurfaceMuted)
                      .merge(style?.sectionLabelStyle),
                ),
              ),
            );
          case _ItemEntry(:final item):
            // A header's bottom gap already spaces its first row.
            final afterHeader =
                index == 0 || entries[index - 1] is _HeaderEntry;
            return Padding(
              key: ValueKey(item.id),
              padding: EdgeInsets.only(top: afterHeader ? 0 : gap),
              child: _ThreadRow(
                item: item,
                selected: item.id == widget.selectedId,
                onTap: onThreadSelected == null
                    ? null
                    : () => onThreadSelected(item.id),
                padding: rowPadding,
                radius: widget.rowRadius ?? _rowRadius,
                style: style,
              ),
            );
        }
      },
    );
  }
}

/// The flattened render order's entries — a section header or a thread.
sealed class _Entry {
  const _Entry();
}

class _HeaderEntry extends _Entry {
  const _HeaderEntry(this.label);

  final String label;
}

class _ItemEntry extends _Entry {
  const _ItemEntry(this.item);

  final FlowThreadListItem item;
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.padding,
    required this.radius,
    required this.style,
  });

  final FlowThreadListItem item;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final FlowThreadListStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;

    // The title is content, not a prompt: constant full ink, no hover
    // lift — the hover wash on the fill is the whole affordance. Unread
    // takes the emphasised cut beside its dot; a 6px disc alone is too
    // quiet a signal.
    final titleStyle =
        (item.unread
                ? typography.labelMediumEmphasised
                : typography.labelMedium)
            .copyWith(color: colors.onSurface)
            .merge(style?.titleStyle);

    final selectedColor = style?.selectedColor ?? colors.surfaceContainer;

    Widget row = Material(
      // The rest state is the selected wash at zero alpha, not
      // Colors.transparent — Material lerps color changes, and fading
      // toward transparent *black* drags the row through a smoky flash
      // on the way out.
      color: selected ? selectedColor : selectedColor.withValues(alpha: 0),
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        // Translucent over translucent: the hover wash composites over
        // the selected fill, so the pointed-at row always answers.
        hoverColor: style?.hoverColor ?? colors.surfaceContainerLow,
        child: Padding(
          padding: padding,
          child: SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: _iconSize,
                    color: style?.iconColor ?? colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: _iconGap),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                if (item.pinned) ...[
                  const SizedBox(width: _trailingGap),
                  Icon(
                    Icons.push_pin_outlined,
                    size: _pinSize,
                    color: style?.pinColor ?? colors.onSurfaceMuted,
                  ),
                ],
                if (item.unread) ...[
                  SizedBox(width: item.pinned ? _pinDotGap : _trailingGap),
                  SizedBox.square(
                    dimension: _dotSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: style?.unreadDotColor ?? colors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Excluding the subtree keeps the title from reading twice and
    // silences the pin and dot — [FlowThreadListItem.semanticLabel] is
    // where their meaning reaches assistive tech — but it drops the
    // InkWell's tap action with it, so the node re-owns activation.
    // Selection announces through the platform's own wording.
    row = Semantics(
      button: onTap != null,
      selected: selected,
      label: item.semanticLabel ?? item.title,
      excludeSemantics: true,
      onTap: onTap,
      child: row,
    );

    final tooltip = item.tooltip;
    if (tooltip != null) {
      row = Tooltip(message: tooltip, child: row);
    }
    return row;
  }
}
