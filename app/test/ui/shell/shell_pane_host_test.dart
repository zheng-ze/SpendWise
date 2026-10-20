import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/ui_test_timeout.dart';

const _windowSize = Size(960, 720);
const _selectedDetail = 'detail-selection';
const _pageKey = ValueKey('page-child');
const _probeWidth = 120.0;
const _fabKey = ValueKey('floating-action');

class _HostApp extends StatelessWidget {
  const _HostApp({
    required this.mode,
    required this.addPresented,
    required this.detail,
    required this.active,
    required this.pageBuilder,
    this.size = _windowSize,
    this.safeInsets = EdgeInsets.zero,
    this.textScaler,
    this.floatingAction,
  });

  final ShellLayoutMode mode;
  final bool addPresented;
  final ShellDetail? detail;
  final bool active;
  final Widget Function(BuildContext, ShellPagePresentation) pageBuilder;
  final Size size;
  final EdgeInsets safeInsets;
  final TextScaler? textScaler;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    final safeWidth = size.width - safeInsets.horizontal;
    final viewportWidth = mode == ShellLayoutMode.open
        ? safeWidth - openRailGutter
        : safeWidth;
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: safeInsets,
          textScaler: textScaler ?? TextScaler.noScaling,
        ),
        child: Scaffold(
          body: ShellPaneScope(
            mode: mode,
            safeBodyWidth: safeWidth,
            addPresented: addPresented,
            child: DestinationActivity(
              active: active,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: safeInsets.left),
                      child: SizedBox(
                        width: viewportWidth,
                        height: size.height,
                        child: ShellPaneHost(
                          key: const ValueKey('pane-host'),
                          pageBuilder: pageBuilder,
                          detail: detail,
                          floatingAction: floatingAction,
                        ),
                      ),
                    ),
                  ),
                  if (mode == ShellLayoutMode.open)
                    Positioned(
                      right: openRailRightInset + safeInsets.right,
                      bottom: openRailBottomInset + safeInsets.bottom,
                      child: OpenRail(
                        selected: ShellDestination.overview,
                        onDestinationSelected: (_) {},
                        onAdd: () {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageProbe extends StatefulWidget {
  const _PageProbe({required this.presentations, required this.presentation});

  final List<ShellPagePresentation> presentations;
  final ShellPagePresentation presentation;

  @override
  State<_PageProbe> createState() => _PageProbeState();
}

class _PageProbeState extends State<_PageProbe> {
  static int mounts = 0;

  @override
  void initState() {
    super.initState();
    mounts++;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      widget.presentations.add(widget.presentation);
      return SizedBox(
        key: _pageKey,
        width: constraints.maxWidth,
        child: const Text('feature page'),
      );
    },
  );
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key, required this.log});

  final List<String> log;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  final focusNode = FocusNode();
  int ticks = 0;

  @override
  void initState() {
    super.initState();
    widget.log.add('init');
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() => ticks++);
    controller.repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _probeWidth,
    child: TextField(focusNode: focusNode, autofocus: true),
  );
}

ShellDetail _probeDetail(String id, List<String> log) => ShellDetail(
  id: id,
  title: 'Probe $id',
  bodyBuilder: (_) => _StateProbe(key: const ValueKey('body-probe'), log: log),
  onClose: () {},
);

Widget _plainPage(BuildContext _, ShellPagePresentation _) =>
    const Text('feature page');

void main() {
  setUp(() => _PageProbeState.mounts = 0);

  testWidgets('960 by 720 host leaves the prescribed open rail gutter', (
    tester,
  ) async {
    final presentations = <ShellPagePresentation>[];
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = _windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _HostApp(
        mode: ShellLayoutMode.open,
        addPresented: false,
        active: true,
        detail: null,
        pageBuilder: (_, presentation) => _PageProbe(
          presentations: presentations,
          presentation: presentation,
        ),
      ),
    );

    final rail = tester.getRect(find.byKey(openRailKey));
    expect(rail.right, 951);
    expect(rail.bottom, 710);
    expect(tester.getSize(find.byKey(_pageKey)).width, 888);
    var previousDy = double.negativeInfinity;
    for (final label in ['Overview', 'History', 'Money', 'Settings', 'Add']) {
      final dy = tester.getCenter(find.text(label)).dy;
      expect(dy, greaterThan(previousDy), reason: label);
      previousDy = dy;
    }
    expect(
      tester.getSemantics(find.text('Overview')),
      matchesSemantics(
        label: 'Overview',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Add')),
      matchesSemantics(
        label: 'Add',
        isButton: true,
        hasSelectedState: false,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }, timeout: uiTestTimeout);

  testWidgets('open selection divides the safe body and keeps bounded panes', (
    tester,
  ) async {
    final presentations = <ShellPagePresentation>[];
    tester.view.physicalSize = _windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _HostApp(
        mode: ShellLayoutMode.open,
        addPresented: false,
        active: true,
        detail: ShellDetail(
          id: _selectedDetail,
          title: 'Selected item',
          bodyBuilder: (_) => ListView.builder(
            itemCount: 40,
            itemBuilder: (_, index) => Text('detail $index'),
          ),
          onClose: () {},
        ),
        pageBuilder: (_, presentation) => _PageProbe(
          presentations: presentations,
          presentation: presentation,
        ),
      ),
    );

    expect(tester.getSize(find.byKey(_pageKey)).width, 480);
    expect(find.byKey(shellDetailDividerKey), findsOneWidget);
    expect(tester.getSize(find.byKey(shellDetailPaneKey)).width, 408);
    expect(presentations.last, ShellPagePresentation.singleColumn);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets(
    'detail remains mounted and observes current selection offstage',
    (tester) async {
      final selection = ValueNotifier('A');
      addTearDown(selection.dispose);
      final presentations = <ShellPagePresentation>[];
      ShellDetail detail() => ShellDetail(
        id: selection.value,
        title: 'Selected ${selection.value}',
        bodyBuilder: (_) => Text('body ${selection.value}'),
        onClose: () {},
      );
      Future<void> pump({
        required ShellLayoutMode mode,
        bool add = false,
      }) async {
        await tester.pumpWidget(
          _HostApp(
            mode: mode,
            addPresented: add,
            active: true,
            detail: detail(),
            pageBuilder: (_, presentation) => _PageProbe(
              presentations: presentations,
              presentation: presentation,
            ),
          ),
        );
      }

      await pump(mode: ShellLayoutMode.open);
      expect(find.text('body A', skipOffstage: false), findsOneWidget);
      final pageElement = tester.element(find.byKey(_pageKey));
      final pageIdentity = identityHashCode(pageElement);
      final mounts = _PageProbeState.mounts;

      selection.value = 'B';
      await pump(mode: ShellLayoutMode.phone);
      expect(find.text('body B', skipOffstage: false), findsOneWidget);
      expect(
        identityHashCode(tester.element(find.byKey(_pageKey))),
        pageIdentity,
      );
      expect(_PageProbeState.mounts, mounts);

      await pump(mode: ShellLayoutMode.open, add: true);
      expect(presentations.last, ShellPagePresentation.singleColumn);
      expect(find.text('body B', skipOffstage: false), findsOneWidget);
      expect(tester.getSize(find.byKey(_pageKey)).width, 480);
      expect(_PageProbeState.mounts, mounts);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Close calls only the supplied callback once', (tester) async {
    var closeCount = 0;
    final presentations = <ShellPagePresentation>[];
    tester.view.physicalSize = _windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _HostApp(
        mode: ShellLayoutMode.open,
        addPresented: false,
        active: true,
        detail: ShellDetail(
          id: _selectedDetail,
          title: 'Selected item',
          bodyBuilder: (_) => const Text('detail body'),
          onClose: () => closeCount++,
        ),
        pageBuilder: (_, presentation) => _PageProbe(
          presentations: presentations,
          presentation: presentation,
        ),
      ),
    );

    await tester.tap(find.byKey(shellDetailCloseKey));

    expect(closeCount, 1);
    expect(find.text('feature page'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('floating action uses usable edge and follows page visibility', (
    tester,
  ) async {
    final presentations = <ShellPagePresentation>[];
    tester.view.physicalSize = _windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget buildAction() => const SizedBox(key: _fabKey, width: 40, height: 40);
    Future<void> pump({bool active = true, bool add = false}) =>
        tester.pumpWidget(
          _HostApp(
            mode: ShellLayoutMode.open,
            addPresented: add,
            active: active,
            detail: null,
            floatingAction: buildAction(),
            pageBuilder: (_, presentation) => _PageProbe(
              presentations: presentations,
              presentation: presentation,
            ),
          ),
        );

    await pump();
    expect(tester.getTopRight(find.byKey(_fabKey)).dx, 885);
    expect(tester.getBottomRight(find.byKey(_fabKey)).dy, 710);
    await pump(active: false);
    expect(find.byKey(_fabKey), findsNothing);
    await pump(add: true);
    expect(find.byKey(_fabKey), findsNothing);
    await pump();
    expect(find.byKey(_fabKey), findsOneWidget);
    showDialog<void>(
      context: tester.element(find.byKey(const ValueKey('pane-host'))),
      builder: (_) => const Dialog(child: Text('covering modal')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_fabKey), findsNothing);
    Navigator.of(tester.element(find.text('covering modal'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(_fabKey), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('page and detail scroll independently at small sizes', (
    tester,
  ) async {
    const smallSize = Size(600, 480);
    tester.view.physicalSize = smallSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _HostApp(
        mode: ShellLayoutMode.open,
        addPresented: false,
        active: true,
        size: smallSize,
        detail: ShellDetail(
          id: _selectedDetail,
          title: 'Selected item',
          bodyBuilder: (_) => ListView.builder(
            key: const ValueKey('detail-scroll'),
            itemCount: 50,
            itemBuilder: (_, index) => Text('detail $index'),
          ),
          onClose: () {},
        ),
        pageBuilder: (_, _) => ListView.builder(
          key: const ValueKey('page-scroll'),
          itemCount: 50,
          itemBuilder: (_, index) => Text('page $index'),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('page-scroll')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    final closeY = tester.getCenter(find.byKey(shellDetailCloseKey)).dy;
    expect(find.text('page 0'), findsNothing);
    expect(find.text('detail 0'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('detail-scroll')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail 0'), findsNothing);
    expect(tester.getCenter(find.byKey(shellDetailCloseKey)).dy, closeY);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('safe insets and larger text preserve the pinned Close control', (
    tester,
  ) async {
    const smallSize = Size(600, 480);
    const safeInsets = EdgeInsets.fromLTRB(20, 16, 30, 12);
    tester.view.physicalSize = smallSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _HostApp(
        mode: ShellLayoutMode.open,
        addPresented: false,
        active: true,
        size: smallSize,
        safeInsets: safeInsets,
        textScaler: TextScaler.linear(1.8),
        detail: ShellDetail(
          id: _selectedDetail,
          title: 'A selected item with a title that wraps at larger text sizes',
          subtitle: 'Additional detail',
          headerActions: [
            TextButton(onPressed: () {}, child: const Text('More actions')),
          ],
          bodyBuilder: (_) => ListView(
            children: [
              for (var index = 0; index < 20; index++) Text('row $index'),
            ],
          ),
          onClose: () {},
        ),
        pageBuilder: (_, _) => ListView(
          children: [
            for (var index = 0; index < 20; index++) Text('page $index'),
          ],
        ),
      ),
    );

    expect(find.byKey(shellDetailCloseKey), findsOneWidget);
    expect(tester.getSize(find.byKey(shellDetailPaneKey)).width, 203);
    final closeRect = tester.getRect(find.byKey(shellDetailCloseKey));
    final paneRect = tester.getRect(find.byKey(shellDetailPaneKey));
    expect(closeRect.top, greaterThanOrEqualTo(safeInsets.top));
    expect(paneRect.top, safeInsets.top);
    expect(paneRect.bottom, smallSize.height - safeInsets.bottom);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('short scaled detail surfaces scroll to keep Close reachable', (
    tester,
  ) async {
    const shortSize = Size(600, 240);
    const safeInsets = EdgeInsets.fromLTRB(20, 16, 30, 12);
    tester.view.physicalSize = shortSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _HostApp(
        mode: ShellLayoutMode.open,
        addPresented: false,
        active: true,
        size: shortSize,
        safeInsets: safeInsets,
        textScaler: TextScaler.linear(1.8),
        detail: ShellDetail(
          id: _selectedDetail,
          title: 'A selected item with a title that wraps at larger text sizes',
          subtitle: 'Additional detail',
          headerActions: [
            TextButton(onPressed: () {}, child: const Text('More actions')),
          ],
          bodyBuilder: (_) => ListView(
            children: [
              for (var index = 0; index < 20; index++) Text('row $index'),
            ],
          ),
          onClose: () {},
        ),
        pageBuilder: (_, _) => const Text('short page'),
      ),
    );

    final pane = find.byKey(shellDetailPaneKey);
    final overflowScroll = find.descendant(
      of: pane,
      matching: find.byType(SingleChildScrollView),
    );
    expect(overflowScroll, findsOneWidget);
    await tester.ensureVisible(find.byKey(shellDetailCloseKey));
    await tester.pumpAndSettle();
    final close = tester.getRect(find.byKey(shellDetailCloseKey));
    final paneRect = tester.getRect(pane);
    expect(close.top, greaterThanOrEqualTo(paneRect.top));
    expect(close.bottom, lessThanOrEqualTo(paneRect.bottom));
    expect(close.top, greaterThanOrEqualTo(safeInsets.top));
    expect(
      paneRect.bottom,
      lessThanOrEqualTo(shortSize.height - safeInsets.bottom),
    );
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('hidden detail neither ticks nor holds focus and resumes shown', (
    tester,
  ) async {
    tester.view.physicalSize = _windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = <String>[];
    Future<void> pump(ShellLayoutMode mode) => tester.pumpWidget(
      _HostApp(
        mode: mode,
        addPresented: false,
        active: true,
        detail: _probeDetail('A', log),
        pageBuilder: _plainPage,
      ),
    );

    await pump(ShellLayoutMode.phone);
    final probe = tester.state<_StateProbeState>(
      find.byType(_StateProbe, skipOffstage: false),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.ticks, 0);
    expect(probe.focusNode.hasFocus, isFalse);

    await pump(ShellLayoutMode.open);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.ticks, greaterThan(0));
    expect(log, ['init']);
  }, timeout: uiTestTimeout);

  testWidgets('floating action and detail do not remount each other', (
    tester,
  ) async {
    tester.view.physicalSize = _windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fabLog = <String>[];
    final bodyLog = <String>[];
    Future<void> pump({required ShellDetail? detail, bool active = true}) =>
        tester.pumpWidget(
          _HostApp(
            mode: ShellLayoutMode.open,
            addPresented: false,
            active: active,
            detail: detail,
            floatingAction: _StateProbe(key: _fabKey, log: fabLog),
            pageBuilder: _plainPage,
          ),
        );

    await pump(detail: null);
    await pump(detail: _probeDetail('A', bodyLog));
    await pump(detail: null);
    expect(fabLog, ['init']);

    bodyLog.clear();
    await pump(detail: _probeDetail('A', bodyLog));
    expect(bodyLog, ['init']);
    await pump(detail: _probeDetail('A', bodyLog), active: false);
    await pump(detail: _probeDetail('A', bodyLog));
    expect(bodyLog, ['init']);
  }, timeout: uiTestTimeout);

  testWidgets('detail body state survives crossing the scroll threshold', (
    tester,
  ) async {
    final log = <String>[];
    Future<void> pump(Size size, double scale) => tester.pumpWidget(
      _HostApp(
        mode: ShellLayoutMode.open,
        addPresented: false,
        active: true,
        size: size,
        textScaler: TextScaler.linear(scale),
        detail: _probeDetail('A', log),
        pageBuilder: _plainPage,
      ),
    );

    await pump(_windowSize, 1);
    await tester.enterText(find.byType(TextField), 'kept');
    await pump(const Size(960, 240), 1);
    expect(
      find.descendant(
        of: find.byKey(shellDetailPaneKey),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    await pump(_windowSize, 1);
    await pump(_windowSize, 2);
    await pump(_windowSize, 1);
    expect(find.text('kept'), findsOneWidget);
    expect(log, ['init']);
  }, timeout: uiTestTimeout);
}
