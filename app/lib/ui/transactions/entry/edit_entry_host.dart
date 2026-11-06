import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_form.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_step_handlers.dart';

// MARK: - Constants
const _loadAlert = SheetAlertData(
  message: "Couldn't load the entry form",
  severity: SheetAlertSeverity.error,
  actionLabel: 'Retry',
);

// MARK: - EditEntryHost
class EditEntryHost extends ConsumerStatefulWidget {
  const EditEntryHost({
    super.key,
    required this.entryId,
    required this.frame,
    required this.onDismiss,
  });

  final String entryId;

  final EntryFormFrame frame;

  final VoidCallback onDismiss;

  @override
  ConsumerState<EditEntryHost> createState() => _EditEntryHostState();
}

class _EditEntryHostState extends ConsumerState<EditEntryHost> {
  late final EditEntryPresentationController _controller;
  late final Object _token;
  late final ProviderSubscription<AsyncValue<EntryFormViewState>> _form;
  final _pickerRoutes = <ModalRoute<dynamic>>[];
  bool _dismissScheduled = false;

  String get _entryId => widget.entryId;

  bool get _active => mounted && _controller.owns(_entryId, _token);

  @override
  void initState() {
    super.initState();
    _controller = ref.read(editEntryPresentationControllerProvider);
    _token = _controller.claim(_entryId);
    _form = ref.listenManual(
      entryFormViewModelProvider(_entryId),
      (_, _) => _consume(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _consume());
  }

  @override
  void dispose() {
    _form.close();
    _controller.release(_entryId, _token);
    final opened = List<ModalRoute<dynamic>>.of(_pickerRoutes);
    scheduleMicrotask(() => _removeActive(opened));
    super.dispose();
  }

  void _removeActive(List<ModalRoute<dynamic>> routes) {
    for (final route in routes) {
      final navigator = route.navigator;
      if (navigator == null || !navigator.mounted || !route.isActive) continue;
      navigator.removeRoute(route);
    }
  }

  void _consume() {
    if (!_active) return;
    final provider = entryFormViewModelProvider(_entryId);
    final state = ref.read(provider).value;
    if (state == null) return;
    final notifier = ref.read(provider.notifier);
    final step = state.step;
    if (step == null) return;
    notifier.clearStep();
    if (!_active) return;
    dispatchEntryFormStep(
      context,
      ref,
      _entryId,
      step,
      useRootNavigator: true,
      isCurrent: () => _active,
      sheetPresentation: shellSheetPresentation,
      onPickerRouteCreated: _pickerRoutes.add,
    );
  }

  void _scheduleDismiss() {
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDismiss();
    });
  }

  void _retry() => ref.invalidate(entryFormViewModelProvider(_entryId));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(entryFormViewModelProvider(_entryId));
    final loaded = async.isLoading || async.hasError ? null : async.value;
    if (loaded == null) {
      final failed = async.hasError && !async.isLoading;
      return NewEntryLoadingForm(
        frame: widget.frame,
        title: editEntryTitle,
        alert: failed ? _loadAlert : null,
        onAlertAction: failed ? _retry : null,
      );
    }
    if (loaded.dismissed || !loaded.isEditing) _scheduleDismiss();
    if (!loaded.isEditing) {
      return NewEntryLoadingForm(frame: widget.frame, title: editEntryTitle);
    }
    final saveError = loaded.error;
    final saveAlert = saveError == null
        ? null
        : SheetAlertData(
            message: entrySaveErrorMessage(saveError),
            severity: SheetAlertSeverity.error,
          );
    return NewEntryForm(
      formKey: _entryId,
      viewModel: ref.read(entryFormViewModelProvider(_entryId).notifier),
      state: loaded,
      display: ref.watch(entryFormDisplayProvider(_entryId)),
      frame: widget.frame,
      alert: saveAlert,
    );
  }
}
