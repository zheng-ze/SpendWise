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

class InsightsTray extends StatelessWidget {
  const InsightsTray({
    super.key,
    required this.insights,
    required this.failed,
    required this.viewModel,
  });

  final OverviewInsights? insights;
  final bool failed;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final insights = this.insights;
    final Widget content;
    if (failed) {
      content = OverviewLoadError(
        message: overviewInsightsErrorTitle,
        onRetry: viewModel.retryReads,
      );
    } else if (insights == null) {
      content = const LoadingSkeleton();
    } else {
      content = switch (insights) {
        OverviewInsightsHistoryNeeded() => const OverviewHistoryNeeded(
          body: overviewInsightsHistoryNeededBody,
        ),
        OverviewInsightsAvailable(:final rows) => InsightRows(rows: rows),
      };
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(title: overviewInsightsTitle, child: content),
    );
  }
}

// MARK: - Rows

class InsightRows extends StatelessWidget {
  const InsightRows({super.key, required this.rows});

  final List<OverviewInsightRow> rows;

  @override
  Widget build(BuildContext context) {
    final frames = [
      for (final (index, row) in rows.indexed)
        OverviewRowFrame(
          isLast: index == rows.length - 1,
          child: InsightRow(row: row),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: frames,
    );
  }
}

class InsightRow extends StatelessWidget {
  const InsightRow({super.key, required this.row});

  final OverviewInsightRow row;

  @override
  Widget build(BuildContext context) {
    final amountColor = AmountStyle.of(context, kind: row.amountKind).color;
    final amount = TextSpan(
      text: row.amount,
      style: TextStyle(color: amountColor),
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: row.lead),
          amount,
          TextSpan(text: row.tail),
        ],
      ),
      style: context.text.body,
    );
  }
}
