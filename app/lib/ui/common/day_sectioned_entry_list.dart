import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/entry_row.dart';

class DaySectionedEntryList extends StatelessWidget {
  const DaySectionedEntryList({
    super.key,
    required this.ledger,
    required this.state,
    required this.window,
    required this.matching,
  });

  final Ledger ledger;
  final LedgerState state;
  final DateRange window;
  final Iterable<Entry> Function() matching;

  @override
  Widget build(BuildContext context) {
    final sections = daySections(matching(), state, interval: window);

    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No entries in this period')),
      );
    }

    return Column(
      children: [
        for (final section in sections) ...[
          DayHeader(day: section.date, net: section.income - section.expenses),
          for (final row in section.rows)
            EntryRow(row: row, ledger: ledger, state: state),
        ],
      ],
    );
  }
}
