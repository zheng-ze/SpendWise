import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/sheets/app_sheet_route.dart';
import 'package:spendwise/ui/shell/shell_pane_geometry.dart';

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
  bool _exposesDetail = false;
  bool? _pendingDetailExposure;
  Route<dynamic>? _shellRoute;
  ShellPaneGeometry? _geometry;

  Route<dynamic>? get shellRoute => _shellRoute;
  ShellPaneGeometry? get geometry => _geometry;

  bool get exposesDetail => _exposesDetail;

  void configure({
    required Route<dynamic>? route,
    required ShellPaneGeometry geometry,
  }) {
    if (_disposed) return;
    if (identical(_shellRoute, route) && _geometry == geometry) return;
    _shellRoute = route;
    _geometry = geometry;
    routesChanged();
  }

  void clearShellConfiguration(Route<dynamic>? route) {
    if (_disposed || !identical(_shellRoute, route)) return;
    _shellRoute = null;
    _geometry = null;
    publishDetailExposure(false);
    routesChanged();
  }

  void publishDetailExposure(bool exposed) {
    if (_disposed) return;
    if ((_pendingDetailExposure ?? _exposesDetail) == exposed) return;
    _pendingDetailExposure = exposed;
    _scheduleNotification();
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
      final exposure = _pendingDetailExposure;
      _pendingDetailExposure = null;
      final changed = exposure != null && exposure != _exposesDetail;
      if (exposure != null) _exposesDetail = exposure;
      final notify = _routesDirty || changed;
      _routesDirty = false;
      if (notify) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _routes.clear();
    _shellRoute = null;
    _geometry = null;
    _exposesDetail = false;
    _pendingDetailExposure = null;
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
