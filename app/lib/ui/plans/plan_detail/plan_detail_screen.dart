import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_content.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _loadErrorTitle = "Couldn't load this plan";
const _headingFontFamily = 'InstrumentSans';
const _headingFontSize = 26.0;
const _headingWeight = FontWeight.w600;
const _headingLetterSpacing = -0.7;
const _headerHorizontalInset = 14.0;
const _headerTopInset = 4.0;
const _headerBottomInset = 8.0;

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

    final header = _PlanDetailHeader(name: asyncState.value?.name ?? '');
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

// MARK: - Header
class _PlanDetailHeader extends StatelessWidget {
  const _PlanDetailHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final back = BackButton(onPressed: () => Navigator.of(context).maybePop());
    final headingStyle = TextStyle(
      fontFamily: _headingFontFamily,
      fontSize: _headingFontSize,
      fontWeight: _headingWeight,
      letterSpacing: _headingLetterSpacing,
      color: context.colors.text,
    );
    final heading = Text(name, style: headingStyle);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _headerHorizontalInset,
        _headerTopInset,
        _headerHorizontalInset,
        _headerBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [back, heading],
      ),
    );
  }
}
