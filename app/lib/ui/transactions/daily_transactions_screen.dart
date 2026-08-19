import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/column_text.dart';
import 'package:spendwise/ui/common/expanding_fab.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/common/top_tab_bar.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/accounts/source_edit_form.dart';
import 'package:spendwise/ui/stats/stats_window.dart';
import 'package:spendwise/ui/transactions/day_header.dart';
import 'package:spendwise/ui/transactions/day_sections.dart';
import 'package:spendwise/ui/transactions/delete_confirmation.dart';
import 'package:spendwise/ui/transactions/empty_state.dart';
import 'package:spendwise/ui/transactions/entry_form.dart';
import 'package:spendwise/ui/transactions/monthly_transactions_view.dart';
import 'package:spendwise/ui/transactions/transaction_cell.dart';
import 'package:spendwise/ui/transactions/transactions_screen_state.dart';

const _tabTitles = ['Daily', 'Monthly'];

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({
    super.key,
    this.sourceScope,
    this.scopeIDs,
    this.title = 'Transactions',
    this.onRowTap,
    this.monthlyBuilder,
  });

  final String? sourceScope;

  /// Filters entries against every id in the set rather than just
  /// [sourceScope]. Falls back to `{sourceScope}` when omitted, so an
  /// account-scoped push can widen the filter to the account plus its
  /// pockets while [sourceScope] keeps identifying the screen for the date
  /// state and prefilling the add-entry form with the account itself.
  final Set<String>? scopeIDs;

  final String title;

  final void Function(Entry entry)? onRowTap;

  final WidgetBuilder? monthlyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox.shrink();

    final resolvedScope =
        scopeIDs ?? (sourceScope == null ? null : {sourceScope!});

    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) {
        return _TransactionsScreenBody(
          sourceScope: sourceScope,
          scopeIDs: resolvedScope,
          title: title,
          ledger: ledger,
          onRowTap:
              onRowTap ??
              (entry) => showEntryFormSheet(
                context: context,
                ledger: ledger,
                entry: entry,
                sourceScope: sourceScope,
              ),
          monthlyBuilder: monthlyBuilder,
        );
      },
    );
  }
}

class _TransactionsScreenBody extends ConsumerWidget {
  const _TransactionsScreenBody({
    required this.sourceScope,
    required this.scopeIDs,
    required this.title,
    required this.ledger,
    required this.onRowTap,
    required this.monthlyBuilder,
  });

  final String? sourceScope;
  final Set<String>? scopeIDs;
  final String title;
  final Ledger ledger;
  final void Function(Entry entry)? onRowTap;
  final WidgetBuilder? monthlyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = transactionsScreenProvider(sourceScope);
    final screenState = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    final step = screenState.mode == TransactionsScreenMode.daily
        ? MonthYearStep.month
        : MonthYearStep.year;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          MonthYearSelector(
            value: screenState.selectedDate,
            step: step,
            onChanged: controller.setDate,
          ),
        ],
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              TopTabBar(
                titles: _tabTitles,
                selectedIndex: screenState.mode.index,
                onSelected: (index) =>
                    controller.setMode(TransactionsScreenMode.values[index]),
              ),
              const Divider(height: 1),
              _TotalsBar(
                state: ledger.state,
                sourceScope: scopeIDs,
                selectedDate: screenState.selectedDate,
                mode: screenState.mode,
              ),
              const Divider(height: 1),
              Expanded(
                child: screenState.mode == TransactionsScreenMode.daily
                    ? _DailyContent(
                        state: ledger.state,
                        sourceScope: scopeIDs,
                        selectedDate: screenState.selectedDate,
                        ledger: ledger,
                        onRowTap: onRowTap,
                      )
                    : (monthlyBuilder?.call(context) ??
                          MonthlyTransactionsView(
                            state: ledger.state,
                            year: screenState.selectedDate,
                            onWeekTap: controller.switchToDaily,
                          )),
              ),
            ],
          ),
          ExpandingFab(
            primary: FabAction(
              label: 'Add Transaction',
              icon: Icons.add,
              onTap: () => showEntryFormSheet(
                context: context,
                ledger: ledger,
                sourceScope: sourceScope,
              ),
            ),
            secondary: sourceScope == null
                ? null
                : FabAction(
                    label: 'Edit ${ledger.state.sourceName(sourceScope) ?? ''}',
                    icon: Icons.edit_outlined,
                    onTap: () => showSourceEditFormSheet(
                      context: context,
                      ledger: ledger,
                      holderID: sourceScope!,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.state,
    required this.sourceScope,
    required this.selectedDate,
    required this.mode,
  });

  final LedgerState state;
  final Set<String>? sourceScope;
  final DateTime selectedDate;
  final TransactionsScreenMode mode;

  @override
  Widget build(BuildContext context) {
    final interval = mode == TransactionsScreenMode.daily
        ? monthWindow(selectedDate)
        : yearWindow(selectedDate);

    final sections = daySections(
      state.entries.values,
      state,
      interval: interval,
      sourceScope: sourceScope,
    );

    var income = Decimal.zero;
    var expenses = Decimal.zero;
    for (final section in sections) {
      income += section.income;
      expenses += section.expenses;
    }
    final total = income - expenses;
    final colors = AmountColors.of(Theme.of(context));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ColumnText(
        items: [
          ColumnTextItem(
            caption: 'Income',
            value: formatCurrency(income),
            valueColor: colors.gain,
          ),
          ColumnTextItem(
            caption: 'Expenses',
            value: formatCurrency(expenses),
            valueColor: colors.loss,
          ),
          ColumnTextItem(
            caption: 'Total',
            value: formatCurrency(total),
            valueColor: colors.netAmountColor(total),
          ),
        ],
      ),
    );
  }
}

class _DailyContent extends StatelessWidget {
  const _DailyContent({
    required this.state,
    required this.sourceScope,
    required this.selectedDate,
    required this.ledger,
    required this.onRowTap,
  });

  final LedgerState state;
  final Set<String>? sourceScope;
  final DateTime selectedDate;
  final Ledger ledger;
  final void Function(Entry entry)? onRowTap;

  @override
  Widget build(BuildContext context) {
    final sections = daySections(
      state.entries.values,
      state,
      interval: monthWindow(selectedDate),
      sourceScope: sourceScope,
    );

    if (sections.isEmpty) return const TransactionsEmptyState();

    return CustomScrollView(
      slivers: [
        for (final section in sections)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: DayHeaderDelegate(
                  day: section.date,
                  net: section.income - section.expenses,
                ),
              ),
              _DaySliverList(
                section: section,
                state: state,
                ledger: ledger,
                onRowTap: onRowTap,
              ),
            ],
          ),
      ],
    );
  }
}

class _DaySliverList extends StatelessWidget {
  const _DaySliverList({
    required this.section,
    required this.state,
    required this.ledger,
    required this.onRowTap,
  });

  final DaySection section;
  final LedgerState state;
  final Ledger ledger;
  final void Function(Entry entry)? onRowTap;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: section.rows.length,
      itemBuilder: (context, index) {
        final row = section.rows[index];
        final entry = state.entries[row.id]!;
        final cell = TransactionCell(
          row: row,
          onTap: onRowTap == null ? null : () => onRowTap!(entry),
        );

        return Semantics(
          customSemanticsActions: {
            CustomSemanticsAction(label: 'Delete ${row.title}'): () async {
              if (await showDeleteConfirmation(
                context,
                note: row.note,
                title: row.title,
              )) {
                ledger.deleteEntry(entry.id);
              }
            },
          },
          child: Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            background: const _DeleteBackground(),
            confirmDismiss: (_) => showDeleteConfirmation(
              context,
              note: row.note,
              title: row.title,
            ),
            onDismissed: (_) => ledger.deleteEntry(entry.id),
            child: cell,
          ),
        );
      },
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
