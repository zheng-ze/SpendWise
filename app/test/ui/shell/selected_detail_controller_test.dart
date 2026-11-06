import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/base/id_selection.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/selected_detail_controller.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/ui_test_timeout.dart';

const _phoneSize = Size(400, 800);
const _openSize = Size(900, 700);

final _selectionProvider = NotifierProvider<IdSelectionNotifier, String?>(
  IdSelectionNotifier.new,
);

final _events = <String>[];

final _ownerProvider = Provider.autoDispose.family<String, String>(
  (ref, id) => id,
);

class _LedgerSource extends Notifier<Ledger?> {
  @override
  Ledger? build() => Ledger();

  void replace() => state = Ledger();
}

final _ledgerSourceProvider = NotifierProvider<_LedgerSource, Ledger?>(
  _LedgerSource.new,
);

class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  late final SelectedDetailController controller = SelectedDetailController(
    ref: ref,
    selection: _selectionProvider,
    buildPage: _buildPage,
    navigatorContext: () => context,
    mounted: () => mounted,
    openOwners: _openOwners,
    onShownChanged: _onShownChanged,
  );

  List<ProviderSubscription<Object?>> _openOwners(String id) {
    _events.add('open $id');
    return [ref.listenManual(_ownerProvider(id), (_, _) {})];
  }

  void _onShownChanged(String? shownID) => _events.add('shown $shownID');

  ModalRoute<Object?> _buildPage(String id) => MaterialPageRoute<Object?>(
    builder: (_) => Scaffold(body: Text('page $id')),
  );

  @override
  void initState() {
    super.initState();
    controller.start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('host'));
}

class _Harness {
  _Harness(this.tester, this.container);

  final WidgetTester tester;
  final ProviderContainer container;
  final navigator = GlobalKey<NavigatorState>();
  final hostVisible = ValueNotifier<bool>(true);
  final clears = <String?>[];

  List<String> get events => _events;

  bool ownerOpen(String id) => container.exists(_ownerProvider(id));

  void replaceLedger() =>
      container.read(_ledgerSourceProvider.notifier).replace();

  void clear() => container.read(_selectionProvider.notifier).clear();

  String? get selection => container.read(_selectionProvider);

  void select(String id) =>
      container.read(_selectionProvider.notifier).select(id);

  void setWindow(Size size) => tester.view.physicalSize = size;

  Widget buildHome(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: hostVisible,
    builder: (_, visible, _) =>
        visible ? const _Host() : const Scaffold(body: Text('gone')),
  );

  AppSheetRoute<void> pushSheet() {
    final route = AppSheetRoute<void>(
      presentation: AppSheetPresentation.phone,
      showShellNavigation: false,
      builder: (_) => const AppSheet(header: Text('sheet'), body: Text('body')),
    );
    navigator.currentState!.push(route);
    return route;
  }

  Future<void> settle() => tester.pumpAndSettle();
}

Future<_Harness> _pump(WidgetTester tester) async {
  _events.clear();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _phoneSize;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWith((ref) => ref.watch(_ledgerSourceProvider)),
      shellPlatformProvider.overrideWithValue((
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      )),
    ],
  );
  addTearDown(container.dispose);
  final harness = _Harness(tester, container);
  container.listen(_selectionProvider, (previous, next) {
    if (previous != null && next == null) harness.clears.add(previous);
  });
  final app = MaterialApp(
    navigatorKey: harness.navigator,
    builder: buildShellAppContent,
    home: Builder(builder: harness.buildHome),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('phone selection pushes the page on the root navigator', (
    tester,
  ) async {
    final harness = await _pump(tester);

    harness.select('a');
    await harness.settle();

    expect(find.text('page a'), findsOneWidget);
    expect(harness.selection, 'a');
  }, timeout: uiTestTimeout);

  testWidgets('an installed sheet defers the push until it completes', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final sheet = harness.pushSheet();
    await harness.settle();

    harness.select('a');
    await harness.settle();
    expect(find.text('page a'), findsNothing);

    harness.navigator.currentState!.removeRoute(sheet);
    await harness.settle();
    expect(find.text('page a'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('switching to open removes the page and keeps the selection', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.select('a');
    await harness.settle();

    harness.setWindow(_openSize);
    await harness.settle();

    expect(find.text('page a'), findsNothing);
    expect(harness.selection, 'a');
    expect(harness.clears, isEmpty);
  }, timeout: uiTestTimeout);

  testWidgets('a user pop clears a selection that still matches the page', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.select('a');
    await harness.settle();

    harness.navigator.currentState!.pop();
    await harness.settle();

    expect(find.text('page a'), findsNothing);
    expect(harness.selection, isNull);
    expect(harness.clears, ['a']);
  }, timeout: uiTestTimeout);

  testWidgets('a user pop leaves a selection that no longer matches', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.select('a');
    await harness.settle();

    harness.select('b');
    harness.navigator.currentState!.pop();
    await harness.settle();

    expect(harness.selection, 'b');
    expect(harness.clears, isEmpty);
    expect(find.text('page b'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('dispose removes the page and closes the owners', (tester) async {
    final harness = await _pump(tester);
    harness.select('a');
    await harness.settle();
    harness.events.clear();

    harness.hostVisible.value = false;
    await harness.settle();

    expect(find.text('page a'), findsNothing);
    expect(harness.selection, 'a');
    expect(harness.clears, isEmpty);
    expect(harness.events, ['shown null']);
    expect(harness.ownerOpen('a'), isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('owners open for the selected id and report it as shown', (
    tester,
  ) async {
    final harness = await _pump(tester);

    harness.select('a');
    await harness.settle();

    expect(harness.events, ['shown a', 'open a']);
    expect(harness.ownerOpen('a'), isTrue);
  }, timeout: uiTestTimeout);

  testWidgets('a new selection reports the change then opens the new owners', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.select('a');
    await harness.settle();
    harness.events.clear();

    harness.select('b');
    await harness.settle();

    expect(harness.events, ['shown b', 'open b']);
    expect(harness.ownerOpen('a'), isFalse);
    expect(harness.ownerOpen('b'), isTrue);
  }, timeout: uiTestTimeout);

  testWidgets('clearing the selection closes the owners', (tester) async {
    final harness = await _pump(tester);
    harness.select('a');
    await harness.settle();
    harness.events.clear();

    harness.clear();
    await harness.settle();

    expect(harness.events, ['shown null']);
    expect(harness.ownerOpen('a'), isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('a replaced ledger clears the selection and closes owners', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.select('a');
    await harness.settle();
    harness.events.clear();

    harness.replaceLedger();
    await harness.settle();

    expect(harness.selection, isNull);
    expect(harness.clears, ['a']);
    expect(harness.events, ['shown null']);
    expect(harness.ownerOpen('a'), isFalse);
  }, timeout: uiTestTimeout);
}
