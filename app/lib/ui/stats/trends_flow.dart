import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

class TrendsFlow extends FlowBase<TrendsStep> {
  const TrendsFlow({super.key, super.onEnded});

  @override
  ConsumerState<TrendsFlow> createState() => _TrendsFlowState();
}

class _TrendsFlowState extends FlowBaseState<TrendsStep, TrendsFlow> {
  Route<void>? _detailRoute;

  TrendsViewModel get _viewModel => ref.read(trendsViewModelProvider.notifier);

  @override
  void Function() subscribeToStep(void Function(TrendsStep? step) handle) {
    final subscription = ref.listenManual(
      trendsViewModelProvider,
      (previous, next) => handle(next.value?.step),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      handle(ref.read(trendsViewModelProvider).value?.step);
    });
    return subscription.close;
  }

  @override
  void handleStep(BuildContext context, TrendsStep step) {
    _viewModel.clearStep();
    switch (step) {
      case TrendsCategoryDetailRequested(:final args):
        _openCategoryDetail(context, args);
    }
  }

  void _openCategoryDetail(BuildContext context, CategoryDetailArgs args) {
    if (_detailRoute != null) return;
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute<void>(
      builder: (_) => CategoryDetailScreen(args: args),
    );
    _detailRoute = route;
    unawaited(navigator.push(route));
    unawaited(route.completed.whenComplete(() => _releaseDetail(route)));
  }

  void _releaseDetail(Route<void> route) {
    if (mounted && identical(_detailRoute, route)) _detailRoute = null;
  }

  @override
  Widget buildRoot(BuildContext context) =>
      _TrendsRoot(onBackPressed: showsOwnBackButton ? goBack : null);
}

class _TrendsRoot extends StatelessWidget {
  const _TrendsRoot({required this.onBackPressed});

  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellPaneScope>();
    final mode = scope?.mode ?? ShellLayoutMode.phone;
    final useOpenComposition = switch (mode) {
      ShellLayoutMode.phone => false,
      ShellLayoutMode.open || ShellLayoutMode.desktop => true,
    };
    return TrendsScreen(
      useOpenComposition: useOpenComposition,
      onBackPressed: onBackPressed,
    );
  }
}
