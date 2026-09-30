import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync/sync.dart';

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
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';

import '../../support/recording_ledger_store.dart';
import '../../sync/in_memory_secret_store.dart';
import '../sync/enrollment/sync_enrollment_flow_test.dart'
    show FakeSessionOpener, pumpFlowFrames;

const _repairLabel = 'Sync needs attention - Repair Device Access';

const _compact = Size(400, 800);

final _statusStateProvider = StateProvider<HostedSyncStatus>(
  (ref) => const HostedSyncNoSelection(),
);

Finder _bannerSurface() => find
    .ancestor(of: find.text(_repairLabel), matching: find.byType(Material))
    .first;

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
  HostedSyncStatus? status = const HostedSyncNoSelection(),
  BannerState? banner,
  Map<ShellDestination, WidgetBuilder>? bodies,
  SyncEnrollmentPhase? seedPhase,
  List<SettingsStep>? settingsSteps,
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
      if (status != null)
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
  if (settingsSteps != null) {
    final subscription = container.listen(settingsRootViewModelProvider, (
      previous,
      next,
    ) {
      final step = next.step;
      if (step != null) settingsSteps.add(step);
    });
    addTearDown(subscription.close);
  }
  if (status != null) {
    container.read(_statusStateProvider.notifier).state = status;
  }

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
    await tester.tap(find.text(_repairLabel), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
  });

  testWidgets('the banner is hidden while the repair route is open and '
      'returns after it closes', (tester) async {
    final harness = await _pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );

    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();

    expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);
    expect(find.text(_repairLabel), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
    expect(find.byType(SyncIdentifierScreen), findsNothing);
    expect(find.text(_repairLabel), findsOneWidget);
  });

  testWidgets('the banner returns on other tabs while the repair route stays '
      'open and leads back to it', (tester) async {
    final harness = await _pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );
    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();
    expect(find.text(_repairLabel), findsNothing);

    harness.container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.transactions;
    await tester.pumpAndSettle();

    expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);
    expect(find.text(_repairLabel), findsOneWidget);

    await tester.tap(find.text(_repairLabel));
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.text(_repairLabel), findsNothing);
  });

  testWidgets('with the keyboard up the repair form keeps Continue '
      'tappable and the banner stays hidden', (tester) async {
    await _pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
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
  });

  testWidgets('a banner tap during the rail breakpoint transition opens '
      'exactly one repair route', (tester) async {
    final harness = await _pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );
    harness.container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsFlow), findsOneWidget);

    tester.view.physicalSize = const Size(900, 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SettingsFlow, skipOffstage: false), findsNWidgets(2));

    await tester.tap(find.text(_repairLabel).last);
    await tester.pump();

    expect(
      find.byType(SyncIdentifierScreen, skipOffstage: false),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(find.byType(SettingsFlow), findsOneWidget);
    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SyncIdentifierScreen), findsNothing);
    expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
  });

  testWidgets('coexisting Settings Flows keep one fresh route and hand it '
      'over when binding repair becomes required', (tester) async {
    final harness = await _pumpShell(tester, status: null);
    final container = harness.container;
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hostedSyncStatus')));
    await pumpFlowFrames(tester);
    final enrollmentRoute = find.byType(
      SyncEnrollmentFlow,
      skipOffstage: false,
    );
    expect(enrollmentRoute, findsOneWidget);
    expect(
      tester.widget<SyncEnrollmentFlow>(enrollmentRoute).repairMode,
      isFalse,
    );

    tester.view.physicalSize = const Size(900, 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SettingsFlow, skipOffstage: false), findsNWidgets(2));

    container
        .read(settingsRootViewModelProvider.notifier)
        .requestStartHostedEnrollment();
    await tester.pump();
    expect(enrollmentRoute, findsOneWidget);

    await harness.metadataStore.setBackendSelection(
      backend: SyncBackendKind.supabase,
    );
    await harness.metadataStore.enterBindingAuthorizationRequired();
    await container.read(appBootProvider).refreshSyncStatus();
    await tester.pump();
    expect(
      container.read(hostedSyncStatusProvider),
      isA<HostedSyncBindingRepair>(),
    );

    await pumpFlowFrames(tester);

    expect(find.byType(SettingsFlow, skipOffstage: false), findsOneWidget);
    expect(enrollmentRoute, findsOneWidget);
    expect(
      tester.widget<SyncEnrollmentFlow>(enrollmentRoute).repairMode,
      isFalse,
    );
    expect(find.byType(BackendPickerScreen), findsOneWidget);
    expect(container.read(enrollmentFlowOpenProvider), isTrue);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('fresh handover stops when the cached status is Ready', (
    tester,
  ) async {
    final harness = await _pumpShell(tester, status: null);
    final container = harness.container;
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hostedSyncStatus')));
    await pumpFlowFrames(tester);
    final enrollmentRoute = find.byType(
      SyncEnrollmentFlow,
      skipOffstage: false,
    );
    expect(enrollmentRoute, findsOneWidget);
    expect(
      tester.widget<SyncEnrollmentFlow>(enrollmentRoute).repairMode,
      isFalse,
    );

    await harness.metadataStore.setBackendSelection(
      backend: SyncBackendKind.supabase,
    );
    await harness.metadataStore.enterReconciliationComplete();
    await harness.metadataStore.enterGateEnabled();
    await container.read(appBootProvider).refreshSyncStatus();
    await tester.pump();
    expect(container.read(hostedSyncStatusProvider), isA<HostedSyncReady>());

    tester.view.physicalSize = const Size(900, 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SettingsFlow, skipOffstage: false), findsNWidgets(2));
    expect(enrollmentRoute, findsOneWidget);
    expect(container.read(enrollmentFlowOpenProvider), isTrue);

    await pumpFlowFrames(tester);

    expect(find.byType(SettingsFlow, skipOffstage: false), findsOneWidget);
    expect(enrollmentRoute, findsNothing);
    expect(container.read(enrollmentFlowOpenProvider), isFalse);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('a repair banner on another tab returns to the active fresh '
      'binding flow without requesting repair', (tester) async {
    final settingsSteps = <SettingsStep>[];
    final harness = await _pumpShell(
      tester,
      status: null,
      settingsSteps: settingsSteps,
    );
    final container = harness.container;
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    tester.view.physicalSize = const Size(900, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.byKey(const Key('hostedSyncStatus')));
    await pumpFlowFrames(tester);
    await tester.tap(find.text('Continue'));
    await pumpFlowFrames(tester);
    final enrollmentRoute = find.byType(
      SyncEnrollmentFlow,
      skipOffstage: false,
    );
    expect(enrollmentRoute, findsOneWidget);
    final freshFlow = tester.widget<SyncEnrollmentFlow>(enrollmentRoute);
    expect(freshFlow.repairMode, isFalse);

    harness.opener.session.onEnroll = () async {
      await harness.metadataStore.enterBindingAuthorizationRequired();
      await container.read(appBootProvider).refreshSyncStatus();
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
    await pumpFlowFrames(tester);

    expect(
      container.read(hostedSyncStatusProvider),
      isA<HostedSyncBindingRepair>(),
    );
    expect(container.read(enrollmentFlowOpenProvider), isTrue);
    expect(enrollmentRoute, findsOneWidget);
    expect(tester.widget<SyncEnrollmentFlow>(enrollmentRoute), same(freshFlow));
    expect(find.byType(SyncOtpScreen), findsOneWidget);
    expect(find.text(_repairLabel), findsNothing);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.transactions;
    await pumpFlowFrames(tester);
    expect(find.byType(SyncOtpScreen), findsNothing);
    expect(enrollmentRoute, findsOneWidget);
    expect(find.text(_repairLabel), findsOneWidget);

    await tester.tap(find.text(_repairLabel));
    await pumpFlowFrames(tester);

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
    expect(enrollmentRoute, findsOneWidget);
    expect(tester.widget<SyncEnrollmentFlow>(enrollmentRoute), same(freshFlow));
    expect(
      tester.widget<SyncEnrollmentFlow>(enrollmentRoute).repairMode,
      isFalse,
    );
    expect(find.byType(SyncOtpScreen), findsOneWidget);
    expect(find.text(_repairLabel), findsNothing);
    expect(settingsSteps.whereType<RepairDeviceAccessRequested>(), isEmpty);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
    expect(harness.opener.openCalls, 1);
  });

  testWidgets('the banner clears the bottom safe-area inset in rail and '
      'bottom-nav layouts', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await _pumpShell(tester, status: const HostedSyncBindingRepair());
    final bottomNavBanner = tester.getRect(_bannerSurface());
    final navBar = tester.getRect(find.byType(NavigationBar));
    expect(bottomNavBanner.bottom, lessThanOrEqualTo(navBar.top));

    tester.view.physicalSize = const Size(900, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    final railBanner = tester.getRect(_bannerSurface());
    expect(railBanner.bottom, lessThanOrEqualTo(800 - 34));
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
