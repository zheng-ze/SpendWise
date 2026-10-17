import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/ui_test_timeout.dart';

const _fixtureSize = Size(960, 720);
const _fixtureViewportWidth = 888.0;
const _rootRouteName = 'fixture-root';
final _fixtureNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'fixture-flow',
);
const _managedRouteKey = ValueKey('managed-phone-detail-route');
const _fixtureFabKey = ValueKey('fixture-floating-action');

class _SelectionFixture extends ChangeNotifier {
  ShellLayoutMode mode = ShellLayoutMode.open;
  String? selectedDetailId;
  bool delayRouteCompletion = false;

  void select(String? id) {
    selectedDetailId = id;
    notifyListeners();
  }

  void setMode(ShellLayoutMode value) {
    mode = value;
    notifyListeners();
  }
}

class _SelectionFixtureApp extends StatefulWidget {
  const _SelectionFixtureApp({required this.fixture});

  final _SelectionFixture fixture;

  @override
  State<_SelectionFixtureApp> createState() => _SelectionFixtureAppState();
}

class _SelectionFixtureAppState extends State<_SelectionFixtureApp> {
  @override
  void initState() {
    super.initState();
    widget.fixture.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(_SelectionFixtureApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.fixture.removeListener(_rebuild);
    widget.fixture.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.fixture.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: ShellPaneScope(
        mode: widget.fixture.mode,
        safeBodyWidth: _fixtureSize.width,
        addPresented: false,
        child: DestinationActivity(
          active: true,
          child: SizedBox(
            width: widget.fixture.mode == ShellLayoutMode.open
                ? _fixtureViewportWidth
                : _fixtureSize.width,
            height: _fixtureSize.height,
            child: _SelectionFixtureFlow(fixture: widget.fixture),
          ),
        ),
      ),
    ),
  );
}

class _SelectionFixtureFlow extends StatefulWidget {
  const _SelectionFixtureFlow({required this.fixture});

  final _SelectionFixture fixture;

  @override
  State<_SelectionFixtureFlow> createState() => _SelectionFixtureFlowState();
}

class _SelectionFixtureFlowState extends State<_SelectionFixtureFlow> {
  final _navigatorKey = _fixtureNavigatorKey;
  late final _routeObserver = _FixtureRouteObserver(
    onChange: _scheduleReconciliation,
    onRoutePushed: (route) {
      if (route.settings.name == _rootRouteName) _rootRoute = route;
    },
    onRouteRemoved: _finishManagedRoute,
    shouldDelayRemovedCompletion: () => widget.fixture.delayRouteCompletion,
  );
  Route<dynamic>? _rootRoute;
  Route<dynamic>? _managedRoute;
  ShellLayoutMode _mode = ShellLayoutMode.phone;
  bool _reconciliationScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.fixture.addListener(_scheduleReconciliation);
  }

  @override
  void didUpdateWidget(_SelectionFixtureFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.fixture.removeListener(_scheduleReconciliation);
    widget.fixture.addListener(_scheduleReconciliation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mode = ShellPaneScope.of(context).mode;
    _scheduleReconciliation();
  }

  @override
  void dispose() {
    widget.fixture.removeListener(_scheduleReconciliation);
    super.dispose();
  }

  void _scheduleReconciliation() {
    if (!mounted || _reconciliationScheduled) return;
    _reconciliationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconciliationScheduled = false;
      if (mounted) _reconcileLatestState();
    });
  }

  void _reconcileLatestState() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    if (_mode == ShellLayoutMode.open) {
      final route = _managedRoute;
      if (route == null) return;
      _managedRoute = null;
      navigator.removeRoute(route);
      return;
    }
    if (_mode != ShellLayoutMode.phone ||
        widget.fixture.selectedDetailId == null ||
        _managedRoute != null ||
        _routeObserver.topRoute != _rootRoute) {
      return;
    }
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'fixture-managed-detail'),
      builder: (context) => _buildManagedRoute(context),
    );
    _managedRoute = route;
    navigator.push(route);
  }

  void _finishManagedRoute(Route<dynamic> route) {
    if (route != _managedRoute) return;
    _managedRoute = null;
    widget.fixture.select(null);
  }

  Widget _buildManagedRoute(BuildContext context) => AnimatedBuilder(
    animation: widget.fixture,
    builder: (context, _) => Scaffold(
      key: _managedRouteKey,
      body: SafeArea(
        child: Column(
          children: [
            Text('Phone detail ${widget.fixture.selectedDetailId}'),
            TextButton(
              key: const ValueKey('select-B-from-detail'),
              onPressed: () => widget.fixture.select('B'),
              child: const Text('Select B'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildRoot(BuildContext context) => AnimatedBuilder(
    animation: widget.fixture,
    builder: (context, _) {
      final selectionId = widget.fixture.selectedDetailId;
      return ShellPaneHost(
        pageBuilder: (context, presentation) => Column(
          children: [
            const Text('Fixture page'),
            for (final id in ['A', 'B'])
              TextButton(
                key: ValueKey('select-$id'),
                onPressed: () => widget.fixture.select(id),
                child: Text('Select $id'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'fixture-cover'),
                  builder: (context) => Scaffold(
                    body: TextButton(
                      key: const ValueKey('dismiss-cover'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Dismiss cover'),
                    ),
                  ),
                ),
              ),
              child: const Text('Cover page'),
            ),
            Text(presentation.name),
          ],
        ),
        detail: selectionId == null
            ? null
            : ShellDetail(
                id: selectionId,
                title: 'Open detail $selectionId',
                bodyBuilder: (_) => Text('Open body $selectionId'),
                onClose: () => widget.fixture.select(null),
              ),
        floatingAction: const SizedBox(
          key: _fixtureFabKey,
          width: 40,
          height: 40,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    _mode = ShellPaneScope.of(context).mode;
    _scheduleReconciliation();
    return Navigator(
      key: _navigatorKey,
      observers: [_routeObserver],
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: const RouteSettings(name: _rootRouteName),
        builder: _buildRoot,
      ),
    );
  }
}

class _FixtureRouteObserver extends NavigatorObserver {
  _FixtureRouteObserver({
    required this.onChange,
    required this.onRoutePushed,
    required this.onRouteRemoved,
    required this.shouldDelayRemovedCompletion,
  });

  final VoidCallback onChange;
  final ValueChanged<Route<dynamic>> onRoutePushed;
  final ValueChanged<Route<dynamic>> onRouteRemoved;
  final bool Function() shouldDelayRemovedCompletion;
  final _routes = <Route<dynamic>>[];
  final _delayedRemovedRoutes = <Route<dynamic>>[];

  Route<dynamic>? get topRoute => _routes.isEmpty ? null : _routes.last;

  int get managedDetailCount => _routes
      .where((route) => route.settings.name == 'fixture-managed-detail')
      .length;

  void completeDelayedRemovals() {
    final routes = List<Route<dynamic>>.of(_delayedRemovedRoutes);
    _delayedRemovedRoutes.clear();
    for (final route in routes) {
      onRouteRemoved(route);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    onRoutePushed(route);
    onChange();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    onRouteRemoved(route);
    onChange();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    if (shouldDelayRemovedCompletion()) {
      _delayedRemovedRoutes.add(route);
    } else {
      onRouteRemoved(route);
    }
    onChange();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _routes.remove(oldRoute);
    if (newRoute != null) {
      _routes.add(newRoute);
      onRoutePushed(newRoute);
    }
    onChange();
  }
}

void main() {
  testWidgets('phone and open presentations track one latest selection', (
    tester,
  ) async {
    final fixture = _SelectionFixture();
    addTearDown(fixture.dispose);
    tester.view.physicalSize = _fixtureSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _SelectionFixtureApp(fixture: fixture),
      ),
    );
    await tester.pumpAndSettle();

    final navigatorElement = tester.element(find.byKey(_fixtureNavigatorKey));
    await tester.tap(find.byKey(const ValueKey('select-A')));
    await tester.pumpAndSettle();
    expect(find.text('Open detail A'), findsOneWidget);

    fixture.setMode(ShellLayoutMode.phone);
    await tester.pumpAndSettle();
    expect(find.text('Phone detail A'), findsOneWidget);
    expect(
      tester.element(find.byKey(_fixtureNavigatorKey)),
      same(navigatorElement),
    );
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    final managedRouteElement = tester.element(find.byKey(_managedRouteKey));
    await tester.tap(find.byKey(const ValueKey('select-B-from-detail')));
    await tester.pumpAndSettle();
    expect(find.text('Phone detail B'), findsOneWidget);
    expect(find.byKey(_managedRouteKey), findsOneWidget);
    expect(
      tester.element(find.byKey(_managedRouteKey)),
      same(managedRouteElement),
    );
    expect(fixture.selectedDetailId, 'B');

    fixture.setMode(ShellLayoutMode.open);
    await tester.pumpAndSettle();
    expect(find.text('Open detail B'), findsOneWidget);
    expect(find.text('Phone detail B'), findsNothing);
    expect(fixture.selectedDetailId, 'B');
    expect(container.read(selectedDestinationProvider), ShellDestination.money);
    await tester.tap(find.byKey(shellDetailCloseKey));
    await tester.pumpAndSettle();
    expect(fixture.selectedDetailId, isNull);
    expect(find.text('Open detail B'), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets(
    'covering routes survive resize and defer a missing phone detail',
    (tester) async {
      final fixture = _SelectionFixture()..setMode(ShellLayoutMode.phone);
      addTearDown(fixture.dispose);
      tester.view.physicalSize = _fixtureSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_SelectionFixtureApp(fixture: fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cover page'));
      await tester.pumpAndSettle();

      fixture.select('A');
      await tester.pumpAndSettle();
      expect(find.byKey(_managedRouteKey, skipOffstage: false), findsNothing);
      fixture.setMode(ShellLayoutMode.open);
      fixture.select('B');
      await tester.pumpAndSettle();
      expect(find.text('Dismiss cover'), findsOneWidget);
      expect(find.byKey(_managedRouteKey, skipOffstage: false), findsNothing);
      expect(find.byKey(_fixtureFabKey), findsNothing);
      await tester.tap(find.byKey(const ValueKey('dismiss-cover')));
      await tester.pumpAndSettle();
      expect(find.text('Open detail B'), findsOneWidget);

      fixture.setMode(ShellLayoutMode.phone);
      await tester.pumpAndSettle();
      expect(find.byKey(_managedRouteKey), findsOneWidget);
      expect(find.text('Phone detail B'), findsOneWidget);
      expect(find.text('Dismiss cover'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-A')));
      await tester.pumpAndSettle();
      expect(find.text('Phone detail A'), findsOneWidget);
      fixture.setMode(ShellLayoutMode.open);
      await tester.pumpAndSettle();
      expect(find.text('Open detail A'), findsOneWidget);
      expect(find.byKey(_managedRouteKey, skipOffstage: false), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'selection made under a cover is pushed when the cover is dismissed '
    'in phone mode',
    (tester) async {
      final fixture = _SelectionFixture()..setMode(ShellLayoutMode.phone);
      addTearDown(fixture.dispose);
      tester.view.physicalSize = _fixtureSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_SelectionFixtureApp(fixture: fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cover page'));
      await tester.pumpAndSettle();

      fixture.select('A');
      fixture.select('B');
      await tester.pumpAndSettle();
      expect(find.byKey(_managedRouteKey, skipOffstage: false), findsNothing);

      await tester.tap(find.byKey(const ValueKey('dismiss-cover')));
      await tester.pumpAndSettle();
      expect(find.byKey(_managedRouteKey), findsOneWidget);
      expect(find.text('Phone detail B'), findsOneWidget);
      expect(find.text('Open detail B'), findsNothing);
      expect(fixture.selectedDetailId, 'B');
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'rapid crossings use latest state and user Back clears selection',
    (tester) async {
      final fixture = _SelectionFixture();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = _fixtureSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_SelectionFixtureApp(fixture: fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-A')));
      fixture.setMode(ShellLayoutMode.phone);
      fixture.setMode(ShellLayoutMode.open);
      fixture.select('B');
      fixture.setMode(ShellLayoutMode.phone);
      await tester.pumpAndSettle();

      expect(find.text('Phone detail B'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(fixture.selectedDetailId, isNull);
      expect(find.text('Phone detail B'), findsNothing);
      expect(find.text('Fixture page'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'late completion of an outgoing route cannot clear replacement selection',
    (tester) async {
      final fixture = _SelectionFixture()..setMode(ShellLayoutMode.phone);
      addTearDown(fixture.dispose);
      tester.view.physicalSize = _fixtureSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_SelectionFixtureApp(fixture: fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-A')));
      await tester.pumpAndSettle();
      expect(find.text('Phone detail A'), findsOneWidget);

      final flowState = tester.state<_SelectionFixtureFlowState>(
        find.byType(_SelectionFixtureFlow),
      );
      fixture.delayRouteCompletion = true;
      fixture.setMode(ShellLayoutMode.open);
      await tester.pumpAndSettle();
      expect(fixture.selectedDetailId, 'A');
      expect(find.text('Phone detail A'), findsNothing);

      fixture.select('B');
      fixture.setMode(ShellLayoutMode.phone);
      await tester.pumpAndSettle();
      expect(find.text('Phone detail B'), findsOneWidget);
      expect(flowState._routeObserver.managedDetailCount, 1);

      fixture.delayRouteCompletion = false;
      flowState._routeObserver.completeDelayedRemovals();
      await tester.pumpAndSettle();
      expect(fixture.selectedDetailId, 'B');
      expect(find.text('Phone detail B'), findsOneWidget);
      expect(flowState._routeObserver.managedDetailCount, 1);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}
