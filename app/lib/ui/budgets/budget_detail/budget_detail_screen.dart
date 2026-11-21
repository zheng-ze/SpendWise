import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_content.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/common/sheets/form_sheet_load_states.dart';

// MARK: - Constants
const _loadingTitle = 'Budget';
const _loadErrorTitle = "Couldn't load this budget";

// MARK: - Screen
class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetID});

  final String budgetID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = budgetDetailViewModelProvider(budgetID);
    final ledger = ref.watch(ledgerProvider);

    return FormSheetAsyncHost(
      state: ref.watch(provider),
      title: _loadingTitle,
      loadErrorMessage: _loadErrorTitle,
      onRetry: () => ref.invalidate(provider),
      builder: (viewState) => ledger == null
          ? const SizedBox.shrink()
          : _BudgetDetailPage(
              viewState: viewState,
              viewModel: ref.read(provider.notifier),
            ),
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

    return Scaffold(
      appBar: _BudgetDetailAppBar(title: viewState.title, viewModel: viewModel),
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

  static const _editTooltip = 'Edit';

  final String title;
  final BudgetDetailViewModel viewModel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final edit = IconButton(
      icon: const Icon(Icons.edit_outlined),
      tooltip: _editTooltip,
      onPressed: viewModel.requestEdit,
    );
    return AppBar(title: Text(title), actions: [edit]);
  }
}
