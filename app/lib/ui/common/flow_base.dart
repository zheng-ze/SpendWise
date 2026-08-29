import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A feature Flow that owns its own nested Navigator. Pair with a
/// [FlowBaseState] subclass, which supplies the navigator plumbing.
abstract class FlowBase<S> extends ConsumerStatefulWidget {
  const FlowBase({super.key, this.onEnded});

  /// Called when a back gesture reaches this Flow's own Navigator with no
  /// route left to pop. Null for a Flow that owns getting back out itself.
  final VoidCallback? onEnded;
}

/// Shared lifecycle plumbing for a [FlowBase]. A subclass supplies
/// [subscribeToStep], [handleStep], and [buildRoot].
abstract class FlowBaseState<S, T extends FlowBase<S>>
    extends ConsumerState<T> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  void Function()? _closeStepSubscription;

  /// This Flow's own nested Navigator's context, for a subclass that listens
  /// to a second step stream beyond [subscribeToStep].
  BuildContext? get navigatorContext => _navigatorKey.currentContext;

  /// Whether this Flow's root screen should show its own back button.
  bool get showsOwnBackButton => widget.onEnded != null;

  /// Ends this Flow the same way a system back gesture would. Pops this
  /// Flow's own Navigator if it can, otherwise calls [FlowBase.onEnded].
  Future<void> goBack() async {
    final popped = await _navigatorKey.currentState?.maybePop() ?? false;
    if (!popped) widget.onEnded?.call();
  }

  /// Starts listening for this Flow's steps, calling [handle] with each new
  /// step. Returns a callback that closes the subscription on dispose.
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
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await goBack();
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
