import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_detail_metadata.dart';
import 'package:spendwise/ui/stats/trends/trends_hosted_root.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

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

class _TrendsRoot extends ConsumerWidget {
  const _TrendsRoot({required this.onBackPressed});

  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellPaneScope>();
    if (scope == null) {
      return TrendsScreen(onBackPressed: onBackPressed);
    }

    final intent = ref.watch(trendsIntentProvider);
    final state = ref.watch(trendsViewModelProvider);
    final metadata = ref.watch(trendsDetailMetadataProvider);
    final viewModel = ref.read(trendsViewModelProvider.notifier);
    final body = switch (state) {
      AsyncData(:final value) => value.body,
      AsyncError() => const TrendsErrorBody(),
      AsyncLoading() => const TrendsLoadingBody(),
    };
    final mode = scope.mode;
    final detailBody = mode == ShellLayoutMode.open
        ? TrendsPeriodDetailBody(
            body: body,
            mode: intent.mode,
            viewModel: viewModel,
          )
        : const SizedBox.shrink();
    final detail = ShellDetail(
      id: metadata.id,
      title: metadata.title,
      bodyBuilder: (_) => detailBody,
    );
    final host = ShellPaneHost(
      detail: detail,
      pageBuilder: (_, presentation) => TrendsScreen(
        onBackPressed: onBackPressed,
        layoutMode: mode,
        presentation: presentation,
      ),
    );
    return Material(color: context.colors.base, child: host);
  }
}
