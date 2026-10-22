import 'package:flutter/material.dart';

import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_whole_period.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _headingText = 'Insights';
const _headingSize = 14.0;
const _titleSize = 10.0;
const _valueSize = 12.0;
const _semiBold = FontWeight.w600;
const _sectionGap = 12.0;
const _headingGap = 8.0;
const _titleGap = 2.0;
const _rowGap = 8.0;

class TrendsInsightsCard extends StatelessWidget {
  const TrendsInsightsCard({super.key, required this.insights});

  final TrendsInsights insights;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const heading = Text(
      _headingText,
      style: TextStyle(fontSize: _headingSize, fontWeight: _semiBold),
    );
    final emptyMessage = insights.emptyMessage;
    final empty = emptyMessage == null
        ? null
        : Text(
            emptyMessage,
            style: TextStyle(fontSize: _valueSize, color: colors.subtext),
          );
    final observations = [
      for (final insight in insights.observations)
        _InsightRow(insight: insight),
    ];
    final card = TrendsCard(
      children: [
        heading,
        const SizedBox(height: _headingGap),
        ...observations,
        ?empty,
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: _sectionGap),
      child: card,
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final TrendsInsight insight;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      insight.title,
      style: TextStyle(fontSize: _titleSize, color: context.colors.subtext),
    );
    final value = Text(
      insight.value,
      style: const TextStyle(fontSize: _valueSize, fontWeight: _semiBold),
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: _titleGap),
        value,
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: _rowGap),
      child: column,
    );
  }
}
