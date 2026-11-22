import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_screen.dart';
import 'package:spendwise/ui/settings/settings_root_screen.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';

// MARK: - SettingsFlow
class SettingsFlow extends FlowBase<SettingsStep> {
  const SettingsFlow({super.key});

  @override
  ConsumerState<SettingsFlow> createState() => _SettingsFlowState();
}

// MARK: - SettingsFlowState
class _SettingsFlowState extends FlowBaseState<SettingsStep, SettingsFlow> {
  @override
  void Function() subscribeToStep(void Function(SettingsStep? step) handle) =>
      ref
          .listenManual(
            settingsRootViewModelProvider,
            (previous, SettingsRootViewState next) => handle(next.step),
          )
          .close;

  @override
  void handleStep(BuildContext context, SettingsStep step) {
    switch (step) {
      case CategoriesRequested():
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CategoryListScreen()),
        );
      case RecycleBinRequested():
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RecycleBinScreen()),
        );
    }
    ref.read(settingsRootViewModelProvider.notifier).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) => const SettingsScreen();
}
