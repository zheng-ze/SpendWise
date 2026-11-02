import 'package:flutter/material.dart';

class MoneyTransactionsRouteSettings extends RouteSettings {
  const MoneyTransactionsRouteSettings({
    super.name,
    required this.preferredSourceId,
  });

  final String? preferredSourceId;
}

String? scopedRegisterSourceId(NavigatorState? navigator) {
  if (navigator == null) return null;
  Route<Object?>? top;
  // Accepting the first route reads the top without popping anything.
  navigator.popUntil((route) {
    top = route;
    return true;
  });
  final settings = top?.settings;
  return settings is MoneyTransactionsRouteSettings
      ? settings.preferredSourceId
      : null;
}
