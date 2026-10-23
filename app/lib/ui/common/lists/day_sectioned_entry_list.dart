import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/entry_row.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

sealed class DaySectionedEntryDescriptor {
  const DaySectionedEntryDescriptor();
}

class DaySectionHeaderDescriptor extends DaySectionedEntryDescriptor {
  const DaySectionHeaderDescriptor({required this.day, required this.net});

  final DateTime day;
  final Decimal net;
}

class DaySectionEntryDescriptor extends DaySectionedEntryDescriptor {
  const DaySectionEntryDescriptor(this.row);

  final TransactionRow row;
}

List<DaySectionedEntryDescriptor> daySectionedEntryDescriptors(
  List<DaySection> sections,
) {
  final descriptors = <DaySectionedEntryDescriptor>[];
  for (final section in sections) {
    descriptors.add(
      DaySectionHeaderDescriptor(
        day: section.date,
        net: section.income - section.expenses,
      ),
    );
    descriptors.addAll(section.rows.map(DaySectionEntryDescriptor.new));
  }
  return List.unmodifiable(descriptors);
}

class DaySectionedEntryList extends StatelessWidget {
  const DaySectionedEntryList({
    super.key,
    required this.ledger,
    required this.state,
    required this.window,
    required this.entries,
  }) : sections = null;

  const DaySectionedEntryList.prepared({
    super.key,
    required this.ledger,
    required this.state,
    required this.sections,
  }) : window = null,
       entries = const [];

  final Ledger ledger;
  final LedgerState state;
  final DateRange? window;
  final Iterable<Entry> entries;
  final List<DaySection>? sections;

  static const _emptyVerticalPadding = 32.0;
  static const _emptyMessage = 'No entries in this period';

  @override
  Widget build(BuildContext context) {
    final resolvedSections =
        sections ?? daySections(entries, state, interval: window);
    if (resolvedSections.isEmpty) {
      const message = Center(child: Text(_emptyMessage));
      const padding = EdgeInsets.symmetric(vertical: _emptyVerticalPadding);
      const padded = Padding(padding: padding, child: message);
      return const SliverToBoxAdapter(child: padded);
    }

    final descriptors = daySectionedEntryDescriptors(resolvedSections);
    Widget itemBuilder(BuildContext context, int index) {
      final descriptor = descriptors[index];
      final entryKey = descriptor is DaySectionEntryDescriptor
          ? ValueKey(descriptor.row.id)
          : null;
      return switch (descriptor) {
        DaySectionHeaderDescriptor(:final day, :final net) => DayHeader(
          day: day,
          net: net,
        ),
        DaySectionEntryDescriptor(:final row) => EntryRow(
          key: entryKey,
          row: row,
          ledger: ledger,
          state: state,
        ),
      };
    }

    return SliverList.builder(
      itemCount: descriptors.length,
      itemBuilder: itemBuilder,
    );
  }
}
