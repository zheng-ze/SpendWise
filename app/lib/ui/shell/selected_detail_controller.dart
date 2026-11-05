import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';

// MARK: - SelectedDetailController
class SelectedDetailController {
  SelectedDetailController({
    required this.ref,
    required this.selection,
    required this.clearSelection,
    required this.buildPage,
    required this.navigatorContext,
    required this.mounted,
  });

  final WidgetRef ref;
  final ProviderListenable<String?> selection;
  final VoidCallback clearSelection;
  final ModalRoute<Object?> Function(String id) buildPage;
  final BuildContext? Function() navigatorContext;
  final bool Function() mounted;

  bool _reconcileScheduled = false;
  ModalRoute<Object?>? _page;
  String? _pageID;
  final Set<ModalRoute<Object?>> _flowRemovedPages = {};
  NavigatorState? _rootNavigator;

  late final ProviderSubscription<String?> _selectionSubscription;
  late final ProviderSubscription<ShellLayoutMode> _modeSubscription;
  late final ProviderSubscription<ShellSheetOccupancy> _occupancySubscription;

  // MARK: - Lifecycle

  void start() {
    _selectionSubscription = ref.listenManual(
      selection,
      (_, _) => _scheduleReconcile(),
    );
    _modeSubscription = ref.listenManual(
      shellLayoutModeProvider,
      (_, _) => _scheduleReconcile(),
    );
    _occupancySubscription = ref.listenManual(
      shellSheetOccupancyProvider,
      (_, _) => _scheduleReconcile(),
    );
    _scheduleReconcile();
  }

  void dispose() {
    _occupancySubscription.close();
    _selectionSubscription.close();
    _modeSubscription.close();
    _removePageAfterFrame();
  }

  // MARK: - Reconciliation

  void reconcileNow() {
    final selected = ref.read(selection);
    final phone = ref.read(shellLayoutModeProvider) == ShellLayoutMode.phone;
    final wanted = phone ? selected : null;
    if (_pageID == wanted) return;
    _removePage();
    final context = navigatorContext();
    if (wanted == null || context == null) return;
    if (ref.read(shellSheetOccupancyProvider).hasSheets) return;
    _pushPage(context, wanted);
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (mounted()) reconcileNow();
    });
  }

  void _pushPage(BuildContext context, String id) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = buildPage(id);
    _rootNavigator = navigator;
    _page = route;
    _pageID = id;
    unawaited(navigator.push(route));
    unawaited(_clearSelectionWhenPopped(route, id));
  }

  Future<void> _clearSelectionWhenPopped(
    ModalRoute<Object?> route,
    String id,
  ) async {
    await route.completed;
    if (_flowRemovedPages.remove(route) || !mounted()) return;
    if (identical(_page, route)) {
      _page = null;
      _pageID = null;
    }
    if (ref.read(selection) != id) return;
    clearSelection();
  }

  void _removePage() {
    final route = _page;
    _page = null;
    _pageID = null;
    if (route == null || !route.isActive) return;
    _flowRemovedPages.add(route);
    _rootNavigator?.removeRoute(route);
  }

  void _removePageAfterFrame() {
    final route = _page;
    final navigator = _rootNavigator;
    _page = null;
    if (route == null || navigator == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }
}
