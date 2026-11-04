import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_sheet_presentation.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_host.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/history_entry_selection.dart';

final editEntryPresentationControllerProvider =
    Provider<EditEntryPresentationController>((ref) {
      final controller = EditEntryPresentationController(ref.container);
      ref.onDispose(controller.dispose);
      return controller;
    });

// MARK: - Open
Future<void> openEditEntry({
  required BuildContext context,
  required WidgetRef ref,
  required String entryId,
}) {
  final controller = ref.read(editEntryPresentationControllerProvider);
  final selection = ref.read(historyEntrySelectionProvider);
  if (selection == entryId) {
    ref.read(historyEntrySelectionProvider.notifier).clear();
  }
  return controller.open(context: context, entryId: entryId);
}

// MARK: - Controller
class EditEntryPresentationController {
  EditEntryPresentationController(this._container);

  final ProviderContainer _container;
  final _owners = <String, Object>{};
  AppSheetRoute<void>? _route;
  bool _disposed = false;

  Future<void> open({required BuildContext context, required String entryId}) {
    if (_disposed || _route != null) return Future<void>.value();
    _container.invalidate(entryFormViewModelProvider(entryId));
    AppSheetRoute<void>? created;
    void close() => _close(created);
    Widget buildHost(BuildContext _) => EditEntryHost(
      entryId: entryId,
      frame: EntryFormFrame.sheet,
      onDismiss: close,
    );
    try {
      unawaited(
        showAppSheet<void>(
          context,
          presentation: accountSheetPresentation(context),
          presentationResolver: accountSheetPresentation,
          showShellNavigation: true,
          onRouteCreated: (route) {
            created = route;
            _route = route;
            unawaited(route.completed.then((_) => _release(route)));
          },
          builder: buildHost,
        ),
      );
    } catch (_) {
      created?.dispose();
      _route = null;
      rethrow;
    }
    return created!.completed;
  }

  Object claim(String entryId) {
    final token = Object();
    _owners[entryId] = token;
    return token;
  }

  bool owns(String entryId, Object token) =>
      !_disposed && identical(_owners[entryId], token);

  void release(String entryId, Object token) {
    if (identical(_owners[entryId], token)) _owners.remove(entryId);
  }

  void dispose() {
    _disposed = true;
    _owners.clear();
  }

  void _release(AppSheetRoute<void> route) {
    if (identical(_route, route)) _route = null;
  }

  void _close(AppSheetRoute<void>? route) {
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) return navigator.pop();
    navigator.removeRoute(route);
  }
}
