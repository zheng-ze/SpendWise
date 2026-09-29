import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_database.dart' show LedgerDatabase;
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../../support/recording_ledger_store.dart';
import '../../../sync/in_memory_secret_store.dart';
import 'sync_enrollment_flow_test.dart'
    show FakeSessionOpener, FakeSyncEnrollmentSession;

const _identifierField = Key('syncIdentifierField');
const _identifierContinue = Key('syncIdentifierContinue');
const _otpField = Key('syncOtpField');
const _otpNewCode = Key('syncOtpNewCode');

final class _Harness {
  late LedgerDatabase db;
  late SyncMetadataStore metadataStore;
  late FakeSessionOpener opener;
  late InMemorySecretStore secrets;
  late ProviderContainer container;
  DateTime clock = DateTime.utc(2026, 1, 1);
  int endedCalls = 0;

  Future<void> pumpRepairFlow(
    WidgetTester tester, {
    SyncEnrollmentPhase? seedPhase,
  }) async {
    db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    metadataStore = SyncMetadataStore(db);
    if (seedPhase == SyncEnrollmentPhase.bindingAuthorizationRequired) {
      await metadataStore.enterBindingAuthorizationRequired();
    } else if (seedPhase == SyncEnrollmentPhase.sessionReauthRequired) {
      await metadataStore.enterSnapshotInProgress();
      await metadataStore.enterSessionReauthRequired();
    }
    opener = FakeSessionOpener();
    secrets = InMemorySecretStore();
    final now = clock;
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
            now: () => clock,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    clock = now;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SyncEnrollmentFlow(
            repairMode: true,
            onEnded: () => endedCalls++,
          ),
        ),
      ),
    );
    await pumpRepairFrames(tester);
  }

  SyncEnrollmentState get state =>
      container.read(syncEnrollmentViewModelProvider);
}

Future<void> pumpRepairFrames(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> submitIdentifier(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byKey(_identifierField), identifier);
  await tester.pump();
  await tester.tap(find.byKey(_identifierContinue));
  await tester.pump();
}

Future<void> driveToOtpEntry(
  WidgetTester tester,
  FakeSyncEnrollmentSession session,
) async {
  session.onEnroll = () async {
    await session.resolveOtp!(
      EnrollmentChallenge(const {'identifier': 'user@example.com'}),
    );
  };
  await submitIdentifier(tester, 'user@example.com');
  await pumpRepairFrames(tester);
}

void main() {
  group('repair identifier and OTP copy', () {
    testWidgets('identifier entry explains code replacement', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(
        tester,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );

      expect(find.text('Repair Device Access'), findsOneWidget);
      expect(
        find.text(
          'Requesting a new code replaces the previous one. '
          'Only the newest code will work.',
        ),
        findsOneWidget,
      );
      expect(find.byType(BackendPickerScreen), findsNothing);
    });

    testWidgets('OTP entry explains replacement and gates the new-code '
        'action on the cooldown', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(
        tester,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      await driveToOtpEntry(tester, harness.opener.session);

      expect(find.byKey(_otpField), findsOneWidget);
      expect(
        find.text('Requesting a new code replaces the previous one.'),
        findsOneWidget,
      );
      final gated = tester.widget<TextButton>(find.byKey(_otpNewCode));
      expect(gated.onPressed, isNull);
      expect(find.text('Send a new code in 60s'), findsOneWidget);

      harness.clock = harness.clock.add(const Duration(seconds: 61));
      await pumpRepairFrames(tester);

      final released = tester.widget<TextButton>(find.byKey(_otpNewCode));
      expect(released.onPressed, isNotNull);
      expect(find.text('Send a new code'), findsOneWidget);
    });
  });
}
