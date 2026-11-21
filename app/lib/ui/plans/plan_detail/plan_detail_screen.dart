import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/common/navigation/page_header.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_content.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_view_model.dart';

// MARK: - Constants
const _loadErrorTitle = "Couldn't load this plan";

// MARK: - PlanDetailScreen
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planID});

  final String planID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = planDetailViewModelProvider(planID);
    final asyncState = ref.watch(provider);
    final body = AsyncValueView(
      value: asyncState,
      onRetry: () => ref.invalidate(provider),
      errorTitle: _loadErrorTitle,
      data: (viewState) => PlanDetailContent(
        viewState: viewState,
        onEdit: ref.read(provider.notifier).requestEdit,
        onDelete: ref.read(provider.notifier).requestDelete,
      ),
    );

    final header = PageHeader(
      title: asyncState.value?.name ?? '',
      onBack: () => Navigator.of(context).maybePop(),
    );
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );
    return Scaffold(body: SafeArea(child: page));
  }
}
