import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/sheets/app_sheet_route.dart';

final shellSheetOccupancyProvider =
    NotifierProvider<ShellSheetOccupancyNotifier, ShellSheetOccupancy>(
      ShellSheetOccupancyNotifier.new,
    );

class ShellSheetOccupancy {
  const ShellSheetOccupancy(this.routes);

  final Set<AppSheetRoute<dynamic>> routes;

  bool get hasSheets => routes.isNotEmpty;

  bool get suppressesShellNavigation =>
      routes.any((route) => route.showShellNavigation);

  bool isCovered(Route<dynamic>? shellRoute) {
    if (shellRoute == null) return false;
    return routes.any(
      (route) => identical(route.nearestNonSheetPredecessor, shellRoute),
    );
  }
}

class ShellSheetOccupancyNotifier extends Notifier<ShellSheetOccupancy> {
  final _routes = <AppSheetRoute<dynamic>>{};
  bool _publishScheduled = false;
  bool _disposed = false;

  @override
  ShellSheetOccupancy build() {
    ref.onDispose(_markDisposed);
    return const ShellSheetOccupancy({});
  }

  void register(AppSheetRoute<dynamic> route) {
    if (_routes.add(route)) routesChanged();
  }

  void release(AppSheetRoute<dynamic> route) {
    if (_routes.remove(route)) routesChanged();
  }

  void routesChanged() {
    if (_disposed || _publishScheduled) return;
    _publishScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) => _publish());
  }

  void _publish() {
    _publishScheduled = false;
    if (_disposed) return;
    state = ShellSheetOccupancy(Set.unmodifiable(_routes));
  }

  void _markDisposed() {
    _disposed = true;
    _routes.clear();
  }
}
