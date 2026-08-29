import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A feature Flow that owns its own nested Navigator (ADR-0059). Pair with a
/// [FlowBaseState] subclass, which supplies the lifecycle plumbing this
/// widget itself stays free of: the navigator key, the [PopScope] that
/// routes a system back gesture into that Navigator instead of the app's
/// root one, and the root-screen scaffolding.
abstract class FlowBase<S> extends ConsumerStatefulWidget {
  const FlowBase({super.key});
}

/// Shared lifecycle plumbing for a [FlowBase]. A subclass supplies
/// [subscribeToStep] to wire up its own ViewModel's step stream,
/// [handleStep] for its step switch, and [buildRoot] for its first screen;
/// each subclass instance keeps its own extra state exactly like any other
/// [ConsumerState] would (see `TransactionsFlow`'s per-entry-form
/// subscription).
abstract class FlowBaseState<S, T extends FlowBase<S>>
    extends ConsumerState<T> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  void Function()? _closeStepSubscription;

  /// This Flow's own nested Navigator's context, for a subclass that listens
  /// to a second step stream beyond [subscribeToStep] (`TransactionsFlow`'s
  /// per-entry-form subscription is the one case today).
  BuildContext? get navigatorContext => _navigatorKey.currentContext;

  /// Starts listening for this Flow's steps, calling [handle] with each new
  /// step (including null, which the caller ignores). Returns the close
  /// callback for the underlying `ref.listenManual` subscription, so this
  /// base can close it on dispose without needing that subscription's own
  /// value type — `ProviderSubscription<T>` is invariant in `T`, and each
  /// Flow's provider has a different one.
  void Function() subscribeToStep(void Function(S? step) handle);

  /// Acts on a non-null step reached via [context] (the nested Navigator's
  /// own context, safe to push routes or show sheets from).
  void handleStep(BuildContext context, S step);

  /// Builds this Flow's first screen.
  Widget buildRoot(BuildContext context);

  @override
  void initState() {
    super.initState();
    _closeStepSubscription = subscribeToStep(_onStep);
  }

  @override
  void dispose() {
    _closeStepSubscription?.call();
    super.dispose();
  }

  void _onStep(S? step) {
    if (step == null) return;
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    handleStep(context, step);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => buildRoot(context),
        ),
      ),
    );
  }
}
