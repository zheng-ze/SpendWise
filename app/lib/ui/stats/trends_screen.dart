import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/navigation/labelled_back_button.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_section.dart';
import 'package:spendwise/ui/stats/trends/trends_controls.dart';
import 'package:spendwise/ui/stats/trends/trends_desktop_layout.dart';
import 'package:spendwise/ui/stats/trends/trends_insights_card.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_state_views.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';

const _trendsTitle = 'Trends';
const _historyBackLabel = 'History';
const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);

// MARK: - Screen
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({
    super.key,
    this.onBackPressed,
    this.layoutMode = ShellLayoutMode.phone,
    this.presentation = ShellPagePresentation.fullPage,
  });

  final VoidCallback? onBackPressed;
  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(trendsIntentProvider);
    final TrendsViewModel viewModel = ref.read(
      trendsViewModelProvider.notifier,
    );
    final body = switch (ref.watch(trendsViewModelProvider)) {
      AsyncData(:final value) => value.body,
      AsyncError() => const TrendsErrorBody(),
      AsyncLoading() => const TrendsLoadingBody(),
    };
    final onBackPressed = this.onBackPressed;
    final leading = onBackPressed == null
        ? null
        : LabelledBackButton(
            onPressed: onBackPressed,
            label: _historyBackLabel,
          );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrendsKindControl(value: intent.kind, onChanged: viewModel.setKind),
        _TrendsBodyView(
          body: body,
          mode: intent.mode,
          layoutMode: layoutMode,
          presentation: presentation,
          viewModel: viewModel,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: const Text(_trendsTitle),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(padding: _pagePadding, child: content),
      ),
    );
  }
}

// MARK: - Body
class _TrendsBodyView extends StatelessWidget {
  const _TrendsBodyView({
    required this.body,
    required this.mode,
    required this.layoutMode,
    required this.presentation,
    required this.viewModel,
  });

  final TrendsBody body;
  final TrendsMode mode;
  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final modeControl = TrendsModeControl(
      value: mode,
      onChanged: viewModel.setMode,
    );
    return switch (body) {
      TrendsLoadingBody() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [modeControl, const TrendsLoadingView()],
      ),
      TrendsErrorBody() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          modeControl,
          TrendsErrorView(onRetry: viewModel.retry),
        ],
      ),
      TrendsEmptyBody(:final period) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          modeControl,
          TrendsPeriodRowView(
            period: period,
            onPrevious: viewModel.previousPage,
            onNext: viewModel.nextPage,
          ),
          const TrendsEmptyView(),
        ],
      ),
      final TrendsReadyBody ready => _ReadyView(
        body: ready,
        modeControl: modeControl,
        layoutMode: layoutMode,
        presentation: presentation,
        viewModel: viewModel,
      ),
    };
  }
}

// MARK: - Ready
class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.body,
    required this.modeControl,
    required this.layoutMode,
    required this.presentation,
    required this.viewModel,
  });

  final TrendsReadyBody body;
  final Widget modeControl;
  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (layoutMode == ShellLayoutMode.open &&
        presentation == ShellPagePresentation.singleColumn) {
      return _OpenReadyView(
        body: body,
        modeControl: modeControl,
        viewModel: viewModel,
      );
    }
    final usual = body.usual;
    final period = TrendsPeriodRowView(
      period: body.period,
      onPrevious: viewModel.previousPage,
      onNext: viewModel.nextPage,
    );
    final chart = TrendsChart(
      bars: body.bars,
      selectedIndex: body.selectedIndex,
      onSelect: viewModel.selectSlot,
    );
    final periodCard = TrendsCard(
      children: [
        modeControl,
        period,
        chart,
        TrendsHeadlineView(headline: body.headline),
        if (usual != null) TrendsUsualView(usual: usual),
      ],
    );
    final breakdown = TrendsBreakdownSection(
      breakdown: body.breakdown,
      amountKind: body.headline.amountKind,
      onOpenCategory: viewModel.requestCategoryDetail,
    );
    return TrendsDesktopLayout(
      layoutMode: layoutMode,
      periodCard: periodCard,
      breakdown: breakdown,
    );
  }
}

class _OpenReadyView extends StatelessWidget {
  const _OpenReadyView({
    required this.body,
    required this.modeControl,
    required this.viewModel,
  });

  final TrendsReadyBody body;
  final Widget modeControl;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final period = TrendsPeriodRowView(
      period: body.period,
      onPrevious: viewModel.previousPage,
      onNext: viewModel.nextPage,
    );
    final chart = TrendsChart(
      bars: body.bars,
      selectedIndex: body.selectedIndex,
      onSelect: viewModel.selectSlot,
    );
    final periodCard = TrendsCard(children: [modeControl, period, chart]);
    final wholePeriod = body.wholePeriod;
    final breakdown = TrendsBreakdownSection(
      breakdown: wholePeriod.breakdown,
      amountKind: body.headline.amountKind,
      header: wholePeriod.header,
      compact: true,
      onOpenCategory: (index) => viewModel.requestCategoryDetail(
        index,
        source: TrendsCategoryDetailSource.wholePeriod,
      ),
    );
    final insights = TrendsInsightsCard(insights: wholePeriod.insights);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [periodCard, breakdown, insights],
    );
  }
}
