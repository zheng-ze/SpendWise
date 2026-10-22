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
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';

import '../../support/recording_ledger_store.dart';
import '../../support/ui_test_timeout.dart';

const _hostedTile = Key('hostedSyncStatus');

Ledger _buildLedger() {
  final account = Account(name: 'Checking', type: AccountType.checking);
  return Ledger(
    state: LedgerState(
      moneySources: {account.id: MoneySource.account(account)},
    ),
  );
}

Future<ProviderContainer> pumpFreshSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final db = LedgerDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final metadataStore = SyncMetadataStore(db);
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(_buildLedger()),
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

void main() {
  testWidgets('NoSelection tile opens exactly one backend picker', (
    tester,
  ) async {
    final container = await pumpFreshSettings(tester);
    expect(find.text('Not configured'), findsOneWidget);

    await tester.tap(find.byKey(_hostedTile));
    await tester.tap(find.byKey(_hostedTile), warnIfMissed: false);
    container
        .read(settingsRootViewModelProvider.notifier)
        .requestStartHostedEnrollment();
    await tester.pumpAndSettle();

    expect(
      find.byType(SyncEnrollmentFlow, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(BackendPickerScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SyncEnrollmentFlow, skipOffstage: false), findsNothing);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(find.text('Not configured'), findsOneWidget);
  }, timeout: uiTestTimeout);
}
