import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_content.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Constants
const _paneScrollPhysics = ClampingScrollPhysics();
const _deletedBudgetTitle = '';
const _editLabel = 'Edit';

// MARK: - BudgetPaneHeader
typedef BudgetPaneHeader = ({String title, String subtitle});

final budgetPaneHeaderProvider = Provider.autoDispose
    .family<BudgetPaneHeader, String>((ref, budgetID) {
      ref.watch(analysisQueriesProvider);
      final state = ref.watch(ledgerProvider)?.state;
      final budget = state?.budgets[budgetID];
      final month = ref.watch(
        budgetDetailContextProvider(budgetID).select((c) => c.selectedMonth),
      );
      return (
        title: budget == null || state == null
            ? _deletedBudgetTitle
            : budgetTitle(budget, state),
        subtitle: formatMonthLabel(month),
      );
    });

// MARK: - BudgetPane
typedef BudgetPane = ({ShellDetail detail, VoidCallback close});

final budgetPaneProvider = Provider.autoDispose<BudgetPane?>((ref) {
  final budgetID = ref.watch(selectedBudgetProvider);
  final open = ref.watch(shellLayoutModeProvider) == ShellLayoutMode.open;
  if (budgetID == null || !open) return null;
  final header = ref.watch(budgetPaneHeaderProvider(budgetID));
  void requestEdit() => ref
      .read(budgetDetailViewModelProvider(budgetID).notifier)
      .requestLimitEdit();
  final edit = TextButton.icon(
    onPressed: requestEdit,
    icon: const Icon(Icons.edit_outlined),
    label: const Text(_editLabel),
  );
  final detail = ShellDetail(
    id: budgetID,
    title: header.title,
    subtitle: header.subtitle,
    bodyBuilder: (_) => BudgetPaneBody(budgetID: budgetID),
    headerActions: [edit],
  );
  void close() => ref.read(selectedBudgetProvider.notifier).clear();
  return (detail: detail, close: close);
}, dependencies: [shellLayoutModeProvider]);

// MARK: - BudgetPaneBody
class BudgetPaneBody extends ConsumerWidget {
  const BudgetPaneBody({super.key, required this.budgetID});

  final String budgetID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(budgetDetailViewModelProvider(budgetID)).value;
    if (viewState == null) return const SizedBox.shrink();
    final viewModel = ref.read(
      budgetDetailViewModelProvider(budgetID).notifier,
    );
    final content = BudgetDetailContent(
      viewState: viewState,
      viewModel: viewModel,
    );
    return ListView(physics: _paneScrollPhysics, children: [content]);
  }
}
