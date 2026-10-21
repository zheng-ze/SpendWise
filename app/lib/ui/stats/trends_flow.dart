import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';

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
        _openCategoryDetail(args);
    }
  }

  void _openCategoryDetail(CategoryDetailArgs args) {
    final navigator = this.navigator;
    if (navigator == null || _detailRoute != null) return;
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
      TrendsScreen(onBackPressed: showsOwnBackButton ? goBack : null);
}
