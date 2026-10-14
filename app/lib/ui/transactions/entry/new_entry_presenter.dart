import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_step_handlers.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';

// MARK: - Presentation State
enum NewEntryPresentation { closed, opening, presented }

final newEntryPresentationProvider = StateProvider<NewEntryPresentation>(
  (ref) => NewEntryPresentation.closed,
);

final newEntryPresentationControllerProvider =
    Provider<NewEntryPresentationController>((ref) {
      final controller = NewEntryPresentationController(ref.container);
      ref.onDispose(controller.dispose);
      return controller;
    });

// MARK: - Helpers
const newEntryFormKey = ValueKey('new-entry-form');

AppSheetPresentation _presentationForMode(ShellLayoutMode mode) =>
    switch (mode) {
      ShellLayoutMode.phone => AppSheetPresentation.phone,
      ShellLayoutMode.open => AppSheetPresentation.open,
      ShellLayoutMode.desktop => AppSheetPresentation.desktop,
    };

Future<void> openNewEntry({
  required BuildContext context,
  required WidgetRef ref,
  String? sourceId,
}) {
  final controller = ref.read(newEntryPresentationControllerProvider);
  return controller.open(context: context, ref: ref, sourceId: sourceId);
}

// MARK: - Controller
class NewEntryPresentationController {
  NewEntryPresentationController(this._container);

  final ProviderContainer _container;
  _AddSession? _session;
  bool _disposed = false;

  Future<void> open({
    required BuildContext context,
    required WidgetRef ref,
    String? sourceId,
  }) {
    if (_disposed || _session != null) return Future<void>.value();
    final session = _AddSession(_container, this, context, ref);
    _session = session;
    _setPresentation(NewEntryPresentation.opening);
    unawaited(_start(context, session, sourceId));
    return session.completion.future;
  }

  void ownerDisposed(BuildContext owner) {
    final session = _session;
    if (session == null || !identical(session.context, owner)) return;
    session.retire();
    if (session.routeInstalled) return session.removeOutsideCallback();
    _release(session);
  }

  void dispose() {
    _disposed = true;
    final session = _session;
    if (session == null) return;
    session.retire();
    if (!session.routeInstalled) return _finish(session);
    session.removeOutsideCallback();
  }

  Future<void> _start(
    BuildContext context,
    _AddSession session,
    String? sourceId,
  ) async {
    try {
      final presented = await _present(context, session, sourceId);
      if (!presented) _release(session);
    } catch (error, stack) {
      if (!session.retired) _report(error, stack);
      _abort(session);
    }
  }

  void _abort(_AddSession session) {
    session.close();
    if (session.routeInstalled) return;
    session.discardRoute();
    _release(session);
  }

  Future<bool> _present(
    BuildContext context,
    _AddSession session,
    String? sourceId,
  ) async {
    final formProvider = entryFormViewModelProvider(null);
    _container.invalidate(formProvider);
    _container.invalidate(receiptEntryCoordinatorProvider(null));
    await _container.read(formProvider.future);
    if (!context.mounted || !session.eligible) return false;
    if (sourceId != null) {
      _container.read(formProvider.notifier).prefillSource(sourceId);
    }
    final initial = _presentationForMode(
      session.ref.read(shellLayoutModeProvider),
    );
    _container
        .read(formProvider.notifier)
        .bindAddLifetime(() => !session.retired);
    session.listenForSteps();
    _setPresentation(NewEntryPresentation.presented);
    final resolver = _liveResolver(initial);
    unawaited(
      showAppSheet<void>(
        context,
        presentation: initial,
        presentationResolver: resolver,
        onRouteCreated: session.attach,
        builder: (_) =>
            EntryForm(key: newEntryFormKey, onDismiss: session.close),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => session.markMounted());
    return true;
  }

  AppSheetPresentation Function(BuildContext) _liveResolver(
    AppSheetPresentation initial,
  ) => (routeContext) {
    final mode = ShellLayoutModeScope.maybeOf(routeContext);
    if (mode == null) return initial;
    return _presentationForMode(mode);
  };

  bool _owns(_AddSession session) => !_disposed && identical(_session, session);

  void _release(_AddSession session) {
    session.retire();
    unawaited(session.cleanedUp.then((_) => _finish(session)));
  }

  void _finish(_AddSession session) {
    if (!identical(_session, session)) return;
    _session = null;
    if (!_disposed) _setPresentation(NewEntryPresentation.closed);
    if (!session.completion.isCompleted) session.completion.complete();
  }

  void _invalidateReceiptCoordinator() {
    if (_disposed) return;
    _container.invalidate(receiptEntryCoordinatorProvider(null));
  }

  void _setPresentation(NewEntryPresentation value) {
    _container.read(newEntryPresentationProvider.notifier).state = value;
  }

  void _report(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'spendwise',
        context: ErrorDescription('while opening a new entry'),
      ),
    );
  }
}

// MARK: - Session
class _AddSession {
  _AddSession(this._container, this._controller, this.context, this.ref);

  final ProviderContainer _container;
  final NewEntryPresentationController _controller;
  final BuildContext context;
  final WidgetRef ref;
  final completion = Completer<void>();
  final _cleaned = Completer<void>();
  AppSheetRoute<void>? route;
  ProviderSubscription<AsyncValue<EntryFormViewState>>? _subscription;
  bool retired = false;
  bool _mounted = false;

  bool get eligible =>
      !retired &&
      _controller._owns(this) &&
      context.mounted &&
      (route?.isActive ?? true);

  void listenForSteps() {
    _subscription = _container.listen(
      entryFormViewModelProvider(null),
      (previous, next) => consumeStep(),
    );
  }

  void attach(AppSheetRoute<void> created) {
    route = created;
    unawaited(_retireWhenPopped(created));
    unawaited(_releaseWhenCompleted(created));
  }

  Future<void> _retireWhenPopped(AppSheetRoute<void> created) async {
    await created.popped;
    retire();
  }

  Future<void> _releaseWhenCompleted(AppSheetRoute<void> created) async {
    await created.completed;
    _controller._release(this);
  }

  void markMounted() {
    _mounted = true;
    consumeStep();
  }

  void consumeStep() {
    if (!_mounted || !eligible) return;
    final formProvider = entryFormViewModelProvider(null);
    final step = _container.read(formProvider).value?.step;
    if (step == null) return;
    _container.read(formProvider.notifier).clearStep();
    if (!eligible) return;
    dispatchEntryFormStep(
      context,
      ref,
      null,
      step,
      useRootNavigator: true,
      isCurrent: () => eligible,
    );
  }

  Future<void> get cleanedUp => _cleaned.future;

  bool get routeInstalled => route?.navigator != null;

  void retire() {
    if (retired) return;
    retired = true;
    _subscription?.close();
    _subscription = null;
    scheduleMicrotask(_completeCleanup);
  }

  void _completeCleanup() {
    _controller._invalidateReceiptCoordinator();
    _cleaned.complete();
  }

  void close() {
    retire();
    final addRoute = route;
    final navigator = addRoute?.navigator;
    if (addRoute == null || navigator == null || !addRoute.isActive) return;
    if (addRoute.isCurrent) {
      navigator.pop();
      return;
    }
    navigator.removeRoute(addRoute);
  }

  void removeOutsideCallback() {
    final addRoute = route;
    if (addRoute == null) return;
    scheduleMicrotask(() => _removeActive(addRoute));
  }

  void _removeActive(AppSheetRoute<void> addRoute) {
    final navigator = addRoute.navigator;
    if (navigator == null || !navigator.mounted || !addRoute.isActive) return;
    navigator.removeRoute(addRoute);
  }

  void discardRoute() => route?.dispose();
}
