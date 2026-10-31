import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/charts/month_bar_chart.dart';
import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _semiBold = FontWeight.w600;
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

  @override
  Widget build(BuildContext context) {
    final columns = [
      for (final bar in bars)
        MonthBarColumn(
          slot: MonthBarSlot(value: bar.value),
          label: bar.label,
          semanticLabel: bar.semanticLabel,
        ),
    ];
    return MonthBarChart(
      columns: columns,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
    );
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
