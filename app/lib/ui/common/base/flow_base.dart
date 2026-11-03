import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// MARK: - FlowBase
abstract class FlowBase<S> extends ConsumerStatefulWidget {
  const FlowBase({super.key, this.onEnded, this.navigatorKey});

  final VoidCallback? onEnded;
  final GlobalKey<NavigatorState>? navigatorKey;
}

// MARK: - FlowBaseState
abstract class FlowBaseState<S, T extends FlowBase<S>>
    extends ConsumerState<T> {
  late final _navigatorKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();

  void Function()? _closeStepSubscription;

  BuildContext? get navigatorContext => _navigatorKey.currentContext;

  bool get showsOwnBackButton => widget.onEnded != null;

  Future<void> goBack() async {
    final popped = await _navigatorKey.currentState?.maybePop() ?? false;
    if (!popped) widget.onEnded?.call();
  }

  void Function() subscribeToStep(void Function(S? step) handle);

  void handleStep(BuildContext context, S step);

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
    final navigator = Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => buildRoot(context),
      ),
    );

    return NavigatorPopHandler(
      onPopWithResult: (_) => unawaited(goBack()),
      child: navigator,
    );
  }
}
