import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/section_label.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/theme/edge_border.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _gripIcon = Icons.drag_indicator;

const _gripIconSize = 20.0;

const _gripTargetSize = 48.0;

const _gripTargetFill = Colors.transparent;

const _rowVerticalPadding = 8.0;

const _textGap = 2.0;

const _hintVerticalPadding = 12.0;

const _headingVerticalPadding = 8.0;

const _sectionHorizontalPadding = Tray.contentPadding;

const _openEdgeOvershoot = Tray.cornerRadius * 2;

const _halfFactor = 0.5;

const _noRadius = Radius.zero;

const _cornerRadius = Radius.circular(Tray.cornerRadius);

// MARK: - Row Text

class _CardText extends StatelessWidget {
  const _CardText({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.text.body.copyWith(
      color: context.colors.text,
      fontWeight: SpendWiseText.semibold,
    );
    final detailStyle = context.text.caption.copyWith(
      color: context.colors.subtext,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: _textGap),
        Text(detail, style: detailStyle),
      ],
    );
  }
}

// MARK: - Overview Edit Row

class OverviewEditRow extends StatelessWidget {
  const OverviewEditRow({super.key, required this.index, required this.card});

  final int index;
  final OverviewCard card;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      _gripIcon,
      size: _gripIconSize,
      color: context.colors.subtext,
    );
    final gripTarget = SizedBox.square(
      dimension: _gripTargetSize,
      child: ColoredBox(
        color: _gripTargetFill,
        child: Center(child: icon),
      ),
    );
    final grip = ReorderableDragStartListener(index: index, child: gripTarget);
    final text = _CardText(title: card.title, detail: card.subtitle);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
      child: Row(
        children: [
          grip,
          Expanded(child: text),
        ],
      ),
    );
  }
}

// MARK: - Hint

class OverviewEditHiddenHint extends StatelessWidget {
  const OverviewEditHiddenHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = context.text.caption.copyWith(color: context.colors.subtext);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _hintVerticalPadding),
      child: Text(text, style: style),
    );
  }
}

// MARK: - Section Heading

class OverviewEditHeading extends StatelessWidget {
  const OverviewEditHeading({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SectionLabel(
      text,
      padding: const EdgeInsets.symmetric(vertical: _headingVerticalPadding),
    );
  }
}

// MARK: - Section Item

enum OverviewEditSlot { first, middle, last }

class OverviewEditSectionItem extends StatelessWidget {
  const OverviewEditSectionItem({
    super.key,
    required this.slot,
    required this.child,
  });

  final OverviewEditSlot slot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decoration = ShapeDecoration(
      color: Tray.fillColor(context),
      shape: _SectionShape(slot: slot, side: edgeSide(context.colors)),
    );
    return DecoratedBox(
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _sectionHorizontalPadding,
        ),
        child: child,
      ),
    );
  }
}

class _SectionShape extends ShapeBorder {
  const _SectionShape({required this.slot, required this.side});

  final OverviewEditSlot slot;
  final BorderSide side;

  BorderRadius get _radius => switch (slot) {
    OverviewEditSlot.first => const BorderRadius.vertical(top: _cornerRadius),
    OverviewEditSlot.middle => const BorderRadius.vertical(
      top: _noRadius,
      bottom: _noRadius,
    ),
    OverviewEditSlot.last => const BorderRadius.vertical(bottom: _cornerRadius),
  };

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_radius.toRRect(rect));

  // The outline is drawn on a rect that overshoots the open edges and clipped
  // to this item, so stacked items join into one continuous border.
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final openTop = slot != OverviewEditSlot.first;
    final openBottom = slot != OverviewEditSlot.last;
    final inset = side.width * _halfFactor;
    final outline = Rect.fromLTRB(
      rect.left + inset,
      rect.top + (openTop ? -_openEdgeOvershoot : inset),
      rect.right - inset,
      rect.bottom + (openBottom ? _openEdgeOvershoot : -inset),
    );
    final rounded = RRect.fromRectAndRadius(outline, _cornerRadius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width
      ..color = side.color;
    canvas
      ..save()
      ..clipRect(rect)
      ..drawRRect(rounded, paint)
      ..restore();
  }

  @override
  ShapeBorder scale(double t) => this;
}
