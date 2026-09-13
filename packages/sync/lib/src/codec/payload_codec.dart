part of '../../sync.dart';

/// Error thrown when a decoded sync payload is malformed or uses a version
/// this codec cannot read.
///
/// Distinct from [SyncPayloadDecryptionError], which is reserved for AEAD
/// authentication failures. A decode failure means the bytes were authentic
/// but not a payload this codec understands.
final class PayloadDecodeError implements FormatException {
  const PayloadDecodeError(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'PayloadDecodeError: $message';
}

/// Hand-written, explicitly versioned codec between sync-payload bytes and the
/// domain entities that back upsert [LedgerChange]s.
///
/// Version 1 is the only emitted version. Tombstones carry no payload, so the
/// codec encodes only entity upserts and rejects empty payloads on decode.
final class PayloadCodec {
  const PayloadCodec();

  static const int currentVersion = 1;

  /// Encodes [change] to payload bytes.
  ///
  /// Upserts serialize the underlying entity; deletes are payload-free and
  /// return an empty list.
  List<int> encodeChange(LedgerChange change) {
    final data = _encodeData(change);
    if (data == null) return const <int>[];
    final payload = <String, Object?>{
      'version': currentVersion,
      'entity': data.entity,
      'data': data.fields,
    };
    return utf8.encode(canonicalJson(payload));
  }

  /// Decodes [payload] into the upsert [LedgerChange] that produced it.
  ///
  /// Throws [PayloadDecodeError] for an empty, malformed, or unsupported
  /// payload.
  LedgerChange decodeChange(List<int> payload) {
    if (payload.isEmpty) {
      throw const PayloadDecodeError(
        'Payload is empty; tombstones carry no entity payload.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload));
    } on FormatException {
      throw const PayloadDecodeError('Payload is not valid JSON.');
    }
    if (decoded is! Map<Object?, Object?>) {
      throw const PayloadDecodeError(
          'Payload must be a canonical JSON object.');
    }
    final map = decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final version = _int(map, 'version');
    if (version != currentVersion) {
      throw PayloadDecodeError(
        'Unsupported payload version: $version.',
      );
    }
    final entity = _str(map, 'entity');
    final data = map['data'];
    if (data is! Map<String, Object?>) {
      throw const PayloadDecodeError('Payload data must be an object.');
    }
    return _decodeEntity(entity, data);
  }

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

  /// Runs a domain-level decode that can throw on attacker-controlled content
  /// (unknown enum codes, unparseable dates or amounts) and converts any
  /// thrown exception into a [PayloadDecodeError] with a fixed, non-leaking
  /// message.
  T _fromCode<T>(String field, T Function() decode) {
    try {
      return decode();
    } catch (_) {
      throw PayloadDecodeError('Field $field is invalid.');
    }
  }

  String _str(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) {
      throw PayloadDecodeError('Field $key must be a string.');
    }
    return value;
  }

  String? _strNullable(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw PayloadDecodeError('Field $key must be a string or null.');
    }
    return value as String?;
  }

  int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw PayloadDecodeError('Field $key must be an integer.');
    }
    return value;
  }

  int? _intNullable(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! int) {
      throw PayloadDecodeError('Field $key must be an integer or null.');
    }
    return value as int?;
  }

  bool _bool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw PayloadDecodeError('Field $key must be a boolean.');
    }
    return value;
  }

  List<Object?> _list(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! List<Object?>) {
      throw PayloadDecodeError('Field $key must be a list.');
    }
    return value;
  }

  Map<String, Object?> _object(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! Map<String, Object?>) {
      throw PayloadDecodeError('Field $key must be an object.');
    }
    return value;
  }

  List<String> _stringList(Map<String, Object?> map, String key) {
    final values = _list(map, key);
    return <String>[
      for (final value in values)
        if (value is! String)
          throw PayloadDecodeError('Field $key must hold strings.')
        else
          value,
    ];
  }
}

class _EncodedChange {
  const _EncodedChange(this.entity, this.fields);
  final String entity;
  final Map<String, Object?> fields;
}
