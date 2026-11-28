import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/import/import_file_picker_service.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/feedback/destructive_confirmation.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_screen.dart';
import 'package:spendwise/ui/settings/import_errors_sheet.dart';
import 'package:spendwise/ui/settings/settings_root_screen.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';

const _importConfirmationTitle = 'Replace all data?';
const _importConfirmationBody =
    'Importing deletes every account, pocket, entry, category, budget, plan '
    'and the recycle bin, then imports the Money Manager file. Display '
    'settings are kept. This can\'t be undone.';
const _importConfirmationLabel = 'Replace';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleHeldStep());
  }

  void _handleHeldStep() {
    final context = navigatorContext;
    if (!mounted || context == null) return;
    final step = ref.read(settingsRootViewModelProvider).step;
    if (step == null) return;
    handleStep(context, step);
  }

  @override
  void handleStep(BuildContext context, SettingsStep step) {
    ref.read(settingsRootViewModelProvider.notifier).clearStep();
    switch (step) {
      case CategoriesRequested():
        _pushScreen(context, const CategoryListScreen());
      case RecycleBinRequested():
        _pushScreen(context, const RecycleBinScreen());
      case ImportFileRequested():
        unawaited(_pickImportFile());
      case ImportConfirmationRequested():
        unawaited(_confirmImport(context));
      case ImportErrorsRequested():
        unawaited(_showImportErrors(context));
    }
  }

  void _pushScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _pickImportFile() async {
    final notifier = ref.read(settingsRootViewModelProvider.notifier);
    final picker = ref.read(importFilePickerProvider);
    try {
      notifier.applyPickedFile(bytes: await picker.pick());
    } catch (e) {
      notifier.applyPickedFile(pickerError: e);
    }
  }

  Future<void> _confirmImport(BuildContext context) async {
    final notifier = ref.read(settingsRootViewModelProvider.notifier);
    final confirmed = await showDestructiveConfirmation(
      context,
      title: _importConfirmationTitle,
      body: _importConfirmationBody,
      confirmLabel: _importConfirmationLabel,
    );
    if (!mounted) return;
    await notifier.applyImportConfirmed(confirmed);
  }

  Future<void> _showImportErrors(BuildContext context) async {
    final notifier = ref.read(settingsRootViewModelProvider.notifier);
    final messages = ref.read(settingsRootViewModelProvider).importErrors;
    await showImportErrorsSheet(context, messages: messages);
    notifier.dismissImportErrors();
  }

  @override
  Widget buildRoot(BuildContext context) => const SettingsScreen();
}
