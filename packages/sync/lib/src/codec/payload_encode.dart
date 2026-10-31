part of '../../sync.dart';

// MARK: - Payload Encode

extension PayloadCodecEncode on PayloadCodec {
  _EncodedChange? _encodeData(LedgerChange change) => switch (change) {
        UpsertAccount(:final account) => _EncodedChange(
            'account',
            <String, Object?>{
              'id': account.id,
              'name': account.name,
              'type': account.type.code,
              'subPocketIDs': account.subPocketIDs.toList()..sort(),
              'incomingTransfersAsExpenses':
                  account.incomingTransfersAsExpenses,
              'includeInNetWorth': account.includeInNetWorth,
              'statementDay': account.statementDay,
              'lifecycle': account.lifecycle.code,
            },
          ),
        UpsertPocket(:final pocket) => _EncodedChange(
            'sub_pocket',
            <String, Object?>{
              'id': pocket.id,
              'name': pocket.name,
              'incomingTransfersAsExpenses': pocket.incomingTransfersAsExpenses,
              'lifecycle': pocket.lifecycle.code,
            },
          ),
        UpsertCategory(:final category) => _EncodedChange(
            'category',
            <String, Object?>{
              'id': category.id,
              'name': category.name,
              'kind': category.kind.code,
              'colorHex': category.colorHex,
              'includeInAnalysis': category.includeInAnalysis,
              'parentID': category.parentID,
              'symbol': category.symbol,
              'lifecycle': category.lifecycle.code,
            },
          ),
        UpsertEntry(:final entry) => _EncodedChange(
            'entry',
            <String, Object?>{
              'id': entry.id,
              'date': entry.date.toUtc().toIso8601String(),
              'amount': entry.amount.toString(),
              'name': entry.name,
              'categoryID': entry.categoryID,
              'sourceID': entry.sourceID,
              'destinationID': entry.destinationID,
              'includeInAnalysis': entry.includeInAnalysis,
              'lifecycle': entry.lifecycle.code,
              'systemKind': entry.systemKind?.code,
              if (entry.note != null) 'note': entry.note,
            },
          ),
        UpsertPlan(:final plan) => _EncodedChange(
            'plan',
            <String, Object?>{
              'id': plan.id,
              'template': _encodeTemplate(plan.template),
              'frequency': plan.frequency.code,
              'anchor': plan.anchor.toUtc().toIso8601String(),
              'endDate': plan.endDate?.toUtc().toIso8601String(),
              'lastResolvedDate':
                  plan.lastResolvedDate.toUtc().toIso8601String(),
            },
          ),
        UpsertBudget(:final budget) => _EncodedChange(
            'budget',
            <String, Object?>{
              'id': budget.id,
              'categoryID': budget.categoryID,
              'limit': budget.limit.toString(),
            },
          ),
        DeleteMoneySource() => null,
        DeleteCategory() => null,
        DeleteEntry() => null,
        DeletePlan() => null,
        DeleteBudget() => null,
      };

  Map<String, Object?> _encodeTemplate(EntryTemplate template) =>
      <String, Object?>{
        'amount': template.amount.toString(),
        'name': template.name,
        'categoryID': template.categoryID,
        'sourceID': template.sourceID,
        'destinationID': template.destinationID,
        'includeInAnalysis': template.includeInAnalysis,
        if (template.note != null) 'note': template.note,
      };
}

// MARK: - Encoded Change

class _EncodedChange {
  const _EncodedChange(this.entity, this.fields);
  final String entity;
  final Map<String, Object?> fields;
}
