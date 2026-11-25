import 'package:domain/domain.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_overview.dart';
import 'package:spendwise/ui/format/money_format.dart';

typedef BudgetListCard = ({
  String id,
  String? savedHex,
  String name,
  String amounts,
  String status,
  double progress,
  bool overLimit,
});

const _percentScale = 100;
const _percentDigits = 1;

List<BudgetListCard> budgetListCards(
  Iterable<CategoryBudgetRow> rows,
  LedgerState state,
) => [
  for (final row in rows)
    (
      id: row.budgetID,
      savedHex: state.categories[row.categoryID]?.colorHex,
      name: row.parentName == null
          ? row.name
          : '${row.parentName} / ${row.name}',
      amounts: '${formatMoney(row.spend)} of ${formatMoney(row.limit)}',
      status:
          '${formatMoney(row.remaining)} left / '
          '${(row.utilizationRatio.toDouble() * _percentScale).toStringAsFixed(_percentDigits)}% used',
      progress: row.utilizationRatio.toDouble(),
      overLimit: row.remaining < Decimal.zero,
    ),
];
