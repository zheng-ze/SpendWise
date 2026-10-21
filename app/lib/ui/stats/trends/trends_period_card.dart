import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _semiBold = FontWeight.w600;
const _bold = FontWeight.w700;
const _captionFontSize = 10.0;
const _labelFontSize = 12.0;

// MARK: - Card
class TrendsCard extends StatelessWidget {
  const TrendsCard({super.key, required this.children});

  final List<Widget> children;

  static const _radius = 14.0;
  static const _padding = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (Theme.of(context).brightness != Brightness.light) return column;
    final decoration = BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.edge),
      borderRadius: BorderRadius.circular(_radius),
    );
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(_padding),
      child: column,
    );
  }
}

// MARK: - Chart
class TrendsChart extends StatelessWidget {
  const TrendsChart({
    super.key,
    required this.bars,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<TrendsBar> bars;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _topMargin = 10.0;
  static const _baselineWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final slots = [for (final bar in bars) MonthBarSlot(value: bar.value)];
    final chart = MonthBars(
      slots: slots,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
    );
    final baseline = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.control, width: _baselineWidth),
        ),
      ),
      child: chart,
    );
    return Padding(
      padding: const EdgeInsets.only(top: _topMargin),
      child: Column(
        children: [
          baseline,
          _TrendsAxis(
            bars: bars,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

// MARK: - Axis
class _TrendsAxis extends StatelessWidget {
  const _TrendsAxis({
    required this.bars,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<TrendsBar> bars;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _cellHeight = 28.0;
  static const _monthFontSize = 10.0;
  static const _yearFontSize = 12.0;
  static const _yearLabelLength = 4;

  @override
  Widget build(BuildContext context) {
    final cells = [
      for (var i = 0; i < bars.length; i++)
        Expanded(
          child: _AxisCell(
            bar: bars[i],
            selected: i == selectedIndex,
            fontSize: bars[i].label.length == _yearLabelLength
                ? _yearFontSize
                : _monthFontSize,
            height: _cellHeight,
            onTap: () => onSelect(i),
          ),
        ),
    ];
    return Row(children: cells);
  }
}

// MARK: - AxisCell
class _AxisCell extends StatelessWidget {
  const _AxisCell({
    required this.bar,
    required this.selected,
    required this.fontSize,
    required this.height,
    required this.onTap,
  });

  final TrendsBar bar;
  final bool selected;
  final double fontSize;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    final selectedColor = light ? colors.action : colors.text;
    final label = Text(
      bar.label,
      style: TextStyle(
        fontSize: fontSize,
        color: selected ? selectedColor : colors.subtext,
        fontWeight: selected ? _bold : null,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: bar.semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Align(alignment: Alignment.topCenter, child: label),
        ),
      ),
    );
  }
}

// MARK: - Headline
class TrendsHeadlineView extends StatelessWidget {
  const TrendsHeadlineView({super.key, required this.headline});

  final TrendsHeadline headline;

  static const _topMargin = 12.0;
  static const _amountFontSize = 24.0;
  static const _trailingGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = Text(
      headline.title,
      style: const TextStyle(fontSize: _labelFontSize, fontWeight: _semiBold),
    );
    final sublabel = Text(
      headline.sublabel,
      style: TextStyle(fontSize: _captionFontSize, color: colors.subtext),
    );
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, sublabel],
    );
    final amount = headline.amount;
    final message = headline.emptyMessage;
    final trailing = amount != null
        ? Text(
            amount,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.text.headline.copyWith(
              fontSize: _amountFontSize,
              color: AmountStyle.of(context, kind: headline.amountKind).color,
            ),
          )
        : Text(
            message ?? '',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: _labelFontSize, color: colors.subtext),
          );
    return Padding(
      padding: const EdgeInsets.only(top: _topMargin),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          label,
          const SizedBox(width: _trailingGap),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}

// MARK: - Usual
class TrendsUsualView extends StatelessWidget {
  const TrendsUsualView({super.key, required this.usual});

  final TrendsUsual usual;

  static const _topMargin = 6.0;
  static const _verticalPadding = 6.0;
  static const _bodyGap = 2.0;
  static const _ruleWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rule = BorderSide(color: colors.edge, width: _ruleWidth);
    final title = Text(
      usual.title,
      style: const TextStyle(fontSize: _labelFontSize, fontWeight: _semiBold),
    );
    final body = Text(
      usual.body,
      style: TextStyle(fontSize: _captionFontSize, color: colors.subtext),
    );
    return Container(
      margin: const EdgeInsets.only(top: _topMargin),
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: _bodyGap),
          body,
        ],
      ),
    );
  }
}
