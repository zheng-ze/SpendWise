import 'package:flutter/material.dart';

import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_category_averages.dart';
import 'package:spendwise/ui/stats/trends/trends_controls.dart';
import 'package:spendwise/ui/stats/trends/trends_insights_card.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_shared_breakdown_card.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

const trendsOpenMinimumTwoColumnContentWidth = 640.0;
const trendsOpenControlsColumnWidth = 240.0;
const trendsOpenColumnGap = 16.0;
const _selectedPeriodGroupTopGap = 12.0;

class TrendsOpenLayout extends StatelessWidget {
  const TrendsOpenLayout({
    super.key,
    required this.body,
    required this.kind,
    required this.scope,
    required this.onKindChanged,
    required this.onModeChanged,
    required this.onScopeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectPeriod,
    required this.onOpenCategory,
  });

  final TrendsReadyBody body;
  final TrendsKind kind;
  final TrendsBreakdownScope scope;
  final ValueChanged<TrendsKind> onKindChanged;
  final ValueChanged<TrendsMode> onModeChanged;
  final ValueChanged<TrendsBreakdownScope> onScopeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectPeriod;
  final void Function(int, TrendsCategoryDetailSource) onOpenCategory;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.hasBoundedWidth &&
          constraints.maxWidth >= trendsOpenMinimumTwoColumnContentWidth;
      return _TrendsOpenContent(
        body: body,
        kind: kind,
        scope: scope,
        twoColumns: twoColumns,
        onKindChanged: onKindChanged,
        onModeChanged: onModeChanged,
        onScopeChanged: onScopeChanged,
        onPrevious: onPrevious,
        onNext: onNext,
        onSelectPeriod: onSelectPeriod,
        onOpenCategory: onOpenCategory,
      );
    },
  );
}

class _TrendsOpenContent extends StatelessWidget {
  const _TrendsOpenContent({
    required this.body,
    required this.kind,
    required this.scope,
    required this.twoColumns,
    required this.onKindChanged,
    required this.onModeChanged,
    required this.onScopeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectPeriod,
    required this.onOpenCategory,
  });

  final TrendsReadyBody body;
  final TrendsKind kind;
  final TrendsBreakdownScope scope;
  final bool twoColumns;
  final ValueChanged<TrendsKind> onKindChanged;
  final ValueChanged<TrendsMode> onModeChanged;
  final ValueChanged<TrendsBreakdownScope> onScopeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectPeriod;
  final void Function(int, TrendsCategoryDetailSource) onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final topCard = _TrendsOpenTopCard(
      body: body,
      kind: kind,
      twoColumns: twoColumns,
      onKindChanged: onKindChanged,
      onModeChanged: onModeChanged,
      onPrevious: onPrevious,
      onNext: onNext,
      onSelectPeriod: onSelectPeriod,
    );
    final lowerGroups = _TrendsOpenLowerGroups(
      body: body,
      scope: scope,
      twoColumns: twoColumns,
      onScopeChanged: onScopeChanged,
      onOpenCategory: onOpenCategory,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [topCard, lowerGroups, const SizedBox.shrink()],
    );
  }
}

class _TrendsOpenTopCard extends StatelessWidget {
  const _TrendsOpenTopCard({
    required this.body,
    required this.kind,
    required this.twoColumns,
    required this.onKindChanged,
    required this.onModeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectPeriod,
  });

  final TrendsReadyBody body;
  final TrendsKind kind;
  final bool twoColumns;
  final ValueChanged<TrendsKind> onKindChanged;
  final ValueChanged<TrendsMode> onModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrendsKindControl(value: kind, onChanged: onKindChanged),
        TrendsModeControl(value: body.breakdown.mode, onChanged: onModeChanged),
        TrendsPeriodRowView(
          period: body.period,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
    final chart = TrendsChart(
      bars: body.bars,
      selectedIndex: body.selectedIndex,
      onSelect: onSelectPeriod,
    );
    final topContent = twoColumns
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: trendsOpenControlsColumnWidth, child: controls),
              const SizedBox(width: trendsOpenColumnGap),
              Expanded(child: chart),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [controls, chart],
          );
    return TrendsCard(children: [topContent]);
  }
}

class _TrendsOpenLowerGroups extends StatelessWidget {
  const _TrendsOpenLowerGroups({
    required this.body,
    required this.scope,
    required this.twoColumns,
    required this.onScopeChanged,
    required this.onOpenCategory,
  });

  final TrendsReadyBody body;
  final TrendsBreakdownScope scope;
  final bool twoColumns;
  final ValueChanged<TrendsBreakdownScope> onScopeChanged;
  final void Function(int, TrendsCategoryDetailSource) onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final sharedGroup = _SharedBreakdownGroup(
      body: body,
      scope: scope,
      onScopeChanged: onScopeChanged,
      onOpenCategory: onOpenCategory,
    );
    final selectedGroup = _SelectedPeriodGroup(
      body: body,
      onOpenCategory: (index) =>
          onOpenCategory(index, TrendsCategoryDetailSource.selectedPeriod),
    );
    if (!twoColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [sharedGroup, selectedGroup],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: sharedGroup),
        const SizedBox(width: trendsOpenColumnGap),
        Expanded(child: selectedGroup),
      ],
    );
  }
}

class _SharedBreakdownGroup extends StatelessWidget {
  const _SharedBreakdownGroup({
    required this.body,
    required this.scope,
    required this.onScopeChanged,
    required this.onOpenCategory,
  });

  final TrendsReadyBody body;
  final TrendsBreakdownScope scope;
  final ValueChanged<TrendsBreakdownScope> onScopeChanged;
  final void Function(int, TrendsCategoryDetailSource) onOpenCategory;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TrendsSharedBreakdownCard(
        body: body,
        scope: scope,
        onScopeChanged: onScopeChanged,
        onOpenCategory: onOpenCategory,
      ),
      TrendsInsightsCard(insights: body.wholePeriod.insights),
    ],
  );
}

class _SelectedPeriodGroup extends StatelessWidget {
  const _SelectedPeriodGroup({
    required this.body,
    required this.onOpenCategory,
  });

  final TrendsReadyBody body;
  final ValueChanged<int> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final usual = body.usual;
    final headline = TrendsCard(
      children: [
        TrendsHeadlineView(headline: body.headline),
        if (usual != null) TrendsUsualView(usual: usual),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _selectedPeriodGroupTopGap),
          child: headline,
        ),
        TrendsCategoryAverages(
          breakdown: body.breakdown,
          averageComparison: body.averageComparison,
          amountKind: body.headline.amountKind,
          onOpenCategory: onOpenCategory,
        ),
      ],
    );
  }
}
