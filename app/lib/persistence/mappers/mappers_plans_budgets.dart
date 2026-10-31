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
    note: row.templateNote,
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
  templateNote: plan.template.note,
);

// MARK: - Budgets

Budget budgetFromRow(rows.Budget row) => Budget(
  id: row.id,
  categoryID: row.categoryId,
  limit: Decimal.parse(row.limitAmount),
);

rows.Budget budgetToRow(Budget budget, VersionVector version) => rows.Budget(
  versionData: _versionToBlob(version),
  lifecycle: LifecycleState.active.code,
  id: budget.id,
  categoryId: budget.categoryID,
  limitAmount: budget.limit.toString(),
);
