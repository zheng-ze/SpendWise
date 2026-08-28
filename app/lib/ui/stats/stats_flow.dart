import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_form.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/stats_root_screen.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

/// Owns the Stats feature's own nested Navigator, covering both `stats/`'s
/// own screens and `budgets/`'s, since `budgets/` has no independent mount
/// point of its own — it is a tab inside the Stats root screen, reached only
/// through this Flow's Navigator.
class StatsFlow extends ConsumerStatefulWidget {
  const StatsFlow({super.key});

  @override
  ConsumerState<StatsFlow> createState() => _StatsFlowState();
}

class _StatsFlowState extends ConsumerState<StatsFlow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  ProviderSubscription<AsyncValue<StatsRootViewState>>? _screenSubscription;

  @override
  void initState() {
    super.initState();
    _screenSubscription = ref.listenManual(
      statsRootViewModelProvider,
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _screenSubscription?.close();
    super.dispose();
  }

  StatsRootViewModel get _rootViewModel =>
      ref.read(statsRootViewModelProvider.notifier);

  void _handleStep(StatsStep? step) {
    if (step == null) return;
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    switch (step) {
      case CategoryDetailRequested(
        :final mainID,
        :final kind,
        :final isYearRange,
        :final initialDate,
      ):
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryDetailScreen(
              args: CategoryDetailArgs(
                mainID: mainID,
                kind: kind,
                isYearRange: isYearRange,
                initialDate: initialDate,
              ),
            ),
          ),
        );
      case BudgetDetailRequested(:final budgetID):
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => BudgetDetailScreen(budgetID: budgetID),
          ),
        );
      case BudgetFormRequested():
        showBudgetFormSheet(context: context);
    }
    _rootViewModel.clearStep();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const StatsRootScreen(),
        ),
      ),
    );
  }
}
