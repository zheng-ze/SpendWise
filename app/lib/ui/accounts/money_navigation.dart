import 'package:flutter/material.dart';

class MoneyTransactionsRouteSettings extends RouteSettings {
  const MoneyTransactionsRouteSettings({
    super.name,
    required this.preferredSourceId,
  });

  final String? preferredSourceId;
}

class MoneyNavigatorObserver extends NavigatorObserver with ChangeNotifier {
  Route<Object?>? _topRoute;

  bool get hasScopedTransactionsRoute =>
      _topRoute?.settings is MoneyTransactionsRouteSettings;

  String? get sourceId {
    final navigator = this.navigator;
    if (navigator == null || !navigator.mounted) return null;
    final route = _topRoute;
    if (route == null || route.navigator != navigator || !route.isCurrent) {
      return null;
    }
    final settings = route.settings;
    return settings is MoneyTransactionsRouteSettings
        ? settings.preferredSourceId
        : null;
  }

  @override
  void didChangeTop(
    Route<Object?>? topRoute,
    Route<Object?>? previousTopRoute,
  ) {
    final previousHasScopedTransactionsRoute = hasScopedTransactionsRoute;
    _topRoute = topRoute;
    if (previousHasScopedTransactionsRoute != hasScopedTransactionsRoute) {
      notifyListeners();
    }
  }
}
