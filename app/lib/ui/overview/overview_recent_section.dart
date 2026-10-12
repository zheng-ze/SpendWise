import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/lists/medallion_row.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_rows.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Tray

class RecentTray extends StatelessWidget {
  const RecentTray({super.key, required this.rows, required this.viewModel});

  final List<OverviewEntryRow>? rows;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    final Widget entries;
    if (rows == null) {
      entries = const LoadingSkeleton();
    } else if (rows.isEmpty) {
      entries = const OverviewEmptyCopy(overviewRecentEmpty);
    } else {
      entries = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, row) in rows.indexed)
            OverviewRowFrame(
              isLast: index == rows.length - 1,
              child: RecentEntryRowContent(row: row),
            ),
        ],
      );
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(
        title: overviewRecentTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            entries,
            HistoryAction(onPressed: viewModel.requestHistory),
          ],
        ),
      ),
    );
  }
}

// MARK: - History Action

class HistoryAction extends StatelessWidget {
  const HistoryAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const _chevronGap = 4.0;
  static const _minWidth = 48.0;
  static const _minHeight = 48.0;
  static const _padding = EdgeInsets.zero;
  static const _alignment = Alignment.centerLeft;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.action;
    return Padding(
      padding: const EdgeInsets.only(top: overviewLinkTopPadding),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(_minWidth, _minHeight),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: _padding,
          alignment: _alignment,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              overviewHistoryLink,
              style: TextStyle(
                fontSize: overviewBodyFontSize,
                fontWeight: overviewSemiBold,
              ),
            ),
            SizedBox(width: _chevronGap),
            Icon(overviewLinkChevron, size: overviewLinkIconSize),
          ],
        ),
      ),
    );
  }
}

// MARK: - Row Content

class RecentEntryRowContent extends StatelessWidget {
  const RecentEntryRowContent({super.key, required this.row});

  final OverviewEntryRow row;

  @override
  Widget build(BuildContext context) {
    return MedallionRow(
      icon: symbolIcon(row.symbolName),
      iconColor: row.color,
      title: row.title,
      subtitle: row.caption,
      trailing: OverviewAmountText(amount: row.amount, kind: row.amountKind),
    );
  }
}
