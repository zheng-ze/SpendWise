import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// MARK: - FlowBase
abstract class FlowBase<S> extends ConsumerStatefulWidget {
  const FlowBase({super.key, this.onEnded});

  final VoidCallback? onEnded;
}

// MARK: - DestinationActivity
class DestinationActivity extends InheritedWidget {
  const DestinationActivity({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DestinationActivity>()
          ?.active ??
      true;

  @override
  bool updateShouldNotify(DestinationActivity oldWidget) =>
      active != oldWidget.active;
}

// MARK: - FlowBaseState
abstract class FlowBaseState<S, T extends FlowBase<S>>
    extends ConsumerState<T> {
  final _navigatorKey = GlobalKey<NavigatorState>();

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

  List<NavigatorObserver> get navigatorObservers => const [];

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
    final active = DestinationActivity.of(context);
    final navigator = Navigator(
      key: _navigatorKey,
      observers: navigatorObservers,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => buildRoot(context),
      ),
    );

    return NavigatorPopHandler(
      enabled: active,
      onPopWithResult: (_) => active ? unawaited(goBack()) : null,
      child: navigator,
    );
  }
}
