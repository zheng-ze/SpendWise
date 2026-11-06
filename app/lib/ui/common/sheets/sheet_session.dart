import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/sheets/app_sheet_route.dart';

// MARK: - Dismissal
void dismissSheetRoute(ModalRoute<Object?>? route) {
  final navigator = route?.navigator;
  if (route == null || navigator == null || !route.isActive) return;
  // A non-current sheet route sits under a picker; pop() would close the picker instead.
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

// MARK: - SheetSession
class SheetSession {
  AppSheetRoute<void>? route;
  ProviderSubscription<Object?>? subscription;
  bool retired = false;

  void end() {
    subscription?.close();
    subscription = null;
  }

  // The removal waits for the frame end so it never runs inside a provider notification or tree finalization.
  void retire() {
    if (retired) return;
    retired = true;
    end();
    final route = this.route;
    final navigator = route?.navigator;
    if (route == null || navigator == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  void dismiss() => dismissSheetRoute(route);
}
