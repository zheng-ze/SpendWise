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

class ComingUpTray extends StatelessWidget {
  const ComingUpTray({super.key, required this.rows});

  final List<OverviewUpcomingRow>? rows;

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    final Widget content;
    if (rows == null) {
      content = const LoadingSkeleton();
    } else if (rows.isEmpty) {
      content = const OverviewEmptyCopy(overviewComingUpEmpty);
    } else {
      content = Column(
        children: [
          for (final (index, row) in rows.indexed)
            OverviewRowFrame(
              isLast: index == rows.length - 1,
              child: UpcomingRowContent(row: row),
            ),
        ],
      );
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(
        title: overviewComingUpTitle,
        trailing: const OverviewEmptyCopy(overviewComingUpWindow),
        child: content,
      ),
    );
  }
}

// MARK: - Row Content

class UpcomingRowContent extends StatelessWidget {
  const UpcomingRowContent({super.key, required this.row});

  final OverviewUpcomingRow row;

  static const _dateWidth = 30.0;
  static const _dayFontSize = 18.0;
  static const _dayLineHeight = 1.05;
  static const _statementIconSize = 17.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = row.amount;
    final kind = row.amountKind;
    final Widget trailing = amount == null || kind == null
        ? Padding(
            padding: const EdgeInsets.only(left: overviewRowTrailingGap),
            child: Icon(
              symbolIcon(overviewStatementSymbol),
              size: _statementIconSize,
              color: colors.text,
            ),
          )
        : OverviewAmountText(amount: amount, kind: kind);
    final date = SizedBox(
      width: _dateWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.day,
            style: const TextStyle(
              fontSize: _dayFontSize,
              fontWeight: overviewSemiBold,
              height: _dayLineHeight,
            ),
          ),
          Text(
            row.month,
            style: TextStyle(
              fontSize: overviewSmallFontSize,
              color: colors.subtext,
              height: _dayLineHeight,
            ),
          ),
        ],
      ),
    );
    return MedallionRow(
      leading: date,
      title: row.title,
      subtitle: row.caption,
      trailing: trailing,
    );
  }
}
