import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

import 'new_entry_session_harness.dart';

const _mlKitChannel = MethodChannel('spendwise/android_text_recognizer');
const _unknownSourceId = 'b0000000-0000-0000-0000-000000000009';
const _barrierTap = Offset(200, 20);
const _scanSettleWait = Duration(milliseconds: 300);
const _invalidated = 'coordinator-invalidated';
const _closed = 'presentation-closed';
const _routeCompleted = 'route-completed';
const _acceptedSettled = 'accepted-settled';
const _completedThenSettled = [_routeCompleted, _acceptedSettled];

class _ScanGate {
  final gates = <Completer<void>>[];

  Future<Object?> handle(Object? call) async {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return [
      {
        'text': 'Coffee Shop',
        'left': 0.0,
        'top': 0.0,
        'right': 100.0,
        'bottom': 100.0,
        'confidence': 0.9,
      },
    ];
  }
}

void _installScanGate(_ScanGate scan) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_mlKitChannel, scan.handle);
  addTearDown(() => messenger.setMockMethodCallHandler(_mlKitChannel, null));
}

Future<void> _startScan(
  WidgetTester tester,
  EntryHarness harness,
  _ScanGate scan,
) async {
  harness.form.requestScan(
    ReceiptScanSource.gallery,
    preCapturedBytes: Uint8List(0),
  );
  await tester.runAsync(() => Future<void>.delayed(_scanSettleWait));
  expect(scan.gates, hasLength(1));
}

Future<void> _finishScan(WidgetTester tester, _ScanGate scan) async {
  scan.gates.single.complete();
  await tester.runAsync(() => Future<void>.delayed(_scanSettleWait));
  await tester.pump();
}

Future<List<FlutterErrorDetails>> _collectReports(
  Future<void> Function() body,
) async {
  final reports = <FlutterErrorDetails>[];
  final original = FlutterError.onError;
  FlutterError.onError = reports.add;
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
  return reports;
}

Future<List<FlutterErrorDetails>> _openCollectingReports(
  WidgetTester tester,
  EntryHarness harness,
) => _collectReports(() async {
  harness.opened = harness.open();
  await tester.pumpAndSettle();
});

Future<void> _backExit(WidgetTester tester, EntryHarness harness) async {
  await harness.recorder.sheets.single.navigator!.maybePop();
  await tester.pumpAndSettle();
}

Future<void> _barrierExit(WidgetTester tester, EntryHarness harness) async {
  await tester.tapAt(_barrierTap);
  await tester.pumpAndSettle();
}

Future<void> _removalExit(WidgetTester tester, EntryHarness harness) async {
  final route = harness.recorder.sheets.single;
  route.navigator!.removeRoute(route);
  await tester.pumpAndSettle();
}

Future<void> _openGated(
  WidgetTester tester,
  EntryHarness harness,
  Completer<void> gate,
) async {
  harness.faults.initGate = gate;
  harness.opened = harness.open();
  await tester.pump();
}

List<String> _trackOrder(EntryHarness harness, AppSheetRoute<void> route) {
  final order = <String>[];
  unawaited(route.completed.then((_) => order.add(_routeCompleted)));
  unawaited(harness.opened.then((_) => order.add(_acceptedSettled)));
  return order;
}

NewEntryPresentationController _controllerOf(EntryHarness harness) =>
    harness.container.read(newEntryPresentationControllerProvider);

Future<void> _tapShellAdd(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add).first);
  await tester.pump();
}

class _PlainHost {
  _PlainHost(this.container, this.faults);

  final ProviderContainer container;
  final EntryFaults faults;
  final show = ValueNotifier<bool>(true);
  late BuildContext context;
  late WidgetRef ref;
}

Future<_PlainHost> _pumpPlainHost(WidgetTester tester) async {
  final faults = EntryFaults();
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(buildEntryLedger()),
      scanStripEnabledProvider.overrideWith((ref) async => false),
      entryFormViewModelProvider(null).overrideWith(() => CountingForm(faults)),
    ],
  );
  addTearDown(container.dispose);
  final host = _PlainHost(container, faults);
  final capture = Capture(
    onBuilt: (context, ref) {
      host.context = context;
      host.ref = ref;
    },
    child: const SizedBox.shrink(),
  );
  final home = ValueListenableBuilder<bool>(
    valueListenable: host.show,
    builder: (_, show, _) => show ? capture : const SizedBox.shrink(),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  return host;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('every Add exit retires once and releases after removal', () {
    final exits = <String, Future<void> Function(WidgetTester, EntryHarness)>{
      'cancel': cancelEntry,
      'save': saveEntry,
      'back': _backExit,
      'barrier': _barrierExit,
      'external removal': _removalExit,
    };

    for (final exit in exits.entries) {
      testWidgets('${exit.key} invalidates the coordinator before release', (
        tester,
      ) async {
        final harness = await pumpShell(tester);
        await openAdd(tester, harness);
        harness.log.events.clear();
        var completions = 0;
        unawaited(harness.opened.then((_) => completions++));

        await exit.value(tester, harness);
        await harness.opened;

        expect(harness.recorder.sheets, isEmpty);
        expect(completions, 1);
        final events = harness.log.events;
        expect(events.first, _invalidated);
        expect(events.last, _closed);
        expect(events.where((e) => e == _closed), hasLength(1));
      });
    }
  });

  group('failures during opening', () {
    testWidgets('failed initialization reports once and releases', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      harness.faults.failInit = true;

      final reports = await _openCollectingReports(tester, harness);
      await harness.opened;

      expect(reports, hasLength(1));
      expect(reports.single.exception, isA<StateError>());
      expect(harness.presentation, NewEntryPresentation.closed);
      expect(harness.recorder.sheets, isEmpty);
      harness.faults.failInit = false;
      await openAdd(tester, harness);
      expect(harness.recorder.sheets, hasLength(1));
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('a created but uninstalled route is disposed and released', (
      tester,
    ) async {
      final harness = await pumpShell(tester, failPush: true);
      final navigator = tester.state<ThrowingNavigatorState>(
        find.byType(ThrowingNavigator),
      );
      final clears = harness.form.clears;

      final reports = await _openCollectingReports(tester, harness);
      await harness.opened;

      final route = navigator.attempted! as AppSheetRoute<void>;
      expect(reports, hasLength(1));
      expect(harness.presentation, NewEntryPresentation.closed);
      await expectLater(route.completed, completes);
      expect(
        () => route.effectivePresentation.addListener(() {}),
        throwsFlutterError,
      );
      harness.form.requestPickSource();
      await tester.pumpAndSettle();
      expect(harness.form.clears, clears);
      expect(find.byType(TwoColumnPickerSheet), findsNothing);
    });

    testWidgets('a suspended initialization ends with its owner', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      final gate = Completer<void>();
      harness.faults.initGate = gate;
      await _tapShellAdd(tester);
      expect(harness.presentation, NewEntryPresentation.opening);

      harness.showShell.value = false;
      await tester.pumpAndSettle();
      expect(harness.presentation, NewEntryPresentation.closed);

      harness.faults.failInit = true;
      final reports = await _collectReports(() async {
        gate.complete();
        await tester.pumpAndSettle();
      });

      expect(harness.recorder.sheets, isEmpty);
      expect(reports, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a failed save keeps the session, draft and error', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    await openAdd(tester, harness);
    final route = harness.recorder.sheets.single;
    harness.form.setAmount('3.00');
    harness.form.setName('Keep');
    harness.form.applyPickedSource(_unknownSourceId);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await resize(tester, openSize);

    expect(harness.recorder.sheets.single, same(route));
    expect(harness.presentation, NewEntryPresentation.presented);
    expect(harness.draft['name'], 'Keep');
    expect(find.byType(ErrorSection), findsOneWidget);

    harness.form.applyPickedSource(checkingId);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await harness.opened;
    expect(harness.recorder.sheets, isEmpty);
  });

  group('owner and container teardown', () {
    testWidgets('removing AppShell removes only its Add route', (tester) async {
      final harness = await pumpShell(tester);
      await _tapShellAdd(tester);
      await tester.pumpAndSettle();
      expect(harness.recorder.sheets, hasLength(1));
      final unrelated = MaterialPageRoute<void>(
        builder: (_) => const Text('unrelated'),
      );
      unawaited(
        Navigator.of(harness.context, rootNavigator: true).push(unrelated),
      );
      await tester.pumpAndSettle();

      harness.showShell.value = false;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.recorder.sheets, isEmpty);
      expect(unrelated.isActive, isTrue);
      expect(harness.presentation, NewEntryPresentation.closed);
    });

    testWidgets('an owner signal settles the accepted request after '
        'route.completed', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final order = _trackOrder(harness, harness.recorder.sheets.single);

      _controllerOf(harness).ownerDisposed(harness.context);
      await tester.pumpAndSettle();

      expect(order, _completedThenSettled);
      expect(harness.recorder.sheets, isEmpty);
    });

    testWidgets('an owner signal settles a suspended initialization', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      final gate = Completer<void>();
      await _openGated(tester, harness, gate);
      var settled = false;
      unawaited(harness.opened.then((_) => settled = true));

      _controllerOf(harness).ownerDisposed(harness.context);
      await tester.pump();
      await tester.pump();

      expect(settled, isTrue);
      gate.complete();
      await tester.pumpAndSettle();
      expect(harness.recorder.sheets, isEmpty);
    });

    testWidgets('disposing the container during initialization settles', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      final gate = Completer<void>();
      await _openGated(tester, harness, gate);
      var completions = 0;
      unawaited(harness.opened.then((_) => completions++));

      harness.container.dispose();
      await tester.pump();
      gate.complete();
      await tester.pump();

      expect(completions, 1);
      expect(harness.recorder.sheets, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing with a surviving Navigator settles after '
        'route.completed', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final order = _trackOrder(harness, harness.recorder.sheets.single);

      harness.container.dispose();
      await tester.pump();
      await tester.pump();

      expect(order, _completedThenSettled);
      expect(harness.recorder.sheets, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing with Navigator teardown settles after '
        'route.completed', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final order = _trackOrder(harness, harness.recorder.sheets.single);

      harness.container.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(order, _completedThenSettled);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing during the reverse transition settles after '
        'route.completed', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final route = harness.recorder.sheets.single;
      final order = _trackOrder(harness, route);
      route.navigator!.pop();
      await tester.pump();
      await tester.pump(halfTransition);
      final removals = harness.recorder.removals;

      harness.container.dispose();
      await tester.pump();
      expect(order, isEmpty);
      await tester.pumpAndSettle();

      expect(order, _completedThenSettled);
      expect(harness.recorder.removals, removals);
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller disposal performs no provider operations', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final order = _trackOrder(harness, harness.recorder.sheets.single);
      harness.log.events.clear();

      _controllerOf(harness).dispose();
      expect(harness.log.events, isEmpty);
      await tester.pumpAndSettle();

      expect(harness.log.events, isEmpty);
      expect(order, _completedThenSettled);
    });

    testWidgets('disposing beneath a picker removes only Add', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      harness.form.requestPickSource();
      await tester.pumpAndSettle();
      final removals = harness.recorder.removals;

      harness.container.dispose();
      await tester.pumpAndSettle();

      expect(harness.recorder.removals, removals + 1);
      expect(harness.recorder.sheets, isEmpty);
      expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new container starts with no leftover guard', (
      tester,
    ) async {
      final first = await pumpShell(tester);
      await openAdd(tester, first);
      first.container.dispose();
      await tester.pumpWidget(const SizedBox.shrink());

      final second = await pumpShell(tester);
      await openAdd(tester, second);

      expect(second.recorder.sheets, hasLength(1));
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await second.opened;
    });

    testWidgets('an unmounted caller settles when initialization resumes', (
      tester,
    ) async {
      final host = await _pumpPlainHost(tester);
      final gate = Completer<void>();
      host.faults.initGate = gate;
      var completions = 0;
      final opened = openNewEntry(context: host.context, ref: host.ref);
      unawaited(opened.then((_) => completions++));
      await tester.pump();

      host.show.value = false;
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(completions, 1);
      expect(
        host.container.read(newEntryPresentationProvider),
        NewEntryPresentation.closed,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('receipt scans after retirement', () {
    testWidgets('a scan in flight cannot touch the retired form', (
      tester,
    ) async {
      final scan = _ScanGate();
      _installScanGate(scan);
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      await _startScan(tester, harness, scan);
      final draft = harness.draft;
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
      var scanEvents = 0;
      harness.container.listen(
        receiptEntryCoordinatorProvider(null),
        (_, _) => scanEvents++,
      );

      await _finishScan(tester, scan);

      expect(harness.draft, draft);
      expect(scanEvents, 0);
    });

    testWidgets('a scan in flight cannot touch a reopened draft', (
      tester,
    ) async {
      final scan = _ScanGate();
      _installScanGate(scan);
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      await _startScan(tester, harness, scan);
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
      await openAdd(tester, harness);
      harness.form.setName('Fresh');
      await tester.pumpAndSettle();
      var scanEvents = 0;
      harness.container.listen(
        receiptEntryCoordinatorProvider(null),
        (_, _) => scanEvents++,
      );

      await _finishScan(tester, scan);

      expect(harness.draft['name'], 'Fresh');
      expect(scanEvents, 0);
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });
  });
}
