import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';

import '../sync/enrollment/sync_enrollment_flow_test.dart' show pumpFlowFrames;
import 'repair_banner_test.dart' show createEnrollmentContainer, pumpShell;
import '../../support/ui_test_timeout.dart';

const _hostedTile = Key('hostedSyncStatus');
const _repairLabel = 'Sync needs attention - Repair Device Access';

Future<void> _openSettingsItem(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
}

Future<void> _openFreshEnrollment(WidgetTester tester) async {
  await tester.tap(find.byKey(_hostedTile));
  await pumpFlowFrames(tester);
}

void _expectClosedCleanly(ProviderContainer container) {
  expect(container.read(enrollmentFlowOpenProvider), isFalse);
  expect(container.read(settingsRootViewModelProvider).step, isNull);
}

Future<void> _selectDestination(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

final class _GatedBackendWriter implements BackendSelectionWriter {
  _GatedBackendWriter(this._store);

  final BackendSelectionWriter _store;
  final gate = Completer<void>();

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) async {
    await gate.future;
    await _store.setBackendSelection(backend: backend, endpoint: endpoint);
  }
}

Future<ProviderContainer> pumpBoundShell(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  final created = await createEnrollmentContainer(
    status: null,
    platform: (isWeb: false, targetPlatform: TargetPlatform.iOS),
    overrides: overrides,
  );
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: created,
      child: MaterialApp(
        builder: buildShellAppContent,
        home: AppShell(
          bodies: {
            ShellDestination.history: (context) => const Text('history body'),
            ShellDestination.settings: (context) => const SettingsFlow(),
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return created;
}

void main() {
  testWidgets('a repair tap selects Settings with one repair route', (
    tester,
  ) async {
    final container = await pumpShell(
      tester,
      status: const HostedSyncBindingRepair(),
      layoutMode: ShellLayoutMode.phone,
      seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
    );

    await tester.tap(find.text(_repairLabel));
    await tester.tap(find.text(_repairLabel), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
    expect(find.byType(SettingsFlow), findsOneWidget);
    expect(find.byType(SyncIdentifierScreen), findsOneWidget);
    expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
  }, timeout: uiTestTimeout);

  group('phone-open resize', () {
    Future<void> resize(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }

    testWidgets('a mobile switch retains an open enrollment route without '
        're-hosting it', (tester) async {
      final container = await pumpBoundShell(tester);
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
  });

  testWidgets('leaving Settings discards an open fresh enrollment', (
    tester,
  ) async {
    final container = await pumpBoundShell(tester);
    await _selectDestination(tester, 'Settings');
    await _openFreshEnrollment(tester);
    expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
    expect(container.read(enrollmentFlowOpenProvider), isTrue);

    await _selectDestination(tester, 'History');
    await pumpFlowFrames(tester);

    expect(find.byType(SyncEnrollmentFlow), findsNothing);
    _expectClosedCleanly(container);

    await _selectDestination(tester, 'Settings');
    expect(find.byType(SyncEnrollmentFlow), findsNothing);
    expect(find.byKey(_hostedTile), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('leaving Settings during a picker save leaves setup resumable', (
    tester,
  ) async {
    late _GatedBackendWriter writer;
    final container = await pumpBoundShell(
      tester,
      overrides: [
        backendPickerViewModelProvider.overrideWith(() {
          return BackendPickerNotifier(writer: writer);
        }),
      ],
    );
    writer = _GatedBackendWriter(container.read(syncMetadataStoreProvider));
    await _selectDestination(tester, 'Settings');
    await _openFreshEnrollment(tester);
    await tester.tap(find.text('Continue'));
    await tester.pump();

    await _selectDestination(tester, 'History');
    writer.gate.complete();
    await pumpFlowFrames(tester);

    expect(find.byType(SyncEnrollmentFlow), findsNothing);
    _expectClosedCleanly(container);

    await _selectDestination(tester, 'Settings');
    expect(find.text('Setup pending'), findsOneWidget);
    await _openFreshEnrollment(tester);
    expect(find.byType(SyncEnrollmentFlow), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsOneWidget);
    expect(container.read(backendPickerViewModelProvider).saving, isFalse);
  }, timeout: uiTestTimeout);
}
