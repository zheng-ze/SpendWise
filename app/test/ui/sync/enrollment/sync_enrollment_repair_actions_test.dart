import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/database/ledger_database.dart'
    show LedgerDatabase;
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../../support/recording_ledger_store.dart';
import '../../../sync/in_memory_secret_store.dart';
import 'sync_enrollment_flow_test.dart' show FakeSessionOpener;

final class _Harness {
  late LedgerDatabase db;
  late SyncMetadataStore metadataStore;
  late FakeSessionOpener opener;
  late InMemorySecretStore secrets;
  late ProviderContainer container;
  DateTime clock = DateTime.utc(2026, 1, 1);

  void build() {
    db = LedgerDatabase(NativeDatabase.memory());
    metadataStore = SyncMetadataStore(db);
    opener = FakeSessionOpener();
    secrets = InMemorySecretStore();
    container = ProviderContainer(
      overrides: [
        appBootProvider.overrideWith(
          (ref) => AppBoot(
            createStore: () async => RecordingLedgerStore(),
            seedChanges: () => const [],
            readSyncSnapshot: () => metadataStore.snapshot(),
          ),
        ),
        ledgerDatabaseProvider.overrideWithValue(db),
        syncMetadataStoreProvider.overrideWithValue(metadataStore),
        syncEnrollmentViewModelProvider.overrideWith(
          () => SyncEnrollmentNotifier(
            sessionOpener: opener.call,
            secretStore: secrets,
            repairMode: true,
            now: () => clock,
          ),
        ),
      ],
    );
  }

  void dispose() {
    container.dispose();
    db.close();
  }

  SyncEnrollmentNotifier get notifier =>
      container.read(syncEnrollmentViewModelProvider.notifier);

  SyncEnrollmentState get state =>
      container.read(syncEnrollmentViewModelProvider);
}

void _collectOtpOnEnroll(_Harness harness) {
  harness.opener.session.onEnroll = () async {
    await harness.opener.session.resolveOtp!(
      EnrollmentChallenge(const {'identifier': 'user@example.com'}),
    );
  };
}

Future<Future<void>> _driveToOtpEntry(_Harness harness) async {
  _collectOtpOnEnroll(harness);
  final pending = harness.notifier.submitIdentifier('user@example.com');
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (harness.state.step is ShowOtpEntry) break;
  }
  expect(harness.state.step, isA<ShowOtpEntry>());
  return Future.value(pending);
}

void main() {
  group('repair entry observation', () {
    test(
      'enterRepairMode reports unneeded when the metadata read fails',
      () async {
        final harness = _Harness()..build();
        addTearDown(harness.dispose);
        await harness.db.close();

        expect(await harness.notifier.enterRepairMode(), isFalse);
      },
    );

    test('submitting during the entry read is ignored', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await harness.metadataStore.enterBindingAuthorizationRequired();

      final entry = harness.notifier.enterRepairMode();
      await harness.notifier.submitIdentifier('user@example.com');

      expect(harness.opener.openCalls, 0);
      expect(harness.state.errorMessage, isNull);
      expect(await entry, isTrue);
      expect(harness.state.inFlight, isFalse);
    });

    test('a superseded entry read reports stale instead of cleared', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await harness.metadataStore.enterBindingAuthorizationRequired();

      final entry = harness.notifier.enterRepairMode();
      harness.notifier.cancelPendingOperation();

      expect(await entry, isNull);
    });
  });

  group('new-code requests', () {
    test('repeated new-code taps while opening issue one request', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await harness.metadataStore.enterBindingAuthorizationRequired();
      await harness.notifier.enterRepairMode();
      await _driveToOtpEntry(harness);
      harness.notifier.clearStep();

      harness.clock = harness.clock.add(const Duration(seconds: 61));
      final openGate = Completer<void>();
      harness.opener.onOpen = () => openGate.future;
      final first = harness.notifier.requestNewCode();
      await harness.notifier.requestNewCode();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(harness.opener.openCalls, 2);
      expect(harness.state.errorMessage, isNull);

      harness.opener.onOpen = null;
      openGate.complete();
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (harness.state.step is ShowOtpEntry) break;
      }
      expect(harness.state.step, isA<ShowOtpEntry>());

      harness.notifier.submitOtp('000000');
      await first;
      expect(harness.opener.openCalls, 2);
      expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    });
  });
}
