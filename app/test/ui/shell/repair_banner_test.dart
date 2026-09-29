import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/banner_state.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/ledger_database.dart' show LedgerDatabase;
import 'package:spendwise/persistence/ledger_store.dart';
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

Future<
  ({
    ProviderContainer container,
    SyncMetadataStore metadataStore,
    FakeSessionOpener opener,
  })
>
_pumpShell(
  WidgetTester tester, {
  HostedSyncStatus status = const HostedSyncNoSelection(),
  BannerState? banner,
  Map<ShellDestination, WidgetBuilder>? bodies,
  SyncEnrollmentPhase? seedPhase,
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
      hostedSyncStatusProvider.overrideWith(
        (ref) => ref.watch(_statusStateProvider),
      ),
      if (banner != null) bannerStateProvider.overrideWith((ref) => banner),
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
  container.read(_statusStateProvider.notifier).state = status;

  tester.view.physicalSize = _compact;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: AppShell(
          bodies:
              bodies ??
              {
                ShellDestination.transactions: (context) =>
                    const Text('transactions body'),
                ShellDestination.settings: (context) => const SettingsFlow(),
              },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, metadataStore: metadataStore, opener: opener);
}

void main() {
  testWidgets('binding repair shows the persistent repair banner', (
    tester,
  ) async {
    await _pumpShell(tester, status: const HostedSyncBindingRepair());

    expect(find.text(_repairLabel), findsOneWidget);
  });

  testWidgets('session reauth shows the persistent repair banner', (
    tester,
  ) async {
    await _pumpShell(tester, status: const HostedSyncSessionReauth());

    expect(find.text(_repairLabel), findsOneWidget);
  });

  testWidgets('non-repair statuses show no repair banner', (tester) async {
    final cases = <HostedSyncStatus>[
      const HostedSyncNoSelection(),
      const HostedSyncSetupPending(),
      const HostedSyncReady(),
      const HostedSyncUnsupportedV2(),
      const HostedSyncUnavailable(),
    ];
    for (final status in cases) {
      await _pumpShell(tester, status: status);
      expect(find.text(_repairLabel), findsNothing);
    }
  });

  testWidgets('tapping the banner opens Repair Device Access once', (
    tester,
  ) async {
    final harness = await _pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );
    final container = harness.container;

    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsNothing);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('a tap before Settings was ever built still opens repair once', (
    tester,
  ) async {
    final harness = await _pumpShell(
      tester,
      status: const HostedSyncSessionReauth(),
      seedPhase: SyncEnrollmentPhase.sessionReauthRequired,
      bodies: {
        ShellDestination.transactions: (context) =>
            const SizedBox.expand(child: Text('transactions body')),
      },
    );
    final container = harness.container;
    expect(find.byType(SettingsFlow), findsNothing);
    await tester.tap(find.text(_repairLabel));
    await tester.pump();
    expect(
      container.read(settingsRootViewModelProvider).step,
      isA<RepairDeviceAccessRequested>(),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppShell(
            bodies: {
              ShellDestination.transactions: (context) =>
                  const Text('transactions body'),
              ShellDestination.settings: (context) => const SettingsFlow(),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('repair takes precedence over a timed banner message, '
      'which returns after repair ends', (tester) async {
    final banner = BannerState();
    final harness = await _pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      banner: banner,
    );
    final container = harness.container;

    banner.receiveSaveState(SaveBannerState.retrying);
    await tester.pump();

    expect(find.text(_repairLabel), findsOneWidget);
    expect(find.text("Couldn't save changes, retrying"), findsNothing);

    container.read(_statusStateProvider.notifier).state =
        const HostedSyncReady();
    await tester.pumpAndSettle();

    expect(find.text(_repairLabel), findsNothing);
    expect(find.text("Couldn't save changes, retrying"), findsOneWidget);
  });

  testWidgets('repeated taps do not stack repair routes', (tester) async {
    await _pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );

    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();

    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
  });

  testWidgets('the repair banner has no dismiss affordance', (tester) async {
    await _pumpShell(tester, status: const HostedSyncBindingRepair());

    expect(find.byType(Dismissible), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.clear), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
  });

  testWidgets('the repair banner exposes button semantics with its label', (
    tester,
  ) async {
    await _pumpShell(tester, status: const HostedSyncBindingRepair());

    expect(find.bySemanticsLabel(_repairLabel), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_repairLabel)),
      matchesSemantics(
        label: _repairLabel,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
  });
}
