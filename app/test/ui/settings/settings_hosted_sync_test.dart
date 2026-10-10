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
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../support/recording_ledger_store.dart';
import '../../sync/in_memory_secret_store.dart';
import '../sync/enrollment/sync_enrollment_flow_test.dart'
    show FakeSessionOpener;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Ledger buildLedger() {
    final account = Account(name: 'Checking', type: AccountType.checking);
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
  }

  Future<
    ({
      ProviderContainer container,
      SyncMetadataStore metadataStore,
      FakeSessionOpener opener,
    })
  >
  pumpSettingsFlow(WidgetTester tester, HostedSyncStatus? status) async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final metadataStore = SyncMetadataStore(db);
    final opener = FakeSessionOpener();
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger()),
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
    return (container: container, metadataStore: metadataStore, opener: opener);
  }

  testWidgets('binding repair shows its explanation and one repair action', (
    tester,
  ) async {
    await pumpSettingsFlow(tester, const HostedSyncBindingRepair());

    expect(find.text('Hosted sync'), findsOneWidget);
    expect(find.text('Binding repair needed'), findsOneWidget);
    expect(
      find.text(
        'Device access must be authorized again. '
        'Reconciliation will run before sync writes resume.',
      ),
      findsOneWidget,
    );
    expect(find.text('Repair Device Access'), findsOneWidget);
  });

  testWidgets('session reauth shows its distinct explanation and one action', (
    tester,
  ) async {
    await pumpSettingsFlow(tester, const HostedSyncSessionReauth());

    expect(find.text('Sign-in expired'), findsOneWidget);
    expect(
      find.text(
        'Your sync sign-in expired. Existing device access will be kept.',
      ),
      findsOneWidget,
    );
    expect(find.text('Repair Device Access'), findsOneWidget);
  });

  testWidgets('non-repair statuses show read-only text with no repair action', (
    tester,
  ) async {
    final cases = <HostedSyncStatus, String>{
      const HostedSyncNoSelection(): 'Not configured',
      const HostedSyncSetupPending(): 'Setup pending',
      const HostedSyncReady(): 'Ready',
      const HostedSyncUnsupportedV2(): 'Unsupported endpoint',
      const HostedSyncUnavailable(): 'Status unavailable',
    };
    for (final entry in cases.entries) {
      await pumpSettingsFlow(tester, entry.key);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Repair Device Access'), findsNothing);
    }
  });

  testWidgets('custom selection shows the unsupported-v2 notice', (
    tester,
  ) async {
    await pumpSettingsFlow(tester, const HostedSyncUnsupportedV2());

    expect(
      find.text('Custom endpoints are not supported by sync protocol v2.'),
      findsOneWidget,
    );
    expect(find.text('Repair Device Access'), findsNothing);
  });

  testWidgets('unavailable status explains that it could not be read', (
    tester,
  ) async {
    await pumpSettingsFlow(tester, const HostedSyncUnavailable());

    expect(find.text('Sync status could not be read.'), findsOneWidget);
    expect(find.text('Repair Device Access'), findsNothing);
  });

  testWidgets('tapping Repair Device Access opens the repair flow, '
      'not the backend picker', (tester) async {
    final harness = await pumpSettingsFlow(
      tester,
      const HostedSyncBindingRepair(),
    );
    await harness.metadataStore.enterBindingAuthorizationRequired();
    await harness.container.read(appBootProvider).refreshSyncStatus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repair Device Access'));
    await tester.pumpAndSettle();

    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsNothing);
  });

  testWidgets('completing repair returns to refreshed Settings', (
    tester,
  ) async {
    final harness = await pumpSettingsFlow(
      tester,
      const HostedSyncBindingRepair(),
    );
    await harness.metadataStore.enterBindingAuthorizationRequired();

    await tester.tap(find.text('Repair Device Access'));
    await tester.pumpAndSettle();
    expect(find.byType(SyncIdentifierScreen), findsOneWidget);

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
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('syncOtpField')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('syncOtpField')), '482916');
    await tester.pump();
    await tester.tap(find.byKey(const Key('syncOtpSubmit')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Device access restored'), findsOneWidget);

    await tester.tap(find.byKey(const Key('syncRepairDone')));
    await tester.pumpAndSettle();

    expect(find.byType(SyncIdentifierScreen), findsNothing);
    expect(find.text('Hosted sync'), findsOneWidget);
    expect(find.text('Repair Device Access'), findsOneWidget);
  });

  testWidgets('mounting SettingsFlow refreshes a changed durable phase', (
    tester,
  ) async {
    final harness = await pumpSettingsFlow(tester, null);
    expect(find.text('Not configured'), findsOneWidget);

    await harness.metadataStore.setBackendSelection(
      backend: SyncBackendKind.supabase,
    );
    await harness.metadataStore.enterBindingAuthorizationRequired();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const MaterialApp(home: SettingsFlow()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Binding repair needed'), findsOneWidget);
    expect(find.text('Repair Device Access'), findsOneWidget);
  });
}
