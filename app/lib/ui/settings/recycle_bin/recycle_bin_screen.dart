import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_purge_dialog.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_sections.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/symbol_map.dart';

// MARK: - Constants

const _screenTitle = 'Recycle bin';

const _accountsTitle = 'Accounts';

const _pocketsTitle = 'Subpockets';

const _categoriesTitle = 'Categories';

const _accountsSymbol = 'wallet';

const _pocketsSymbol = 'inbox';

// MARK: - Screen

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

// MARK: - State

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  ProviderSubscription<AsyncValue<RecycleBinViewState>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      recycleBinViewModelProvider,
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  RecycleBinViewModel get _viewModel =>
      ref.read(recycleBinViewModelProvider.notifier);

  void _handleStep(RecycleBinStep? step) {
    if (step == null) return;
    switch (step) {
      case PurgeConfirmationRequested(:final row):
        _confirmPurge(row);
    }
  }

  Future<void> _confirmPurge(BinRow row) async {
    final confirmed = await confirmBinPurge(context, row);
    if (!mounted) return;
    _viewModel.applyPurgeConfirmed(confirmed, row.kind, row.id);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(recycleBinViewModelProvider);

    return asyncState.when(
      data: (viewState) =>
          _RecycleBinScreenBody(viewState: viewState, viewModel: _viewModel),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

// MARK: - Body

class _RecycleBinScreenBody extends StatelessWidget {
  const _RecycleBinScreenBody({
    required this.viewState,
    required this.viewModel,
  });

  final RecycleBinViewState viewState;
  final RecycleBinViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final entries = viewState.entries;
    final accounts = viewState.accounts;
    final pockets = viewState.pockets;
    final categories = viewState.categories;

    final isEmpty =
        entries.isEmpty &&
        accounts.isEmpty &&
        pockets.isEmpty &&
        categories.isEmpty;

    void restore(BinRow row) => viewModel.restore(row.kind, row.id);
    void requestPurge(BinRow row) => viewModel.requestPurge(row);

    final sections = [
      if (entries.isNotEmpty)
        BinEntriesSection(
          rows: entries,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
      if (accounts.isNotEmpty)
        BinSection(
          title: _accountsTitle,
          sectionIcon: symbolIcon(_accountsSymbol),
          rows: accounts,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
      if (pockets.isNotEmpty)
        BinSection(
          title: _pocketsTitle,
          sectionIcon: symbolIcon(_pocketsSymbol),
          rows: pockets,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
      if (categories.isNotEmpty)
        BinSection(
          title: _categoriesTitle,
          sectionIcon: null,
          rows: categories,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
    ];
    final content = isEmpty
        ? const BinEmptyState()
        : ListView(children: sections);

    return Scaffold(
      appBar: AppBar(title: const Text(_screenTitle)),
      body: SafeArea(child: content),
    );
  }
}
