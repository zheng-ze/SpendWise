import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/banner_state.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_screen.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';

import '../sync/enrollment/sync_enrollment_flow_test.dart' show pumpFlowFrames;
import 'repair_banner_test.dart' show pumpShell;

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
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        ShellDestination.settings.index,
      );
      expect(find.text('transactions body'), findsNothing);
    });

    testWidgets('the Settings root shows no back control', (tester) async {
      await pumpShell(tester, status: null, layoutMode: ShellLayoutMode.phone);
      await _openSettingsItem(tester);

      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('Android back at the Settings root preserves the selection', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
      );
      await _openSettingsItem(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
    });

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
    );

    testWidgets('Plans and Recycle Bin child routes return to the root', (
      tester,
    ) async {
      await pumpShell(tester, status: null, layoutMode: ShellLayoutMode.phone);
      await _openSettingsItem(tester);

      await tester.tap(find.text('Recurring Plans'));
      await tester.pumpAndSettle();
      expect(find.byType(PlanListScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PlanListScreen), findsNothing);

      await tester.tap(find.text('Recycle Bin'));
      await tester.pumpAndSettle();
      expect(find.byType(RecycleBinScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RecycleBinScreen), findsNothing);
      expect(find.byKey(_hostedTile), findsOneWidget);
    });

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
    });

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
    });

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
    });

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
    });

    testWidgets('switching destination during enrollment keeps the route for '
        'return', (tester) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
      );
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SyncEnrollmentFlow, skipOffstage: false),
        findsOneWidget,
      );
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

      await _openSettingsItem(tester);

      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);
    });

    testWidgets('system Back on another destination leaves the hidden '
        'enrollment route alone', (tester) async {
      final harness = await pumpShell(
        tester,
        status: null,
        layoutMode: ShellLayoutMode.phone,
        bodies: {ShellDestination.stats: (context) => const _HoldingFlow()},
      );
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      await tester.tap(find.text('Stats'));
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
    });

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
    });
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
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        ShellDestination.settings.index,
      );
    });

    testWidgets('Android back at the Settings root preserves the selection', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: null,
        size: _desktop,
        layoutMode: ShellLayoutMode.desktop,
      );
      await _openSettingsItem(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      _expectSelectedSettings(harness.container);
      expect(find.byType(SettingsFlow), findsOneWidget);
    });

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
    });
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
          ShellDestination.transactions;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.settings;
      await tester.pump();
      expect(find.text(_repairLabel), findsNothing);

      container.read(enrollmentFlowOpenProvider.notifier).state = false;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);
    });
  });
}
