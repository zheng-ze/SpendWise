import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:spendwise/sync/custom_endpoint_validator.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/common/step_emitting.dart';

/// Validates a raw custom endpoint string, injected so tests can substitute it.
typedef CustomEndpointValidator = CustomEndpointValidation Function(
  String? endpoint,
);

/// One-shot continuation after the picker durably persists its selection.
sealed class BackendPickerStep {}

/// The hosted choice persisted; the flow may continue enrollment.
final class HostedReady extends BackendPickerStep {}

/// The custom choice persisted but has no backend behind it yet, so the flow
/// shows its not-available affordance instead of continuing.
final class CustomEndpointUnavailable extends BackendPickerStep {}

final class BackendPickerState
    implements HasStep<BackendPickerState, BackendPickerStep> {
  const BackendPickerState({
    this.selectedBackend = SyncBackendKind.supabase,
    this.endpoint = '',
    this.endpointError,
    this.saveError,
    this.saving = false,
    this.step,
  });

  final SyncBackendKind selectedBackend;
  final String endpoint;

  /// Validation message for the custom URL field, null when the input stands.
  final String? endpointError;

  /// Persistence failure kept in flow, null when no save has failed.
  final String? saveError;
  final bool saving;

  @override
  final BackendPickerStep? step;

  BackendPickerState copyWith({
    SyncBackendKind? selectedBackend,
    String? endpoint,
    String? Function()? endpointError,
    String? Function()? saveError,
    bool? saving,
    BackendPickerStep? Function()? step,
  }) {
    return BackendPickerState(
      selectedBackend: selectedBackend ?? this.selectedBackend,
      endpoint: endpoint ?? this.endpoint,
      endpointError: endpointError == null
          ? this.endpointError
          : endpointError(),
      saveError: saveError == null ? this.saveError : saveError(),
      saving: saving ?? this.saving,
      step: step == null ? this.step : step(),
    );
  }

  @override
  BackendPickerState withStep(BackendPickerStep? Function() step) =>
      copyWith(step: step);
}

abstract class BackendPickerViewModel {
  void selectBackend(SyncBackendKind backend);
  void updateEndpoint(String endpoint);
  Future<void> continueWithSelection();
  void clearStep();
}

class BackendPickerNotifier extends Notifier<BackendPickerState>
    with StepEmitting<BackendPickerState, BackendPickerStep>
    implements BackendPickerViewModel {
  BackendPickerNotifier({
    BackendSelectionWriter? writer,
    this._validator = CustomEndpointValidation.validate,
  }) : _writerOverride = writer;

  final BackendSelectionWriter? _writerOverride;
  final CustomEndpointValidator _validator;
  late BackendSelectionWriter _writer;

  @override
  BackendPickerState build() {
    _writer = _writerOverride ?? ref.watch(syncMetadataStoreProvider);
    return const BackendPickerState();
  }

  @override
  void updateState(
    BackendPickerState Function(BackendPickerState current) apply,
  ) => state = apply(state);

  @override
  void selectBackend(SyncBackendKind backend) {
    if (state.saving) return;
    state = state.copyWith(
      selectedBackend: backend,
      endpointError: () => null,
      saveError: () => null,
    );
  }

  @override
  void updateEndpoint(String endpoint) {
    if (state.saving) return;
    state = state.copyWith(endpoint: endpoint, endpointError: () => null);
  }

  @override
  Future<void> continueWithSelection() async {
    if (state.saving) return;
    final selected = state.selectedBackend;
    if (selected == SyncBackendKind.supabase) {
      await _persistHosted();
      return;
    }
    await _persistCustom();
  }

  Future<void> _persistHosted() async {
    state = state.copyWith(saving: true, saveError: () => null);
    try {
      await _writer.setBackendSelection(backend: SyncBackendKind.supabase);
    } on Exception catch (_) {
      if (!ref.mounted) return;
      _failSave();
      return;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(saving: false);
      }
      rethrow;
    }
    if (!ref.mounted) return;
    state = state.copyWith(saving: false);
    emitStep(HostedReady());
  }

  Future<void> _persistCustom() async {
    final validation = _validator(state.endpoint);
    switch (validation) {
      case InvalidCustomEndpoint(:final failure):
        state = state.copyWith(endpointError: () => failure.message);
        return;
      case ValidCustomEndpoint(:final uri):
        state = state.copyWith(
          saving: true,
          endpointError: () => null,
          saveError: () => null,
        );
        try {
          await _writer.setBackendSelection(
            backend: SyncBackendKind.custom,
            endpoint: uri.toString(),
          );
        } on Exception catch (_) {
          if (!ref.mounted) return;
          _failSave();
          return;
        } catch (_) {
          if (ref.mounted) {
            state = state.copyWith(saving: false);
          }
          rethrow;
        }
        if (!ref.mounted) return;
        state = state.copyWith(saving: false);
        emitStep(CustomEndpointUnavailable());
    }
  }

  void _failSave() {
    state = state.copyWith(
      saving: false,
      saveError: () =>
          'Could not save the backend selection. Please try again.',
    );
  }
}

final backendPickerViewModelProvider =
    NotifierProvider<BackendPickerNotifier, BackendPickerState>(
      BackendPickerNotifier.new,
    );
