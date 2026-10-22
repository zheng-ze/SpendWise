import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_section.dart';
import 'package:spendwise/ui/stats/trends/trends_scoped_presentation.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

class TrendsSharedBreakdownCard extends StatelessWidget {
  const TrendsSharedBreakdownCard({
    super.key,
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
  Widget build(BuildContext context) {
    final presentation = resolveTrendsScopedPresentation(body, scope);
    final mode = body.breakdown.mode;
    final scopeControl = SegmentedControl<TrendsBreakdownScope>(
      options: [
        const SegmentedOption(
          value: TrendsBreakdownScope.wholePeriod,
          label: 'Whole period',
        ),
        SegmentedOption(
          value: TrendsBreakdownScope.selectedPeriod,
          label: TrendsBreakdownScope.selectedPeriod.label(mode),
        ),
      ],
      value: scope,
      onChanged: onScopeChanged,
    );
    return TrendsBreakdownSection(
      breakdown: presentation.breakdown,
      amountKind: body.headline.amountKind,
      header: presentation.header,
      scopeControl: scopeControl,
      onOpenCategory: (index) =>
          onOpenCategory(index, presentation.categorySource),
    );
  }
}
