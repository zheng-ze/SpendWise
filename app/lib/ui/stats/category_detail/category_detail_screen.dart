import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/lists/day_sectioned_entry_list.dart';
import 'package:spendwise/ui/common/sheets/sliver_tray.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_sections.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_trend.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);
const _sectionGap = 12.0;
const _backWidth = 112.0;
const _subtitleSize = 12.0;
const _headerGap = 2.0;
const _statusPadding = EdgeInsets.all(24);
const _backLabel = 'Trends';

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({
    super.key,
    required this.args,
    this.onBackPressed,
  });

  final CategoryDetailArgs args;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = categoryDetailViewModelProvider(args);
    final CategoryDetailViewModel viewModel = ref.read(provider.notifier);
    final viewState = ref.watch(provider).asData?.value;
    final body = viewState?.body ?? const CategoryDetailLoadingBody();
    final ledger = ref.watch(ledgerProvider);
    final category = ledger?.state.categories[args.mainID];
    final title = body is CategoryDetailReadyBody
        ? body.title
        : category?.name ?? 'Uncategorized';
    final subtitle = viewState?.subtitle ?? '';
    final titleText = Text(title);
    final subtitleText = Text(
      subtitle,
      style: TextStyle(color: context.colors.subtext, fontSize: _subtitleSize),
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleText,
        const SizedBox(height: _headerGap),
        subtitleText,
      ],
    );
    final backAction = onBackPressed;
    final leading = backAction == null
        ? null
        : TextButton.icon(
            onPressed: backAction,
            icon: const Icon(Icons.chevron_left),
            label: const Text(_backLabel, maxLines: 1, softWrap: false),
          );
    final appBar = AppBar(
      leadingWidth: _backWidth,
      leading: leading,
      title: heading,
      centerTitle: false,
    );
    final content = switch (body) {
      CategoryDetailReadyBody() when ledger != null => _CategoryDetailReadyView(
        body: body,
        viewModel: viewModel,
        ledger: ledger,
      ),
      CategoryDetailErrorBody() => _CategoryDetailErrorView(
        onRetry: viewModel.retry,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: content),
    );
  }
}

class _CategoryDetailReadyView extends StatelessWidget {
  const _CategoryDetailReadyView({
    required this.body,
    required this.viewModel,
    required this.ledger,
  });

  final CategoryDetailReadyBody body;
  final CategoryDetailViewModel viewModel;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final headline = CategoryDetailHeadline(
      amount: body.totals.scopeTotal,
      kind: body.amountKind,
    );
    final chips = CategoryDetailScopeChips(
      chips: body.chips,
      onSelect: viewModel.setScope,
    );
    final breakdown = CategoryDetailSubcategories(
      rows: body.breakdown,
      kind: body.amountKind,
      onSelect: viewModel.setScope,
    );
    final entrySliver = DaySectionedEntryList.prepared(
      sections: body.sections,
      ledger: ledger,
      state: ledger.state,
    );
    final entriesTray = SliverTray(title: 'Entries', slivers: [entrySliver]);
    final trend = body.trend;
    final slivers = <Widget>[
      SliverToBoxAdapter(child: headline),
      if (body.chips.isNotEmpty) SliverToBoxAdapter(child: chips),
      if (body.showSubcategories) SliverToBoxAdapter(child: breakdown),
      const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
      entriesTray,
      if (trend != null)
        const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
      if (trend != null)
        CategoryDetailTrend(
          trend: trend,
          viewModel: viewModel,
          ledger: ledger,
          state: ledger.state,
        ),
    ];
    final group = SliverMainAxisGroup(slivers: slivers);
    final padded = SliverPadding(padding: _pagePadding, sliver: group);
    return CustomScrollView(slivers: [padded]);
  }
}

class _CategoryDetailErrorView extends StatelessWidget {
  const _CategoryDetailErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = FilledButton(onPressed: onRetry, child: const Text('Retry'));
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [const Text('Could not load category details'), retry],
    );
    return Center(
      child: Padding(padding: _statusPadding, child: content),
    );
  }
}
