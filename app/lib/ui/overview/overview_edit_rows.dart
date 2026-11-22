import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _gripIcon = Icons.drag_indicator;

const _gripSize = 20.0;

const _rowVerticalPadding = 8.0;

const _rowGap = 10.0;

const _textGap = 2.0;

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

// MARK: - Shown Row

class ShownRow extends StatelessWidget {
  const ShownRow({
    super.key,
    required this.index,
    required this.card,
    required this.onHide,
  });

  final int index;
  final OverviewCard card;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final grip = ReorderableDragStartListener(
      index: index,
      child: Icon(_gripIcon, size: _gripSize, color: context.colors.subtext),
    );
    final text = _CardText(title: card.title, detail: card.subtitle);
    final hide = SecondaryButton(label: overviewEditHide, onPressed: onHide);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
      child: Row(
        children: [
          grip,
          const SizedBox(width: _rowGap),
          Expanded(child: text),
          hide,
        ],
      ),
    );
  }
}

// MARK: - Addable Row

class AddableRow extends StatelessWidget {
  const AddableRow({super.key, required this.card, required this.onAdd});

  final OverviewCard card;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = _CardText(title: card.title, detail: card.subtitle);
    final add = SecondaryButton(label: overviewEditAdd, onPressed: onAdd);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
      child: Row(
        children: [
          Expanded(child: text),
          add,
        ],
      ),
    );
  }
}

// MARK: - Catalogue Row

class CatalogueRow extends StatelessWidget {
  const CatalogueRow({
    super.key,
    required this.card,
    required this.added,
    required this.onAdd,
  });

  final OverviewCard card;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = _CardText(title: card.title, detail: card.question);
    final addedCaption = Text(
      overviewEditAdded,
      style: context.text.caption.copyWith(color: context.colors.subtext),
    );
    final add = SecondaryButton(label: overviewEditAdd, onPressed: onAdd);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
      child: Row(
        children: [
          Expanded(child: text),
          added ? addedCaption : add,
        ],
      ),
    );
  }
}
