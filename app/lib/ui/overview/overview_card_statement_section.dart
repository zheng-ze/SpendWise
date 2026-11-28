import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/overview/overview_card_statement_mapping.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_rows.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _captionSeparator = ' / ';

// MARK: - Tray

class CardStatementTray extends StatelessWidget {
  const CardStatementTray({super.key, required this.rows});

  final List<OverviewCardStatementRow>? rows;

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    final Widget content;
    if (rows == null) {
      content = const LoadingSkeleton();
    } else if (rows.isEmpty) {
      content = const OverviewEmptyCopy(overviewCardStatementEmpty);
    } else {
      content = CardStatementRows(rows: rows);
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(title: overviewCardStatementTitle, child: content),
    );
  }
}

// MARK: - Rows

class CardStatementRows extends StatelessWidget {
  const CardStatementRows({super.key, required this.rows});

  final List<OverviewCardStatementRow> rows;

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final (index, row) in rows.indexed)
        OverviewRowFrame(
          isLast: index == rows.length - 1,
          child: CardStatementRow(row: row),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }
}

class CardStatementRow extends StatelessWidget {
  const CardStatementRow({super.key, required this.row});

  final OverviewCardStatementRow row;

  static const _lineGap = 4.0;
  static const _labelGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final name = Expanded(
      child: Text(
        row.cardName,
        style: text.body.copyWith(fontWeight: SpendWiseText.semibold),
      ),
    );
    final daysToCut = Text(
      row.daysToCut,
      style: text.caption.copyWith(color: colors.subtext),
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        name,
        const SizedBox(width: _labelGap),
        daysToCut,
      ],
    );
    final payableLabel = Expanded(
      child: Text(
        overviewCardStatementPayableLabel,
        style: text.body.copyWith(color: colors.subtext),
      ),
    );
    final payable = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        payableLabel,
        const SizedBox(width: _labelGap),
        Text(row.payable, style: text.small),
      ],
    );
    final caption = OverviewEmptyCopy(
      '${row.cutDate}$_captionSeparator'
      '$overviewCardStatementCyclePrefix${row.cycleAmount}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: _lineGap),
        payable,
        const SizedBox(height: _lineGap),
        caption,
      ],
    );
  }
}
