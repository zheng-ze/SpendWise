import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const shellConfirmationOpenMaxWidth = 308.0;

const shellConfirmationHorizontalMargin = 24.0;

const shellConfirmationVerticalMargin = 24.0;

const shellConfirmationOpenDim = Color(0x33000000);

const shellConfirmationStandardDim = Color(0x8A000000);

const shellConfirmationBarrier = Color(0x00000000);

const shellConfirmationBarrierLabel = 'Dismiss';

const shellConfirmationTransitionMillis = 150;

const shellConfirmationTransitionCurve = Curves.easeOut;

Future<T?> showShellConfirmation<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(_ShellConfirmationRoute<T>(builder: builder));
}

class _ShellConfirmationRoute<T> extends ModalRoute<T> {
  _ShellConfirmationRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: shellConfirmationTransitionMillis);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => shellConfirmationBarrier;

  @override
  String? get barrierLabel => shellConfirmationBarrierLabel;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _ShellConfirmationPage<T>(route: this);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: shellConfirmationTransitionCurve,
      ),
      child: child,
    );
  }
}

class _ShellConfirmationPage<T> extends StatelessWidget {
  const _ShellConfirmationPage({required this.route});

  final _ShellConfirmationRoute<T> route;

  @override
  Widget build(BuildContext context) {
    final open = ShellLayoutModeScope.maybeOf(context) == ShellLayoutMode.open;
    if (open) {
      return Stack(
        children: [
          const Positioned.fill(
            right: openRailGutter,
            child: IgnorePointer(
              child: ColoredBox(color: shellConfirmationOpenDim),
            ),
          ),
          Positioned.fill(
            right: openRailGutter,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: shellConfirmationHorizontalMargin,
                    vertical: shellConfirmationVerticalMargin,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: shellConfirmationOpenMaxWidth,
                    ),
                    child: Builder(builder: route.builder),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: shellConfirmationStandardDim),
          ),
        ),
        SafeArea(
          child: Center(child: Builder(builder: route.builder)),
        ),
      ],
    );
  }
}
