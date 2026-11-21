import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_content.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/common/navigation/page_header.dart';

// MARK: - Constants
const _editTooltip = 'Edit';

// MARK: - Screen
class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetID});

  final String budgetID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(budgetDetailViewModelProvider(budgetID));
    final ledger = ref.watch(ledgerProvider);

    return asyncState.when(
      data: (viewState) => ledger == null
          ? const SizedBox.shrink()
          : _BudgetDetailPage(
              viewState: viewState,
              viewModel: ref.read(
                budgetDetailViewModelProvider(budgetID).notifier,
              ),
            ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

// MARK: - Page
class _BudgetDetailPage extends StatelessWidget {
  const _BudgetDetailPage({required this.viewState, required this.viewModel});

  final BudgetDetailViewState viewState;
  final BudgetDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final content = BudgetDetailContent(
      viewState: viewState,
      viewModel: viewModel,
    );
    final edit = IconButton(
      icon: const Icon(Icons.edit_outlined),
      tooltip: _editTooltip,
      onPressed: viewModel.requestEdit,
    );
    final header = PageHeader(
      title: viewState.title,
      onBack: Navigator.of(context).maybePop,
      trailing: edit,
    );
    final scroller = ListView(
      physics: const ClampingScrollPhysics(),
      children: [content],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(children: [header, Expanded(child: scroller)]),
      ),
    );
  }
}
