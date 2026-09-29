import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_database.dart' show LedgerDatabase;
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
    test('enterRepairMode reports whether repair is still needed', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);

      expect(await harness.notifier.enterRepairMode(), isFalse);

      await harness.metadataStore.enterBindingAuthorizationRequired();
      expect(await harness.notifier.enterRepairMode(), isTrue);
    });

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
    test(
      'requestNewCode cancels the pending OTP and opens a new session',
      () async {
        final harness = _Harness()..build();
        addTearDown(harness.dispose);
        await harness.metadataStore.enterBindingAuthorizationRequired();
        await harness.notifier.enterRepairMode();
        final pending = await _driveToOtpEntry(harness);
        expect(harness.opener.openCalls, 1);

        harness.clock = harness.clock.add(const Duration(seconds: 61));
        _collectOtpOnEnroll(harness);
        harness.notifier.submitOtp('482916');
        await pending;
        harness.notifier.clearStep();

        _collectOtpOnEnroll(harness);
        final resend = harness.notifier.requestNewCode();
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (harness.state.step is ShowOtpEntry) break;
        }

        expect(harness.opener.openCalls, 2);
        expect(harness.opener.identifiers.last, 'user@example.com');
        expect(harness.state.step, isA<ShowOtpEntry>());

        harness.notifier.submitOtp('000000');
        await resend;
      },
    );

    test('requestNewCode during the cooldown opens no new session', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await harness.metadataStore.enterBindingAuthorizationRequired();
      await harness.notifier.enterRepairMode();
      final pending = await _driveToOtpEntry(harness);

      await harness.notifier.requestNewCode();

      expect(harness.opener.openCalls, 1);
      expect(harness.state.errorMessage, contains('Send a new code in'));

      harness.notifier.submitOtp('482916');
      await pending;
    });
  });

  group('cooldown observation', () {
    test(
      'no cooldown before a challenge, 60 seconds after, clear later',
      () async {
        final harness = _Harness()..build();
        addTearDown(harness.dispose);
        await harness.metadataStore.enterBindingAuthorizationRequired();
        await harness.notifier.enterRepairMode();

        expect(harness.notifier.codeCooldownRemaining(), isNull);

        final pending = await _driveToOtpEntry(harness);
        expect(
          harness.notifier.codeCooldownRemaining(),
          const Duration(seconds: 60),
        );

        harness.clock = harness.clock.add(const Duration(seconds: 61));
        expect(harness.notifier.codeCooldownRemaining(), isNull);

        harness.notifier.submitOtp('482916');
        await pending;
      },
    );
  });

  group('repair dismissal', () {
    test('dismissRepairFlow emits a single-shot close step', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);

      harness.notifier.dismissRepairFlow();

      expect(harness.state.step, isA<DismissRepairFlow>());
      harness.notifier.clearStep();
      expect(harness.state.step, isNull);
    });
  });
}
