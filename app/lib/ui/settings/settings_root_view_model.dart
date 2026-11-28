import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/import/money_manager/money_manager_importer.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/settings/import_error_text.dart';

// MARK: - Steps
sealed class SettingsStep {}

class CategoriesRequested extends SettingsStep {}

class RecycleBinRequested extends SettingsStep {}

class ImportFileRequested extends SettingsStep {}

class ImportConfirmationRequested extends SettingsStep {}

class ImportErrorsRequested extends SettingsStep {}

// MARK: - ImportStatus
enum ImportStatus { idle, picking, confirming, running }

// MARK: - SettingsRootViewState
class SettingsRootViewState
    implements HasStep<SettingsRootViewState, SettingsStep> {
  const SettingsRootViewState({
    this.step,
    this.importStatus = ImportStatus.idle,
    this.importErrors = const [],
  });

  @override
  final SettingsStep? step;
  final ImportStatus importStatus;
  final List<String> importErrors;

  SettingsRootViewState copyWith({
    SettingsStep? Function()? step,
    ImportStatus? importStatus,
    List<String>? importErrors,
  }) {
    return SettingsRootViewState(
      step: step == null ? this.step : step(),
      importStatus: importStatus ?? this.importStatus,
      importErrors: importErrors ?? this.importErrors,
    );
  }

  @override
  SettingsRootViewState withStep(SettingsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - SettingsRootViewModel
abstract class SettingsRootViewModel {
  void requestCategories();
  void requestRecycleBin();
  void requestImport();
  void applyPickedFile({Uint8List? bytes, Object? pickerError});
  Future<void> applyImportConfirmed(bool confirmed);
  void dismissImportErrors();
  void clearStep();
}

// MARK: - SettingsRootNotifier
class SettingsRootNotifier extends Notifier<SettingsRootViewState>
    with StepEmitting<SettingsRootViewState, SettingsStep>
    implements SettingsRootViewModel {
  Uint8List? _pickedBytes;
  KeepAliveLink? _errorsKeepAlive;

  @override
  SettingsRootViewState build() => const SettingsRootViewState();

  @override
  void updateState(
    SettingsRootViewState Function(SettingsRootViewState current) apply,
  ) => state = apply(state);

  @override
  void requestCategories() => emitStep(CategoriesRequested());

  @override
  void requestRecycleBin() => emitStep(RecycleBinRequested());

  @override
  void requestImport() {
    if (state.importStatus != ImportStatus.idle) return;
    _setImportStatus(ImportStatus.picking);
    emitStep(ImportFileRequested());
  }

  @override
  void applyPickedFile({Uint8List? bytes, Object? pickerError}) {
    // The picker future can complete after the Settings screen is gone.
    if (!ref.mounted) return;
    if (state.importStatus != ImportStatus.picking) return;
    if (pickerError != null) {
      _showImportErrors(const [importFileOpenFailedMessage]);
      return;
    }
    if (bytes == null) {
      _setImportStatus(ImportStatus.idle);
      return;
    }
    _pickedBytes = bytes;
    _setImportStatus(ImportStatus.confirming);
    emitStep(ImportConfirmationRequested());
  }

  @override
  Future<void> applyImportConfirmed(bool confirmed) async {
    if (state.importStatus != ImportStatus.confirming) return;
    final bytes = _pickedBytes;
    _pickedBytes = null;
    if (!confirmed || bytes == null) {
      _setImportStatus(ImportStatus.idle);
      return;
    }
    // Keeps the notifier alive so an error outcome survives leaving Settings.
    final keepAlive = ref.keepAlive();
    _setImportStatus(ImportStatus.running);
    final outcome = await _runImport(bytes);
    if (ref.mounted) _setImportStatus(ImportStatus.idle);
    final messages = importErrorMessages(outcome);
    if (messages.isEmpty) {
      keepAlive.close();
      return;
    }
    _errorsKeepAlive = keepAlive;
    _showImportErrors(messages);
  }

  @override
  void dismissImportErrors() {
    updateState((current) => current.copyWith(importErrors: const []));
    _errorsKeepAlive?.close();
    _errorsKeepAlive = null;
  }

  Future<ImportOutcome> _runImport(Uint8List bytes) async {
    final importer = ref.read(moneyManagerImporterProvider);
    if (importer == null) return const ImportFailedUnexpectedly();
    try {
      return await importer.run(bytes);
    } catch (_) {
      return const ImportFailedUnexpectedly();
    }
  }

  void _showImportErrors(List<String> messages) {
    updateState(
      (current) => current.copyWith(
        importStatus: ImportStatus.idle,
        importErrors: messages,
      ),
    );
    emitStep(ImportErrorsRequested());
  }

  void _setImportStatus(ImportStatus status) =>
      updateState((current) => current.copyWith(importStatus: status));
}

// MARK: - Constants
const String importFileOpenFailedMessage = "Couldn't open the file.";

final settingsRootViewModelProvider =
    NotifierProvider.autoDispose<SettingsRootNotifier, SettingsRootViewState>(
      SettingsRootNotifier.new,
    );
