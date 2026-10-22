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

  @override
  Widget build(BuildContext context) {
    final cells = [
      for (var i = 0; i < bars.length; i++)
        _AxisCell(
          bar: bars[i],
          index: i,
          selected: i == selectedIndex,
          onSelect: onSelect,
        ),
    ];
    return Row(children: cells);
  }
}

// MARK: - AxisCell
class _AxisCell extends StatelessWidget {
  const _AxisCell({
    required this.bar,
    required this.index,
    required this.selected,
    required this.onSelect,
  });

  final TrendsBar bar;
  final int index;
  final bool selected;
  final ValueChanged<int> onSelect;

  static const _height = 28.0;
  static const _labelTopPadding = 4.0;
  static const _monthFontSize = 10.0;
  static const _yearFontSize = 12.0;
  static const _yearLabelLength = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    final selectedColor = light ? colors.action : colors.text;
    final isYear = bar.label.length == _yearLabelLength;
    final label = Text(
      bar.label,
      style: TextStyle(
        fontSize: isYear ? _yearFontSize : _monthFontSize,
        color: selected ? selectedColor : colors.subtext,
        fontWeight: selected ? _bold : null,
      ),
    );
    final aligned = Padding(
      padding: const EdgeInsets.only(top: _labelTopPadding),
      child: Align(alignment: Alignment.topCenter, child: label),
    );
    final surface = InkWell(
      onTap: () => onSelect(index),
      child: SizedBox(height: _height, child: aligned),
    );
    final cell = Semantics(
      button: true,
      selected: selected,
      label: bar.semanticLabel,
      excludeSemantics: true,
      onTap: () => onSelect(index),
      child: surface,
    );
    return Expanded(child: cell);
  }
}

// MARK: - Headline
class TrendsHeadlineView extends StatelessWidget {
  const TrendsHeadlineView({super.key, required this.headline});

  final TrendsHeadline headline;

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
    return LayoutBuilder(
      builder: (context, constraints) => _HeadlineWrap(
        label: label,
        headline: headline,
        maxWidth: constraints.maxWidth,
      ),
    );
  }
}

// MARK: - HeadlineWrap
class _HeadlineWrap extends StatelessWidget {
  const _HeadlineWrap({
    required this.label,
    required this.headline,
    required this.maxWidth,
  });

  final Widget label;
  final TrendsHeadline headline;
  final double maxWidth;

  static const _runSpacing = 4.0;

  @override
  Widget build(BuildContext context) {
    final trailing = _HeadlineTrailing(headline: headline, maxWidth: maxWidth);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: _runSpacing,
      children: [label, trailing],
    );
  }
}

// MARK: - HeadlineTrailing
class _HeadlineTrailing extends StatelessWidget {
  const _HeadlineTrailing({required this.headline, required this.maxWidth});

  final TrendsHeadline headline;
  final double maxWidth;

  static const _amountFontSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = headline.amount;
    final text = amount != null
        ? Text(
            amount,
            maxLines: 1,
            softWrap: false,
            style: context.text.headline.copyWith(
              fontSize: _amountFontSize,
              color: AmountStyle.of(context, kind: headline.amountKind).color,
            ),
          )
        : Text(
            headline.emptyMessage ?? '',
            style: TextStyle(fontSize: _labelFontSize, color: colors.subtext),
          );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(fit: BoxFit.scaleDown, child: text),
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
