import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_rows.dart';
import 'package:spendwise/ui/overview/overview_top_categories_mapping.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Tray

class TopCategoriesTray extends ConsumerWidget {
  const TopCategoriesTray({
    super.key,
    required this.topCategories,
    required this.failed,
    required this.viewModel,
  });

  final OverviewTopCategories? topCategories;
  final bool failed;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topCategories = this.topCategories;
    final chartColours = ref.watch(
      displayPreferencesProvider.select((value) => value.chartColours),
    );
    final Widget content;
    if (failed) {
      content = OverviewLoadError(
        message: overviewTopCategoriesErrorTitle,
        onRetry: viewModel.retryReads,
      );
    } else if (topCategories == null) {
      content = const LoadingSkeleton();
    } else {
      content = TopCategoriesContent(
        topCategories: topCategories,
        chartColours: chartColours,
        onOpenTrends: viewModel.requestTrends,
      );
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(title: overviewTopCategoriesTitle, child: content),
    );
  }
}

// MARK: - Content

class TopCategoriesContent extends StatelessWidget {
  const TopCategoriesContent({
    super.key,
    required this.topCategories,
    required this.chartColours,
    required this.onOpenTrends,
  });

  final OverviewTopCategories topCategories;
  final ChartColours chartColours;
  final VoidCallback onOpenTrends;

  @override
  Widget build(BuildContext context) {
    final rows = topCategories.rows;
    final caption = OverviewEmptyCopy(topCategories.caption);
    final body = rows.isEmpty
        ? const OverviewEmptyCopy(overviewTopCategoriesEmpty)
        : TopCategoriesRows(rows: rows, chartColours: chartColours);
    final link = OverviewLinkAction(
      label: overviewTopCategoriesTrendsLink,
      onPressed: onOpenTrends,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        caption,
        const SizedBox(height: overviewTopCategoryCaptionGap),
        body,
        link,
      ],
    );
  }
}

// MARK: - Rows

class TopCategoriesRows extends StatelessWidget {
  const TopCategoriesRows({
    super.key,
    required this.rows,
    required this.chartColours,
  });

  final List<OverviewTopCategoryRow> rows;
  final ChartColours chartColours;

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final (index, row) in rows.indexed)
        OverviewRowFrame(
          isLast: index == rows.length - 1,
          child: OverviewTopCategoryRowView(
            row: row,
            index: index,
            chartColours: chartColours,
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }
}

class OverviewTopCategoryRowView extends StatelessWidget {
  const OverviewTopCategoryRowView({
    super.key,
    required this.row,
    required this.index,
    required this.chartColours,
  });

  final OverviewTopCategoryRow row;
  final int index;
  final ChartColours chartColours;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final barColor = CategoryPalette.resolve(
      savedHex: row.savedHex,
      rank: index,
      mode: chartColours,
      colors: colors,
    );
    final icon = Icon(
      symbolIcon(row.symbolName),
      size: overviewTopCategoryIconSize,
      color: barColor,
    );
    final name = Expanded(child: Text(row.name, style: text.body));
    final amount = Padding(
      padding: const EdgeInsets.only(left: overviewRowTrailingGap),
      child: Text(row.amount, style: text.small),
    );
    final header = Row(
      children: [
        icon,
        const SizedBox(width: overviewTopCategoryIconGap),
        name,
        amount,
      ],
    );
    final bar = TopCategoryBar(ratio: row.barRatio, color: barColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: overviewTopCategoryBarTopGap),
        bar,
      ],
    );
  }
}

class TopCategoryBar extends StatelessWidget {
  const TopCategoryBar({super.key, required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(overviewTopCategoryBarRadius);
    final fill = DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: radius),
    );
    final track = DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.tint,
        borderRadius: radius,
      ),
    );
    final filled = FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: ratio,
      child: fill,
    );
    return SizedBox(
      height: overviewTopCategoryBarHeight,
      width: overviewFullWidth,
      child: Stack(fit: StackFit.expand, children: [track, filled]),
    );
  }
}
