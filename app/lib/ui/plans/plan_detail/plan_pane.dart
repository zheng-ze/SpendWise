import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/plans/plan_detail/plan_detail_content.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_view_model.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Constants
const _missingPlanTitle = '';

// MARK: - PlanPane
final planPaneProvider = Provider.autoDispose<ShellPane?>((ref) {
  final planID = ref.watch(selectedPlanProvider);
  final phone = ref.watch(shellLayoutModeProvider) == ShellLayoutMode.phone;
  if (planID == null || phone) return null;
  void close() => ref.read(selectedPlanProvider.notifier).clear();
  final title = ref.watch(
    planDetailViewModelProvider(planID)
        .select((state) => state.value?.name ?? _missingPlanTitle),
  );
  final detail = ShellDetail(
    id: planID,
    title: title,
    bodyBuilder: (_) => PlanPaneBody(planID: planID),
    onClose: close,
  );
  return (detail: detail, close: close);
}, dependencies: [shellLayoutModeProvider]);

// MARK: - PlanPaneBody
class PlanPaneBody extends ConsumerWidget {
  const PlanPaneBody({super.key, required this.planID});

  final String planID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = planDetailViewModelProvider(planID);
    final viewState = ref.watch(provider).value;
    if (viewState == null) return const SizedBox.shrink();
    return PlanDetailContent(
      viewState: viewState,
      onEdit: ref.read(provider.notifier).requestEdit,
      onDelete: ref.read(provider.notifier).requestDelete,
    );
  }
}
