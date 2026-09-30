import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/ledger_database.dart' show LedgerDatabase;
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../support/recording_ledger_store.dart';
import '../../sync/in_memory_secret_store.dart';
import '../sync/enrollment/sync_enrollment_flow_test.dart'
    show FakeSessionOpener;

const _hostedTile = Key('hostedSyncStatus');

Ledger _buildLedger() {
  final account = Account(name: 'Checking', type: AccountType.checking);
  return Ledger(
    state: LedgerState(
      moneySources: {account.id: MoneySource.account(account)},
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<
  ({
    ProviderContainer container,
    SyncMetadataStore metadataStore,
    FakeSessionOpener opener,
  })
>
pumpFreshSettings(WidgetTester tester, {HostedSyncStatus? status}) async {
  SharedPreferences.setMockInitialValues({});
  final db = LedgerDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final metadataStore = SyncMetadataStore(db);
  final opener = FakeSessionOpener();
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(_buildLedger()),
      if (status != null) hostedSyncStatusProvider.overrideWithValue(status),
      ledgerDatabaseProvider.overrideWithValue(db),
      syncMetadataStoreProvider.overrideWithValue(metadataStore),
      appBootProvider.overrideWith(
        (ref) => AppBoot(
          createStore: () async => RecordingLedgerStore(),
          seedChanges: () => const [],
          readSyncSnapshot: () => metadataStore.snapshot(),
        ),
      ),
      syncEnrollmentViewModelProvider.overrideWith(
        () => SyncEnrollmentNotifier(
          sessionOpener: opener.call,
          secretStore: InMemorySecretStore(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsFlow()),
    ),
  );
  await tester.pumpAndSettle();
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.settings;
  await tester.pumpAndSettle();
  return (container: container, metadataStore: metadataStore, opener: opener);
}

Future<void> _refreshAndSettle(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await container.read(appBootProvider).refreshSyncStatus();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('NoSelection tile opens exactly one backend picker', (
    tester,
  ) async {
    final harness = await pumpFreshSettings(tester);
    expect(find.text('Not configured'), findsOneWidget);

    final tile = tester.widget<ListTile>(find.byKey(_hostedTile));
    expect(tile.onTap, isNotNull);
    expect(tile.trailing, isA<Icon>());

    await tester.tap(find.byKey(_hostedTile));
    await tester.tap(find.byKey(_hostedTile), warnIfMissed: false);
    harness.container
        .read(settingsRootViewModelProvider.notifier)
        .requestStartHostedEnrollment();
    await _pumpFrames(tester);

    expect(
      find.byType(SyncEnrollmentFlow, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(BackendPickerScreen), findsOneWidget);
    expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);
    expect(harness.container.read(settingsRootViewModelProvider).step, isNull);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester);

    expect(find.byType(SyncEnrollmentFlow, skipOffstage: false), findsNothing);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(find.text('Not configured'), findsOneWidget);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
  });

  testWidgets('hosted is preselected and continuing reaches identifier entry', (
    tester,
  ) async {
    final harness = await pumpFreshSettings(tester);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);

    expect(
      harness.container.read(backendPickerViewModelProvider).selectedBackend,
      SyncBackendKind.supabase,
    );
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('syncIdentifierField')), findsOneWidget);
  });

  testWidgets('an unpersisted custom choice does not stick across reopen', (
    tester,
  ) async {
    final harness = await pumpFreshSettings(tester);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    await tester.tap(find.text('Custom server'));
    await tester.pump();
    expect(
      harness.container.read(backendPickerViewModelProvider).selectedBackend,
      SyncBackendKind.custom,
    );

    await tester.tap(find.byKey(const Key('syncPickerBack')));
    await _pumpFrames(tester);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
    expect(find.text('Not configured'), findsOneWidget);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    expect(
      harness.container.read(backendPickerViewModelProvider).selectedBackend,
      SyncBackendKind.supabase,
    );
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('syncIdentifierField')), findsOneWidget);
  });

  testWidgets('SetupPending re-entry preserves the durable tuple and '
      'a notEnrolled phase enrolls with one OTP', (tester) async {
    final harness = await pumpFreshSettings(tester);
    await harness.metadataStore.setBackendSelection(
      backend: SyncBackendKind.supabase,
    );
    await _refreshAndSettle(tester, harness.container);
    expect(find.text('Setup pending'), findsOneWidget);

    final tile = tester.widget<ListTile>(find.byKey(_hostedTile));
    expect(tile.onTap, isNotNull);
    expect(tile.trailing, isA<Icon>());

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    expect(find.byType(BackendPickerScreen), findsOneWidget);

    final before = await harness.metadataStore.snapshot();
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('syncIdentifierField')), findsOneWidget);
    final after = await harness.metadataStore.snapshot();
    expect(after.phase, before.phase);
    expect(after.deviceBindingState, before.deviceBindingState);
    expect(after.backend, SyncBackendKind.supabase);

    harness.opener.session.onEnroll = () async {
      await harness.opener.session.resolveOtp!(
        EnrollmentChallenge(const {'identifier': 'user@example.com'}),
      );
    };
    await tester.enterText(
      find.byKey(const Key('syncIdentifierField')),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('syncIdentifierContinue')));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('syncOtpField')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('syncOtpField')), '482916');
    await tester.pump();
    await tester.tap(find.byKey(const Key('syncOtpSubmit')));
    await _pumpFrames(tester);

    expect(harness.opener.openCalls, 1);
    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });

  testWidgets('a bound in-progress phase retries from resume without '
      'another OTP', (tester) async {
    final harness = await pumpFreshSettings(tester);
    await harness.metadataStore.setBackendSelection(
      backend: SyncBackendKind.supabase,
    );
    await harness.metadataStore.enterSnapshotInProgress();
    await _refreshAndSettle(tester, harness.container);
    expect(find.text('Setup pending'), findsOneWidget);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('syncIdentifierField')), findsOneWidget);
    final continued = await harness.metadataStore.snapshot();
    expect(continued.phase, SyncEnrollmentPhase.snapshotInProgress);
    expect(continued.deviceBindingState, SyncDeviceBindingState.bound);

    harness.opener.session.onEnroll = () async {
      throw const SyncEnrollmentException(
        step: 'reconcileBegin',
        code: 'unavailable',
      );
    };
    await tester.enterText(
      find.byKey(const Key('syncIdentifierField')),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('syncIdentifierContinue')));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('syncResumeRetry')), findsOneWidget);
    expect(find.byKey(const Key('syncOtpField')), findsNothing);
    expect(harness.opener.session.resolveOtpCalls, 0);

    harness.opener.session.onEnroll = () async {};
    await tester.tap(find.byKey(const Key('syncResumeRetry')));
    await _pumpFrames(tester);

    expect(harness.opener.openCalls, 1);
    expect(harness.opener.session.resolveOtpCalls, 0);
    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });

  testWidgets('ineligible statuses keep a passive tile with existing copy', (
    tester,
  ) async {
    final cases = <HostedSyncStatus, String>{
      const HostedSyncReady(): 'Ready',
      const HostedSyncBindingRepair(): 'Binding repair needed',
      const HostedSyncSessionReauth(): 'Sign-in expired',
      const HostedSyncUnsupportedV2(): 'Unsupported endpoint',
      const HostedSyncUnavailable(): 'Status unavailable',
    };
    for (final entry in cases.entries) {
      await pumpFreshSettings(tester, status: entry.key);
      expect(find.text('Hosted sync'), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
      final tile = tester.widget<ListTile>(find.byKey(_hostedTile));
      expect(tile.onTap, isNull);
      expect(tile.trailing, isNull);
      expect(find.byType(BackendPickerScreen), findsNothing);
    }
  });

  testWidgets('binding repair tile still opens repair identifier entry, '
      'not the picker', (tester) async {
    final harness = await pumpFreshSettings(
      tester,
      status: const HostedSyncBindingRepair(),
    );
    await harness.metadataStore.enterBindingAuthorizationRequired();
    await _refreshAndSettle(tester, harness.container);
    expect(find.text('Repair Device Access'), findsOneWidget);

    await tester.tap(find.text('Repair Device Access'));
    await _pumpFrames(tester);

    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);
    expect(harness.container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('session reauth tile still opens repair identifier entry, '
      'not the picker', (tester) async {
    final harness = await pumpFreshSettings(
      tester,
      status: const HostedSyncSessionReauth(),
    );
    await harness.metadataStore.enterBindingAuthorizationRequired();
    await _refreshAndSettle(tester, harness.container);
    expect(find.text('Repair Device Access'), findsOneWidget);

    await tester.tap(find.text('Repair Device Access'));
    await _pumpFrames(tester);

    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);
    expect(harness.container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('a fresh step in an ineligible status pushes no route and '
      'is consumed', (tester) async {
    final harness = await pumpFreshSettings(
      tester,
      status: const HostedSyncReady(),
    );

    harness.container
        .read(settingsRootViewModelProvider.notifier)
        .requestStartHostedEnrollment();
    await _pumpFrames(tester);

    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(find.byType(SyncIdentifierScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
    expect(harness.container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('persisting hosted then closing projects Setup pending', (
    tester,
  ) async {
    final harness = await pumpFreshSettings(tester);
    expect(find.text('Not configured'), findsOneWidget);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('syncIdentifierField')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester);
    expect(find.byType(BackendPickerScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester);

    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
    expect(find.text('Setup pending'), findsOneWidget);
  });

  testWidgets('system back at the picker root closes the route and '
      'clears the shared flag', (tester) async {
    final harness = await pumpFreshSettings(tester);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    expect(find.byType(BackendPickerScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester);

    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
    expect(find.text('Not configured'), findsOneWidget);
  });

  testWidgets('the picker close control closes the route', (tester) async {
    final harness = await pumpFreshSettings(tester);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('syncPickerBack')));
    await _pumpFrames(tester);

    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
    expect(find.text('Not configured'), findsOneWidget);
  });

  testWidgets('fresh completion Done closes the route, clears the flag, '
      'and shows Ready', (tester) async {
    final harness = await pumpFreshSettings(tester);

    await tester.tap(find.byKey(_hostedTile));
    await _pumpFrames(tester);
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);

    harness.opener.session.onEnroll = () async {
      await harness.opener.session.resolveOtp!(
        EnrollmentChallenge(const {'identifier': 'user@example.com'}),
      );
    };
    await tester.enterText(
      find.byKey(const Key('syncIdentifierField')),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('syncIdentifierContinue')));
    await _pumpFrames(tester);
    await tester.enterText(find.byKey(const Key('syncOtpField')), '482916');
    await tester.pump();
    await tester.tap(find.byKey(const Key('syncOtpSubmit')));
    await _pumpFrames(tester);
    expect(find.text('Sync enrollment complete'), findsOneWidget);
    await harness.metadataStore.enterReconciliationComplete();
    await harness.metadataStore.enterGateEnabled();

    await tester.tap(find.byKey(const Key('syncFreshDone')));
    await _pumpFrames(tester);

    expect(find.text('Sync enrollment complete'), findsNothing);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
    expect(find.text('Ready'), findsOneWidget);
  });
}
