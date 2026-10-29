import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/accounts/account_sheet_presentation.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/ui_test_timeout.dart';

void main() {
  testWidgets('closing an open detail pane runs its close action', (
    tester,
  ) async {
    var closed = false;
    await _pumpOpenShell(
      tester,
      detail: ShellDetail(
        id: 'account',
        title: 'Account details',
        bodyBuilder: (_) => const Text('Account content'),
        onClose: () => closed = true,
      ),
    );

    expect(find.text('Account content'), findsOneWidget);
    await tester.tap(find.byKey(shellDetailCloseKey));

    expect(closed, isTrue);
  }, timeout: uiTestTimeout);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets(
      'retains page and detail State through ${platform.name} nested sheets',
      (tester) => _verifyRetainedSlots(tester, platform),
      timeout: uiTestTimeout,
    );
    testWidgets(
      'derives ${platform.name} fallback and re-shift from current detail',
      (tester) => _verifyCurrentDetail(tester, platform),
      timeout: uiTestTimeout,
    );
    testWidgets(
      'a ${platform.name} foreground page keeps its sheet presentation',
      (tester) => _verifyForeground(tester, platform),
      timeout: uiTestTimeout,
    );
  }
  testWidgets('shell teardown clears installed sheets and the shell route', (
    tester,
  ) async {
    final harness = await _pumpPane(tester, TargetPlatform.macOS);
    final sheet = harness.push();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await sheet.completed.timeout(_completionTimeout);
    await tester.pump();
    expect(harness.occupancy.hasSheets, isFalse);
  }, timeout: uiTestTimeout);
  testWidgets(
    'phone-open resizing retains sheet draft and mounted detail State',
    _verifyResizing,
    timeout: uiTestTimeout,
  );
}

Future<void> _pumpOpenShell(
  WidgetTester tester, {
  required ShellDetail detail,
}) async {
  final container = ProviderContainer(
    overrides: [
      shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: _shellHome(detail)),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _shellHome(ShellDetail detail) => AppShell(
  bodies: {
    ShellDestination.overview: (_) => ShellPaneHost(
      detail: detail,
      pageBuilder: (_, _) => const SizedBox.shrink(),
    ),
  },
);

const _pageKey = ValueKey('page-probe');
const _sheetKey = ValueKey('sheet-probe');
const _nestedKey = ValueKey('nested-probe');
const _openSize = Size(1024, 800);
const _phoneSize = Size(400, 800);
const _shortSize = Size(1024, 400);
const _completionTimeout = Duration(seconds: 5);

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key, required this.label});

  final String label;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  late final controller = TextEditingController(text: widget.label);
  final focus = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: controller, focusNode: focus);
}

class _PaneHarness {
  final selection = ValueNotifier<String?>('first');
  late BuildContext context;
  late ProviderContainer container;

  ShellSheetOccupancy get occupancy =>
      container.read(shellSheetOccupancyProvider);

  Widget buildHost(BuildContext context) {
    this.context = context;
    return ValueListenableBuilder<String?>(
      valueListenable: selection,
      builder: (_, id, _) {
        final detail = id == null ? null : _probeDetail(id);
        return ShellPaneHost(detail: detail, pageBuilder: _probePage);
      },
    );
  }

  AppSheetRoute<void> push({Key key = _sheetKey}) {
    final route = AppSheetRoute<void>(
      presentation: accountSheetPresentation(context),
      presentationResolver: accountSheetPresentation,
      builder: (_) => AppSheet(
        header: const Text('Draft'),
        body: _StateProbe(key: key, label: 'draft'),
      ),
    );
    Navigator.of(context, rootNavigator: true).push(route);
    return route;
  }
}

Widget _probePage(BuildContext context, ShellPagePresentation presentation) =>
    const _StateProbe(key: _pageKey, label: 'page');

ShellDetail _probeDetail(String id) => ShellDetail(
  id: id,
  title: id,
  bodyBuilder: (_) => _StateProbe(key: ValueKey('detail-$id'), label: id),
);

Future<_PaneHarness> _pumpPane(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  tester.view.physicalSize = _openSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      shellPlatformProvider.overrideWithValue((
        isWeb: false,
        targetPlatform: platform,
      )),
    ],
  );
  addTearDown(container.dispose);
  final harness = _PaneHarness()..container = container;
  addTearDown(harness.selection.dispose);
  final shell = AppShell(
    bodies: {ShellDestination.overview: harness.buildHost},
  );
  final app = MaterialApp(builder: buildShellAppContent, home: shell);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
  return harness;
}

_StateProbeState _probe(WidgetTester tester, Key key) =>
    tester.state<_StateProbeState>(find.byKey(key, skipOffstage: false));

Future<void> _closeSheet(WidgetTester tester, AppSheetRoute<void> sheet) async {
  sheet.navigator!.pop();
  await tester.pumpAndSettle();
  await sheet.completed.timeout(_completionTimeout);
}

Future<void> _verifyRetainedSlots(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final harness = await _pumpPane(tester, platform);
  final page = _probe(tester, _pageKey);
  final detail = _probe(tester, const ValueKey('detail-first'));
  final sheet = harness.push();
  await tester.pumpAndSettle();
  final draft = _probe(tester, _sheetKey);
  draft.controller.text = 'kept draft';
  expect(sheet.dimsBackground, isFalse);
  expect(_probe(tester, _pageKey), same(page));
  expect(_probe(tester, const ValueKey('detail-first')), same(detail));
  expect(find.byKey(_pageKey), findsNothing);
  expect(find.byKey(const ValueKey('detail-first')), findsOneWidget);
  expect(page.focus.canRequestFocus, isFalse);
  final nested = harness.push(key: _nestedKey);
  await tester.pumpAndSettle();
  expect(nested.dimsBackground, isFalse);
  await _closeSheet(tester, nested);
  expect(harness.occupancy.hasSheets, isTrue);
  expect(find.byKey(_pageKey), findsNothing);
  expect(_probe(tester, _sheetKey), same(draft));
  expect(draft.controller.text, 'kept draft');
  await _closeSheet(tester, sheet);
  expect(find.byKey(_pageKey), findsOneWidget);
  expect(page.focus.canRequestFocus, isTrue);
  expect(_probe(tester, _pageKey), same(page));
  expect(_probe(tester, const ValueKey('detail-first')), same(detail));
}

Future<void> _verifyCurrentDetail(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final harness = await _pumpPane(tester, platform);
  final initial = _probe(tester, const ValueKey('detail-first'));
  final sheet = harness.push();
  await tester.pumpAndSettle();
  final draft = _probe(tester, _sheetKey);
  draft.controller.text = 'retained';
  harness.selection.value = null;
  await tester.pumpAndSettle();
  expect(initial.mounted, isFalse);
  expect(find.byKey(_pageKey), findsOneWidget);
  expect(sheet.dimsBackground, isFalse);
  harness.selection.value = 'first';
  await tester.pumpAndSettle();
  expect(find.byKey(_pageKey), findsNothing);
  harness.selection.value = 'second';
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('detail-first')), findsNothing);
  expect(find.byKey(const ValueKey('detail-second')), findsOneWidget);
  expect(_probe(tester, _sheetKey), same(draft));
  expect(draft.controller.text, 'retained');
  await _closeSheet(tester, sheet);
  expect(find.byKey(_pageKey), findsOneWidget);
  expect(find.byKey(const ValueKey('detail-second')), findsOneWidget);
}

Future<void> _verifyResizing(WidgetTester tester) async {
  final harness = await _pumpPane(tester, TargetPlatform.iOS);
  final sheet = harness.push();
  await tester.pumpAndSettle();
  final draft = _probe(tester, _sheetKey);
  final detail = _probe(tester, const ValueKey('detail-first'));
  for (final size in [_phoneSize, _openSize, _shortSize, _openSize]) {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
    final open = size == _openSize;
    expect(sheet.dimsBackground, !open);
    expect(_probe(tester, _sheetKey), same(draft));
    expect(_probe(tester, const ValueKey('detail-first')), same(detail));
  }
  await _closeSheet(tester, sheet);
}

Future<void> _verifyForeground(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final harness = await _pumpPane(tester, platform);
  final navigator = Navigator.of(harness.context, rootNavigator: true);
  final foreground = MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Text('foreground')),
  );
  navigator.push(foreground);
  await tester.pumpAndSettle();
  final sheet = harness.push();
  await tester.pumpAndSettle();
  expect(sheet.nearestNonSheetPredecessor, same(foreground));
  final shellRoute = ModalRoute.of(
    tester.element(find.byType(AppShell, skipOffstage: false)),
  );
  expect(harness.occupancy.isCovered(shellRoute), isFalse);
  expect(sheet.dimsBackground, isFalse);
  await _closeSheet(tester, sheet);
  expect(find.text('foreground'), findsOneWidget);
  navigator.pop();
  await tester.pumpAndSettle();
  await foreground.completed.timeout(_completionTimeout);
}
