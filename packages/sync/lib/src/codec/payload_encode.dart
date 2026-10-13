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
              'limitEvents': <Object?>[
                for (final event in budget.limitEvents)
                  <String, Object?>{
                    'effectiveFromMonth':
                        _encodeYearMonth(event.effectiveFromMonth),
                    'value': event.value.toString(),
                    'kind': event.kind.code,
                  },
              ],
              'createdAtMonth': _encodeYearMonth(budget.createdAtMonth),
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
      };

  Object? _encodeYearMonth(YearMonth? month) => month == null
      ? null
      : <String, Object?>{'year': month.year, 'month': month.month};
}

// MARK: - Encoded Change

class _EncodedChange {
  const _EncodedChange(this.entity, this.fields);
  final String entity;
  final Map<String, Object?> fields;
}
