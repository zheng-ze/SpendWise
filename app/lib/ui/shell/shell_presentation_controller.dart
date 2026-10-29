import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/sheets/app_sheet_route.dart';

final shellPresentationControllerProvider =
    Provider<ShellPresentationController>((ref) {
      final controller = ShellPresentationController();
      ref.onDispose(controller.dispose);
      return controller;
    });

class ShellPresentationController extends ChangeNotifier {
  final _routes = <AppSheetRoute<dynamic>>{};
  bool _notificationScheduled = false;
  bool _routesDirty = false;
  bool _disposed = false;
  Route<dynamic>? _shellRoute;

  Route<dynamic>? get shellRoute => _shellRoute;

  void configure({required Route<dynamic>? route}) {
    if (_disposed || identical(_shellRoute, route)) return;
    _shellRoute = route;
    routesChanged();
  }

  void clearShellConfiguration(Route<dynamic>? route) {
    if (_disposed || !identical(_shellRoute, route)) return;
    _shellRoute = null;
    routesChanged();
  }

  bool get hasSheets => _routes.isNotEmpty;

  bool get suppressesShellNavigation =>
      _routes.any((route) => route.showShellNavigation);

  bool isCovered(Route<dynamic>? shellRoute) {
    if (shellRoute == null) return false;
    return _routes.any((route) {
      assert(route.predecessorInitialized);
      return identical(route.nearestNonSheetPredecessor, shellRoute);
    });
  }

  void register(AppSheetRoute<dynamic> route) {
    if (_disposed || !_routes.add(route)) return;
    routesChanged();
  }

  void release(AppSheetRoute<dynamic> route) {
    if (_disposed || !_routes.remove(route)) return;
    routesChanged();
  }

  void routesChanged() {
    if (_disposed) return;
    _routesDirty = true;
    _scheduleNotification();
  }

  void _scheduleNotification() {
    if (_disposed || _notificationScheduled) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _notificationScheduled = false;
      if (_disposed) return;
      assert(_routes.every((route) => route.predecessorInitialized));
      if (!_routesDirty) return;
      _routesDirty = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _routes.clear();
    _shellRoute = null;
    super.dispose();
  }
}

class ShellPresentationScope
    extends InheritedNotifier<ShellPresentationController> {
  const ShellPresentationScope({
    super.key,
    required ShellPresentationController controller,
    required super.child,
  }) : super(notifier: controller);

  static ShellPresentationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShellPresentationScope>()
      ?.notifier;

  static ShellPresentationController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellPresentationScope>()?.notifier;
}
