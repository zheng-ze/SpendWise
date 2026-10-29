import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/pickers/receipt_choice_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_step_handlers.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';

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
    session.beginOpening(sourceId);
    final attempt = session.beginAttempt(resetReceipt: true);
    final initial = _presentationForMode(
      session.ref.read(shellLayoutModeProvider),
    );
    session.listenForSteps();
    Widget buildEntryForm(BuildContext context) => EntryForm(
      key: newEntryFormKey,
      onDismiss: session.close,
      onRetry: session.retryInitialization,
    );
    unawaited(
      showAppSheet<void>(
        context,
        presentation: initial,
        showShellNavigation: true,
        presentationResolver: _liveResolver(initial),
        onRouteCreated: session.attach,
        builder: buildEntryForm,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => session.markMounted());
    await session.finishAttempt(attempt);
    if (!session.eligible) session.close();
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
    if (!session.completion.isCompleted) session.completion.complete();
  }

  void _invalidateReceiptCoordinator() {
    if (_disposed) return;
    _container.invalidate(receiptEntryCoordinatorProvider(null));
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
class _AddAttempt {
  const _AddAttempt({
    required this.attempt,
    required this.future,
    required this.notifier,
  });

  final int attempt;

  final Future<EntryFormViewState> future;

  final EntryFormNotifier notifier;
}

class _AddSession {
  _AddSession(this._container, this._controller, this.context, this.ref);

  final ProviderContainer _container;
  final NewEntryPresentationController _controller;
  final BuildContext context;
  final WidgetRef ref;
  final completion = Completer<void>();
  final _cleaned = Completer<void>();
  AppSheetRoute<void>? route;
  AppSheetRoute<ReceiptChoice>? _receiptRoute;
  ProviderSubscription<AsyncValue<EntryFormViewState>>? _subscription;
  bool retired = false;
  bool _mounted = false;
  String? _sourceId;
  int _attempt = 0;
  bool _prefillApplied = false;
  bool _initializing = false;

  bool get eligible =>
      !retired &&
      _controller._owns(this) &&
      context.mounted &&
      (route?.isActive ?? true);

  void beginOpening(String? sourceId) => _sourceId = sourceId;

  _AddAttempt beginAttempt({required bool resetReceipt}) {
    final attempt = ++_attempt;
    _initializing = true;
    final formProvider = entryFormViewModelProvider(null);
    _container.invalidate(formProvider);
    if (resetReceipt) {
      _container.invalidate(receiptEntryCoordinatorProvider(null));
    }
    final notifier = _container.read(formProvider.notifier);
    notifier.bindAddLifetime(() => !retired && _attempt == attempt);
    return _AddAttempt(
      attempt: attempt,
      future: _container.read(formProvider.future),
      notifier: notifier,
    );
  }

  void retryInitialization() => unawaited(retryLoad());

  Future<void> retryLoad() async {
    if (retired || _initializing) return;
    if (!_controller._owns(this)) return;
    final current = _container.read(entryFormViewModelProvider(null));
    if (!current.hasError) return;
    await finishAttempt(beginAttempt(resetReceipt: false));
  }

  Future<void> finishAttempt(_AddAttempt start) async {
    try {
      try {
        await start.future;
      } catch (_) {
        return;
      }
      if (!eligible || _attempt != start.attempt || _prefillApplied) return;
      _prefillApplied = true;
      final sourceId = _sourceId;
      if (sourceId != null) start.notifier.prefillSource(sourceId);
    } finally {
      _initializing = false;
    }
  }

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
      sheetPresentation: route?.resolveLive,
      onReceiptRouteCreated: (created) => _receiptRoute = created,
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
    final receiptRoute = _receiptRoute;
    _receiptRoute = null;
    final navigator = receiptRoute?.navigator;
    if (receiptRoute != null && navigator != null && navigator.mounted) {
      if (receiptRoute.isActive) navigator.removeRoute(receiptRoute);
    }
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
