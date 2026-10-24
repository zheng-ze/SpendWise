import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/navigation/labelled_back_button.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_section.dart';
import 'package:spendwise/ui/stats/trends/trends_controls.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_open_layout.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_state_views.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

const _trendsTitle = 'Trends';
const _historyBackLabel = 'History';
const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({
    super.key,
    this.useOpenComposition = false,
    this.onBackPressed,
  });

  final bool useOpenComposition;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(trendsIntentProvider);
    final scope = ref.watch(trendsBreakdownScopeProvider);
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
    final showStandaloneKindControl =
        !useOpenComposition || body is! TrendsReadyBody;
    final kindControl = showStandaloneKindControl
        ? TrendsKindControl(value: intent.kind, onChanged: viewModel.setKind)
        : null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?kindControl,
        _TrendsBodyView(
          body: body,
          kind: intent.kind,
          mode: intent.mode,
          scope: scope,
          useOpenComposition: useOpenComposition,
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

class _TrendsBodyView extends StatelessWidget {
  const _TrendsBodyView({
    required this.body,
    required this.kind,
    required this.mode,
    required this.scope,
    required this.useOpenComposition,
    required this.viewModel,
  });

  final TrendsBody body;
  final TrendsKind kind;
  final TrendsMode mode;
  final TrendsBreakdownScope scope;
  final bool useOpenComposition;
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
      final TrendsEmptyBody empty => _EmptyView(
        body: empty,
        modeControl: modeControl,
        viewModel: viewModel,
      ),
      final TrendsReadyBody ready => _ReadyView(
        body: ready,
        kind: kind,
        modeControl: modeControl,
        scope: scope,
        useOpenComposition: useOpenComposition,
        viewModel: viewModel,
      ),
    };
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.body,
    required this.modeControl,
    required this.viewModel,
  });

  final TrendsEmptyBody body;
  final Widget modeControl;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final bars = body.bars;
    final selectedIndex = body.selectedIndex;
    final headline = body.headline;
    final usual = body.usual;
    final periodRow = TrendsPeriodRowView(
      period: body.period,
      onPrevious: viewModel.previousPage,
      onNext: viewModel.nextPage,
    );
    if (bars == null ||
        selectedIndex == null ||
        headline == null ||
        usual == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [modeControl, periodRow, const TrendsEmptyView()],
      );
    }
    return _EmptyMonthView(
      modeControl: modeControl,
      periodRow: periodRow,
      bars: bars,
      selectedIndex: selectedIndex,
      headline: headline,
      usual: usual,
      viewModel: viewModel,
    );
  }
}

class _EmptyMonthView extends StatelessWidget {
  const _EmptyMonthView({
    required this.modeControl,
    required this.periodRow,
    required this.bars,
    required this.selectedIndex,
    required this.headline,
    required this.usual,
    required this.viewModel,
  });

  final Widget modeControl;
  final Widget periodRow;
  final List<TrendsBar> bars;
  final int selectedIndex;
  final TrendsHeadline headline;
  final TrendsUsual usual;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final periodCard = TrendsCard(
      children: [
        modeControl,
        periodRow,
        TrendsChart(
          bars: bars,
          selectedIndex: selectedIndex,
          onSelect: viewModel.selectSlot,
        ),
        TrendsHeadlineView(headline: headline),
        TrendsUsualView(usual: usual),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [periodCard, const TrendsEmptyView()],
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.body,
    required this.kind,
    required this.modeControl,
    required this.scope,
    required this.useOpenComposition,
    required this.viewModel,
  });

  final TrendsReadyBody body;
  final TrendsKind kind;
  final Widget modeControl;
  final TrendsBreakdownScope scope;
  final bool useOpenComposition;
  final TrendsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (useOpenComposition) {
      return TrendsOpenLayout(
        body: body,
        kind: kind,
        scope: scope,
        onKindChanged: viewModel.setKind,
        onModeChanged: viewModel.setMode,
        onScopeChanged: viewModel.setBreakdownScope,
        onPrevious: viewModel.previousPage,
        onNext: viewModel.nextPage,
        onSelectPeriod: viewModel.selectSlot,
        onOpenCategory: (index, source) =>
            viewModel.requestCategoryDetail(index, source: source),
      );
    }

    final periodCard = TrendsCard(
      children: [
        modeControl,
        TrendsPeriodRowView(
          period: body.period,
          onPrevious: viewModel.previousPage,
          onNext: viewModel.nextPage,
        ),
        TrendsChart(
          bars: body.bars,
          selectedIndex: body.selectedIndex,
          onSelect: viewModel.selectSlot,
        ),
        TrendsHeadlineView(headline: body.headline),
        if (body.usual case final usual?) TrendsUsualView(usual: usual),
      ],
    );
    final breakdown = TrendsBreakdownSection(
      breakdown: body.breakdown,
      amountKind: body.headline.amountKind,
      onOpenCategory: viewModel.requestCategoryDetail,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [periodCard, breakdown],
    );
  }
}
