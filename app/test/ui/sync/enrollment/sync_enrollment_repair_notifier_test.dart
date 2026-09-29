import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
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
  int snapshotReads = 0;

  void build({bool repairMode = true, bool stubAppBoot = false}) {
    db = LedgerDatabase(NativeDatabase.memory());
    metadataStore = SyncMetadataStore(db);
    opener = FakeSessionOpener();
    secrets = InMemorySecretStore();
    container = ProviderContainer(
      overrides: [
        if (stubAppBoot)
          appBootProvider.overrideWith(
            (ref) => AppBoot(
              createStore: () async => RecordingLedgerStore(),
              seedChanges: () => const [],
              readSyncSnapshot: () {
                snapshotReads++;
                return metadataStore.snapshot();
              },
            ),
          ),
        ledgerDatabaseProvider.overrideWithValue(db),
        syncMetadataStoreProvider.overrideWithValue(metadataStore),
        syncEnrollmentViewModelProvider.overrideWith(
          () => SyncEnrollmentNotifier(
            sessionOpener: opener.call,
            secretStore: secrets,
            repairMode: repairMode,
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

  void rebuildNotifier() {
    container.dispose();
    container = ProviderContainer(
      overrides: [
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

  SyncEnrollmentNotifier get notifier =>
      container.read(syncEnrollmentViewModelProvider.notifier);

  SyncEnrollmentState get state =>
      container.read(syncEnrollmentViewModelProvider);
}

Future<void> _seedRepair(_Harness harness, SyncEnrollmentPhase phase) async {
  if (phase == SyncEnrollmentPhase.sessionReauthRequired) {
    await harness.metadataStore.enterSnapshotInProgress();
    await harness.metadataStore.enterSessionReauthRequired();
  } else {
    await harness.metadataStore.enterBindingAuthorizationRequired();
  }
  await harness.notifier.enterRepairMode();
}

void _collectOtpOnEnroll(_Harness harness) {
  harness.opener.session.onEnroll = () async {
    await harness.opener.session.resolveOtp!(
      EnrollmentChallenge(const {'identifier': 'user@example.com'}),
    );
  };
}

Future<void> _submitOtpFlow(
  _Harness harness,
  String identifier,
  String otp,
) async {
  _collectOtpOnEnroll(harness);
  final pending = harness.notifier.submitIdentifier(identifier);
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (harness.state.step is ShowOtpEntry) break;
  }
  expect(harness.state.step, isA<ShowOtpEntry>());
  harness.notifier.submitOtp(otp);
  await pending;
}

void main() {
  group('repair OTP entry (TS1)', () {
    for (final phase in [
      SyncEnrollmentPhase.bindingAuthorizationRequired,
      SyncEnrollmentPhase.sessionReauthRequired,
    ]) {
      test('opens a live OTP resolver from $phase', () async {
        final harness = _Harness()..build();
        addTearDown(harness.dispose);
        await _seedRepair(harness, phase);

        String? seenOtp;
        harness.opener.session.onEnroll = () async {
          seenOtp = await harness.opener.session.resolveOtp!(
            EnrollmentChallenge(const {'identifier': 'user@example.com'}),
          );
        };
        final pending = harness.notifier.submitIdentifier('user@example.com');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(harness.opener.identifiers, ['user@example.com']);
        expect(harness.state.step, isA<ShowOtpEntry>());
        expect(harness.state.repairPhase, phase);
        expect(harness.state.explainCodeReplacement, isTrue);

        harness.notifier.submitOtp('482916');
        await pending;

        expect(seenOtp, '482916');
        expect(harness.opener.session.enrollCalls, 1);
      });

      test(
        'retry from $phase returns to identifier entry without resuming',
        () async {
          final harness = _Harness()..build();
          addTearDown(harness.dispose);
          await _seedRepair(harness, phase);

          await harness.notifier.retry();

          expect(harness.state.step, isA<ShowIdentifierEntry>());
          expect(harness.opener.openCalls, 0);
          expect(harness.opener.session.enrollCalls, 0);
        },
      );

      test('works after notifier recreation from $phase', () async {
        final harness = _Harness()..build();
        addTearDown(harness.dispose);
        await _seedRepair(harness, phase);
        harness.rebuildNotifier();
        await harness.notifier.enterRepairMode();
        expect(harness.state.identifier, isEmpty);

        _collectOtpOnEnroll(harness);
        final pending = harness.notifier.submitIdentifier('user@example.com');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(harness.state.step, isA<ShowOtpEntry>());

        harness.notifier.submitOtp('482916');
        await pending;

        expect(harness.opener.session.enrollCalls, 1);
      });
    }

    test('ordinary-phase retry still resumes without OTP', () async {
      final harness = _Harness()..build(repairMode: false);
      addTearDown(harness.dispose);
      await harness.metadataStore.enterSnapshotInProgress();
      harness.opener.session.onEnroll = () async {};

      await harness.notifier.retry();

      expect(harness.opener.session.enrollCalls, 1);
      expect(harness.opener.session.resolveOtpCalls, 0);
      expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    });
  });

  group('repair cancellation token (TS1)', () {
    test('disposing before the resolver exists releases the guard and '
        'ignores the late session', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      final gate = Completer<void>();
      harness.opener.onOpen = () => gate.future;
      harness.opener.session.onEnroll = () async {};

      final pending = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.state.inFlight, isTrue);
      harness.notifier.clearStep();

      harness.notifier.cancelPendingOperation();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.state.inFlight, isFalse);

      gate.complete();
      await pending;

      expect(harness.state.step, isNull);
      expect(harness.opener.session.enrollCalls, 0);
      expect(
        () => harness.opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        ),
        throwsA(isA<SyncEnrollmentOtpCancelled>()),
      );
    });

    test('disposing while enroll is pending skips completion and, with no proof, publication', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      final enrollGate = Completer<void>();
      harness.opener.session.onEnroll = () async {
        await harness.opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        );
        await enrollGate.future;
      };
      final pending = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.state.step, isA<ShowOtpEntry>());
      harness.notifier.submitOtp('482916');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      harness.notifier.cancelPendingOperation();
      enrollGate.complete();
      await pending;

      expect(harness.state.step, isA<ShowOtpEntry>());
      expect(harness.opener.session.publishCalls, 0);
      expect(harness.state.inFlight, isFalse);
    });

    test(
      'disposing while enroll is pending still publishes a stored write proof '
      'without completing',
      () async {
        final harness = _Harness()..build();
        addTearDown(harness.dispose);
        await _seedRepair(
          harness,
          SyncEnrollmentPhase.bindingAuthorizationRequired,
        );
        await harness.secrets.write(syncWriteProofSecretKey, 'proof-1');
        final enrollGate = Completer<void>();
        harness.opener.session.onEnroll = () async {
          await harness.opener.session.resolveOtp!(
            EnrollmentChallenge(const {'identifier': 'user@example.com'}),
          );
          await enrollGate.future;
        };
        final pending = harness.notifier.submitIdentifier('user@example.com');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(harness.state.step, isA<ShowOtpEntry>());
        harness.notifier.submitOtp('482916');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        harness.notifier.cancelPendingOperation();
        enrollGate.complete();
        await pending;

        expect(harness.state.step, isA<ShowOtpEntry>());
        expect(harness.opener.session.publishCalls, 1);
        expect(harness.state.inFlight, isFalse);
      },
    );

    test('a new repair waits for an abandoned publication to finish', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      await harness.secrets.write(syncWriteProofSecretKey, 'proof-1');
      final enrollGate = Completer<void>();
      final publishGate = Completer<void>();
      harness.opener.session.onEnroll = () async {
        await harness.opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        );
        await enrollGate.future;
      };
      harness.opener.session.onPublish = () async {
        await publishGate.future;
        return const EnrollmentSnapshotPublished();
      };
      final first = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      harness.notifier.submitOtp('482916');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      harness.notifier.cancelPendingOperation();
      enrollGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.opener.session.publishCalls, 1);

      harness.clock = harness.clock.add(const Duration(seconds: 61));
      final second = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.opener.openCalls, 1);

      publishGate.complete();
      await first;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.opener.openCalls, 2);
      harness.notifier.cancelPendingOperation();
      await second;
    });

    test('disposing while enroll is pending still refreshes the durable '
        'status once the service settles', () async {
      final harness = _Harness()..build(stubAppBoot: true);
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      final enrollGate = Completer<void>();
      harness.opener.session.onEnroll = () => enrollGate.future;
      final pending = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.opener.session.enrollCalls, 1);
      final readsBeforeCancel = harness.snapshotReads;

      harness.notifier.cancelPendingOperation();
      enrollGate.complete();
      await pending;

      expect(harness.snapshotReads, greaterThan(readsBeforeCancel));
    });

    test('a late operation cannot overwrite a newer one', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      final gate = Completer<void>();
      harness.opener.onOpen = () => gate.future;
      final stale = harness.notifier.submitIdentifier('stale@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      harness.notifier.cancelPendingOperation();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      harness.opener.onOpen = null;
      _collectOtpOnEnroll(harness);
      final fresh = harness.notifier.submitIdentifier('fresh@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.state.step, isA<ShowOtpEntry>());
      harness.notifier.submitOtp('482916');

      gate.complete();
      await stale;
      await fresh;

      expect(harness.opener.openCalls, 2);
      expect(harness.opener.session.enrollCalls, 1);
      expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    });
  });

  group('repair failure copy and cooldown (TS1)', () {
    test('sanitizes exception and server messages', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      harness.opener.errorOnOpen = StateError(
        'bearer stub-bearer secret hunter2 user@example.com',
      );

      await harness.notifier.submitIdentifier('user@example.com');

      expect(harness.state.step, isA<ShowIdentifierEntry>());
      expect(harness.state.errorMessage, isNotNull);
      expect(harness.state.errorMessage, isNot(contains('stub-bearer')));
      expect(harness.state.errorMessage, isNot(contains('hunter2')));
      expect(harness.state.errorMessage, isNot(contains('user@example.com')));
    });

    test('maps an invalid code to fixed copy without server text', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(harness, SyncEnrollmentPhase.sessionReauthRequired);
      harness.opener.session.onEnroll = () async {
        throw const SyncEnrollmentException(
          step: 'completeEnrollment',
          code: 'invalid_request',
          message: 'server: bad otp 482916 for user@example.com',
        );
      };

      await harness.notifier.submitIdentifier('user@example.com');

      expect(harness.state.step, isA<ShowIdentifierEntry>());
      expect(harness.state.errorMessage, isNotNull);
      expect(harness.state.errorMessage, isNot(contains('482916')));
      expect(harness.state.errorMessage, isNot(contains('user@example.com')));
    });

    test('blocks a new code request for 60 seconds', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      _collectOtpOnEnroll(harness);
      final pending = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      harness.notifier.submitOtp('482916');
      await pending;
      expect(harness.opener.openCalls, 1);

      await harness.notifier.submitIdentifier('user@example.com');

      expect(harness.opener.openCalls, 1);
      expect(harness.state.errorMessage, contains('Send a new code in'));
    });

    test('a longer server retryAfter extends the cooldown', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      harness.opener.session.onEnroll = () async {
        throw const SyncEnrollmentException(
          step: 'completeEnrollment',
          code: 'rate_limited',
          retryAfter: Duration(seconds: 120),
        );
      };

      await harness.notifier.submitIdentifier('user@example.com');

      expect(harness.state.errorMessage, contains('wait'));
      harness.clock = harness.clock.add(const Duration(seconds: 61));
      await harness.notifier.submitIdentifier('user@example.com');
      expect(harness.opener.openCalls, 1);

      harness.clock = harness.clock.add(const Duration(seconds: 61));
      _collectOtpOnEnroll(harness);
      final pending = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(harness.opener.openCalls, 2);
      harness.notifier.submitOtp('482916');
      await pending;
    });

    test('a Retry-After beyond the display cap surfaces bounded copy on the '
        'cooldown rejection too', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      harness.opener.session.onEnroll = () async {
        throw const SyncEnrollmentException(
          step: 'completeEnrollment',
          code: 'rate_limited',
          retryAfter: Duration(seconds: 3600),
        );
      };
      await harness.notifier.submitIdentifier('user@example.com');

      await harness.notifier.submitIdentifier('user@example.com');

      expect(harness.state.errorMessage, contains('wait'));
      expect(harness.state.errorMessage, isNot(contains('3600')));
      expect(harness.opener.openCalls, 1);
    });
  });

  group('repair proof-aware completion (TS1)', () {
    test('publishes when a write proof is present', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(
        harness,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      await harness.secrets.write(syncWriteProofSecretKey, 'proof-1');
      await _submitOtpFlow(harness, 'user@example.com', '482916');

      expect(harness.opener.session.publishCalls, 1);
      expect(harness.state.step, isA<ShowEnrollmentCompleted>());
      expect(await harness.secrets.read(syncWriteProofSecretKey), 'proof-1');
    });

    test('skips publication when no write proof is present', () async {
      final harness = _Harness()..build();
      addTearDown(harness.dispose);
      await _seedRepair(harness, SyncEnrollmentPhase.sessionReauthRequired);
      await _submitOtpFlow(harness, 'user@example.com', '482916');

      expect(harness.opener.session.publishCalls, 0);
      expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    });
  });
}
