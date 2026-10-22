import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/database/ledger_database.dart'
    show LedgerDatabase;
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';

import '../../support/recording_ledger_store.dart';
import '../../sync/in_memory_secret_store.dart';
import '../sync/enrollment/sync_enrollment_flow_test.dart'
    show FakeSessionOpener;
import '../../support/ui_test_timeout.dart';

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
  }, timeout: uiTestTimeout);
}
