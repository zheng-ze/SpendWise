part of 'mappers.dart';

// MARK: - Plans

RecurringPlan planFromRow(rows.Plan row) => RecurringPlan(
  id: row.id,
  template: EntryTemplate(
    amount: Decimal.parse(row.templateAmount),
    name: row.templateName,
    categoryID: row.templateCategoryId,
    sourceID: row.templateSourceId,
    destinationID: row.templateDestinationId,
    includeInAnalysis: row.templateIncludeInAnalysis,
  ),
  frequency: _frequency(row.frequency),
  anchor: dayFromMillis(row.anchor),
  endDate: row.endDate == null ? null : dayFromMillis(row.endDate!),
  lastResolvedDate: dayFromMillis(row.lastResolvedDate),
);

rows.Plan planToRow(RecurringPlan plan, VersionVector version) => rows.Plan(
  versionData: _versionToBlob(version),
  lifecycle: LifecycleState.active.code,
  id: plan.id,
  frequency: plan.frequency.code,
  anchor: millisFromDay(plan.anchor),
  endDate: plan.endDate == null ? null : millisFromDay(plan.endDate!),
  lastResolvedDate: millisFromDay(plan.lastResolvedDate),
  templateAmount: plan.template.amount.toString(),
  templateName: plan.template.name,
  templateCategoryId: plan.template.categoryID,
  templateSourceId: plan.template.sourceID,
  templateDestinationId: plan.template.destinationID,
  templateIncludeInAnalysis: plan.template.includeInAnalysis,
);

// MARK: - Budgets

Budget budgetFromRow(rows.Budget row) => Budget(
  id: row.id,
  categoryID: row.categoryId,
  limitEvents: [
    for (final event in json.decode(row.limitEvents) as List<dynamic>)
      _limitEventFromJson(event as Map<String, dynamic>),
  ],
  createdAtMonth: _yearMonthFromString(row.createdAtMonth),
);

rows.Budget budgetToRow(Budget budget, VersionVector version) => rows.Budget(
  versionData: _versionToBlob(version),
  lifecycle: LifecycleState.active.code,
  id: budget.id,
  categoryId: budget.categoryID,
  limitEvents: json.encode([
    for (final event in budget.limitEvents) _limitEventToJson(event),
  ]),
  createdAtMonth: _yearMonthToString(budget.createdAtMonth),
);

// MARK: - Budget Encoding

YearMonth _yearMonthFromString(String value) {
  final parts = value.split('-');
  return YearMonth(int.parse(parts[0]), int.parse(parts[1]));
}

String _yearMonthToString(YearMonth month) =>
    '${month.year.toString().padLeft(4, '0')}-'
    '${month.month.toString().padLeft(2, '0')}';

LimitEvent _limitEventFromJson(Map<String, dynamic> map) => LimitEvent(
  effectiveFromMonth: map['effectiveFromMonth'] == null
      ? null
      : _yearMonthFromString(map['effectiveFromMonth'] as String),
  value: Decimal.parse(map['value'] as String),
  kind: LimitEventKind.fromCode(map['kind'] as int),
);

Map<String, dynamic> _limitEventToJson(LimitEvent event) => {
  'effectiveFromMonth': event.effectiveFromMonth == null
      ? null
      : _yearMonthToString(event.effectiveFromMonth!),
  'value': event.value.toString(),
  'kind': event.kind.code,
};
