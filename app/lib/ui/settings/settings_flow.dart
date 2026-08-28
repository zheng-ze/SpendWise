import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/settings/category_list_screen.dart';
import 'package:spendwise/ui/settings/plan_list_screen.dart';
import 'package:spendwise/ui/settings/recycle_bin_screen.dart';
import 'package:spendwise/ui/settings/settings_root_screen.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';

/// Owns the Settings feature's own nested Navigator, so its list screens
/// push without reaching for the app's root Navigator.
class SettingsFlow extends ConsumerStatefulWidget {
  const SettingsFlow({super.key});

  @override
  ConsumerState<SettingsFlow> createState() => _SettingsFlowState();
}

class _SettingsFlowState extends ConsumerState<SettingsFlow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  ProviderSubscription<SettingsRootViewState>? _screenSubscription;

  @override
  void initState() {
    super.initState();
    _screenSubscription = ref.listenManual(
      settingsRootViewModelProvider,
      (previous, next) => _handleStep(next.step),
    );
  }

  @override
  void dispose() {
    _screenSubscription?.close();
    super.dispose();
  }

  SettingsRootViewModel get _rootViewModel =>
      ref.read(settingsRootViewModelProvider.notifier);

  void _handleStep(SettingsStep? step) {
    if (step == null) return;
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    switch (step) {
      case CategoriesRequested():
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CategoryListScreen()),
        );
      case PlansRequested():
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PlanListScreen()));
      case RecycleBinRequested():
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RecycleBinScreen()),
        );
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
          builder: (_) => const SettingsScreen(),
        ),
      ),
    );
  }
}
