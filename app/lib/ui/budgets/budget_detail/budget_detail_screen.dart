import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_content.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_presentation.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';

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
              ledger: ledger,
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
  const _BudgetDetailPage({
    required this.viewState,
    required this.viewModel,
    required this.ledger,
  });

  final BudgetDetailViewState viewState;
  final BudgetDetailViewModel viewModel;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final isDeleted =
        budgetDetailPresentation(viewState).body == BudgetDetailBody.deleted;
    final content = BudgetDetailContent(
      viewState: viewState,
      viewModel: viewModel,
      ledger: ledger,
    );

    return Scaffold(
      appBar: isDeleted
          ? null
          : _BudgetDetailAppBar(title: viewState.title, viewModel: viewModel),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          children: [content],
        ),
      ),
    );
  }
}

// MARK: - App Bar
class _BudgetDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BudgetDetailAppBar({required this.title, required this.viewModel});

  static const _editTooltip = 'Edit limit history';

  final String title;
  final BudgetDetailViewModel viewModel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: _editTooltip,
          onPressed: viewModel.requestLimitEdit,
        ),
      ],
    );
  }
}
