import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';

import '../../support/recording_ledger_store.dart';
import '../../sync/in_memory_secret_store.dart';
import '../sync/enrollment/sync_enrollment_flow_test.dart'
    show FakeSessionOpener;
import '../../support/ui_test_timeout.dart';

const _repairLabel = 'Sync needs attention - Repair Device Access';

const _compact = Size(400, 800);

final _statusStateProvider = StateProvider<HostedSyncStatus>(
  (ref) => const HostedSyncNoSelection(),
);

Ledger _buildLedger() {
  final account = Account(name: 'Checking', type: AccountType.checking);
  return Ledger(
    state: LedgerState(
      moneySources: {account.id: MoneySource.account(account)},
    ),
  );
}

Future<ProviderContainer> createEnrollmentContainer({
  HostedSyncStatus? status = const HostedSyncNoSelection(),
  SyncEnrollmentPhase? seedPhase,
  ShellLayoutMode? layoutMode,
  ShellPlatformFacts? platform,
}) async {
  SharedPreferences.setMockInitialValues({});
  final db = LedgerDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final metadataStore = SyncMetadataStore(db);
  if (seedPhase == SyncEnrollmentPhase.bindingAuthorizationRequired) {
    await metadataStore.enterBindingAuthorizationRequired();
  } else if (seedPhase == SyncEnrollmentPhase.sessionReauthRequired) {
    await metadataStore.enterSnapshotInProgress();
    await metadataStore.enterSessionReauthRequired();
  }
  final opener = FakeSessionOpener();
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(_buildLedger()),
      if (layoutMode != null)
        shellLayoutModeProvider.overrideWithValue(layoutMode),
      if (platform != null) shellPlatformProvider.overrideWithValue(platform),
      if (status != null)
        hostedSyncStatusProvider.overrideWith(
          (ref) => ref.watch(_statusStateProvider),
        ),
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
  if (status != null) {
    container.read(_statusStateProvider.notifier).state = status;
  }
  return container;
}

Future<ProviderContainer> pumpShell(
  WidgetTester tester, {
  HostedSyncStatus? status = const HostedSyncNoSelection(),
  Size size = _compact,
  required ShellLayoutMode layoutMode,
  SyncEnrollmentPhase? seedPhase,
  Map<ShellDestination, WidgetBuilder>? bodies,
}) async {
  final container = await createEnrollmentContainer(
    status: status,
    seedPhase: seedPhase,
    layoutMode: layoutMode,
  );

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: AppShell(
          bodies: {
            ShellDestination.history: (context) => const Text('history body'),
            ShellDestination.settings: (context) => const SettingsFlow(),
            ...?bodies,
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('binding repair shows the persistent repair banner', (
    tester,
  ) async {
    await pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      layoutMode: ShellLayoutMode.phone,
    );

    expect(find.text(_repairLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('session reauth shows the persistent repair banner', (
    tester,
  ) async {
    await pumpShell(
      tester,
      status: const HostedSyncSessionReauth(),
      layoutMode: ShellLayoutMode.phone,
    );

    expect(find.text(_repairLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('non-repair statuses show no repair banner', (tester) async {
    await pumpShell(
      tester,
      status: const HostedSyncReady(),
      layoutMode: ShellLayoutMode.phone,
    );

    expect(find.text(_repairLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('tapping the banner opens Repair Device Access once', (
    tester,
  ) async {
    final container = await pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      layoutMode: ShellLayoutMode.phone,
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );
    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
  }, timeout: uiTestTimeout);

  testWidgets('the banner is hidden while the repair route is open and '
      'returns after the repair route closes', (tester) async {
    final container = await pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      layoutMode: ShellLayoutMode.phone,
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );

    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();

    expect(container.read(enrollmentFlowOpenProvider), isTrue);
    expect(find.text(_repairLabel), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(container.read(enrollmentFlowOpenProvider), isFalse);
    expect(find.byType(SyncIdentifierScreen), findsNothing);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
    expect(find.text(_repairLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('with the keyboard up the repair form keeps Continue '
      'tappable and the banner stays hidden', (tester) async {
    await pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      layoutMode: ShellLayoutMode.phone,
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );
    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final continueButton = find.byKey(const Key('syncIdentifierContinue'));
    expect(find.text(_repairLabel), findsNothing);
    expect(continueButton.hitTestable(), findsOneWidget);
  }, timeout: uiTestTimeout);
}
