import 'package:flutter/material.dart';

import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_section.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_state_views.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

class TrendsPeriodDetailBody extends StatelessWidget {
  const TrendsPeriodDetailBody({
    super.key,
    required this.body,
    required this.mode,
    required this.viewModel,
  });

  final TrendsBody body;
  final TrendsMode mode;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) => switch (body) {
    TrendsLoadingBody() => const TrendsLoadingView(),
    TrendsErrorBody() => TrendsErrorView(onRetry: viewModel.retry),
    TrendsEmptyBody() => const TrendsEmptyView(),
    final TrendsReadyBody ready => _ReadyPeriodDetail(
      body: ready,
      mode: mode,
      viewModel: viewModel,
    ),
  };
}

class _ReadyPeriodDetail extends StatelessWidget {
  const _ReadyPeriodDetail({
    required this.body,
    required this.mode,
    required this.viewModel,
  });

  final TrendsReadyBody body;
  final TrendsMode mode;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final usual = mode == TrendsMode.month && body.usual != null
        ? TrendsUsualView(usual: body.usual!)
        : null;
    final headline = TrendsHeadlineView(headline: body.headline);
    final breakdown = TrendsBreakdownSection(
      breakdown: body.breakdown,
      amountKind: body.headline.amountKind,
      averageComparison: body.averageComparison,
      onOpenCategory: viewModel.requestCategoryDetail,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [headline, ?usual, breakdown],
      ),
    );
  }
}
