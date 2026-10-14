import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const shellConfirmationOpenMaxWidth = 308.0;

const shellConfirmationHorizontalMargin = 24.0;

const shellConfirmationVerticalMargin = 24.0;

const shellConfirmationOpenDim = Color(0x33000000);

const shellConfirmationStandardDimFallback = Colors.black54;

const shellConfirmationNoInset = 0.0;

const shellConfirmationBarrier = Color(0x00000000);

const shellConfirmationTransitionMillis = 150;

const shellConfirmationTransitionCurve = Curves.easeOut;

Future<T?> showShellConfirmation<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<T>(
    _ShellConfirmationRoute<T>(builder: builder, themes: themes),
  );
}

class _ShellConfirmationRoute<T> extends ModalRoute<T> {
  _ShellConfirmationRoute({required this.builder, required this.themes});

  final WidgetBuilder builder;

  final CapturedThemes themes;

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
  String? get barrierLabel =>
      MaterialLocalizations.of(navigator!.context).modalBarrierDismissLabel;

  @override
  bool get maintainState => true;

  @override
  TraversalEdgeBehavior get traversalEdgeBehavior =>
      TraversalEdgeBehavior.closedLoop;

  @override
  TraversalEdgeBehavior get directionalTraversalEdgeBehavior =>
      TraversalEdgeBehavior.closedLoop;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return themes.wrap(_ShellConfirmationPage<T>(route: this));
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
    final railInset = open
        ? openRailGutter + MediaQuery.paddingOf(context).right
        : shellConfirmationNoInset;
    final dimColor = open
        ? shellConfirmationOpenDim
        : DialogTheme.of(context).barrierColor ??
              shellConfirmationStandardDimFallback;
    final dim = Positioned.fill(
      right: railInset,
      child: IgnorePointer(child: ColoredBox(color: dimColor)),
    );
    final dialog = open
        ? Positioned.fill(
            right: railInset,
            child: SafeArea(
              right: false,
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
          )
        : DisplayFeatureSubScreen(
            child: SafeArea(
              child: Center(child: Builder(builder: route.builder)),
            ),
          );
    return Stack(children: [dim, dialog]);
  }
}
