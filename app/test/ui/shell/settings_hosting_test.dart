import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

import '../sync/enrollment/sync_enrollment_flow_test.dart' show pumpFlowFrames;
import 'repair_banner_test.dart' show pumpShell;

const _phone = Size(400, 800);
const _desktop = Size(1200, 800);
const _hostedTile = Key('hostedSyncStatus');
const _repairLabel = 'Sync needs attention - Repair Device Access';

Future<void> _openSettingsItem(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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

Future<ProviderContainer> _pumpRepair(WidgetTester tester, Size size) async {
  final harness = await pumpShell(
    tester,
    status: const HostedSyncBindingRepair(),
    seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    size: size,
  );
  return harness.container;
}

void _expectOneRepairRoute(WidgetTester tester) {
  final route = find.byType(SyncEnrollmentFlow, skipOffstage: false);
  expect(route, findsOneWidget);
  expect(tester.widget<SyncEnrollmentFlow>(route).repairMode, isTrue);
}

void _expectClosedCleanly(ProviderContainer container) {
  expect(container.read(enrollmentFlowOpenProvider), isFalse);
  expect(container.read(settingsRootViewModelProvider).step, isNull);
}

void _expectOneSettingsAndOneEnrollment(
  WidgetTester tester,
  ProviderContainer container,
) {
  expect(find.byType(SettingsFlow, skipOffstage: false), findsOneWidget);
  expect(find.byType(SyncEnrollmentFlow, skipOffstage: false), findsOneWidget);
  expect(container.read(settingsOpenProvider), isTrue);
  expect(container.read(enrollmentFlowOpenProvider), isTrue);
}

void main() {
  group('phone', () {
    testWidgets('the Settings item opens one root route and sets the flag', (
      tester,
    ) async {
      final harness = await pumpShell(tester, status: null);

      await _openSettingsItem(tester);

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(harness.container.read(settingsOpenProvider), isTrue);
      expect(
        harness.container.read(selectedDestinationProvider),
        ShellDestination.transactions,
      );
      expect(find.byTooltip('Transactions'), findsOneWidget);
    });

    testWidgets('the back control clears the flag and removes the route', (
      tester,
    ) async {
      final harness = await pumpShell(tester, status: null);
      await _openSettingsItem(tester);

      await tester.tap(find.byTooltip('Transactions'));
      await tester.pumpAndSettle();

      expect(harness.container.read(settingsOpenProvider), isFalse);
      expect(find.byType(SettingsFlow), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Android back at the Settings root clears the flag', (
      tester,
    ) async {
      final harness = await pumpShell(tester, status: null);
      await _openSettingsItem(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.container.read(settingsOpenProvider), isFalse);
      expect(find.byType(SettingsFlow), findsNothing);
    });

    testWidgets('removing the route with removeRoute leaves the flag true', (
      tester,
    ) async {
      final harness = await pumpShell(tester, status: null);
      await _openSettingsItem(tester);
      final route = ModalRoute.of(tester.element(find.byType(SettingsFlow)))!;

      Navigator.of(
        tester.element(find.byType(SettingsFlow)),
        rootNavigator: true,
      ).removeRoute(route);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsFlow), findsNothing);
      expect(harness.container.read(settingsOpenProvider), isTrue);
    });

    testWidgets('closing Settings with a fresh enrollment route open clears '
        'it and the next open shows the Settings root', (tester) async {
      final harness = await pumpShell(tester, status: null);
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

      tester.widget<SettingsFlow>(find.byType(SettingsFlow)).onEnded!();
      await tester.pumpAndSettle();

      expect(harness.container.read(settingsOpenProvider), isFalse);
      expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
      expect(harness.container.read(settingsRootViewModelProvider).step, null);

      await _openSettingsItem(tester);

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(SyncEnrollmentFlow), findsNothing);
      expect(find.byKey(_hostedTile), findsOneWidget);
    });

    testWidgets('a repair tap opens Settings with one repair route', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );

      await tester.tap(find.text(_repairLabel));
      await tester.tap(find.text(_repairLabel), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(SyncIdentifierScreen), findsOneWidget);
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(harness.container.read(settingsOpenProvider), isTrue);
    });

    testWidgets('a repair tap while an enrollment route is already open '
        'requests no second repair', (tester) async {
      final steps = <SettingsStep>[];
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        settingsSteps: steps,
      );
      harness.container.read(enrollmentFlowOpenProvider.notifier).state = true;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);

      await tester.tap(find.text(_repairLabel));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(steps.whereType<RepairDeviceAccessRequested>(), isEmpty);
    });

    testWidgets('a Ready status ends a handed-over fresh route on the switch '
        'to desktop', (tester) async {
      final harness = await pumpShell(tester, status: null);
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);
      await harness.metadataStore.setBackendSelection(
        backend: SyncBackendKind.supabase,
      );
      await harness.metadataStore.enterReconciliationComplete();
      await harness.metadataStore.enterGateEnabled();
      await harness.container.read(appBootProvider).refreshSyncStatus();
      await tester.pump();
      expect(
        harness.container.read(hostedSyncStatusProvider),
        isA<HostedSyncReady>(),
      );

      await _resize(tester, _desktop);

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(SyncEnrollmentFlow), findsNothing);
      expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
      expect(harness.container.read(settingsRootViewModelProvider).step, null);
    });
  });

  group('desktop', () {
    testWidgets('the Settings item shows Settings in the content area', (
      tester,
    ) async {
      final harness = await pumpShell(tester, status: null, size: _desktop);

      await _openSettingsItem(tester);

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(harness.container.read(settingsOpenProvider), isTrue);
    });

    testWidgets('Android back at the Settings root clears the flag', (
      tester,
    ) async {
      final harness = await pumpShell(tester, status: null, size: _desktop);
      await _openSettingsItem(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.container.read(settingsOpenProvider), isFalse);
      expect(find.byType(SettingsFlow), findsNothing);
    });

    testWidgets('selecting a destination clears the flag', (tester) async {
      final harness = await pumpShell(tester, status: null, size: _desktop);
      await _openSettingsItem(tester);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(harness.container.read(settingsOpenProvider), isFalse);
      expect(
        harness.container.read(selectedDestinationProvider),
        ShellDestination.stats,
      );
      expect(find.byType(SettingsFlow), findsNothing);
    });

    testWidgets('switching destination with a fresh enrollment route open '
        'clears it and the next open shows the Settings root', (tester) async {
      final harness = await pumpShell(tester, status: null, size: _desktop);
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);
      expect(harness.container.read(enrollmentFlowOpenProvider), isTrue);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(harness.container.read(enrollmentFlowOpenProvider), isFalse);
      expect(harness.container.read(settingsRootViewModelProvider).step, null);

      await _openSettingsItem(tester);

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(SyncEnrollmentFlow), findsNothing);
    });

    testWidgets('a repair tap opens Settings with one repair route', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
        size: _desktop,
      );

      await tester.tap(find.text(_repairLabel));
      await tester.tap(find.text(_repairLabel), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(SyncIdentifierScreen), findsOneWidget);
      expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
      expect(harness.container.read(settingsOpenProvider), isTrue);
    });
  });

  group('layout switch with Settings open', () {
    testWidgets('phone to desktop keeps one Settings and one enrollment '
        'route', (tester) async {
      final harness = await pumpShell(tester, status: null);
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      await _resize(tester, _desktop);

      _expectOneSettingsAndOneEnrollment(tester, harness.container);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('desktop to phone keeps one Settings and one enrollment '
        'route', (tester) async {
      final harness = await pumpShell(tester, status: null, size: _desktop);
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      await _resize(tester, _phone);

      _expectOneSettingsAndOneEnrollment(tester, harness.container);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('hysteresis holds the open Settings in place between 680 and '
        '720', (tester) async {
      final harness = await pumpShell(tester, status: null);
      await _openSettingsItem(tester);

      await _resize(tester, const Size(700, 800));

      expect(find.byType(SettingsFlow), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(harness.container.read(settingsOpenProvider), isTrue);
    });
  });

  group('repair route ownership', () {
    testWidgets('destination switch on desktop closes an open repair route', (
      tester,
    ) async {
      final container = await _pumpRepair(tester, _desktop);
      await _openRepairRoute(tester);
      _expectOneRepairRoute(tester);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SyncEnrollmentFlow, skipOffstage: false),
        findsNothing,
      );
      _expectClosedCleanly(container);
    });

    testWidgets('closing Settings on phone closes an open repair route', (
      tester,
    ) async {
      final container = await _pumpRepair(tester, _phone);
      await _openRepairRoute(tester);

      tester.widget<SettingsFlow>(find.byType(SettingsFlow)).onEnded!();
      await tester.pumpAndSettle();

      expect(
        find.byType(SyncEnrollmentFlow, skipOffstage: false),
        findsNothing,
      );
      _expectClosedCleanly(container);
    });

    testWidgets('phone to desktop hands the repair route over once', (
      tester,
    ) async {
      final container = await _pumpRepair(tester, _phone);
      await _openRepairRoute(tester);

      await _resize(tester, _desktop);

      _expectOneRepairRoute(tester);
      expect(find.byType(SettingsFlow, skipOffstage: false), findsOneWidget);
      expect(container.read(enrollmentFlowOpenProvider), isTrue);
    });

    testWidgets('desktop to phone hands the repair route over once', (
      tester,
    ) async {
      final container = await _pumpRepair(tester, _desktop);
      await _openRepairRoute(tester);

      await _resize(tester, _phone);

      _expectOneRepairRoute(tester);
      expect(find.byType(SettingsFlow, skipOffstage: false), findsOneWidget);
      expect(container.read(enrollmentFlowOpenProvider), isTrue);
    });

    testWidgets('a repair tap during an unsettled transition opens one '
        'repair route', (tester) async {
      final container = await _pumpRepair(tester, _desktop);

      tester.view.physicalSize = _phone;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text(_repairLabel).last);
      await tester.pump();
      await tester.pumpAndSettle();

      _expectOneRepairRoute(tester);
      expect(find.byType(SettingsFlow, skipOffstage: false), findsOneWidget);
      expect(container.read(settingsOpenProvider), isTrue);
    });

    testWidgets('closing and reopening Settings before the outgoing layout '
        'disposes does not reopen the enrollment route', (tester) async {
      final harness = await pumpShell(tester, status: null, size: _desktop);
      final container = harness.container;
      await _openSettingsItem(tester);
      await _openFreshEnrollment(tester);

      tester.view.physicalSize = _phone;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      container.read(settingsOpenProvider.notifier).state = false;
      await tester.pump();
      container.read(settingsOpenProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(find.byType(SettingsFlow, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(SyncEnrollmentFlow, skipOffstage: false),
        findsNothing,
      );
      expect(find.byKey(_hostedTile), findsOneWidget);
      _expectClosedCleanly(container);
    });
  });

  group('StatusBanner', () {
    testWidgets('hides the repair banner only when the enrollment route and '
        'Settings are both open', (tester) async {
      final harness = await pumpShell(
        tester,
        status: const HostedSyncBindingRepair(),
        size: _desktop,
      );
      final container = harness.container;
      expect(find.text(_repairLabel), findsOneWidget);

      container.read(enrollmentFlowOpenProvider.notifier).state = true;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);

      container.read(settingsOpenProvider.notifier).state = true;
      await tester.pump();
      expect(find.text(_repairLabel), findsNothing);

      container.read(enrollmentFlowOpenProvider.notifier).state = false;
      await tester.pump();
      expect(find.text(_repairLabel), findsOneWidget);
    });
  });
}
