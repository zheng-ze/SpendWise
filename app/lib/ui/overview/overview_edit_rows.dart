import 'package:flutter/material.dart';

import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _gripIcon = Icons.drag_indicator;

const _gripIconSize = 20.0;

const _gripTargetSize = 48.0;

const _gripTargetFill = Colors.transparent;

const _rowVerticalPadding = 8.0;

const _textGap = 2.0;

const _hintVerticalPadding = 12.0;

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

// MARK: - Hidden Hint

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
