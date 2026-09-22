import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

typedef BackendSelectionCall = ({SyncBackendKind backend, String? endpoint});

/// Records every persist call, optionally holding the caller at a gate or
/// failing it, so tests can prove ordering and serialization.
final class RecordingBackendSelectionWriter implements BackendSelectionWriter {
  Completer<void>? gate;
  void Function()? onWrite;
  Exception? failure;

  final List<BackendSelectionCall> calls = [];

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) async {
    calls.add((backend: backend, endpoint: endpoint));
    onWrite?.call();
    final pending = gate;
    if (pending != null) await pending.future;
    final error = failure;
    if (error != null) throw error;
  }
}

ProviderContainer containerWith({
  required RecordingBackendSelectionWriter writer,
}) {
  final container = ProviderContainer(
    overrides: [
      backendPickerViewModelProvider.overrideWith(
        () => BackendPickerNotifier(writer: writer),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('BackendPickerNotifier hosted continue', () {
    test(
      'persists supabase with a null endpoint before emitting HostedReady',
      () async {
        final writer = RecordingBackendSelectionWriter();
        final container = containerWith(writer: writer);
        writer.onWrite = () {
          expect(
            container.read(backendPickerViewModelProvider).step,
            isNull,
            reason: 'no continuation step may exist before the write lands',
          );
        };

        await container
            .read(backendPickerViewModelProvider.notifier)
            .continueWithSelection();

        expect(writer.calls, hasLength(1));
        expect(writer.calls.single.backend, SyncBackendKind.supabase);
        expect(writer.calls.single.endpoint, isNull);
        final state = container.read(backendPickerViewModelProvider);
        expect(state.step, isA<HostedReady>());
        expect(state.saving, isFalse);
        expect(state.saveError, isNull);
      },
    );

    test('writer failure surfaces a save error and emits no step', () async {
      final writer = RecordingBackendSelectionWriter()
        ..failure = Exception('disk full');
      final container = containerWith(writer: writer);

      await container
          .read(backendPickerViewModelProvider.notifier)
          .continueWithSelection();

      final state = container.read(backendPickerViewModelProvider);
      expect(writer.calls, hasLength(1));
      expect(state.saveError, isNotNull);
      expect(state.step, isNull);
      expect(state.saving, isFalse);
    });

    test(
      'a second continue while a persist is in flight makes no extra write',
      () async {
        final writer = RecordingBackendSelectionWriter()
          ..gate = Completer<void>();
        final container = containerWith(writer: writer);
        final viewModel = container.read(
          backendPickerViewModelProvider.notifier,
        );

        final first = viewModel.continueWithSelection();
        final second = viewModel.continueWithSelection();
        writer.gate?.complete();
        await first;
        await second;

        expect(writer.calls, hasLength(1));
        expect(
          container.read(backendPickerViewModelProvider).step,
          isA<HostedReady>(),
        );
      },
    );
  });

  group('BackendPickerNotifier custom continue', () {
    test('persists custom with the validated endpoint before emitting '
        'CustomEndpointUnavailable', () async {
      final writer = RecordingBackendSelectionWriter();
      final container = containerWith(writer: writer);
      writer.onWrite = () {
        expect(
          container.read(backendPickerViewModelProvider).step,
          isNull,
          reason: 'no continuation step may exist before the write lands',
        );
      };
      final viewModel = container.read(backendPickerViewModelProvider.notifier);

      viewModel.selectBackend(SyncBackendKind.custom);
      viewModel.updateEndpoint('https://sync.example.com/sync');
      await viewModel.continueWithSelection();

      expect(writer.calls, hasLength(1));
      expect(writer.calls.single.backend, SyncBackendKind.custom);
      expect(writer.calls.single.endpoint, 'https://sync.example.com/sync');
      final state = container.read(backendPickerViewModelProvider);
      expect(state.step, isA<CustomEndpointUnavailable>());
      expect(state.saving, isFalse);
      expect(state.saveError, isNull);
    });

    test('writer failure surfaces a save error and emits no step', () async {
      final writer = RecordingBackendSelectionWriter()
        ..failure = Exception('disk full');
      final container = containerWith(writer: writer);
      final viewModel = container.read(backendPickerViewModelProvider.notifier);

      viewModel.selectBackend(SyncBackendKind.custom);
      viewModel.updateEndpoint('https://sync.example.com/sync');
      await viewModel.continueWithSelection();

      final state = container.read(backendPickerViewModelProvider);
      expect(writer.calls, hasLength(1));
      expect(state.saveError, isNotNull);
      expect(state.step, isNull);
      expect(state.saving, isFalse);
    });
  });

  group('BackendPickerNotifier custom validation', () {
    const invalidEndpoints = {
      'blank': '',
      'relative': 'sync/push',
      'non-https': 'http://sync.example.com',
      'malformed': 'https://[::1',
      'empty host': 'https://',
    };

    for (final entry in invalidEndpoints.entries) {
      test(
        '${entry.key} endpoint persists nothing and surfaces validation',
        () async {
          final writer = RecordingBackendSelectionWriter();
          final container = containerWith(writer: writer);
          final viewModel = container.read(
            backendPickerViewModelProvider.notifier,
          );

          viewModel.selectBackend(SyncBackendKind.custom);
          viewModel.updateEndpoint(entry.value);
          await viewModel.continueWithSelection();

          final state = container.read(backendPickerViewModelProvider);
          expect(writer.calls, isEmpty);
          expect(state.endpointError, isNotNull);
          expect(state.step, isNull);
          expect(state.saving, isFalse);
        },
      );
    }
  });

  group('BackendPickerNotifier constructor surface', () {
    test('depends only on the writer and the validator', () {
      final source = File(
        'lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart',
      ).readAsStringSync();

      expect(source, contains('BackendSelectionWriter'));
      expect(source, contains('CustomEndpointValidator'));
      expect(source, isNot(contains('Resolver')));
      expect(source, isNot(contains('Coordinator')));
      expect(source, isNot(contains('Authenticator')));
      expect(source, isNot(contains('EnrollmentService')));
      expect(source, isNot(contains(RegExp(r'\bSyncBackend\b'))));
      expect(source, isNot(contains('Supabase')));
    });
  });
}
