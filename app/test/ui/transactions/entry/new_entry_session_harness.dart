import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';

const phoneSize = Size(400, 800);
const openSize = Size(960, 720);
const checkingId = 'a0000000-0000-0000-0000-000000000001';
const coffeeId = 'c0000000-0000-0000-0000-000000000001';
const probeLabel = 'overview probe';
const decodeWait = Duration(milliseconds: 500);
const halfTransition = Duration(milliseconds: 100);

class RouteRecorder extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  int removals = 0;
  int sheetPushes = 0;

  List<AppSheetRoute<dynamic>> get sheets =>
      routes.whereType<AppSheetRoute<dynamic>>().toList();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    if (route is AppSheetRoute) sheetPushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removals++;
    routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removals++;
    routes.remove(route);
  }
}

class EntryFaults {
  bool failInit = false;
  Completer<void>? initGate;
}

class CountingForm extends EntryFormNotifier {
  CountingForm(this.faults) : super(null);

  final EntryFaults faults;
  int clears = 0;

  @override
  Future<EntryFormViewState> build() async {
    final built = super.build();
    final gate = faults.initGate;
    if (gate != null) await gate.future;
    if (faults.failInit) throw StateError('deliberate init failure');
    return built;
  }

  @override
  void clearStep() {
    clears++;
    super.clearStep();
  }
}

class HookedLedger extends Ledger {
  HookedLedger({super.state});

  VoidCallback? onNextRead;

  @override
  LedgerState get state {
    final hook = onNextRead;
    onNextRead = null;
    hook?.call();
    return super.state;
  }
}

class Capture extends ConsumerWidget {
  const Capture({super.key, required this.onBuilt, required this.child});

  final void Function(BuildContext context, WidgetRef ref) onBuilt;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuilt(context, ref);
    return child;
  }
}

final class LifecycleLog extends ProviderObserver {
  final events = <String>[];

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (context.provider == receiptEntryCoordinatorProvider(null)) {
      events.add('coordinator-invalidated');
    }
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (context.provider == newEntryPresentationProvider) {
      events.add('presentation-${(newValue as NewEntryPresentation).name}');
    }
  }
}

class ThrowingNavigator extends Navigator {
  const ThrowingNavigator({super.key, super.onGenerateRoute, super.observers});

  @override
  NavigatorState createState() => ThrowingNavigatorState();
}

class ThrowingNavigatorState extends NavigatorState {
  Route<dynamic>? attempted;

  @override
  Future<T?> push<T extends Object?>(Route<T> route) {
    attempted = route;
    throw StateError('deliberate presentation failure');
  }
}

class EntryHarness {
  EntryHarness(
    this.container,
    this.recorder,
    this.ledger,
    this.faults,
    this.log,
  );

  final ProviderContainer container;
  final RouteRecorder recorder;
  final HookedLedger ledger;
  final EntryFaults faults;
  final LifecycleLog log;
  final showShell = ValueNotifier<bool>(true);
  late BuildContext context;
  late WidgetRef ref;
  late Future<void> opened;

  CountingForm get form =>
      container.read(entryFormViewModelProvider(null).notifier) as CountingForm;

  Future<void> open() => openNewEntry(context: context, ref: ref);

  NewEntryPresentation get presentation =>
      container.read(newEntryPresentationProvider);

  Map<String, Object?> get draft {
    final state = container.read(entryFormViewModelProvider(null)).value!;
    return {
      'amount': state.amountText,
      'name': state.nameText,
      'date': state.date,
      'source': state.sourceId,
      'destination': state.destinationId,
      'category': state.categoryId,
      'recurrence': state.recurrence,
      'endDate': state.endDate,
    };
  }
}

HookedLedger buildEntryLedger() {
  final checking = Account(
    id: checkingId,
    name: 'Checking',
    type: AccountType.checking,
  );
  final coffee = TransactionCategory(
    id: coffeeId,
    name: 'Coffee',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );
  return HookedLedger(
    state: LedgerState(
      moneySources: {checking.id: MoneySource.account(checking)},
      categories: {coffee.id: coffee},
    ),
  );
}

final entryShellBodies = <ShellDestination, WidgetBuilder>{
  ShellDestination.overview: (_) => ShellPaneHost(
    pageBuilder: (_, _) => const Center(child: Text(probeLabel)),
  ),
  ShellDestination.trends: (_) => const Center(child: Text('trends probe')),
};

Future<Uint8List> solidPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 20, 20),
    Paint()..color = const Color(0xFF0000FF),
  );
  final image = await recorder.endRecording().toImage(20, 20);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Future<EntryHarness> pumpShell(
  WidgetTester tester, {
  Size size = phoneSize,
  TargetPlatform platform = TargetPlatform.iOS,
  bool failPush = false,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final recorder = RouteRecorder();
  final ledger = buildEntryLedger();
  final faults = EntryFaults();
  final log = LifecycleLog();
  final container = ProviderContainer(
    observers: [log],
    overrides: [
      hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
      shellPlatformProvider.overrideWithValue((
        isWeb: false,
        targetPlatform: platform,
      )),
      ledgerProvider.overrideWithValue(ledger),
      scanStripEnabledProvider.overrideWith((ref) async => false),
      entryFormViewModelProvider(null).overrideWith(() => CountingForm(faults)),
    ],
  );
  addTearDown(container.dispose);
  final harness = EntryHarness(container, recorder, ledger, faults, log);
  final shell = Capture(
    onBuilt: (context, ref) {
      harness.context = context;
      harness.ref = ref;
    },
    child: AppShell(bodies: entryShellBodies),
  );
  final home = ValueListenableBuilder<bool>(
    valueListenable: harness.showShell,
    builder: (_, show, _) => show ? shell : const SizedBox.shrink(),
  );
  Widget appContent(BuildContext context, Widget? child) {
    final root = failPush
        ? ThrowingNavigator(
            observers: [recorder],
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => home),
          )
        : child;
    return buildShellAppContent(context, root);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        builder: appContent,
        navigatorObservers: [recorder],
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> openAdd(WidgetTester tester, EntryHarness harness) async {
  harness.opened = harness.open();
  await tester.pumpAndSettle();
}

VoidCallback addDismiss(WidgetTester tester) =>
    tester.widget<EntryForm>(find.byType(EntryForm)).onDismiss!;

Future<void> resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<void> saveEntry(WidgetTester tester, EntryHarness harness) async {
  harness.form.setAmount('12.50');
  harness.form.setName('Lunch');
  harness.form.applyPickedSource(checkingId);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save entry'));
  await tester.pumpAndSettle();
}

Future<void> cancelEntry(WidgetTester tester, EntryHarness harness) async {
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
}
