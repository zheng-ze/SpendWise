import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_insights_mapping.dart';
import 'package:spendwise/ui/overview/overview_rows.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Tray

class WeekSoFarTray extends StatelessWidget {
  const WeekSoFarTray({
    super.key,
    required this.weekSoFar,
    required this.failed,
    required this.viewModel,
  });

  final OverviewWeekSoFar? weekSoFar;
  final bool failed;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final week = weekSoFar;
    final Widget content;
    if (failed) {
      content = OverviewLoadError(
        message: overviewWeekSoFarErrorTitle,
        onRetry: viewModel.retryReads,
      );
    } else if (week == null) {
      content = const LoadingSkeleton();
    } else {
      content = switch (week) {
        OverviewWeekHistoryNeeded() => const OverviewHistoryNeeded(
          body: overviewWeekHistoryNeededBody,
        ),
        OverviewWeekAvailable() => WeekSoFarContent(week: week),
      };
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(title: overviewWeekSoFarTitle, child: content),
    );
  }
}

// MARK: - Content

class WeekSoFarContent extends StatelessWidget {
  const WeekSoFarContent({super.key, required this.week});

  final OverviewWeekAvailable week;

  static const _rangeBottomGap = 6.0;
  static const _totalBottomGap = 6.0;
  static const _comparisonBottomGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final comparison = week.comparison;
    final range = OverviewEmptyCopy(week.range);
    final tone = week.totalTone;
    final totalStyle = tone == null
        ? context.text.small
        : context.text.small.copyWith(
            color: AmountStyle.of(context, kind: tone).color,
          );
    final total = Text(week.total, style: totalStyle);
    final comparisonText = comparison == null
        ? null
        : Text(
            comparison,
            style: context.text.body.copyWith(color: colors.subtext),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        range,
        const SizedBox(height: _rangeBottomGap),
        total,
        const SizedBox(height: _totalBottomGap),
        ?comparisonText,
        if (comparisonText != null)
          const SizedBox(height: _comparisonBottomGap),
        OverviewEmptyCopy(week.usualNote),
      ],
    );
  }
}
