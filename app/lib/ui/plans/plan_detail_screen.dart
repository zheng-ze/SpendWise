import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/common/navigation/labelled_back_button.dart';
import 'package:spendwise/ui/plans/plan_detail_content.dart';
import 'package:spendwise/ui/plans/plan_detail_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _backLabel = 'Plans';
const _subtitle = 'Plan';
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
      data: (viewState) => ListView(
        physics: const ClampingScrollPhysics(),
        children: [PlanDetailContent(viewState: viewState)],
      ),
    );

    return Scaffold(
      appBar: _PlanDetailAppBar(name: asyncState.value?.name ?? ''),
      body: SafeArea(child: body),
    );
  }
}

// MARK: - AppBar
class _PlanDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PlanDetailAppBar({required this.name});

  final String name;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final back = LabelledBackButton(
      label: _backLabel,
      onPressed: () => Navigator.of(context).maybePop(),
    );
    final subtitle = Text(
      _subtitle,
      style: context.text.small.copyWith(color: context.colors.subtext),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(name), subtitle],
    );
    return AppBar(leading: back, title: title);
  }
}
