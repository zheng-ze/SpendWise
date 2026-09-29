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

import '../../support/recording_ledger_store.dart';

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

  Future<ProviderContainer> pumpSettingsFlow(
    WidgetTester tester,
    HostedSyncStatus status,
  ) async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final metadataStore = SyncMetadataStore(db);
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger()),
        hostedSyncStatusProvider.overrideWithValue(status),
        ledgerDatabaseProvider.overrideWithValue(db),
        syncMetadataStoreProvider.overrideWithValue(metadataStore),
        appBootProvider.overrideWith(
          (ref) => AppBoot(
            createStore: () async => RecordingLedgerStore(),
            seedChanges: () => const [],
            readSyncSnapshot: () => metadataStore.snapshot(),
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
    return container;
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
    final container = await pumpSettingsFlow(
      tester,
      const HostedSyncBindingRepair(),
    );
    final metadataStore = container.read(syncMetadataStoreProvider);
    await metadataStore.enterBindingAuthorizationRequired();
    await container.read(appBootProvider).refreshSyncStatus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repair Device Access'));
    await tester.pumpAndSettle();

    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsNothing);
  });
}
