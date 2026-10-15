part of '../../sync.dart';

// MARK: - Payload Entity Decode

extension PayloadCodecDecodeEntities on PayloadCodec {
  LedgerChange _decodeEntity(String entity, Map<String, Object?> data) =>
      switch (entity) {
        'account' => _decodeAccount(data),
        'sub_pocket' => _decodeSubPocket(data),
        'category' => _decodeCategory(data),
        'entry' => _decodeEntry(data),
        'plan' => _decodePlan(data),
        'budget' => _decodeBudget(data),
        _ => throw PayloadDecodeError('Unknown payload entity: $entity.'),
      };

  LedgerChange _decodeAccount(Map<String, Object?> data) {
    final subPocketIDs = <String>{
      for (final raw in _stringList(data, 'subPocketIDs')) normalizedID(raw),
    };
    return UpsertAccount(Account(
      id: normalizedID(_str(data, 'id')),
      name: _str(data, 'name'),
      type: _fromCode('type', () => AccountType.fromCode(_int(data, 'type'))),
      subPocketIDs: subPocketIDs,
      incomingTransfersAsExpenses: _bool(data, 'incomingTransfersAsExpenses'),
      includeInNetWorth: _bool(data, 'includeInNetWorth'),
      statementDay: _intNullable(data, 'statementDay'),
      lifecycle: _fromCode(
          'lifecycle', () => LifecycleState.fromCode(_int(data, 'lifecycle'))),
    ));
  }

  LedgerChange _decodeSubPocket(Map<String, Object?> data) => UpsertPocket(
        SubPocket(
          id: normalizedID(_str(data, 'id')),
          name: _str(data, 'name'),
          incomingTransfersAsExpenses:
              _bool(data, 'incomingTransfersAsExpenses'),
          lifecycle: _fromCode('lifecycle',
              () => LifecycleState.fromCode(_int(data, 'lifecycle'))),
        ),
      );

  LedgerChange _decodeCategory(Map<String, Object?> data) => UpsertCategory(
        TransactionCategory(
          id: normalizedID(_str(data, 'id')),
          name: _str(data, 'name'),
          kind: _fromCode(
              'kind', () => CategoryKind.fromCode(_int(data, 'kind'))),
          colorHex: _str(data, 'colorHex'),
          includeInAnalysis: _bool(data, 'includeInAnalysis'),
          parentID: normalizedOptionalID(_strNullable(data, 'parentID')),
          symbol: _str(data, 'symbol'),
          lifecycle: _fromCode('lifecycle',
              () => LifecycleState.fromCode(_int(data, 'lifecycle'))),
        ),
      );

  LedgerChange _decodeEntry(Map<String, Object?> data) {
    final systemKindCode = _intNullable(data, 'systemKind');
    final systemKind = systemKindCode == null
        ? null
        : _fromCode(
            'systemKind', () => SystemEntryKind.fromCode(systemKindCode));
    if (systemKindCode != null && systemKind == null) {
      throw const PayloadDecodeError('Field systemKind is invalid.');
    }
    return UpsertEntry(
      Entry(
        id: normalizedID(_str(data, 'id')),
        date: _dateTime('date', _str(data, 'date')),
        amount: _fromCode('amount', () => Decimal.parse(_str(data, 'amount'))),
        name: _str(data, 'name'),
        categoryID: normalizedOptionalID(_strNullable(data, 'categoryID')),
        sourceID: normalizedID(_str(data, 'sourceID')),
        destinationID:
            normalizedOptionalID(_strNullable(data, 'destinationID')),
        includeInAnalysis: _bool(data, 'includeInAnalysis'),
        lifecycle: _fromCode('lifecycle',
            () => LifecycleState.fromCode(_int(data, 'lifecycle'))),
        systemKind: systemKind,
        note: _strNullable(data, 'note'),
      ),
    );
  }

  LedgerChange _decodePlan(Map<String, Object?> data) => UpsertPlan(
        RecurringPlan(
          id: normalizedID(_str(data, 'id')),
          template: _decodeTemplate(data, 'template'),
          frequency: _fromCode('frequency',
              () => RecurrenceFrequency.fromCode(_int(data, 'frequency'))),
          anchor: _dateTime('anchor', _str(data, 'anchor')),
          endDate: _strNullable(data, 'endDate') == null
              ? null
              : _dateTime('endDate', _str(data, 'endDate')),
          lastResolvedDate:
              _dateTime('lastResolvedDate', _str(data, 'lastResolvedDate')),
        ),
      );

  EntryTemplate _decodeTemplate(Map<String, Object?> data, String key) {
    final raw = data[key];
    if (raw is! Map<String, Object?>) {
      throw const PayloadDecodeError('Entry template must be an object.');
    }
    return EntryTemplate(
      amount: _fromCode('amount', () => Decimal.parse(_str(raw, 'amount'))),
      name: _str(raw, 'name'),
      categoryID: normalizedOptionalID(_strNullable(raw, 'categoryID')),
      sourceID: normalizedID(_str(raw, 'sourceID')),
      destinationID: normalizedOptionalID(_strNullable(raw, 'destinationID')),
      includeInAnalysis: _bool(raw, 'includeInAnalysis'),
    );
  }

  LedgerChange _decodeBudget(Map<String, Object?> data) => UpsertBudget(
        Budget(
          id: normalizedID(_str(data, 'id')),
          categoryID: normalizedOptionalID(_strNullable(data, 'categoryID')),
          limitEvents: <LimitEvent>[
            for (final raw in _list(data, 'limitEvents'))
              _decodeLimitEvent(raw),
          ],
          createdAtMonth: _yearMonth(_object(data, 'createdAtMonth')),
        ),
      );

  LimitEvent _decodeLimitEvent(Object? raw) {
    final map = raw;
    if (map is! Map<String, Object?>) {
      throw const PayloadDecodeError('Limit event must be an object.');
    }
    return LimitEvent(
      effectiveFromMonth: _decodeYearMonth(map['effectiveFromMonth']),
      value: _fromCode('value', () => Decimal.parse(_str(map, 'value'))),
      kind: _fromCode('kind', () => LimitEventKind.fromCode(_int(map, 'kind'))),
    );
  }

  YearMonth _yearMonth(Map<String, Object?> map) =>
      YearMonth(_int(map, 'year'), _int(map, 'month'));

  YearMonth? _decodeYearMonth(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) {
      throw const PayloadDecodeError('YearMonth must be an object or null.');
    }
    return YearMonth(_int(raw, 'year'), _int(raw, 'month'));
  }

  DateTime _dateTime(String field, String iso) =>
      _fromCode(field, () => DateTime.parse(iso).toUtc());
}
