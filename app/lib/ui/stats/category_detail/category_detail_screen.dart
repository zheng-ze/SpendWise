import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/feedback/load_error_view.dart';
import 'package:spendwise/ui/common/navigation/page_header.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_sections.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_trend.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';

const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);
const _sectionGap = 12.0;
const _statusPadding = EdgeInsets.all(24);
const _errorMessage = 'Could not load category details';

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
    final header = PageHeader(
      title: title,
      subtitle: subtitle,
      onBack: onBackPressed,
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
    final page = Column(children: [header, Expanded(child: content)]);
    return Scaffold(body: SafeArea(child: page));
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
    final trend = body.trend;
    final slivers = <Widget>[
      SliverToBoxAdapter(child: headline),
      if (body.chips.isNotEmpty) SliverToBoxAdapter(child: chips),
      if (body.showSubcategories) SliverToBoxAdapter(child: breakdown),
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
    final content = LoadErrorView.box(message: _errorMessage, onRetry: onRetry);
    return Center(
      child: Padding(padding: _statusPadding, child: content),
    );
  }
}
