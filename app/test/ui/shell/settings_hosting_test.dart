import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/banner_state.dart';
import 'package:spendwise/persistence/store/ledger_store.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_screen.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';

import '../sync/enrollment/sync_enrollment_flow_test.dart'
    show FakeSessionOpener, pumpFlowFrames;
import 'repair_banner_test.dart' show createEnrollmentContainer, pumpShell;
import '../../support/ui_test_timeout.dart';

const _desktop = Size(1200, 800);
const _hostedTile = Key('hostedSyncStatus');
const _repairLabel = 'Sync needs attention - Repair Device Access';

class _HoldingFlow extends FlowBase<String> {
  const _HoldingFlow();

  @override
  ConsumerState<_HoldingFlow> createState() => _HoldingFlowState();
}

class _HoldingFlowState extends FlowBaseState<String, _HoldingFlow> {
  @override
  void Function() subscribeToStep(void Function(String? step) handle) => () {};

  @override
  void handleStep(BuildContext context, String step) {}

  @override
  Widget buildRoot(BuildContext context) => const Text('holding body');
}

Future<void> _openSettingsItem(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
}

Future<void> _openFreshEnrollment(WidgetTester tester) async {
  await tester.tap(find.byKey(_hostedTile));
  await pumpFlowFrames(tester);
}

Future<void> _openRepairRoute(WidgetTester tester) async {
  await tester.tap(find.text(_repairLabel));
  await tester.pumpAndSettle();
}

void _expectSelectedSettings(ProviderContainer container) {
  expect(
    container.read(selectedDestinationProvider),
    ShellDestination.settings,
  );
}

void _expectClosedCleanly(ProviderContainer container) {
  expect(container.read(enrollmentFlowOpenProvider), isFalse);
  expect(container.read(settingsRootViewModelProvider).step, isNull);
}

void main() {
  group('phone', () {
    testWidgets('the Settings item selects the Settings destination in place', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
      );

      await _openSettingsItem(tester);

      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byKey(const ValueKey('phone-bar')), findsOneWidget);
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byKey(const ValueKey('phone-bar')),
            matching: find.text('Settings'),
          ),
        ),
        matchesSemantics(
          label: 'Settings',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      expect(find.text('history body'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('the Settings root shows no back control', (tester) async {
      await pumpShell(tester, status: null, layoutMode: ShellLayoutMode.phone);
      await _openSettingsItem(tester);

      expect(find.byType(BackButton), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('Android back at the Settings root preserves the selection', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
        bodies: {ShellDestination.history: (context) => const _HoldingFlow()},
      );
      await _openSettingsItem(tester);
      final holdingRoot = tester.element(
        find.text('holding body', skipOffstage: false),
      );
      Navigator.of(holdingRoot).push(
        MaterialPageRoute<void>(builder: (_) => const Text('history detail')),
      );
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.text('history detail', skipOffstage: false), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets(
      'Back pops a Settings child route and keeps Settings selected',
      (tester) async {
        final harness = await pumpShell(
          tester,
          status: null,
          layoutMode: ShellLayoutMode.phone,
        );
        await _openSettingsItem(tester);

        await tester.tap(find.text('Categories'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryListScreen), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.byType(CategoryListScreen), findsNothing);
        _expectSelectedSettings(harness.container);
        expect(find.byKey(_hostedTile), findsOneWidget);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('Settings omits Plans and Recycle Bin returns to the root', (
      tester,
    ) async {
      await pumpShell(tester, status: null, layoutMode: ShellLayoutMode.phone);
      await _openSettingsItem(tester);

      expect(find.text('Recurring Plans'), findsNothing);
      expect(find.byType(PlanListScreen), findsNothing);

      await tester.tap(find.text('Recycle Bin'));
      await tester.pumpAndSettle();
      expect(find.byType(RecycleBinScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RecycleBinScreen), findsNothing);
      expect(find.byKey(_hostedTile), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets(
      'system Back with a root dialog open dismisses only the dialog',
      (tester) async {
        final harness = await pumpShell(
          tester,
          status: null,
          layoutMode: ShellLayoutMode.phone,
        );
        await _openSettingsItem(tester);
        await tester.tap(find.text('Categories'));
        await tester.pumpAndSettle();

        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(AppShell)),
            builder: (_) => const Text('root dialog'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('root dialog'), findsOneWidget);

        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(find.text('root dialog'), findsNothing);
        expect(find.byType(CategoryListScreen), findsOneWidget);
        _expectSelectedSettings(harness.container);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('a fresh enrollment opens one route and closes cleanly', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
      );
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

      await tester.binding.handlePopRoute();
      await pumpFlowFrames(tester);

      expect(find.byType(SyncEnrollmentFlow), findsNothing);
      expect(find.byKey(_hostedTile), findsOneWidget);
      _expectClosedCleanly(harness.container);
    }, timeout: uiTestTimeout);

    testWidgets(
      'completing an enrollment route refreshes status and releases the guard',
      (tester) async {
        final harness = await pumpShell(
          tester,
          status: null,
          layoutMode: ShellLayoutMode.phone,
        );
        await harness.metadataStore.setBackendSelection(
          backend: SyncBackendKind.supabase,
        );
        await harness.metadataStore.enterBindingAuthorizationRequired();
        await _openSettingsItem(tester);
        expect(find.text('Binding repair needed'), findsOneWidget);

        await tester.tap(find.text('Repair Device Access'));
        await pumpFlowFrames(tester);
        expect(find.byType(SyncEnrollmentFlow), findsOneWidget);

        await harness.metadataStore.clearBackendSelection();

        await tester.binding.handlePopRoute();
        await pumpFlowFrames(tester);

        expect(find.byType(SyncEnrollmentFlow), findsNothing);
        _expectClosedCleanly(harness.container);
        expect(find.text('Status unavailable'), findsOneWidget);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('selecting Settings refreshes a changed durable phase', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
      );
      expect(find.text('Not configured', skipOffstage: false), findsOneWidget);

      await harness.metadataStore.setBackendSelection(
        backend: SyncBackendKind.supabase,
      );
      await harness.metadataStore.enterBindingAuthorizationRequired();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Not configured', skipOffstage: false), findsOneWidget);

      await _openSettingsItem(tester);
      expect(find.text('Binding repair needed'), findsOneWidget);

      await harness.metadataStore.clearBackendSelection();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(
        find.text('Binding repair needed', skipOffstage: false),
        findsOneWidget,
      );

      await _openSettingsItem(tester);
      expect(find.text('Status unavailable'), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a repair tap selects Settings with one repair route', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        layoutMode: ShellLayoutMode.phone,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );

      await tester.tap(find.text(_repairLabel));
      await tester.tap(find.text(_repairLabel), warnIfMissed: false);
      await tester.pumpAndSettle();

      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(SyncIdentifierScreen), findsOneWidget);
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a save problem shows above Settings', (tester) async {
      final banner = BannerState();
      await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
        banner: banner,
      );
      await _openSettingsItem(tester);

      banner.receiveSaveState(SaveBannerState.retrying);
      await tester.pump();

      expect(find.text("Couldn't save changes, retrying"), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets(
      'the repair banner stays hidden while the repair route is open',
      (tester) async {
        await pumpShell(
          tester,
          status: const HostedSyncBindingRepair(),
          layoutMode: ShellLayoutMode.phone,
          seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
        );
        await _openRepairRoute(tester);

        expect(find.text(_repairLabel, skipOffstage: false), findsNothing);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('a repair tap while an enrollment route is already open '
        'requests no second repair', (tester) async {
      final steps = <SettingsStep>[];
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        layoutMode: ShellLayoutMode.phone,
        settingsSteps: steps,
      );
      harness.container.read(enrollmentFlowOpenProvider.notifier).state = true;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);

      await tester.tap(find.text(_repairLabel));
      await tester.pumpAndSettle();

      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(steps.whereType<RepairDeviceAccessRequested>(), isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('switching destination during enrollment keeps the route for '
        'return', (tester) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
      );
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SyncEnrollmentFlow, skipOffstage: false),
        findsOneWidget,
      );
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

      await _openSettingsItem(tester);

      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);
    }, timeout: uiTestTimeout);

    testWidgets('system Back on another destination leaves the hidden '
        'enrollment route alone', (tester) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
        bodies: {ShellDestination.history: (context) => const _HoldingFlow()},
      );
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('holding body'), findsOneWidget);
      expect(
        find.byType(SyncEnrollmentFlow, skipOffstage: false),
        findsOneWidget,
      );
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

      await _openSettingsItem(tester);

      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('teardown with an owned enrollment route releases the guard '
        'without emitting a step', (tester) async {
      final steps = <SettingsStep>[];
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
        settingsSteps: steps,
      );
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      _expectClosedCleanly(harness.container);
      expect(steps.whereType<ResumeFreshEnrollmentRequested>(), isEmpty);
      expect(steps.whereType<RepairDeviceAccessRequested>(), isEmpty);
    }, timeout: uiTestTimeout);
  });

  group('desktop', () {
    testWidgets('the Settings item shows Settings in the content area', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        size: _desktop,
        layoutMode: ShellLayoutMode.desktop,
      );

      await _openSettingsItem(tester);

      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byKey(const ValueKey('sidebar')), findsOneWidget);
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byKey(const ValueKey('sidebar')),
            matching: find.text('Settings'),
          ),
        ),
        matchesSemantics(
          label: 'Settings',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
    }, timeout: uiTestTimeout);

    testWidgets('Android back at the Settings root preserves the selection', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        size: _desktop,
        layoutMode: ShellLayoutMode.desktop,
        bodies: {ShellDestination.history: (context) => const _HoldingFlow()},
      );
      await _openSettingsItem(tester);
      final holdingRoot = tester.element(
        find.text('holding body', skipOffstage: false),
      );
      Navigator.of(holdingRoot).push(
        MaterialPageRoute<void>(builder: (_) => const Text('history detail')),
      );
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.text('history detail', skipOffstage: false), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a repair tap selects Settings with one repair route', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
        size: _desktop,
        layoutMode: ShellLayoutMode.desktop,
      );

      await tester.tap(find.text(_repairLabel));
      await tester.tap(find.text(_repairLabel), warnIfMissed: false);
      await tester.pumpAndSettle();

      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(SyncIdentifierScreen), findsOneWidget);
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
    }, timeout: uiTestTimeout);
  });

  group('StatusBanner', () {
    testWidgets('hides the repair banner only when Settings is selected and '
        'enrollment is open', (tester) async {
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        size: _desktop,
        layoutMode: ShellLayoutMode.desktop,
      );
      final container = harness.container;
      expect(find.text(_repairLabel), findsOneWidget);

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.settings;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);

      container.read(enrollmentFlowOpenProvider.notifier).state = true;
      await tester.pump();
      expect(find.text(_repairLabel), findsNothing);

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.settings;
      await tester.pump();
      expect(find.text(_repairLabel), findsNothing);

      container.read(enrollmentFlowOpenProvider.notifier).state = false;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);
    }, timeout: uiTestTimeout);
  });

  group('pending step pickup', () {
    testWidgets(
      'a repair requested before mount opens one route exactly once',
      (tester) async {
        final created = await createEnrollmentContainer(
          status: const HostedSyncBindingRepair(),
          seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
        );
        created.container
            .read(settingsRootViewModelProvider.notifier)
            .requestRepair();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: created.container,
            child: const MaterialApp(home: SettingsFlow()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(SyncEnrollmentFlow, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byType(SyncIdentifierScreen), findsOneWidget);
        expect(
          created.container.read(settingsRootViewModelProvider).step,
          isNull,
        );
        expect(created.container.read(enrollmentFlowOpenProvider), isTrue);
      },
      timeout: uiTestTimeout,
    );
  });

  group('phone-open resize', () {
    Future<
      ({
        ProviderContainer container,
        SyncMetadataStore metadataStore,
        FakeSessionOpener opener,
      })
    >
    pumpBoundShell(
      WidgetTester tester, {
      Size size = const Size(400, 800),
      Map<ShellDestination, WidgetBuilder>? bodies,
    }) async {
      final created = await createEnrollmentContainer(
        status: null,
        platform: (isWeb: false, targetPlatform: TargetPlatform.iOS),
      );
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: created.container,
          child: MaterialApp(
            builder: buildShellAppContent,
            home: AppShell(
              bodies: {
                ShellDestination.history: (context) =>
                    const Text('history body'),
                ShellDestination.settings: (context) => const SettingsFlow(),
                ...?bodies,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return created;
    }

    Future<void> resize(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }

    testWidgets('a mobile switch retains the settings flow, its child route '
        'and its container', (tester) async {
      final harness = await pumpBoundShell(tester);
      final container = harness.container;
      await _openSettingsItem(tester);

      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryListScreen), findsOneWidget);
      final flowState = tester.state(find.byType(SettingsFlow));
      final scoped = ProviderScope.containerOf(
        tester.element(find.byType(SettingsFlow)),
      );

      await resize(tester, const Size(960, 720));
      expect(find.byKey(const ValueKey('open-rail')), findsOneWidget);
      expect(find.byType(CategoryListScreen), findsOneWidget);
      expect(
        identical(tester.state(find.byType(SettingsFlow)), flowState),
        isTrue,
      );
      expect(
        identical(
          ProviderScope.containerOf(tester.element(find.byType(SettingsFlow))),
          scoped,
        ),
        isTrue,
      );

      await resize(tester, const Size(400, 800));
      expect(find.byKey(const ValueKey('phone-bar')), findsOneWidget);
      expect(find.byType(CategoryListScreen), findsOneWidget);
      expect(
        identical(tester.state(find.byType(SettingsFlow)), flowState),
        isTrue,
      );
      _expectSelectedSettings(container);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CategoryListScreen), findsNothing);
      expect(find.byKey(_hostedTile), findsOneWidget);
      _expectSelectedSettings(container);
    }, timeout: uiTestTimeout);

    testWidgets('a mobile switch retains an open enrollment route without '
        're-hosting it', (tester) async {
      final harness = await pumpBoundShell(tester);
      final container = harness.container;
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(container.read(enrollmentFlowOpenProvider), isTrue);
      final scoped = ProviderScope.containerOf(
        tester.element(find.byType(SettingsFlow)),
      );

      await resize(tester, const Size(960, 720));
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(container.read(enrollmentFlowOpenProvider), isTrue);
      expect(
        identical(
          ProviderScope.containerOf(tester.element(find.byType(SettingsFlow))),
          scoped,
        ),
        isTrue,
      );

      await resize(tester, const Size(400, 800));
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(container.read(enrollmentFlowOpenProvider), isTrue);

      await tester.binding.handlePopRoute();
      await pumpFlowFrames(tester);
      expect(find.byType(SyncEnrollmentFlow), findsNothing);
      _expectClosedCleanly(container);
    }, timeout: uiTestTimeout);

    testWidgets('system back across a resize targets the active destination '
        'and leaves hidden stacks intact', (tester) async {
      final harness = await pumpBoundShell(
        tester,
        bodies: {ShellDestination.history: (context) => const _HoldingFlow()},
      );
      final container = harness.container;
      await _openSettingsItem(tester);
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await tester.pumpAndSettle();
      final holdingRoot = tester.element(
        find.text('holding body', skipOffstage: false),
      );
      Navigator.of(holdingRoot).push(
        MaterialPageRoute<void>(builder: (_) => const Text('history detail')),
      );
      await tester.pumpAndSettle();

      await resize(tester, const Size(960, 720));

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('history detail'), findsNothing);
      expect(find.text('holding body'), findsOneWidget);
      expect(
        find.byType(CategoryListScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
    }, timeout: uiTestTimeout);
  });
}
