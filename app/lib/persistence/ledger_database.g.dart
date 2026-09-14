// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionDataMeta = const VerificationMeta(
    'versionData',
  );
  @override
  late final GeneratedColumn<Uint8List> versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<int> lifecycle = GeneratedColumn<int>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subPocketIdsMeta = const VerificationMeta(
    'subPocketIds',
  );
  @override
  late final GeneratedColumn<String> subPocketIds = GeneratedColumn<String>(
    'sub_pocket_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomingTransfersAsExpensesMeta =
      const VerificationMeta('incomingTransfersAsExpenses');
  @override
  late final GeneratedColumn<bool> incomingTransfersAsExpenses =
      GeneratedColumn<bool>(
        'incoming_transfers_as_expenses',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("incoming_transfers_as_expenses" IN (0, 1))',
        ),
      );
  static const VerificationMeta _includeInNetWorthMeta = const VerificationMeta(
    'includeInNetWorth',
  );
  @override
  late final GeneratedColumn<bool> includeInNetWorth = GeneratedColumn<bool>(
    'include_in_net_worth',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_net_worth" IN (0, 1))',
    ),
  );
  static const VerificationMeta _statementDayMeta = const VerificationMeta(
    'statementDay',
  );
  @override
  late final GeneratedColumn<int> statementDay = GeneratedColumn<int>(
    'statement_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    versionData,
    lifecycle,
    id,
    name,
    type,
    subPocketIds,
    incomingTransfersAsExpenses,
    includeInNetWorth,
    statementDay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version_data')) {
      context.handle(
        _versionDataMeta,
        versionData.isAcceptableOrUnknown(
          data['version_data']!,
          _versionDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionDataMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('sub_pocket_ids')) {
      context.handle(
        _subPocketIdsMeta,
        subPocketIds.isAcceptableOrUnknown(
          data['sub_pocket_ids']!,
          _subPocketIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subPocketIdsMeta);
    }
    if (data.containsKey('incoming_transfers_as_expenses')) {
      context.handle(
        _incomingTransfersAsExpensesMeta,
        incomingTransfersAsExpenses.isAcceptableOrUnknown(
          data['incoming_transfers_as_expenses']!,
          _incomingTransfersAsExpensesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomingTransfersAsExpensesMeta);
    }
    if (data.containsKey('include_in_net_worth')) {
      context.handle(
        _includeInNetWorthMeta,
        includeInNetWorth.isAcceptableOrUnknown(
          data['include_in_net_worth']!,
          _includeInNetWorthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeInNetWorthMeta);
    }
    if (data.containsKey('statement_day')) {
      context.handle(
        _statementDayMeta,
        statementDay.isAcceptableOrUnknown(
          data['statement_day']!,
          _statementDayMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      versionData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version_data'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      subPocketIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_pocket_ids'],
      )!,
      incomingTransfersAsExpenses: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}incoming_transfers_as_expenses'],
      )!,
      includeInNetWorth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_net_worth'],
      )!,
      statementDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}statement_day'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final Uint8List versionData;
  final int lifecycle;
  final String id;
  final String name;
  final int type;

  /// Parentage lives here alone, so a pocket row has no back pointer to read it
  /// from.
  final String subPocketIds;
  final bool incomingTransfersAsExpenses;
  final bool includeInNetWorth;
  final int? statementDay;
  const Account({
    required this.versionData,
    required this.lifecycle,
    required this.id,
    required this.name,
    required this.type,
    required this.subPocketIds,
    required this.incomingTransfersAsExpenses,
    required this.includeInNetWorth,
    this.statementDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version_data'] = Variable<Uint8List>(versionData);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<int>(type);
    map['sub_pocket_ids'] = Variable<String>(subPocketIds);
    map['incoming_transfers_as_expenses'] = Variable<bool>(
      incomingTransfersAsExpenses,
    );
    map['include_in_net_worth'] = Variable<bool>(includeInNetWorth);
    if (!nullToAbsent || statementDay != null) {
      map['statement_day'] = Variable<int>(statementDay);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      versionData: Value(versionData),
      lifecycle: Value(lifecycle),
      id: Value(id),
      name: Value(name),
      type: Value(type),
      subPocketIds: Value(subPocketIds),
      incomingTransfersAsExpenses: Value(incomingTransfersAsExpenses),
      includeInNetWorth: Value(includeInNetWorth),
      statementDay: statementDay == null && nullToAbsent
          ? const Value.absent()
          : Value(statementDay),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      versionData: serializer.fromJson<Uint8List>(json['versionData']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<int>(json['type']),
      subPocketIds: serializer.fromJson<String>(json['subPocketIds']),
      incomingTransfersAsExpenses: serializer.fromJson<bool>(
        json['incomingTransfersAsExpenses'],
      ),
      includeInNetWorth: serializer.fromJson<bool>(json['includeInNetWorth']),
      statementDay: serializer.fromJson<int?>(json['statementDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'versionData': serializer.toJson<Uint8List>(versionData),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<int>(type),
      'subPocketIds': serializer.toJson<String>(subPocketIds),
      'incomingTransfersAsExpenses': serializer.toJson<bool>(
        incomingTransfersAsExpenses,
      ),
      'includeInNetWorth': serializer.toJson<bool>(includeInNetWorth),
      'statementDay': serializer.toJson<int?>(statementDay),
    };
  }

  Account copyWith({
    Uint8List? versionData,
    int? lifecycle,
    String? id,
    String? name,
    int? type,
    String? subPocketIds,
    bool? incomingTransfersAsExpenses,
    bool? includeInNetWorth,
    Value<int?> statementDay = const Value.absent(),
  }) => Account(
    versionData: versionData ?? this.versionData,
    lifecycle: lifecycle ?? this.lifecycle,
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    subPocketIds: subPocketIds ?? this.subPocketIds,
    incomingTransfersAsExpenses:
        incomingTransfersAsExpenses ?? this.incomingTransfersAsExpenses,
    includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
    statementDay: statementDay.present ? statementDay.value : this.statementDay,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      subPocketIds: data.subPocketIds.present
          ? data.subPocketIds.value
          : this.subPocketIds,
      incomingTransfersAsExpenses: data.incomingTransfersAsExpenses.present
          ? data.incomingTransfersAsExpenses.value
          : this.incomingTransfersAsExpenses,
      includeInNetWorth: data.includeInNetWorth.present
          ? data.includeInNetWorth.value
          : this.includeInNetWorth,
      statementDay: data.statementDay.present
          ? data.statementDay.value
          : this.statementDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('subPocketIds: $subPocketIds, ')
          ..write('incomingTransfersAsExpenses: $incomingTransfersAsExpenses, ')
          ..write('includeInNetWorth: $includeInNetWorth, ')
          ..write('statementDay: $statementDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(versionData),
    lifecycle,
    id,
    name,
    type,
    subPocketIds,
    incomingTransfersAsExpenses,
    includeInNetWorth,
    statementDay,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          $driftBlobEquality.equals(other.versionData, this.versionData) &&
          other.lifecycle == this.lifecycle &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.subPocketIds == this.subPocketIds &&
          other.incomingTransfersAsExpenses ==
              this.incomingTransfersAsExpenses &&
          other.includeInNetWorth == this.includeInNetWorth &&
          other.statementDay == this.statementDay);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<Uint8List> versionData;
  final Value<int> lifecycle;
  final Value<String> id;
  final Value<String> name;
  final Value<int> type;
  final Value<String> subPocketIds;
  final Value<bool> incomingTransfersAsExpenses;
  final Value<bool> includeInNetWorth;
  final Value<int?> statementDay;
  final Value<int> rowid;
  const AccountsCompanion({
    this.versionData = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.subPocketIds = const Value.absent(),
    this.incomingTransfersAsExpenses = const Value.absent(),
    this.includeInNetWorth = const Value.absent(),
    this.statementDay = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required Uint8List versionData,
    required int lifecycle,
    required String id,
    required String name,
    required int type,
    required String subPocketIds,
    required bool incomingTransfersAsExpenses,
    required bool includeInNetWorth,
    this.statementDay = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : versionData = Value(versionData),
       lifecycle = Value(lifecycle),
       id = Value(id),
       name = Value(name),
       type = Value(type),
       subPocketIds = Value(subPocketIds),
       incomingTransfersAsExpenses = Value(incomingTransfersAsExpenses),
       includeInNetWorth = Value(includeInNetWorth);
  static Insertable<Account> custom({
    Expression<Uint8List>? versionData,
    Expression<int>? lifecycle,
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? type,
    Expression<String>? subPocketIds,
    Expression<bool>? incomingTransfersAsExpenses,
    Expression<bool>? includeInNetWorth,
    Expression<int>? statementDay,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (versionData != null) 'version_data': versionData,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (subPocketIds != null) 'sub_pocket_ids': subPocketIds,
      if (incomingTransfersAsExpenses != null)
        'incoming_transfers_as_expenses': incomingTransfersAsExpenses,
      if (includeInNetWorth != null) 'include_in_net_worth': includeInNetWorth,
      if (statementDay != null) 'statement_day': statementDay,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<Uint8List>? versionData,
    Value<int>? lifecycle,
    Value<String>? id,
    Value<String>? name,
    Value<int>? type,
    Value<String>? subPocketIds,
    Value<bool>? incomingTransfersAsExpenses,
    Value<bool>? includeInNetWorth,
    Value<int?>? statementDay,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      versionData: versionData ?? this.versionData,
      lifecycle: lifecycle ?? this.lifecycle,
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      subPocketIds: subPocketIds ?? this.subPocketIds,
      incomingTransfersAsExpenses:
          incomingTransfersAsExpenses ?? this.incomingTransfersAsExpenses,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      statementDay: statementDay ?? this.statementDay,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(versionData.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (subPocketIds.present) {
      map['sub_pocket_ids'] = Variable<String>(subPocketIds.value);
    }
    if (incomingTransfersAsExpenses.present) {
      map['incoming_transfers_as_expenses'] = Variable<bool>(
        incomingTransfersAsExpenses.value,
      );
    }
    if (includeInNetWorth.present) {
      map['include_in_net_worth'] = Variable<bool>(includeInNetWorth.value);
    }
    if (statementDay.present) {
      map['statement_day'] = Variable<int>(statementDay.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('subPocketIds: $subPocketIds, ')
          ..write('incomingTransfersAsExpenses: $incomingTransfersAsExpenses, ')
          ..write('includeInNetWorth: $includeInNetWorth, ')
          ..write('statementDay: $statementDay, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubPocketsTable extends SubPockets
    with TableInfo<$SubPocketsTable, SubPocket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubPocketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionDataMeta = const VerificationMeta(
    'versionData',
  );
  @override
  late final GeneratedColumn<Uint8List> versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<int> lifecycle = GeneratedColumn<int>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomingTransfersAsExpensesMeta =
      const VerificationMeta('incomingTransfersAsExpenses');
  @override
  late final GeneratedColumn<bool> incomingTransfersAsExpenses =
      GeneratedColumn<bool>(
        'incoming_transfers_as_expenses',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("incoming_transfers_as_expenses" IN (0, 1))',
        ),
      );
  @override
  List<GeneratedColumn> get $columns => [
    versionData,
    lifecycle,
    id,
    name,
    incomingTransfersAsExpenses,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sub_pockets';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubPocket> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version_data')) {
      context.handle(
        _versionDataMeta,
        versionData.isAcceptableOrUnknown(
          data['version_data']!,
          _versionDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionDataMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('incoming_transfers_as_expenses')) {
      context.handle(
        _incomingTransfersAsExpensesMeta,
        incomingTransfersAsExpenses.isAcceptableOrUnknown(
          data['incoming_transfers_as_expenses']!,
          _incomingTransfersAsExpensesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomingTransfersAsExpensesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubPocket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubPocket(
      versionData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version_data'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      incomingTransfersAsExpenses: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}incoming_transfers_as_expenses'],
      )!,
    );
  }

  @override
  $SubPocketsTable createAlias(String alias) {
    return $SubPocketsTable(attachedDatabase, alias);
  }
}

class SubPocket extends DataClass implements Insertable<SubPocket> {
  final Uint8List versionData;
  final int lifecycle;
  final String id;
  final String name;
  final bool incomingTransfersAsExpenses;
  const SubPocket({
    required this.versionData,
    required this.lifecycle,
    required this.id,
    required this.name,
    required this.incomingTransfersAsExpenses,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version_data'] = Variable<Uint8List>(versionData);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['incoming_transfers_as_expenses'] = Variable<bool>(
      incomingTransfersAsExpenses,
    );
    return map;
  }

  SubPocketsCompanion toCompanion(bool nullToAbsent) {
    return SubPocketsCompanion(
      versionData: Value(versionData),
      lifecycle: Value(lifecycle),
      id: Value(id),
      name: Value(name),
      incomingTransfersAsExpenses: Value(incomingTransfersAsExpenses),
    );
  }

  factory SubPocket.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubPocket(
      versionData: serializer.fromJson<Uint8List>(json['versionData']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      incomingTransfersAsExpenses: serializer.fromJson<bool>(
        json['incomingTransfersAsExpenses'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'versionData': serializer.toJson<Uint8List>(versionData),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'incomingTransfersAsExpenses': serializer.toJson<bool>(
        incomingTransfersAsExpenses,
      ),
    };
  }

  SubPocket copyWith({
    Uint8List? versionData,
    int? lifecycle,
    String? id,
    String? name,
    bool? incomingTransfersAsExpenses,
  }) => SubPocket(
    versionData: versionData ?? this.versionData,
    lifecycle: lifecycle ?? this.lifecycle,
    id: id ?? this.id,
    name: name ?? this.name,
    incomingTransfersAsExpenses:
        incomingTransfersAsExpenses ?? this.incomingTransfersAsExpenses,
  );
  SubPocket copyWithCompanion(SubPocketsCompanion data) {
    return SubPocket(
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      incomingTransfersAsExpenses: data.incomingTransfersAsExpenses.present
          ? data.incomingTransfersAsExpenses.value
          : this.incomingTransfersAsExpenses,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubPocket(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('incomingTransfersAsExpenses: $incomingTransfersAsExpenses')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(versionData),
    lifecycle,
    id,
    name,
    incomingTransfersAsExpenses,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubPocket &&
          $driftBlobEquality.equals(other.versionData, this.versionData) &&
          other.lifecycle == this.lifecycle &&
          other.id == this.id &&
          other.name == this.name &&
          other.incomingTransfersAsExpenses ==
              this.incomingTransfersAsExpenses);
}

class SubPocketsCompanion extends UpdateCompanion<SubPocket> {
  final Value<Uint8List> versionData;
  final Value<int> lifecycle;
  final Value<String> id;
  final Value<String> name;
  final Value<bool> incomingTransfersAsExpenses;
  final Value<int> rowid;
  const SubPocketsCompanion({
    this.versionData = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.incomingTransfersAsExpenses = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubPocketsCompanion.insert({
    required Uint8List versionData,
    required int lifecycle,
    required String id,
    required String name,
    required bool incomingTransfersAsExpenses,
    this.rowid = const Value.absent(),
  }) : versionData = Value(versionData),
       lifecycle = Value(lifecycle),
       id = Value(id),
       name = Value(name),
       incomingTransfersAsExpenses = Value(incomingTransfersAsExpenses);
  static Insertable<SubPocket> custom({
    Expression<Uint8List>? versionData,
    Expression<int>? lifecycle,
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? incomingTransfersAsExpenses,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (versionData != null) 'version_data': versionData,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (incomingTransfersAsExpenses != null)
        'incoming_transfers_as_expenses': incomingTransfersAsExpenses,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubPocketsCompanion copyWith({
    Value<Uint8List>? versionData,
    Value<int>? lifecycle,
    Value<String>? id,
    Value<String>? name,
    Value<bool>? incomingTransfersAsExpenses,
    Value<int>? rowid,
  }) {
    return SubPocketsCompanion(
      versionData: versionData ?? this.versionData,
      lifecycle: lifecycle ?? this.lifecycle,
      id: id ?? this.id,
      name: name ?? this.name,
      incomingTransfersAsExpenses:
          incomingTransfersAsExpenses ?? this.incomingTransfersAsExpenses,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(versionData.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (incomingTransfersAsExpenses.present) {
      map['incoming_transfers_as_expenses'] = Variable<bool>(
        incomingTransfersAsExpenses.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubPocketsCompanion(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('incomingTransfersAsExpenses: $incomingTransfersAsExpenses, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionDataMeta = const VerificationMeta(
    'versionData',
  );
  @override
  late final GeneratedColumn<Uint8List> versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<int> lifecycle = GeneratedColumn<int>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _includeInAnalysisMeta = const VerificationMeta(
    'includeInAnalysis',
  );
  @override
  late final GeneratedColumn<bool> includeInAnalysis = GeneratedColumn<bool>(
    'include_in_analysis',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_analysis" IN (0, 1))',
    ),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    versionData,
    lifecycle,
    id,
    name,
    kind,
    colorHex,
    includeInAnalysis,
    parentId,
    symbol,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version_data')) {
      context.handle(
        _versionDataMeta,
        versionData.isAcceptableOrUnknown(
          data['version_data']!,
          _versionDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionDataMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('include_in_analysis')) {
      context.handle(
        _includeInAnalysisMeta,
        includeInAnalysis.isAcceptableOrUnknown(
          data['include_in_analysis']!,
          _includeInAnalysisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeInAnalysisMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      versionData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version_data'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      includeInAnalysis: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_analysis'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final Uint8List versionData;
  final int lifecycle;
  final String id;
  final String name;
  final int kind;
  final String colorHex;
  final bool includeInAnalysis;

  /// No foreign key: a category may outlive its parent as a reference-only row.
  final String? parentId;
  final String symbol;
  const Category({
    required this.versionData,
    required this.lifecycle,
    required this.id,
    required this.name,
    required this.kind,
    required this.colorHex,
    required this.includeInAnalysis,
    this.parentId,
    required this.symbol,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version_data'] = Variable<Uint8List>(versionData);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<int>(kind);
    map['color_hex'] = Variable<String>(colorHex);
    map['include_in_analysis'] = Variable<bool>(includeInAnalysis);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['symbol'] = Variable<String>(symbol);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      versionData: Value(versionData),
      lifecycle: Value(lifecycle),
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      colorHex: Value(colorHex),
      includeInAnalysis: Value(includeInAnalysis),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      symbol: Value(symbol),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      versionData: serializer.fromJson<Uint8List>(json['versionData']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<int>(json['kind']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      includeInAnalysis: serializer.fromJson<bool>(json['includeInAnalysis']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      symbol: serializer.fromJson<String>(json['symbol']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'versionData': serializer.toJson<Uint8List>(versionData),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<int>(kind),
      'colorHex': serializer.toJson<String>(colorHex),
      'includeInAnalysis': serializer.toJson<bool>(includeInAnalysis),
      'parentId': serializer.toJson<String?>(parentId),
      'symbol': serializer.toJson<String>(symbol),
    };
  }

  Category copyWith({
    Uint8List? versionData,
    int? lifecycle,
    String? id,
    String? name,
    int? kind,
    String? colorHex,
    bool? includeInAnalysis,
    Value<String?> parentId = const Value.absent(),
    String? symbol,
  }) => Category(
    versionData: versionData ?? this.versionData,
    lifecycle: lifecycle ?? this.lifecycle,
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    colorHex: colorHex ?? this.colorHex,
    includeInAnalysis: includeInAnalysis ?? this.includeInAnalysis,
    parentId: parentId.present ? parentId.value : this.parentId,
    symbol: symbol ?? this.symbol,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      includeInAnalysis: data.includeInAnalysis.present
          ? data.includeInAnalysis.value
          : this.includeInAnalysis,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colorHex: $colorHex, ')
          ..write('includeInAnalysis: $includeInAnalysis, ')
          ..write('parentId: $parentId, ')
          ..write('symbol: $symbol')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(versionData),
    lifecycle,
    id,
    name,
    kind,
    colorHex,
    includeInAnalysis,
    parentId,
    symbol,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          $driftBlobEquality.equals(other.versionData, this.versionData) &&
          other.lifecycle == this.lifecycle &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.colorHex == this.colorHex &&
          other.includeInAnalysis == this.includeInAnalysis &&
          other.parentId == this.parentId &&
          other.symbol == this.symbol);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<Uint8List> versionData;
  final Value<int> lifecycle;
  final Value<String> id;
  final Value<String> name;
  final Value<int> kind;
  final Value<String> colorHex;
  final Value<bool> includeInAnalysis;
  final Value<String?> parentId;
  final Value<String> symbol;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.versionData = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.includeInAnalysis = const Value.absent(),
    this.parentId = const Value.absent(),
    this.symbol = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required Uint8List versionData,
    required int lifecycle,
    required String id,
    required String name,
    required int kind,
    required String colorHex,
    required bool includeInAnalysis,
    this.parentId = const Value.absent(),
    required String symbol,
    this.rowid = const Value.absent(),
  }) : versionData = Value(versionData),
       lifecycle = Value(lifecycle),
       id = Value(id),
       name = Value(name),
       kind = Value(kind),
       colorHex = Value(colorHex),
       includeInAnalysis = Value(includeInAnalysis),
       symbol = Value(symbol);
  static Insertable<Category> custom({
    Expression<Uint8List>? versionData,
    Expression<int>? lifecycle,
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? kind,
    Expression<String>? colorHex,
    Expression<bool>? includeInAnalysis,
    Expression<String>? parentId,
    Expression<String>? symbol,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (versionData != null) 'version_data': versionData,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (colorHex != null) 'color_hex': colorHex,
      if (includeInAnalysis != null) 'include_in_analysis': includeInAnalysis,
      if (parentId != null) 'parent_id': parentId,
      if (symbol != null) 'symbol': symbol,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<Uint8List>? versionData,
    Value<int>? lifecycle,
    Value<String>? id,
    Value<String>? name,
    Value<int>? kind,
    Value<String>? colorHex,
    Value<bool>? includeInAnalysis,
    Value<String?>? parentId,
    Value<String>? symbol,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      versionData: versionData ?? this.versionData,
      lifecycle: lifecycle ?? this.lifecycle,
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      colorHex: colorHex ?? this.colorHex,
      includeInAnalysis: includeInAnalysis ?? this.includeInAnalysis,
      parentId: parentId ?? this.parentId,
      symbol: symbol ?? this.symbol,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(versionData.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (includeInAnalysis.present) {
      map['include_in_analysis'] = Variable<bool>(includeInAnalysis.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colorHex: $colorHex, ')
          ..write('includeInAnalysis: $includeInAnalysis, ')
          ..write('parentId: $parentId, ')
          ..write('symbol: $symbol, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionDataMeta = const VerificationMeta(
    'versionData',
  );
  @override
  late final GeneratedColumn<Uint8List> versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<int> lifecycle = GeneratedColumn<int>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationIdMeta = const VerificationMeta(
    'destinationId',
  );
  @override
  late final GeneratedColumn<String> destinationId = GeneratedColumn<String>(
    'destination_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _includeInAnalysisMeta = const VerificationMeta(
    'includeInAnalysis',
  );
  @override
  late final GeneratedColumn<bool> includeInAnalysis = GeneratedColumn<bool>(
    'include_in_analysis',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_analysis" IN (0, 1))',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _systemKindMeta = const VerificationMeta(
    'systemKind',
  );
  @override
  late final GeneratedColumn<int> systemKind = GeneratedColumn<int>(
    'system_kind',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    versionData,
    lifecycle,
    id,
    date,
    amount,
    name,
    categoryId,
    sourceId,
    destinationId,
    includeInAnalysis,
    note,
    systemKind,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version_data')) {
      context.handle(
        _versionDataMeta,
        versionData.isAcceptableOrUnknown(
          data['version_data']!,
          _versionDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionDataMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('destination_id')) {
      context.handle(
        _destinationIdMeta,
        destinationId.isAcceptableOrUnknown(
          data['destination_id']!,
          _destinationIdMeta,
        ),
      );
    }
    if (data.containsKey('include_in_analysis')) {
      context.handle(
        _includeInAnalysisMeta,
        includeInAnalysis.isAcceptableOrUnknown(
          data['include_in_analysis']!,
          _includeInAnalysisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeInAnalysisMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('system_kind')) {
      context.handle(
        _systemKindMeta,
        systemKind.isAcceptableOrUnknown(data['system_kind']!, _systemKindMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      versionData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version_data'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      destinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_id'],
      ),
      includeInAnalysis: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_analysis'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      systemKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}system_kind'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final Uint8List versionData;
  final int lifecycle;
  final String id;
  final int date;

  /// A float column would not round-trip the stored amount.
  final String amount;
  final String name;
  final String? categoryId;
  final String sourceId;
  final String? destinationId;
  final bool includeInAnalysis;

  /// Reserved and never written by this version. Adding either column later
  /// costs a migration, so they are claimed now while the schema is still v1.
  final String? note;

  /// Marks a synthetic entry: 0 opening balance, 1 balance adjustment, null for
  /// a user entry.
  final int? systemKind;
  const Entry({
    required this.versionData,
    required this.lifecycle,
    required this.id,
    required this.date,
    required this.amount,
    required this.name,
    this.categoryId,
    required this.sourceId,
    this.destinationId,
    required this.includeInAnalysis,
    this.note,
    this.systemKind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version_data'] = Variable<Uint8List>(versionData);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['id'] = Variable<String>(id);
    map['date'] = Variable<int>(date);
    map['amount'] = Variable<String>(amount);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || destinationId != null) {
      map['destination_id'] = Variable<String>(destinationId);
    }
    map['include_in_analysis'] = Variable<bool>(includeInAnalysis);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || systemKind != null) {
      map['system_kind'] = Variable<int>(systemKind);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      versionData: Value(versionData),
      lifecycle: Value(lifecycle),
      id: Value(id),
      date: Value(date),
      amount: Value(amount),
      name: Value(name),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      sourceId: Value(sourceId),
      destinationId: destinationId == null && nullToAbsent
          ? const Value.absent()
          : Value(destinationId),
      includeInAnalysis: Value(includeInAnalysis),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      systemKind: systemKind == null && nullToAbsent
          ? const Value.absent()
          : Value(systemKind),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      versionData: serializer.fromJson<Uint8List>(json['versionData']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<int>(json['date']),
      amount: serializer.fromJson<String>(json['amount']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      destinationId: serializer.fromJson<String?>(json['destinationId']),
      includeInAnalysis: serializer.fromJson<bool>(json['includeInAnalysis']),
      note: serializer.fromJson<String?>(json['note']),
      systemKind: serializer.fromJson<int?>(json['systemKind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'versionData': serializer.toJson<Uint8List>(versionData),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<int>(date),
      'amount': serializer.toJson<String>(amount),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String?>(categoryId),
      'sourceId': serializer.toJson<String>(sourceId),
      'destinationId': serializer.toJson<String?>(destinationId),
      'includeInAnalysis': serializer.toJson<bool>(includeInAnalysis),
      'note': serializer.toJson<String?>(note),
      'systemKind': serializer.toJson<int?>(systemKind),
    };
  }

  Entry copyWith({
    Uint8List? versionData,
    int? lifecycle,
    String? id,
    int? date,
    String? amount,
    String? name,
    Value<String?> categoryId = const Value.absent(),
    String? sourceId,
    Value<String?> destinationId = const Value.absent(),
    bool? includeInAnalysis,
    Value<String?> note = const Value.absent(),
    Value<int?> systemKind = const Value.absent(),
  }) => Entry(
    versionData: versionData ?? this.versionData,
    lifecycle: lifecycle ?? this.lifecycle,
    id: id ?? this.id,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    name: name ?? this.name,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    sourceId: sourceId ?? this.sourceId,
    destinationId: destinationId.present
        ? destinationId.value
        : this.destinationId,
    includeInAnalysis: includeInAnalysis ?? this.includeInAnalysis,
    note: note.present ? note.value : this.note,
    systemKind: systemKind.present ? systemKind.value : this.systemKind,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      amount: data.amount.present ? data.amount.value : this.amount,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      destinationId: data.destinationId.present
          ? data.destinationId.value
          : this.destinationId,
      includeInAnalysis: data.includeInAnalysis.present
          ? data.includeInAnalysis.value
          : this.includeInAnalysis,
      note: data.note.present ? data.note.value : this.note,
      systemKind: data.systemKind.present
          ? data.systemKind.value
          : this.systemKind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('sourceId: $sourceId, ')
          ..write('destinationId: $destinationId, ')
          ..write('includeInAnalysis: $includeInAnalysis, ')
          ..write('note: $note, ')
          ..write('systemKind: $systemKind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(versionData),
    lifecycle,
    id,
    date,
    amount,
    name,
    categoryId,
    sourceId,
    destinationId,
    includeInAnalysis,
    note,
    systemKind,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          $driftBlobEquality.equals(other.versionData, this.versionData) &&
          other.lifecycle == this.lifecycle &&
          other.id == this.id &&
          other.date == this.date &&
          other.amount == this.amount &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.sourceId == this.sourceId &&
          other.destinationId == this.destinationId &&
          other.includeInAnalysis == this.includeInAnalysis &&
          other.note == this.note &&
          other.systemKind == this.systemKind);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<Uint8List> versionData;
  final Value<int> lifecycle;
  final Value<String> id;
  final Value<int> date;
  final Value<String> amount;
  final Value<String> name;
  final Value<String?> categoryId;
  final Value<String> sourceId;
  final Value<String?> destinationId;
  final Value<bool> includeInAnalysis;
  final Value<String?> note;
  final Value<int?> systemKind;
  final Value<int> rowid;
  const EntriesCompanion({
    this.versionData = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.amount = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.destinationId = const Value.absent(),
    this.includeInAnalysis = const Value.absent(),
    this.note = const Value.absent(),
    this.systemKind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required Uint8List versionData,
    required int lifecycle,
    required String id,
    required int date,
    required String amount,
    required String name,
    this.categoryId = const Value.absent(),
    required String sourceId,
    this.destinationId = const Value.absent(),
    required bool includeInAnalysis,
    this.note = const Value.absent(),
    this.systemKind = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : versionData = Value(versionData),
       lifecycle = Value(lifecycle),
       id = Value(id),
       date = Value(date),
       amount = Value(amount),
       name = Value(name),
       sourceId = Value(sourceId),
       includeInAnalysis = Value(includeInAnalysis);
  static Insertable<Entry> custom({
    Expression<Uint8List>? versionData,
    Expression<int>? lifecycle,
    Expression<String>? id,
    Expression<int>? date,
    Expression<String>? amount,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<String>? sourceId,
    Expression<String>? destinationId,
    Expression<bool>? includeInAnalysis,
    Expression<String>? note,
    Expression<int>? systemKind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (versionData != null) 'version_data': versionData,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (amount != null) 'amount': amount,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (sourceId != null) 'source_id': sourceId,
      if (destinationId != null) 'destination_id': destinationId,
      if (includeInAnalysis != null) 'include_in_analysis': includeInAnalysis,
      if (note != null) 'note': note,
      if (systemKind != null) 'system_kind': systemKind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<Uint8List>? versionData,
    Value<int>? lifecycle,
    Value<String>? id,
    Value<int>? date,
    Value<String>? amount,
    Value<String>? name,
    Value<String?>? categoryId,
    Value<String>? sourceId,
    Value<String?>? destinationId,
    Value<bool>? includeInAnalysis,
    Value<String?>? note,
    Value<int?>? systemKind,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      versionData: versionData ?? this.versionData,
      lifecycle: lifecycle ?? this.lifecycle,
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      sourceId: sourceId ?? this.sourceId,
      destinationId: destinationId ?? this.destinationId,
      includeInAnalysis: includeInAnalysis ?? this.includeInAnalysis,
      note: note ?? this.note,
      systemKind: systemKind ?? this.systemKind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(versionData.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (destinationId.present) {
      map['destination_id'] = Variable<String>(destinationId.value);
    }
    if (includeInAnalysis.present) {
      map['include_in_analysis'] = Variable<bool>(includeInAnalysis.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (systemKind.present) {
      map['system_kind'] = Variable<int>(systemKind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('sourceId: $sourceId, ')
          ..write('destinationId: $destinationId, ')
          ..write('includeInAnalysis: $includeInAnalysis, ')
          ..write('note: $note, ')
          ..write('systemKind: $systemKind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlansTable extends Plans with TableInfo<$PlansTable, Plan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionDataMeta = const VerificationMeta(
    'versionData',
  );
  @override
  late final GeneratedColumn<Uint8List> versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<int> lifecycle = GeneratedColumn<int>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<int> frequency = GeneratedColumn<int>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anchorMeta = const VerificationMeta('anchor');
  @override
  late final GeneratedColumn<int> anchor = GeneratedColumn<int>(
    'anchor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<int> endDate = GeneratedColumn<int>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastResolvedDateMeta = const VerificationMeta(
    'lastResolvedDate',
  );
  @override
  late final GeneratedColumn<int> lastResolvedDate = GeneratedColumn<int>(
    'last_resolved_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateAmountMeta = const VerificationMeta(
    'templateAmount',
  );
  @override
  late final GeneratedColumn<String> templateAmount = GeneratedColumn<String>(
    'template_amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateNameMeta = const VerificationMeta(
    'templateName',
  );
  @override
  late final GeneratedColumn<String> templateName = GeneratedColumn<String>(
    'template_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateCategoryIdMeta =
      const VerificationMeta('templateCategoryId');
  @override
  late final GeneratedColumn<String> templateCategoryId =
      GeneratedColumn<String>(
        'template_category_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _templateSourceIdMeta = const VerificationMeta(
    'templateSourceId',
  );
  @override
  late final GeneratedColumn<String> templateSourceId = GeneratedColumn<String>(
    'template_source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateDestinationIdMeta =
      const VerificationMeta('templateDestinationId');
  @override
  late final GeneratedColumn<String> templateDestinationId =
      GeneratedColumn<String>(
        'template_destination_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _templateIncludeInAnalysisMeta =
      const VerificationMeta('templateIncludeInAnalysis');
  @override
  late final GeneratedColumn<bool> templateIncludeInAnalysis =
      GeneratedColumn<bool>(
        'template_include_in_analysis',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("template_include_in_analysis" IN (0, 1))',
        ),
      );
  @override
  List<GeneratedColumn> get $columns => [
    versionData,
    lifecycle,
    id,
    frequency,
    anchor,
    endDate,
    lastResolvedDate,
    templateAmount,
    templateName,
    templateCategoryId,
    templateSourceId,
    templateDestinationId,
    templateIncludeInAnalysis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version_data')) {
      context.handle(
        _versionDataMeta,
        versionData.isAcceptableOrUnknown(
          data['version_data']!,
          _versionDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionDataMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('anchor')) {
      context.handle(
        _anchorMeta,
        anchor.isAcceptableOrUnknown(data['anchor']!, _anchorMeta),
      );
    } else if (isInserting) {
      context.missing(_anchorMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('last_resolved_date')) {
      context.handle(
        _lastResolvedDateMeta,
        lastResolvedDate.isAcceptableOrUnknown(
          data['last_resolved_date']!,
          _lastResolvedDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastResolvedDateMeta);
    }
    if (data.containsKey('template_amount')) {
      context.handle(
        _templateAmountMeta,
        templateAmount.isAcceptableOrUnknown(
          data['template_amount']!,
          _templateAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateAmountMeta);
    }
    if (data.containsKey('template_name')) {
      context.handle(
        _templateNameMeta,
        templateName.isAcceptableOrUnknown(
          data['template_name']!,
          _templateNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateNameMeta);
    }
    if (data.containsKey('template_category_id')) {
      context.handle(
        _templateCategoryIdMeta,
        templateCategoryId.isAcceptableOrUnknown(
          data['template_category_id']!,
          _templateCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('template_source_id')) {
      context.handle(
        _templateSourceIdMeta,
        templateSourceId.isAcceptableOrUnknown(
          data['template_source_id']!,
          _templateSourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateSourceIdMeta);
    }
    if (data.containsKey('template_destination_id')) {
      context.handle(
        _templateDestinationIdMeta,
        templateDestinationId.isAcceptableOrUnknown(
          data['template_destination_id']!,
          _templateDestinationIdMeta,
        ),
      );
    }
    if (data.containsKey('template_include_in_analysis')) {
      context.handle(
        _templateIncludeInAnalysisMeta,
        templateIncludeInAnalysis.isAcceptableOrUnknown(
          data['template_include_in_analysis']!,
          _templateIncludeInAnalysisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateIncludeInAnalysisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Plan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plan(
      versionData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version_data'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frequency'],
      )!,
      anchor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anchor'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_date'],
      ),
      lastResolvedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_resolved_date'],
      )!,
      templateAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_amount'],
      )!,
      templateName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_name'],
      )!,
      templateCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_category_id'],
      ),
      templateSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_source_id'],
      )!,
      templateDestinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_destination_id'],
      ),
      templateIncludeInAnalysis: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}template_include_in_analysis'],
      )!,
    );
  }

  @override
  $PlansTable createAlias(String alias) {
    return $PlansTable(attachedDatabase, alias);
  }
}

class Plan extends DataClass implements Insertable<Plan> {
  final Uint8List versionData;
  final int lifecycle;
  final String id;
  final int frequency;
  final int anchor;
  final int? endDate;
  final int lastResolvedDate;
  final String templateAmount;
  final String templateName;
  final String? templateCategoryId;
  final String templateSourceId;
  final String? templateDestinationId;
  final bool templateIncludeInAnalysis;
  const Plan({
    required this.versionData,
    required this.lifecycle,
    required this.id,
    required this.frequency,
    required this.anchor,
    this.endDate,
    required this.lastResolvedDate,
    required this.templateAmount,
    required this.templateName,
    this.templateCategoryId,
    required this.templateSourceId,
    this.templateDestinationId,
    required this.templateIncludeInAnalysis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version_data'] = Variable<Uint8List>(versionData);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['id'] = Variable<String>(id);
    map['frequency'] = Variable<int>(frequency);
    map['anchor'] = Variable<int>(anchor);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<int>(endDate);
    }
    map['last_resolved_date'] = Variable<int>(lastResolvedDate);
    map['template_amount'] = Variable<String>(templateAmount);
    map['template_name'] = Variable<String>(templateName);
    if (!nullToAbsent || templateCategoryId != null) {
      map['template_category_id'] = Variable<String>(templateCategoryId);
    }
    map['template_source_id'] = Variable<String>(templateSourceId);
    if (!nullToAbsent || templateDestinationId != null) {
      map['template_destination_id'] = Variable<String>(templateDestinationId);
    }
    map['template_include_in_analysis'] = Variable<bool>(
      templateIncludeInAnalysis,
    );
    return map;
  }

  PlansCompanion toCompanion(bool nullToAbsent) {
    return PlansCompanion(
      versionData: Value(versionData),
      lifecycle: Value(lifecycle),
      id: Value(id),
      frequency: Value(frequency),
      anchor: Value(anchor),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      lastResolvedDate: Value(lastResolvedDate),
      templateAmount: Value(templateAmount),
      templateName: Value(templateName),
      templateCategoryId: templateCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateCategoryId),
      templateSourceId: Value(templateSourceId),
      templateDestinationId: templateDestinationId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateDestinationId),
      templateIncludeInAnalysis: Value(templateIncludeInAnalysis),
    );
  }

  factory Plan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plan(
      versionData: serializer.fromJson<Uint8List>(json['versionData']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      id: serializer.fromJson<String>(json['id']),
      frequency: serializer.fromJson<int>(json['frequency']),
      anchor: serializer.fromJson<int>(json['anchor']),
      endDate: serializer.fromJson<int?>(json['endDate']),
      lastResolvedDate: serializer.fromJson<int>(json['lastResolvedDate']),
      templateAmount: serializer.fromJson<String>(json['templateAmount']),
      templateName: serializer.fromJson<String>(json['templateName']),
      templateCategoryId: serializer.fromJson<String?>(
        json['templateCategoryId'],
      ),
      templateSourceId: serializer.fromJson<String>(json['templateSourceId']),
      templateDestinationId: serializer.fromJson<String?>(
        json['templateDestinationId'],
      ),
      templateIncludeInAnalysis: serializer.fromJson<bool>(
        json['templateIncludeInAnalysis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'versionData': serializer.toJson<Uint8List>(versionData),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'id': serializer.toJson<String>(id),
      'frequency': serializer.toJson<int>(frequency),
      'anchor': serializer.toJson<int>(anchor),
      'endDate': serializer.toJson<int?>(endDate),
      'lastResolvedDate': serializer.toJson<int>(lastResolvedDate),
      'templateAmount': serializer.toJson<String>(templateAmount),
      'templateName': serializer.toJson<String>(templateName),
      'templateCategoryId': serializer.toJson<String?>(templateCategoryId),
      'templateSourceId': serializer.toJson<String>(templateSourceId),
      'templateDestinationId': serializer.toJson<String?>(
        templateDestinationId,
      ),
      'templateIncludeInAnalysis': serializer.toJson<bool>(
        templateIncludeInAnalysis,
      ),
    };
  }

  Plan copyWith({
    Uint8List? versionData,
    int? lifecycle,
    String? id,
    int? frequency,
    int? anchor,
    Value<int?> endDate = const Value.absent(),
    int? lastResolvedDate,
    String? templateAmount,
    String? templateName,
    Value<String?> templateCategoryId = const Value.absent(),
    String? templateSourceId,
    Value<String?> templateDestinationId = const Value.absent(),
    bool? templateIncludeInAnalysis,
  }) => Plan(
    versionData: versionData ?? this.versionData,
    lifecycle: lifecycle ?? this.lifecycle,
    id: id ?? this.id,
    frequency: frequency ?? this.frequency,
    anchor: anchor ?? this.anchor,
    endDate: endDate.present ? endDate.value : this.endDate,
    lastResolvedDate: lastResolvedDate ?? this.lastResolvedDate,
    templateAmount: templateAmount ?? this.templateAmount,
    templateName: templateName ?? this.templateName,
    templateCategoryId: templateCategoryId.present
        ? templateCategoryId.value
        : this.templateCategoryId,
    templateSourceId: templateSourceId ?? this.templateSourceId,
    templateDestinationId: templateDestinationId.present
        ? templateDestinationId.value
        : this.templateDestinationId,
    templateIncludeInAnalysis:
        templateIncludeInAnalysis ?? this.templateIncludeInAnalysis,
  );
  Plan copyWithCompanion(PlansCompanion data) {
    return Plan(
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      id: data.id.present ? data.id.value : this.id,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      anchor: data.anchor.present ? data.anchor.value : this.anchor,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      lastResolvedDate: data.lastResolvedDate.present
          ? data.lastResolvedDate.value
          : this.lastResolvedDate,
      templateAmount: data.templateAmount.present
          ? data.templateAmount.value
          : this.templateAmount,
      templateName: data.templateName.present
          ? data.templateName.value
          : this.templateName,
      templateCategoryId: data.templateCategoryId.present
          ? data.templateCategoryId.value
          : this.templateCategoryId,
      templateSourceId: data.templateSourceId.present
          ? data.templateSourceId.value
          : this.templateSourceId,
      templateDestinationId: data.templateDestinationId.present
          ? data.templateDestinationId.value
          : this.templateDestinationId,
      templateIncludeInAnalysis: data.templateIncludeInAnalysis.present
          ? data.templateIncludeInAnalysis.value
          : this.templateIncludeInAnalysis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plan(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('frequency: $frequency, ')
          ..write('anchor: $anchor, ')
          ..write('endDate: $endDate, ')
          ..write('lastResolvedDate: $lastResolvedDate, ')
          ..write('templateAmount: $templateAmount, ')
          ..write('templateName: $templateName, ')
          ..write('templateCategoryId: $templateCategoryId, ')
          ..write('templateSourceId: $templateSourceId, ')
          ..write('templateDestinationId: $templateDestinationId, ')
          ..write('templateIncludeInAnalysis: $templateIncludeInAnalysis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(versionData),
    lifecycle,
    id,
    frequency,
    anchor,
    endDate,
    lastResolvedDate,
    templateAmount,
    templateName,
    templateCategoryId,
    templateSourceId,
    templateDestinationId,
    templateIncludeInAnalysis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plan &&
          $driftBlobEquality.equals(other.versionData, this.versionData) &&
          other.lifecycle == this.lifecycle &&
          other.id == this.id &&
          other.frequency == this.frequency &&
          other.anchor == this.anchor &&
          other.endDate == this.endDate &&
          other.lastResolvedDate == this.lastResolvedDate &&
          other.templateAmount == this.templateAmount &&
          other.templateName == this.templateName &&
          other.templateCategoryId == this.templateCategoryId &&
          other.templateSourceId == this.templateSourceId &&
          other.templateDestinationId == this.templateDestinationId &&
          other.templateIncludeInAnalysis == this.templateIncludeInAnalysis);
}

class PlansCompanion extends UpdateCompanion<Plan> {
  final Value<Uint8List> versionData;
  final Value<int> lifecycle;
  final Value<String> id;
  final Value<int> frequency;
  final Value<int> anchor;
  final Value<int?> endDate;
  final Value<int> lastResolvedDate;
  final Value<String> templateAmount;
  final Value<String> templateName;
  final Value<String?> templateCategoryId;
  final Value<String> templateSourceId;
  final Value<String?> templateDestinationId;
  final Value<bool> templateIncludeInAnalysis;
  final Value<int> rowid;
  const PlansCompanion({
    this.versionData = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.id = const Value.absent(),
    this.frequency = const Value.absent(),
    this.anchor = const Value.absent(),
    this.endDate = const Value.absent(),
    this.lastResolvedDate = const Value.absent(),
    this.templateAmount = const Value.absent(),
    this.templateName = const Value.absent(),
    this.templateCategoryId = const Value.absent(),
    this.templateSourceId = const Value.absent(),
    this.templateDestinationId = const Value.absent(),
    this.templateIncludeInAnalysis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlansCompanion.insert({
    required Uint8List versionData,
    required int lifecycle,
    required String id,
    required int frequency,
    required int anchor,
    this.endDate = const Value.absent(),
    required int lastResolvedDate,
    required String templateAmount,
    required String templateName,
    this.templateCategoryId = const Value.absent(),
    required String templateSourceId,
    this.templateDestinationId = const Value.absent(),
    required bool templateIncludeInAnalysis,
    this.rowid = const Value.absent(),
  }) : versionData = Value(versionData),
       lifecycle = Value(lifecycle),
       id = Value(id),
       frequency = Value(frequency),
       anchor = Value(anchor),
       lastResolvedDate = Value(lastResolvedDate),
       templateAmount = Value(templateAmount),
       templateName = Value(templateName),
       templateSourceId = Value(templateSourceId),
       templateIncludeInAnalysis = Value(templateIncludeInAnalysis);
  static Insertable<Plan> custom({
    Expression<Uint8List>? versionData,
    Expression<int>? lifecycle,
    Expression<String>? id,
    Expression<int>? frequency,
    Expression<int>? anchor,
    Expression<int>? endDate,
    Expression<int>? lastResolvedDate,
    Expression<String>? templateAmount,
    Expression<String>? templateName,
    Expression<String>? templateCategoryId,
    Expression<String>? templateSourceId,
    Expression<String>? templateDestinationId,
    Expression<bool>? templateIncludeInAnalysis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (versionData != null) 'version_data': versionData,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (id != null) 'id': id,
      if (frequency != null) 'frequency': frequency,
      if (anchor != null) 'anchor': anchor,
      if (endDate != null) 'end_date': endDate,
      if (lastResolvedDate != null) 'last_resolved_date': lastResolvedDate,
      if (templateAmount != null) 'template_amount': templateAmount,
      if (templateName != null) 'template_name': templateName,
      if (templateCategoryId != null)
        'template_category_id': templateCategoryId,
      if (templateSourceId != null) 'template_source_id': templateSourceId,
      if (templateDestinationId != null)
        'template_destination_id': templateDestinationId,
      if (templateIncludeInAnalysis != null)
        'template_include_in_analysis': templateIncludeInAnalysis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlansCompanion copyWith({
    Value<Uint8List>? versionData,
    Value<int>? lifecycle,
    Value<String>? id,
    Value<int>? frequency,
    Value<int>? anchor,
    Value<int?>? endDate,
    Value<int>? lastResolvedDate,
    Value<String>? templateAmount,
    Value<String>? templateName,
    Value<String?>? templateCategoryId,
    Value<String>? templateSourceId,
    Value<String?>? templateDestinationId,
    Value<bool>? templateIncludeInAnalysis,
    Value<int>? rowid,
  }) {
    return PlansCompanion(
      versionData: versionData ?? this.versionData,
      lifecycle: lifecycle ?? this.lifecycle,
      id: id ?? this.id,
      frequency: frequency ?? this.frequency,
      anchor: anchor ?? this.anchor,
      endDate: endDate ?? this.endDate,
      lastResolvedDate: lastResolvedDate ?? this.lastResolvedDate,
      templateAmount: templateAmount ?? this.templateAmount,
      templateName: templateName ?? this.templateName,
      templateCategoryId: templateCategoryId ?? this.templateCategoryId,
      templateSourceId: templateSourceId ?? this.templateSourceId,
      templateDestinationId:
          templateDestinationId ?? this.templateDestinationId,
      templateIncludeInAnalysis:
          templateIncludeInAnalysis ?? this.templateIncludeInAnalysis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(versionData.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<int>(frequency.value);
    }
    if (anchor.present) {
      map['anchor'] = Variable<int>(anchor.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<int>(endDate.value);
    }
    if (lastResolvedDate.present) {
      map['last_resolved_date'] = Variable<int>(lastResolvedDate.value);
    }
    if (templateAmount.present) {
      map['template_amount'] = Variable<String>(templateAmount.value);
    }
    if (templateName.present) {
      map['template_name'] = Variable<String>(templateName.value);
    }
    if (templateCategoryId.present) {
      map['template_category_id'] = Variable<String>(templateCategoryId.value);
    }
    if (templateSourceId.present) {
      map['template_source_id'] = Variable<String>(templateSourceId.value);
    }
    if (templateDestinationId.present) {
      map['template_destination_id'] = Variable<String>(
        templateDestinationId.value,
      );
    }
    if (templateIncludeInAnalysis.present) {
      map['template_include_in_analysis'] = Variable<bool>(
        templateIncludeInAnalysis.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansCompanion(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('frequency: $frequency, ')
          ..write('anchor: $anchor, ')
          ..write('endDate: $endDate, ')
          ..write('lastResolvedDate: $lastResolvedDate, ')
          ..write('templateAmount: $templateAmount, ')
          ..write('templateName: $templateName, ')
          ..write('templateCategoryId: $templateCategoryId, ')
          ..write('templateSourceId: $templateSourceId, ')
          ..write('templateDestinationId: $templateDestinationId, ')
          ..write('templateIncludeInAnalysis: $templateIncludeInAnalysis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionDataMeta = const VerificationMeta(
    'versionData',
  );
  @override
  late final GeneratedColumn<Uint8List> versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<int> lifecycle = GeneratedColumn<int>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _limitEventsMeta = const VerificationMeta(
    'limitEvents',
  );
  @override
  late final GeneratedColumn<String> limitEvents = GeneratedColumn<String>(
    'limit_events',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMonthMeta = const VerificationMeta(
    'createdAtMonth',
  );
  @override
  late final GeneratedColumn<String> createdAtMonth = GeneratedColumn<String>(
    'created_at_month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    versionData,
    lifecycle,
    id,
    categoryId,
    limitEvents,
    createdAtMonth,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Budget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version_data')) {
      context.handle(
        _versionDataMeta,
        versionData.isAcceptableOrUnknown(
          data['version_data']!,
          _versionDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionDataMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('limit_events')) {
      context.handle(
        _limitEventsMeta,
        limitEvents.isAcceptableOrUnknown(
          data['limit_events']!,
          _limitEventsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_limitEventsMeta);
    }
    if (data.containsKey('created_at_month')) {
      context.handle(
        _createdAtMonthMeta,
        createdAtMonth.isAcceptableOrUnknown(
          data['created_at_month']!,
          _createdAtMonthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMonthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      versionData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version_data'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      limitEvents: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}limit_events'],
      )!,
      createdAtMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at_month'],
      )!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final Uint8List versionData;
  final int lifecycle;
  final String id;
  final String? categoryId;

  /// JSON-encoded array of {effectiveFromMonth, value, kind}.
  final String limitEvents;
  final String createdAtMonth;
  const Budget({
    required this.versionData,
    required this.lifecycle,
    required this.id,
    this.categoryId,
    required this.limitEvents,
    required this.createdAtMonth,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version_data'] = Variable<Uint8List>(versionData);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['limit_events'] = Variable<String>(limitEvents);
    map['created_at_month'] = Variable<String>(createdAtMonth);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      versionData: Value(versionData),
      lifecycle: Value(lifecycle),
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      limitEvents: Value(limitEvents),
      createdAtMonth: Value(createdAtMonth),
    );
  }

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      versionData: serializer.fromJson<Uint8List>(json['versionData']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      limitEvents: serializer.fromJson<String>(json['limitEvents']),
      createdAtMonth: serializer.fromJson<String>(json['createdAtMonth']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'versionData': serializer.toJson<Uint8List>(versionData),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String?>(categoryId),
      'limitEvents': serializer.toJson<String>(limitEvents),
      'createdAtMonth': serializer.toJson<String>(createdAtMonth),
    };
  }

  Budget copyWith({
    Uint8List? versionData,
    int? lifecycle,
    String? id,
    Value<String?> categoryId = const Value.absent(),
    String? limitEvents,
    String? createdAtMonth,
  }) => Budget(
    versionData: versionData ?? this.versionData,
    lifecycle: lifecycle ?? this.lifecycle,
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    limitEvents: limitEvents ?? this.limitEvents,
    createdAtMonth: createdAtMonth ?? this.createdAtMonth,
  );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      limitEvents: data.limitEvents.present
          ? data.limitEvents.value
          : this.limitEvents,
      createdAtMonth: data.createdAtMonth.present
          ? data.createdAtMonth.value
          : this.createdAtMonth,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('limitEvents: $limitEvents, ')
          ..write('createdAtMonth: $createdAtMonth')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(versionData),
    lifecycle,
    id,
    categoryId,
    limitEvents,
    createdAtMonth,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          $driftBlobEquality.equals(other.versionData, this.versionData) &&
          other.lifecycle == this.lifecycle &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.limitEvents == this.limitEvents &&
          other.createdAtMonth == this.createdAtMonth);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<Uint8List> versionData;
  final Value<int> lifecycle;
  final Value<String> id;
  final Value<String?> categoryId;
  final Value<String> limitEvents;
  final Value<String> createdAtMonth;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.versionData = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.limitEvents = const Value.absent(),
    this.createdAtMonth = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required Uint8List versionData,
    required int lifecycle,
    required String id,
    this.categoryId = const Value.absent(),
    required String limitEvents,
    required String createdAtMonth,
    this.rowid = const Value.absent(),
  }) : versionData = Value(versionData),
       lifecycle = Value(lifecycle),
       id = Value(id),
       limitEvents = Value(limitEvents),
       createdAtMonth = Value(createdAtMonth);
  static Insertable<Budget> custom({
    Expression<Uint8List>? versionData,
    Expression<int>? lifecycle,
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? limitEvents,
    Expression<String>? createdAtMonth,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (versionData != null) 'version_data': versionData,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (limitEvents != null) 'limit_events': limitEvents,
      if (createdAtMonth != null) 'created_at_month': createdAtMonth,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<Uint8List>? versionData,
    Value<int>? lifecycle,
    Value<String>? id,
    Value<String?>? categoryId,
    Value<String>? limitEvents,
    Value<String>? createdAtMonth,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      versionData: versionData ?? this.versionData,
      lifecycle: lifecycle ?? this.lifecycle,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limitEvents: limitEvents ?? this.limitEvents,
      createdAtMonth: createdAtMonth ?? this.createdAtMonth,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(versionData.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (limitEvents.present) {
      map['limit_events'] = Variable<String>(limitEvents.value);
    }
    if (createdAtMonth.present) {
      map['created_at_month'] = Variable<String>(createdAtMonth.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('versionData: $versionData, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('limitEvents: $limitEvents, ')
          ..write('createdAtMonth: $createdAtMonth, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoreMetaTable extends StoreMeta
    with TableInfo<$StoreMetaTable, StoreMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoreMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasSeededMeta = const VerificationMeta(
    'hasSeeded',
  );
  @override
  late final GeneratedColumn<bool> hasSeeded = GeneratedColumn<bool>(
    'has_seeded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_seeded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, deviceId, hasSeeded];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'store_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoreMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('has_seeded')) {
      context.handle(
        _hasSeededMeta,
        hasSeeded.isAcceptableOrUnknown(data['has_seeded']!, _hasSeededMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoreMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoreMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      hasSeeded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_seeded'],
      )!,
    );
  }

  @override
  $StoreMetaTable createAlias(String alias) {
    return $StoreMetaTable(attachedDatabase, alias);
  }
}

class StoreMetaRow extends DataClass implements Insertable<StoreMetaRow> {
  final int id;
  final String deviceId;
  final bool hasSeeded;
  const StoreMetaRow({
    required this.id,
    required this.deviceId,
    required this.hasSeeded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['has_seeded'] = Variable<bool>(hasSeeded);
    return map;
  }

  StoreMetaCompanion toCompanion(bool nullToAbsent) {
    return StoreMetaCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      hasSeeded: Value(hasSeeded),
    );
  }

  factory StoreMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoreMetaRow(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      hasSeeded: serializer.fromJson<bool>(json['hasSeeded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'hasSeeded': serializer.toJson<bool>(hasSeeded),
    };
  }

  StoreMetaRow copyWith({int? id, String? deviceId, bool? hasSeeded}) =>
      StoreMetaRow(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        hasSeeded: hasSeeded ?? this.hasSeeded,
      );
  StoreMetaRow copyWithCompanion(StoreMetaCompanion data) {
    return StoreMetaRow(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      hasSeeded: data.hasSeeded.present ? data.hasSeeded.value : this.hasSeeded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoreMetaRow(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('hasSeeded: $hasSeeded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deviceId, hasSeeded);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoreMetaRow &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.hasSeeded == this.hasSeeded);
}

class StoreMetaCompanion extends UpdateCompanion<StoreMetaRow> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<bool> hasSeeded;
  const StoreMetaCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.hasSeeded = const Value.absent(),
  });
  StoreMetaCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    this.hasSeeded = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<StoreMetaRow> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<bool>? hasSeeded,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (hasSeeded != null) 'has_seeded': hasSeeded,
    });
  }

  StoreMetaCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
    Value<bool>? hasSeeded,
  }) {
    return StoreMetaCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      hasSeeded: hasSeeded ?? this.hasSeeded,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (hasSeeded.present) {
      map['has_seeded'] = Variable<bool>(hasSeeded.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoreMetaCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('hasSeeded: $hasSeeded')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backendSelectionMeta = const VerificationMeta(
    'backendSelection',
  );
  @override
  late final GeneratedColumn<String> backendSelection = GeneratedColumn<String>(
    'backend_selection',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrollmentPhaseMeta = const VerificationMeta(
    'enrollmentPhase',
  );
  @override
  late final GeneratedColumn<int> enrollmentPhase = GeneratedColumn<int>(
    'enrollment_phase',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _writeGateMeta = const VerificationMeta(
    'writeGate',
  );
  @override
  late final GeneratedColumn<bool> writeGate = GeneratedColumn<bool>(
    'write_gate',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("write_gate" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    backendSelection,
    enrollmentPhase,
    writeGate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('backend_selection')) {
      context.handle(
        _backendSelectionMeta,
        backendSelection.isAcceptableOrUnknown(
          data['backend_selection']!,
          _backendSelectionMeta,
        ),
      );
    }
    if (data.containsKey('enrollment_phase')) {
      context.handle(
        _enrollmentPhaseMeta,
        enrollmentPhase.isAcceptableOrUnknown(
          data['enrollment_phase']!,
          _enrollmentPhaseMeta,
        ),
      );
    }
    if (data.containsKey('write_gate')) {
      context.handle(
        _writeGateMeta,
        writeGate.isAcceptableOrUnknown(data['write_gate']!, _writeGateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      backendSelection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend_selection'],
      ),
      enrollmentPhase: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enrollment_phase'],
      ),
      writeGate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}write_gate'],
      )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataRow extends DataClass implements Insertable<SyncMetadataRow> {
  final int id;

  /// Selected backend profile and endpoint configuration. Null until
  /// enrollment, so a pre-enrollment read never infers a backend.
  final String? backendSelection;

  /// Monotonic durable enrollment phase, stored as its explicit code. Null
  /// before enrollment starts; only a reconciliation-complete phase permits
  /// the idempotent gate flip.
  final int? enrollmentPhase;

  /// Whether new sync runs may start. Defaults off so a fresh or migrated
  /// store never enables writes before enrollment.
  final bool writeGate;
  const SyncMetadataRow({
    required this.id,
    this.backendSelection,
    this.enrollmentPhase,
    required this.writeGate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || backendSelection != null) {
      map['backend_selection'] = Variable<String>(backendSelection);
    }
    if (!nullToAbsent || enrollmentPhase != null) {
      map['enrollment_phase'] = Variable<int>(enrollmentPhase);
    }
    map['write_gate'] = Variable<bool>(writeGate);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      id: Value(id),
      backendSelection: backendSelection == null && nullToAbsent
          ? const Value.absent()
          : Value(backendSelection),
      enrollmentPhase: enrollmentPhase == null && nullToAbsent
          ? const Value.absent()
          : Value(enrollmentPhase),
      writeGate: Value(writeGate),
    );
  }

  factory SyncMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataRow(
      id: serializer.fromJson<int>(json['id']),
      backendSelection: serializer.fromJson<String?>(json['backendSelection']),
      enrollmentPhase: serializer.fromJson<int?>(json['enrollmentPhase']),
      writeGate: serializer.fromJson<bool>(json['writeGate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'backendSelection': serializer.toJson<String?>(backendSelection),
      'enrollmentPhase': serializer.toJson<int?>(enrollmentPhase),
      'writeGate': serializer.toJson<bool>(writeGate),
    };
  }

  SyncMetadataRow copyWith({
    int? id,
    Value<String?> backendSelection = const Value.absent(),
    Value<int?> enrollmentPhase = const Value.absent(),
    bool? writeGate,
  }) => SyncMetadataRow(
    id: id ?? this.id,
    backendSelection: backendSelection.present
        ? backendSelection.value
        : this.backendSelection,
    enrollmentPhase: enrollmentPhase.present
        ? enrollmentPhase.value
        : this.enrollmentPhase,
    writeGate: writeGate ?? this.writeGate,
  );
  SyncMetadataRow copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      backendSelection: data.backendSelection.present
          ? data.backendSelection.value
          : this.backendSelection,
      enrollmentPhase: data.enrollmentPhase.present
          ? data.enrollmentPhase.value
          : this.enrollmentPhase,
      writeGate: data.writeGate.present ? data.writeGate.value : this.writeGate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataRow(')
          ..write('id: $id, ')
          ..write('backendSelection: $backendSelection, ')
          ..write('enrollmentPhase: $enrollmentPhase, ')
          ..write('writeGate: $writeGate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, backendSelection, enrollmentPhase, writeGate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataRow &&
          other.id == this.id &&
          other.backendSelection == this.backendSelection &&
          other.enrollmentPhase == this.enrollmentPhase &&
          other.writeGate == this.writeGate);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataRow> {
  final Value<int> id;
  final Value<String?> backendSelection;
  final Value<int?> enrollmentPhase;
  final Value<bool> writeGate;
  const SyncMetadataCompanion({
    this.id = const Value.absent(),
    this.backendSelection = const Value.absent(),
    this.enrollmentPhase = const Value.absent(),
    this.writeGate = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    this.id = const Value.absent(),
    this.backendSelection = const Value.absent(),
    this.enrollmentPhase = const Value.absent(),
    this.writeGate = const Value.absent(),
  });
  static Insertable<SyncMetadataRow> custom({
    Expression<int>? id,
    Expression<String>? backendSelection,
    Expression<int>? enrollmentPhase,
    Expression<bool>? writeGate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (backendSelection != null) 'backend_selection': backendSelection,
      if (enrollmentPhase != null) 'enrollment_phase': enrollmentPhase,
      if (writeGate != null) 'write_gate': writeGate,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<int>? id,
    Value<String?>? backendSelection,
    Value<int?>? enrollmentPhase,
    Value<bool>? writeGate,
  }) {
    return SyncMetadataCompanion(
      id: id ?? this.id,
      backendSelection: backendSelection ?? this.backendSelection,
      enrollmentPhase: enrollmentPhase ?? this.enrollmentPhase,
      writeGate: writeGate ?? this.writeGate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (backendSelection.present) {
      map['backend_selection'] = Variable<String>(backendSelection.value);
    }
    if (enrollmentPhase.present) {
      map['enrollment_phase'] = Variable<int>(enrollmentPhase.value);
    }
    if (writeGate.present) {
      map['write_gate'] = Variable<bool>(writeGate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('id: $id, ')
          ..write('backendSelection: $backendSelection, ')
          ..write('enrollmentPhase: $enrollmentPhase, ')
          ..write('writeGate: $writeGate')
          ..write(')'))
        .toString();
  }
}

class $SyncWatermarkTable extends SyncWatermark
    with TableInfo<$SyncWatermarkTable, SyncWatermarkData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncWatermarkTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [collection, cursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_watermark';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncWatermarkData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    } else if (isInserting) {
      context.missing(_cursorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection};
  @override
  SyncWatermarkData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncWatermarkData(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      )!,
    );
  }

  @override
  $SyncWatermarkTable createAlias(String alias) {
    return $SyncWatermarkTable(attachedDatabase, alias);
  }
}

class SyncWatermarkData extends DataClass
    implements Insertable<SyncWatermarkData> {
  final String collection;
  final String cursor;
  const SyncWatermarkData({required this.collection, required this.cursor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['cursor'] = Variable<String>(cursor);
    return map;
  }

  SyncWatermarkCompanion toCompanion(bool nullToAbsent) {
    return SyncWatermarkCompanion(
      collection: Value(collection),
      cursor: Value(cursor),
    );
  }

  factory SyncWatermarkData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncWatermarkData(
      collection: serializer.fromJson<String>(json['collection']),
      cursor: serializer.fromJson<String>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'cursor': serializer.toJson<String>(cursor),
    };
  }

  SyncWatermarkData copyWith({String? collection, String? cursor}) =>
      SyncWatermarkData(
        collection: collection ?? this.collection,
        cursor: cursor ?? this.cursor,
      );
  SyncWatermarkData copyWithCompanion(SyncWatermarkCompanion data) {
    return SyncWatermarkData(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncWatermarkData(')
          ..write('collection: $collection, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncWatermarkData &&
          other.collection == this.collection &&
          other.cursor == this.cursor);
}

class SyncWatermarkCompanion extends UpdateCompanion<SyncWatermarkData> {
  final Value<String> collection;
  final Value<String> cursor;
  final Value<int> rowid;
  const SyncWatermarkCompanion({
    this.collection = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncWatermarkCompanion.insert({
    required String collection,
    required String cursor,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       cursor = Value(cursor);
  static Insertable<SyncWatermarkData> custom({
    Expression<String>? collection,
    Expression<String>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncWatermarkCompanion copyWith({
    Value<String>? collection,
    Value<String>? cursor,
    Value<int>? rowid,
  }) {
    return SyncWatermarkCompanion(
      collection: collection ?? this.collection,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncWatermarkCompanion(')
          ..write('collection: $collection, ')
          ..write('cursor: $cursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncAcknowledgedVectorTable extends SyncAcknowledgedVector
    with TableInfo<$SyncAcknowledgedVectorTable, SyncAcknowledgedVectorData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncAcknowledgedVectorTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIDMeta = const VerificationMeta('rowID');
  @override
  late final GeneratedColumn<String> rowID = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionDataMeta = const VerificationMeta(
    'versionData',
  );
  @override
  late final GeneratedColumn<Uint8List> versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [collection, rowID, versionData];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_acknowledged_vector';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncAcknowledgedVectorData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIDMeta,
        rowID.isAcceptableOrUnknown(data['row_id']!, _rowIDMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIDMeta);
    }
    if (data.containsKey('version_data')) {
      context.handle(
        _versionDataMeta,
        versionData.isAcceptableOrUnknown(
          data['version_data']!,
          _versionDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionDataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, rowID};
  @override
  SyncAcknowledgedVectorData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncAcknowledgedVectorData(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      rowID: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      versionData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version_data'],
      )!,
    );
  }

  @override
  $SyncAcknowledgedVectorTable createAlias(String alias) {
    return $SyncAcknowledgedVectorTable(attachedDatabase, alias);
  }
}

class SyncAcknowledgedVectorData extends DataClass
    implements Insertable<SyncAcknowledgedVectorData> {
  final String collection;
  final String rowID;
  final Uint8List versionData;
  const SyncAcknowledgedVectorData({
    required this.collection,
    required this.rowID,
    required this.versionData,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['row_id'] = Variable<String>(rowID);
    map['version_data'] = Variable<Uint8List>(versionData);
    return map;
  }

  SyncAcknowledgedVectorCompanion toCompanion(bool nullToAbsent) {
    return SyncAcknowledgedVectorCompanion(
      collection: Value(collection),
      rowID: Value(rowID),
      versionData: Value(versionData),
    );
  }

  factory SyncAcknowledgedVectorData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncAcknowledgedVectorData(
      collection: serializer.fromJson<String>(json['collection']),
      rowID: serializer.fromJson<String>(json['rowID']),
      versionData: serializer.fromJson<Uint8List>(json['versionData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'rowID': serializer.toJson<String>(rowID),
      'versionData': serializer.toJson<Uint8List>(versionData),
    };
  }

  SyncAcknowledgedVectorData copyWith({
    String? collection,
    String? rowID,
    Uint8List? versionData,
  }) => SyncAcknowledgedVectorData(
    collection: collection ?? this.collection,
    rowID: rowID ?? this.rowID,
    versionData: versionData ?? this.versionData,
  );
  SyncAcknowledgedVectorData copyWithCompanion(
    SyncAcknowledgedVectorCompanion data,
  ) {
    return SyncAcknowledgedVectorData(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      rowID: data.rowID.present ? data.rowID.value : this.rowID,
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncAcknowledgedVectorData(')
          ..write('collection: $collection, ')
          ..write('rowID: $rowID, ')
          ..write('versionData: $versionData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(collection, rowID, $driftBlobEquality.hash(versionData));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncAcknowledgedVectorData &&
          other.collection == this.collection &&
          other.rowID == this.rowID &&
          $driftBlobEquality.equals(other.versionData, this.versionData));
}

class SyncAcknowledgedVectorCompanion
    extends UpdateCompanion<SyncAcknowledgedVectorData> {
  final Value<String> collection;
  final Value<String> rowID;
  final Value<Uint8List> versionData;
  final Value<int> rowid;
  const SyncAcknowledgedVectorCompanion({
    this.collection = const Value.absent(),
    this.rowID = const Value.absent(),
    this.versionData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncAcknowledgedVectorCompanion.insert({
    required String collection,
    required String rowID,
    required Uint8List versionData,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       rowID = Value(rowID),
       versionData = Value(versionData);
  static Insertable<SyncAcknowledgedVectorData> custom({
    Expression<String>? collection,
    Expression<String>? rowID,
    Expression<Uint8List>? versionData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (rowID != null) 'row_id': rowID,
      if (versionData != null) 'version_data': versionData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncAcknowledgedVectorCompanion copyWith({
    Value<String>? collection,
    Value<String>? rowID,
    Value<Uint8List>? versionData,
    Value<int>? rowid,
  }) {
    return SyncAcknowledgedVectorCompanion(
      collection: collection ?? this.collection,
      rowID: rowID ?? this.rowID,
      versionData: versionData ?? this.versionData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (rowID.present) {
      map['row_id'] = Variable<String>(rowID.value);
    }
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(versionData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncAcknowledgedVectorCompanion(')
          ..write('collection: $collection, ')
          ..write('rowID: $rowID, ')
          ..write('versionData: $versionData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncPendingAckTable extends SyncPendingAck
    with TableInfo<$SyncPendingAckTable, SyncPendingAckData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncPendingAckTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkpointMeta = const VerificationMeta(
    'checkpoint',
  );
  @override
  late final GeneratedColumn<String> checkpoint = GeneratedColumn<String>(
    'checkpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [collection, checkpoint];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_pending_ack';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncPendingAckData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('checkpoint')) {
      context.handle(
        _checkpointMeta,
        checkpoint.isAcceptableOrUnknown(data['checkpoint']!, _checkpointMeta),
      );
    } else if (isInserting) {
      context.missing(_checkpointMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, checkpoint};
  @override
  SyncPendingAckData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncPendingAckData(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      checkpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint'],
      )!,
    );
  }

  @override
  $SyncPendingAckTable createAlias(String alias) {
    return $SyncPendingAckTable(attachedDatabase, alias);
  }
}

class SyncPendingAckData extends DataClass
    implements Insertable<SyncPendingAckData> {
  final String collection;
  final String checkpoint;
  const SyncPendingAckData({
    required this.collection,
    required this.checkpoint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['checkpoint'] = Variable<String>(checkpoint);
    return map;
  }

  SyncPendingAckCompanion toCompanion(bool nullToAbsent) {
    return SyncPendingAckCompanion(
      collection: Value(collection),
      checkpoint: Value(checkpoint),
    );
  }

  factory SyncPendingAckData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncPendingAckData(
      collection: serializer.fromJson<String>(json['collection']),
      checkpoint: serializer.fromJson<String>(json['checkpoint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'checkpoint': serializer.toJson<String>(checkpoint),
    };
  }

  SyncPendingAckData copyWith({String? collection, String? checkpoint}) =>
      SyncPendingAckData(
        collection: collection ?? this.collection,
        checkpoint: checkpoint ?? this.checkpoint,
      );
  SyncPendingAckData copyWithCompanion(SyncPendingAckCompanion data) {
    return SyncPendingAckData(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      checkpoint: data.checkpoint.present
          ? data.checkpoint.value
          : this.checkpoint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncPendingAckData(')
          ..write('collection: $collection, ')
          ..write('checkpoint: $checkpoint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, checkpoint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncPendingAckData &&
          other.collection == this.collection &&
          other.checkpoint == this.checkpoint);
}

class SyncPendingAckCompanion extends UpdateCompanion<SyncPendingAckData> {
  final Value<String> collection;
  final Value<String> checkpoint;
  final Value<int> rowid;
  const SyncPendingAckCompanion({
    this.collection = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncPendingAckCompanion.insert({
    required String collection,
    required String checkpoint,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       checkpoint = Value(checkpoint);
  static Insertable<SyncPendingAckData> custom({
    Expression<String>? collection,
    Expression<String>? checkpoint,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (checkpoint != null) 'checkpoint': checkpoint,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncPendingAckCompanion copyWith({
    Value<String>? collection,
    Value<String>? checkpoint,
    Value<int>? rowid,
  }) {
    return SyncPendingAckCompanion(
      collection: collection ?? this.collection,
      checkpoint: checkpoint ?? this.checkpoint,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (checkpoint.present) {
      map['checkpoint'] = Variable<String>(checkpoint.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncPendingAckCompanion(')
          ..write('collection: $collection, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStagingGroupTable extends SyncStagingGroup
    with TableInfo<$SyncStagingGroupTable, SyncStagingGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStagingGroupTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIDMeta = const VerificationMeta('rowID');
  @override
  late final GeneratedColumn<String> rowID = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siblingsMeta = const VerificationMeta(
    'siblings',
  );
  @override
  late final GeneratedColumn<Uint8List> siblings = GeneratedColumn<Uint8List>(
    'sibling_data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sequence, collection, rowID, siblings];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_staging_group';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStagingGroupData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIDMeta,
        rowID.isAcceptableOrUnknown(data['row_id']!, _rowIDMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIDMeta);
    }
    if (data.containsKey('sibling_data')) {
      context.handle(
        _siblingsMeta,
        siblings.isAcceptableOrUnknown(data['sibling_data']!, _siblingsMeta),
      );
    } else if (isInserting) {
      context.missing(_siblingsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sequence};
  @override
  SyncStagingGroupData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStagingGroupData(
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      rowID: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      siblings: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}sibling_data'],
      )!,
    );
  }

  @override
  $SyncStagingGroupTable createAlias(String alias) {
    return $SyncStagingGroupTable(attachedDatabase, alias);
  }
}

class SyncStagingGroupData extends DataClass
    implements Insertable<SyncStagingGroupData> {
  /// Insertion order: oldest-first ordering reads this column ascending.
  final int sequence;
  final String collection;
  final String rowID;

  /// JSON-serialized, decrypted staged siblings for this group.
  final Uint8List siblings;
  const SyncStagingGroupData({
    required this.sequence,
    required this.collection,
    required this.rowID,
    required this.siblings,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sequence'] = Variable<int>(sequence);
    map['collection'] = Variable<String>(collection);
    map['row_id'] = Variable<String>(rowID);
    map['sibling_data'] = Variable<Uint8List>(siblings);
    return map;
  }

  SyncStagingGroupCompanion toCompanion(bool nullToAbsent) {
    return SyncStagingGroupCompanion(
      sequence: Value(sequence),
      collection: Value(collection),
      rowID: Value(rowID),
      siblings: Value(siblings),
    );
  }

  factory SyncStagingGroupData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStagingGroupData(
      sequence: serializer.fromJson<int>(json['sequence']),
      collection: serializer.fromJson<String>(json['collection']),
      rowID: serializer.fromJson<String>(json['rowID']),
      siblings: serializer.fromJson<Uint8List>(json['siblings']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sequence': serializer.toJson<int>(sequence),
      'collection': serializer.toJson<String>(collection),
      'rowID': serializer.toJson<String>(rowID),
      'siblings': serializer.toJson<Uint8List>(siblings),
    };
  }

  SyncStagingGroupData copyWith({
    int? sequence,
    String? collection,
    String? rowID,
    Uint8List? siblings,
  }) => SyncStagingGroupData(
    sequence: sequence ?? this.sequence,
    collection: collection ?? this.collection,
    rowID: rowID ?? this.rowID,
    siblings: siblings ?? this.siblings,
  );
  SyncStagingGroupData copyWithCompanion(SyncStagingGroupCompanion data) {
    return SyncStagingGroupData(
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      rowID: data.rowID.present ? data.rowID.value : this.rowID,
      siblings: data.siblings.present ? data.siblings.value : this.siblings,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStagingGroupData(')
          ..write('sequence: $sequence, ')
          ..write('collection: $collection, ')
          ..write('rowID: $rowID, ')
          ..write('siblings: $siblings')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sequence,
    collection,
    rowID,
    $driftBlobEquality.hash(siblings),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStagingGroupData &&
          other.sequence == this.sequence &&
          other.collection == this.collection &&
          other.rowID == this.rowID &&
          $driftBlobEquality.equals(other.siblings, this.siblings));
}

class SyncStagingGroupCompanion extends UpdateCompanion<SyncStagingGroupData> {
  final Value<int> sequence;
  final Value<String> collection;
  final Value<String> rowID;
  final Value<Uint8List> siblings;
  const SyncStagingGroupCompanion({
    this.sequence = const Value.absent(),
    this.collection = const Value.absent(),
    this.rowID = const Value.absent(),
    this.siblings = const Value.absent(),
  });
  SyncStagingGroupCompanion.insert({
    this.sequence = const Value.absent(),
    required String collection,
    required String rowID,
    required Uint8List siblings,
  }) : collection = Value(collection),
       rowID = Value(rowID),
       siblings = Value(siblings);
  static Insertable<SyncStagingGroupData> custom({
    Expression<int>? sequence,
    Expression<String>? collection,
    Expression<String>? rowID,
    Expression<Uint8List>? siblings,
  }) {
    return RawValuesInsertable({
      if (sequence != null) 'sequence': sequence,
      if (collection != null) 'collection': collection,
      if (rowID != null) 'row_id': rowID,
      if (siblings != null) 'sibling_data': siblings,
    });
  }

  SyncStagingGroupCompanion copyWith({
    Value<int>? sequence,
    Value<String>? collection,
    Value<String>? rowID,
    Value<Uint8List>? siblings,
  }) {
    return SyncStagingGroupCompanion(
      sequence: sequence ?? this.sequence,
      collection: collection ?? this.collection,
      rowID: rowID ?? this.rowID,
      siblings: siblings ?? this.siblings,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (rowID.present) {
      map['row_id'] = Variable<String>(rowID.value);
    }
    if (siblings.present) {
      map['sibling_data'] = Variable<Uint8List>(siblings.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStagingGroupCompanion(')
          ..write('sequence: $sequence, ')
          ..write('collection: $collection, ')
          ..write('rowID: $rowID, ')
          ..write('siblings: $siblings')
          ..write(')'))
        .toString();
  }
}

abstract class _$LedgerDatabase extends GeneratedDatabase {
  _$LedgerDatabase(QueryExecutor e) : super(e);
  $LedgerDatabaseManager get managers => $LedgerDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $SubPocketsTable subPockets = $SubPocketsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $PlansTable plans = $PlansTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $StoreMetaTable storeMeta = $StoreMetaTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  late final $SyncWatermarkTable syncWatermark = $SyncWatermarkTable(this);
  late final $SyncAcknowledgedVectorTable syncAcknowledgedVector =
      $SyncAcknowledgedVectorTable(this);
  late final $SyncPendingAckTable syncPendingAck = $SyncPendingAckTable(this);
  late final $SyncStagingGroupTable syncStagingGroup = $SyncStagingGroupTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    subPockets,
    categories,
    entries,
    plans,
    budgets,
    storeMeta,
    syncMetadata,
    syncWatermark,
    syncAcknowledgedVector,
    syncPendingAck,
    syncStagingGroup,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required Uint8List versionData,
  required int lifecycle,
  required String id,
  required String name,
  required int type,
  required String subPocketIds,
  required bool incomingTransfersAsExpenses,
  required bool includeInNetWorth,
  Value<int?> statementDay,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<Uint8List> versionData,
  Value<int> lifecycle,
  Value<String> id,
  Value<String> name,
  Value<int> type,
  Value<String> subPocketIds,
  Value<bool> incomingTransfersAsExpenses,
  Value<bool> includeInNetWorth,
  Value<int?> statementDay,
  Value<int> rowid,
});

class $$AccountsTableFilterComposer
    extends Composer<_$LedgerDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subPocketIds => $composableBuilder(
    column: $table.subPocketIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get incomingTransfersAsExpenses => $composableBuilder(
    column: $table.incomingTransfersAsExpenses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subPocketIds => $composableBuilder(
    column: $table.subPocketIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get incomingTransfersAsExpenses => $composableBuilder(
    column: $table.incomingTransfersAsExpenses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get subPocketIds => $composableBuilder(
    column: $table.subPocketIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get incomingTransfersAsExpenses => $composableBuilder(
    column: $table.incomingTransfersAsExpenses,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => column,
  );
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, BaseReferences<_$LedgerDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$LedgerDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> versionData = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String> subPocketIds = const Value.absent(),
                Value<bool> incomingTransfersAsExpenses = const Value.absent(),
                Value<bool> includeInNetWorth = const Value.absent(),
                Value<int?> statementDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                name: name,
                type: type,
                subPocketIds: subPocketIds,
                incomingTransfersAsExpenses: incomingTransfersAsExpenses,
                includeInNetWorth: includeInNetWorth,
                statementDay: statementDay,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List versionData,
                required int lifecycle,
                required String id,
                required String name,
                required int type,
                required String subPocketIds,
                required bool incomingTransfersAsExpenses,
                required bool includeInNetWorth,
                Value<int?> statementDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                name: name,
                type: type,
                subPocketIds: subPocketIds,
                incomingTransfersAsExpenses: incomingTransfersAsExpenses,
                includeInNetWorth: includeInNetWorth,
                statementDay: statementDay,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  BaseReferences<_$LedgerDatabase, $AccountsTable, Account>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, BaseReferences<_$LedgerDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $$SubPocketsTableCreateCompanionBuilder = SubPocketsCompanion Function({
  required Uint8List versionData,
  required int lifecycle,
  required String id,
  required String name,
  required bool incomingTransfersAsExpenses,
  Value<int> rowid,
});
typedef $$SubPocketsTableUpdateCompanionBuilder = SubPocketsCompanion Function({
  Value<Uint8List> versionData,
  Value<int> lifecycle,
  Value<String> id,
  Value<String> name,
  Value<bool> incomingTransfersAsExpenses,
  Value<int> rowid,
});

class $$SubPocketsTableFilterComposer
    extends Composer<_$LedgerDatabase, $SubPocketsTable> {
  $$SubPocketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get incomingTransfersAsExpenses => $composableBuilder(
    column: $table.incomingTransfersAsExpenses,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubPocketsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SubPocketsTable> {
  $$SubPocketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get incomingTransfersAsExpenses => $composableBuilder(
    column: $table.incomingTransfersAsExpenses,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubPocketsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SubPocketsTable> {
  $$SubPocketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get incomingTransfersAsExpenses => $composableBuilder(
    column: $table.incomingTransfersAsExpenses,
    builder: (column) => column,
  );
}

class $$SubPocketsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SubPocketsTable,
          SubPocket,
          $$SubPocketsTableFilterComposer,
          $$SubPocketsTableOrderingComposer,
          $$SubPocketsTableAnnotationComposer,
          $$SubPocketsTableCreateCompanionBuilder,
          $$SubPocketsTableUpdateCompanionBuilder,
          (
            SubPocket,
            BaseReferences<_$LedgerDatabase, $SubPocketsTable, SubPocket>,
          ),
          SubPocket,
          PrefetchHooks Function()
        > {
  $$SubPocketsTableTableManager(_$LedgerDatabase db, $SubPocketsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubPocketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubPocketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubPocketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> versionData = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> incomingTransfersAsExpenses = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubPocketsCompanion(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                name: name,
                incomingTransfersAsExpenses: incomingTransfersAsExpenses,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List versionData,
                required int lifecycle,
                required String id,
                required String name,
                required bool incomingTransfersAsExpenses,
                Value<int> rowid = const Value.absent(),
              }) => SubPocketsCompanion.insert(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                name: name,
                incomingTransfersAsExpenses: incomingTransfersAsExpenses,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubPocketsTable, SubPocket>(table),
                  BaseReferences<_$LedgerDatabase, $SubPocketsTable, SubPocket>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubPocketsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SubPocketsTable,
      SubPocket,
      $$SubPocketsTableFilterComposer,
      $$SubPocketsTableOrderingComposer,
      $$SubPocketsTableAnnotationComposer,
      $$SubPocketsTableCreateCompanionBuilder,
      $$SubPocketsTableUpdateCompanionBuilder,
      (
        SubPocket,
        BaseReferences<_$LedgerDatabase, $SubPocketsTable, SubPocket>,
      ),
      SubPocket,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required Uint8List versionData,
  required int lifecycle,
  required String id,
  required String name,
  required int kind,
  required String colorHex,
  required bool includeInAnalysis,
  Value<String?> parentId,
  required String symbol,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<Uint8List> versionData,
  Value<int> lifecycle,
  Value<String> id,
  Value<String> name,
  Value<int> kind,
  Value<String> colorHex,
  Value<bool> includeInAnalysis,
  Value<String?> parentId,
  Value<String> symbol,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$LedgerDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInAnalysis => $composableBuilder(
    column: $table.includeInAnalysis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$LedgerDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInAnalysis => $composableBuilder(
    column: $table.includeInAnalysis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get includeInAnalysis => $composableBuilder(
    column: $table.includeInAnalysis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            Category,
            BaseReferences<_$LedgerDatabase, $CategoriesTable, Category>,
          ),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$LedgerDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> versionData = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<bool> includeInAnalysis = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                name: name,
                kind: kind,
                colorHex: colorHex,
                includeInAnalysis: includeInAnalysis,
                parentId: parentId,
                symbol: symbol,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List versionData,
                required int lifecycle,
                required String id,
                required String name,
                required int kind,
                required String colorHex,
                required bool includeInAnalysis,
                Value<String?> parentId = const Value.absent(),
                required String symbol,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                name: name,
                kind: kind,
                colorHex: colorHex,
                includeInAnalysis: includeInAnalysis,
                parentId: parentId,
                symbol: symbol,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  BaseReferences<_$LedgerDatabase, $CategoriesTable, Category>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$LedgerDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  required Uint8List versionData,
  required int lifecycle,
  required String id,
  required int date,
  required String amount,
  required String name,
  Value<String?> categoryId,
  required String sourceId,
  Value<String?> destinationId,
  required bool includeInAnalysis,
  Value<String?> note,
  Value<int?> systemKind,
  Value<int> rowid,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<Uint8List> versionData,
  Value<int> lifecycle,
  Value<String> id,
  Value<int> date,
  Value<String> amount,
  Value<String> name,
  Value<String?> categoryId,
  Value<String> sourceId,
  Value<String?> destinationId,
  Value<bool> includeInAnalysis,
  Value<String?> note,
  Value<int?> systemKind,
  Value<int> rowid,
});

class $$EntriesTableFilterComposer
    extends Composer<_$LedgerDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInAnalysis => $composableBuilder(
    column: $table.includeInAnalysis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get systemKind => $composableBuilder(
    column: $table.systemKind,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$LedgerDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInAnalysis => $composableBuilder(
    column: $table.includeInAnalysis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get systemKind => $composableBuilder(
    column: $table.systemKind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeInAnalysis => $composableBuilder(
    column: $table.includeInAnalysis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get systemKind => $composableBuilder(
    column: $table.systemKind,
    builder: (column) => column,
  );
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, BaseReferences<_$LedgerDatabase, $EntriesTable, Entry>),
          Entry,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$LedgerDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> versionData = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<String> amount = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> destinationId = const Value.absent(),
                Value<bool> includeInAnalysis = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> systemKind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                date: date,
                amount: amount,
                name: name,
                categoryId: categoryId,
                sourceId: sourceId,
                destinationId: destinationId,
                includeInAnalysis: includeInAnalysis,
                note: note,
                systemKind: systemKind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List versionData,
                required int lifecycle,
                required String id,
                required int date,
                required String amount,
                required String name,
                Value<String?> categoryId = const Value.absent(),
                required String sourceId,
                Value<String?> destinationId = const Value.absent(),
                required bool includeInAnalysis,
                Value<String?> note = const Value.absent(),
                Value<int?> systemKind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                date: date,
                amount: amount,
                name: name,
                categoryId: categoryId,
                sourceId: sourceId,
                destinationId: destinationId,
                includeInAnalysis: includeInAnalysis,
                note: note,
                systemKind: systemKind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, Entry>(table),
                  BaseReferences<_$LedgerDatabase, $EntriesTable, Entry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, BaseReferences<_$LedgerDatabase, $EntriesTable, Entry>),
      Entry,
      PrefetchHooks Function()
    >;
typedef $$PlansTableCreateCompanionBuilder = PlansCompanion Function({
  required Uint8List versionData,
  required int lifecycle,
  required String id,
  required int frequency,
  required int anchor,
  Value<int?> endDate,
  required int lastResolvedDate,
  required String templateAmount,
  required String templateName,
  Value<String?> templateCategoryId,
  required String templateSourceId,
  Value<String?> templateDestinationId,
  required bool templateIncludeInAnalysis,
  Value<int> rowid,
});
typedef $$PlansTableUpdateCompanionBuilder = PlansCompanion Function({
  Value<Uint8List> versionData,
  Value<int> lifecycle,
  Value<String> id,
  Value<int> frequency,
  Value<int> anchor,
  Value<int?> endDate,
  Value<int> lastResolvedDate,
  Value<String> templateAmount,
  Value<String> templateName,
  Value<String?> templateCategoryId,
  Value<String> templateSourceId,
  Value<String?> templateDestinationId,
  Value<bool> templateIncludeInAnalysis,
  Value<int> rowid,
});

class $$PlansTableFilterComposer
    extends Composer<_$LedgerDatabase, $PlansTable> {
  $$PlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastResolvedDate => $composableBuilder(
    column: $table.lastResolvedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateAmount => $composableBuilder(
    column: $table.templateAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateName => $composableBuilder(
    column: $table.templateName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateCategoryId => $composableBuilder(
    column: $table.templateCategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateSourceId => $composableBuilder(
    column: $table.templateSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateDestinationId => $composableBuilder(
    column: $table.templateDestinationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get templateIncludeInAnalysis => $composableBuilder(
    column: $table.templateIncludeInAnalysis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlansTableOrderingComposer
    extends Composer<_$LedgerDatabase, $PlansTable> {
  $$PlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastResolvedDate => $composableBuilder(
    column: $table.lastResolvedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateAmount => $composableBuilder(
    column: $table.templateAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateName => $composableBuilder(
    column: $table.templateName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateCategoryId => $composableBuilder(
    column: $table.templateCategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateSourceId => $composableBuilder(
    column: $table.templateSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateDestinationId => $composableBuilder(
    column: $table.templateDestinationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get templateIncludeInAnalysis => $composableBuilder(
    column: $table.templateIncludeInAnalysis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlansTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $PlansTable> {
  $$PlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get anchor =>
      $composableBuilder(column: $table.anchor, builder: (column) => column);

  GeneratedColumn<int> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get lastResolvedDate => $composableBuilder(
    column: $table.lastResolvedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateAmount => $composableBuilder(
    column: $table.templateAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateName => $composableBuilder(
    column: $table.templateName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateCategoryId => $composableBuilder(
    column: $table.templateCategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateSourceId => $composableBuilder(
    column: $table.templateSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateDestinationId => $composableBuilder(
    column: $table.templateDestinationId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get templateIncludeInAnalysis => $composableBuilder(
    column: $table.templateIncludeInAnalysis,
    builder: (column) => column,
  );
}

class $$PlansTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $PlansTable,
          Plan,
          $$PlansTableFilterComposer,
          $$PlansTableOrderingComposer,
          $$PlansTableAnnotationComposer,
          $$PlansTableCreateCompanionBuilder,
          $$PlansTableUpdateCompanionBuilder,
          (Plan, BaseReferences<_$LedgerDatabase, $PlansTable, Plan>),
          Plan,
          PrefetchHooks Function()
        > {
  $$PlansTableTableManager(_$LedgerDatabase db, $PlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> versionData = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> frequency = const Value.absent(),
                Value<int> anchor = const Value.absent(),
                Value<int?> endDate = const Value.absent(),
                Value<int> lastResolvedDate = const Value.absent(),
                Value<String> templateAmount = const Value.absent(),
                Value<String> templateName = const Value.absent(),
                Value<String?> templateCategoryId = const Value.absent(),
                Value<String> templateSourceId = const Value.absent(),
                Value<String?> templateDestinationId = const Value.absent(),
                Value<bool> templateIncludeInAnalysis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                frequency: frequency,
                anchor: anchor,
                endDate: endDate,
                lastResolvedDate: lastResolvedDate,
                templateAmount: templateAmount,
                templateName: templateName,
                templateCategoryId: templateCategoryId,
                templateSourceId: templateSourceId,
                templateDestinationId: templateDestinationId,
                templateIncludeInAnalysis: templateIncludeInAnalysis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List versionData,
                required int lifecycle,
                required String id,
                required int frequency,
                required int anchor,
                Value<int?> endDate = const Value.absent(),
                required int lastResolvedDate,
                required String templateAmount,
                required String templateName,
                Value<String?> templateCategoryId = const Value.absent(),
                required String templateSourceId,
                Value<String?> templateDestinationId = const Value.absent(),
                required bool templateIncludeInAnalysis,
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion.insert(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                frequency: frequency,
                anchor: anchor,
                endDate: endDate,
                lastResolvedDate: lastResolvedDate,
                templateAmount: templateAmount,
                templateName: templateName,
                templateCategoryId: templateCategoryId,
                templateSourceId: templateSourceId,
                templateDestinationId: templateDestinationId,
                templateIncludeInAnalysis: templateIncludeInAnalysis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlansTable, Plan>(table),
                  BaseReferences<_$LedgerDatabase, $PlansTable, Plan>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlansTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $PlansTable,
      Plan,
      $$PlansTableFilterComposer,
      $$PlansTableOrderingComposer,
      $$PlansTableAnnotationComposer,
      $$PlansTableCreateCompanionBuilder,
      $$PlansTableUpdateCompanionBuilder,
      (Plan, BaseReferences<_$LedgerDatabase, $PlansTable, Plan>),
      Plan,
      PrefetchHooks Function()
    >;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  required Uint8List versionData,
  required int lifecycle,
  required String id,
  Value<String?> categoryId,
  required String limitEvents,
  required String createdAtMonth,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<Uint8List> versionData,
  Value<int> lifecycle,
  Value<String> id,
  Value<String?> categoryId,
  Value<String> limitEvents,
  Value<String> createdAtMonth,
  Value<int> rowid,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$LedgerDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get limitEvents => $composableBuilder(
    column: $table.limitEvents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAtMonth => $composableBuilder(
    column: $table.createdAtMonth,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get limitEvents => $composableBuilder(
    column: $table.limitEvents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAtMonth => $composableBuilder(
    column: $table.createdAtMonth,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get limitEvents => $composableBuilder(
    column: $table.limitEvents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAtMonth => $composableBuilder(
    column: $table.createdAtMonth,
    builder: (column) => column,
  );
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $BudgetsTable,
          Budget,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (Budget, BaseReferences<_$LedgerDatabase, $BudgetsTable, Budget>),
          Budget,
          PrefetchHooks Function()
        > {
  $$BudgetsTableTableManager(_$LedgerDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> versionData = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> limitEvents = const Value.absent(),
                Value<String> createdAtMonth = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                categoryId: categoryId,
                limitEvents: limitEvents,
                createdAtMonth: createdAtMonth,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List versionData,
                required int lifecycle,
                required String id,
                Value<String?> categoryId = const Value.absent(),
                required String limitEvents,
                required String createdAtMonth,
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                versionData: versionData,
                lifecycle: lifecycle,
                id: id,
                categoryId: categoryId,
                limitEvents: limitEvents,
                createdAtMonth: createdAtMonth,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetsTable, Budget>(table),
                  BaseReferences<_$LedgerDatabase, $BudgetsTable, Budget>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $BudgetsTable,
      Budget,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (Budget, BaseReferences<_$LedgerDatabase, $BudgetsTable, Budget>),
      Budget,
      PrefetchHooks Function()
    >;
typedef $$StoreMetaTableCreateCompanionBuilder = StoreMetaCompanion Function({
  Value<int> id,
  required String deviceId,
  Value<bool> hasSeeded,
});
typedef $$StoreMetaTableUpdateCompanionBuilder = StoreMetaCompanion Function({
  Value<int> id,
  Value<String> deviceId,
  Value<bool> hasSeeded,
});

class $$StoreMetaTableFilterComposer
    extends Composer<_$LedgerDatabase, $StoreMetaTable> {
  $$StoreMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSeeded => $composableBuilder(
    column: $table.hasSeeded,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoreMetaTableOrderingComposer
    extends Composer<_$LedgerDatabase, $StoreMetaTable> {
  $$StoreMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSeeded => $composableBuilder(
    column: $table.hasSeeded,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoreMetaTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $StoreMetaTable> {
  $$StoreMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get hasSeeded =>
      $composableBuilder(column: $table.hasSeeded, builder: (column) => column);
}

class $$StoreMetaTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $StoreMetaTable,
          StoreMetaRow,
          $$StoreMetaTableFilterComposer,
          $$StoreMetaTableOrderingComposer,
          $$StoreMetaTableAnnotationComposer,
          $$StoreMetaTableCreateCompanionBuilder,
          $$StoreMetaTableUpdateCompanionBuilder,
          (
            StoreMetaRow,
            BaseReferences<_$LedgerDatabase, $StoreMetaTable, StoreMetaRow>,
          ),
          StoreMetaRow,
          PrefetchHooks Function()
        > {
  $$StoreMetaTableTableManager(_$LedgerDatabase db, $StoreMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoreMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoreMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoreMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<bool> hasSeeded = const Value.absent(),
              }) => StoreMetaCompanion(
                id: id,
                deviceId: deviceId,
                hasSeeded: hasSeeded,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceId,
                Value<bool> hasSeeded = const Value.absent(),
              }) => StoreMetaCompanion.insert(
                id: id,
                deviceId: deviceId,
                hasSeeded: hasSeeded,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StoreMetaTable, StoreMetaRow>(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $StoreMetaTable,
                    StoreMetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoreMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $StoreMetaTable,
      StoreMetaRow,
      $$StoreMetaTableFilterComposer,
      $$StoreMetaTableOrderingComposer,
      $$StoreMetaTableAnnotationComposer,
      $$StoreMetaTableCreateCompanionBuilder,
      $$StoreMetaTableUpdateCompanionBuilder,
      (
        StoreMetaRow,
        BaseReferences<_$LedgerDatabase, $StoreMetaTable, StoreMetaRow>,
      ),
      StoreMetaRow,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<int> id,
      Value<String?> backendSelection,
      Value<int?> enrollmentPhase,
      Value<bool> writeGate,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<int> id,
      Value<String?> backendSelection,
      Value<int?> enrollmentPhase,
      Value<bool> writeGate,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backendSelection => $composableBuilder(
    column: $table.backendSelection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enrollmentPhase => $composableBuilder(
    column: $table.enrollmentPhase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get writeGate => $composableBuilder(
    column: $table.writeGate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backendSelection => $composableBuilder(
    column: $table.backendSelection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enrollmentPhase => $composableBuilder(
    column: $table.enrollmentPhase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get writeGate => $composableBuilder(
    column: $table.writeGate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get backendSelection => $composableBuilder(
    column: $table.backendSelection,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enrollmentPhase => $composableBuilder(
    column: $table.enrollmentPhase,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get writeGate =>
      $composableBuilder(column: $table.writeGate, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncMetadataTable,
          SyncMetadataRow,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataRow,
            BaseReferences<
              _$LedgerDatabase,
              $SyncMetadataTable,
              SyncMetadataRow
            >,
          ),
          SyncMetadataRow,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$LedgerDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> backendSelection = const Value.absent(),
                Value<int?> enrollmentPhase = const Value.absent(),
                Value<bool> writeGate = const Value.absent(),
              }) => SyncMetadataCompanion(
                id: id,
                backendSelection: backendSelection,
                enrollmentPhase: enrollmentPhase,
                writeGate: writeGate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> backendSelection = const Value.absent(),
                Value<int?> enrollmentPhase = const Value.absent(),
                Value<bool> writeGate = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                id: id,
                backendSelection: backendSelection,
                enrollmentPhase: enrollmentPhase,
                writeGate: writeGate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetadataTable, SyncMetadataRow>(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncMetadataTable,
                    SyncMetadataRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncMetadataTable,
      SyncMetadataRow,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataRow,
        BaseReferences<_$LedgerDatabase, $SyncMetadataTable, SyncMetadataRow>,
      ),
      SyncMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$SyncWatermarkTableCreateCompanionBuilder =
    SyncWatermarkCompanion Function({
      required String collection,
      required String cursor,
      Value<int> rowid,
    });
typedef $$SyncWatermarkTableUpdateCompanionBuilder =
    SyncWatermarkCompanion Function({
      Value<String> collection,
      Value<String> cursor,
      Value<int> rowid,
    });

class $$SyncWatermarkTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncWatermarkTable> {
  $$SyncWatermarkTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncWatermarkTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncWatermarkTable> {
  $$SyncWatermarkTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncWatermarkTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncWatermarkTable> {
  $$SyncWatermarkTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $$SyncWatermarkTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncWatermarkTable,
          SyncWatermarkData,
          $$SyncWatermarkTableFilterComposer,
          $$SyncWatermarkTableOrderingComposer,
          $$SyncWatermarkTableAnnotationComposer,
          $$SyncWatermarkTableCreateCompanionBuilder,
          $$SyncWatermarkTableUpdateCompanionBuilder,
          (
            SyncWatermarkData,
            BaseReferences<
              _$LedgerDatabase,
              $SyncWatermarkTable,
              SyncWatermarkData
            >,
          ),
          SyncWatermarkData,
          PrefetchHooks Function()
        > {
  $$SyncWatermarkTableTableManager(
    _$LedgerDatabase db,
    $SyncWatermarkTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncWatermarkTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncWatermarkTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncWatermarkTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncWatermarkCompanion(
                collection: collection,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String cursor,
                Value<int> rowid = const Value.absent(),
              }) => SyncWatermarkCompanion.insert(
                collection: collection,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncWatermarkTable, SyncWatermarkData>(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncWatermarkTable,
                    SyncWatermarkData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncWatermarkTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncWatermarkTable,
      SyncWatermarkData,
      $$SyncWatermarkTableFilterComposer,
      $$SyncWatermarkTableOrderingComposer,
      $$SyncWatermarkTableAnnotationComposer,
      $$SyncWatermarkTableCreateCompanionBuilder,
      $$SyncWatermarkTableUpdateCompanionBuilder,
      (
        SyncWatermarkData,
        BaseReferences<
          _$LedgerDatabase,
          $SyncWatermarkTable,
          SyncWatermarkData
        >,
      ),
      SyncWatermarkData,
      PrefetchHooks Function()
    >;
typedef $$SyncAcknowledgedVectorTableCreateCompanionBuilder =
    SyncAcknowledgedVectorCompanion Function({
      required String collection,
      required String rowID,
      required Uint8List versionData,
      Value<int> rowid,
    });
typedef $$SyncAcknowledgedVectorTableUpdateCompanionBuilder =
    SyncAcknowledgedVectorCompanion Function({
      Value<String> collection,
      Value<String> rowID,
      Value<Uint8List> versionData,
      Value<int> rowid,
    });

class $$SyncAcknowledgedVectorTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncAcknowledgedVectorTable> {
  $$SyncAcknowledgedVectorTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowID => $composableBuilder(
    column: $table.rowID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncAcknowledgedVectorTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncAcknowledgedVectorTable> {
  $$SyncAcknowledgedVectorTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowID => $composableBuilder(
    column: $table.rowID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncAcknowledgedVectorTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncAcknowledgedVectorTable> {
  $$SyncAcknowledgedVectorTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowID =>
      $composableBuilder(column: $table.rowID, builder: (column) => column);

  GeneratedColumn<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => column,
  );
}

class $$SyncAcknowledgedVectorTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncAcknowledgedVectorTable,
          SyncAcknowledgedVectorData,
          $$SyncAcknowledgedVectorTableFilterComposer,
          $$SyncAcknowledgedVectorTableOrderingComposer,
          $$SyncAcknowledgedVectorTableAnnotationComposer,
          $$SyncAcknowledgedVectorTableCreateCompanionBuilder,
          $$SyncAcknowledgedVectorTableUpdateCompanionBuilder,
          (
            SyncAcknowledgedVectorData,
            BaseReferences<
              _$LedgerDatabase,
              $SyncAcknowledgedVectorTable,
              SyncAcknowledgedVectorData
            >,
          ),
          SyncAcknowledgedVectorData,
          PrefetchHooks Function()
        > {
  $$SyncAcknowledgedVectorTableTableManager(
    _$LedgerDatabase db,
    $SyncAcknowledgedVectorTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncAcknowledgedVectorTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SyncAcknowledgedVectorTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncAcknowledgedVectorTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> rowID = const Value.absent(),
                Value<Uint8List> versionData = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncAcknowledgedVectorCompanion(
                collection: collection,
                rowID: rowID,
                versionData: versionData,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String rowID,
                required Uint8List versionData,
                Value<int> rowid = const Value.absent(),
              }) => SyncAcknowledgedVectorCompanion.insert(
                collection: collection,
                rowID: rowID,
                versionData: versionData,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SyncAcknowledgedVectorTable,
                    SyncAcknowledgedVectorData
                  >(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncAcknowledgedVectorTable,
                    SyncAcknowledgedVectorData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncAcknowledgedVectorTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncAcknowledgedVectorTable,
      SyncAcknowledgedVectorData,
      $$SyncAcknowledgedVectorTableFilterComposer,
      $$SyncAcknowledgedVectorTableOrderingComposer,
      $$SyncAcknowledgedVectorTableAnnotationComposer,
      $$SyncAcknowledgedVectorTableCreateCompanionBuilder,
      $$SyncAcknowledgedVectorTableUpdateCompanionBuilder,
      (
        SyncAcknowledgedVectorData,
        BaseReferences<
          _$LedgerDatabase,
          $SyncAcknowledgedVectorTable,
          SyncAcknowledgedVectorData
        >,
      ),
      SyncAcknowledgedVectorData,
      PrefetchHooks Function()
    >;
typedef $$SyncPendingAckTableCreateCompanionBuilder =
    SyncPendingAckCompanion Function({
      required String collection,
      required String checkpoint,
      Value<int> rowid,
    });
typedef $$SyncPendingAckTableUpdateCompanionBuilder =
    SyncPendingAckCompanion Function({
      Value<String> collection,
      Value<String> checkpoint,
      Value<int> rowid,
    });

class $$SyncPendingAckTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncPendingAckTable> {
  $$SyncPendingAckTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncPendingAckTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncPendingAckTable> {
  $$SyncPendingAckTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncPendingAckTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncPendingAckTable> {
  $$SyncPendingAckTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => column,
  );
}

class $$SyncPendingAckTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncPendingAckTable,
          SyncPendingAckData,
          $$SyncPendingAckTableFilterComposer,
          $$SyncPendingAckTableOrderingComposer,
          $$SyncPendingAckTableAnnotationComposer,
          $$SyncPendingAckTableCreateCompanionBuilder,
          $$SyncPendingAckTableUpdateCompanionBuilder,
          (
            SyncPendingAckData,
            BaseReferences<
              _$LedgerDatabase,
              $SyncPendingAckTable,
              SyncPendingAckData
            >,
          ),
          SyncPendingAckData,
          PrefetchHooks Function()
        > {
  $$SyncPendingAckTableTableManager(
    _$LedgerDatabase db,
    $SyncPendingAckTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncPendingAckTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncPendingAckTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncPendingAckTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> checkpoint = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncPendingAckCompanion(
                collection: collection,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String checkpoint,
                Value<int> rowid = const Value.absent(),
              }) => SyncPendingAckCompanion.insert(
                collection: collection,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncPendingAckTable, SyncPendingAckData>(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncPendingAckTable,
                    SyncPendingAckData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncPendingAckTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncPendingAckTable,
      SyncPendingAckData,
      $$SyncPendingAckTableFilterComposer,
      $$SyncPendingAckTableOrderingComposer,
      $$SyncPendingAckTableAnnotationComposer,
      $$SyncPendingAckTableCreateCompanionBuilder,
      $$SyncPendingAckTableUpdateCompanionBuilder,
      (
        SyncPendingAckData,
        BaseReferences<
          _$LedgerDatabase,
          $SyncPendingAckTable,
          SyncPendingAckData
        >,
      ),
      SyncPendingAckData,
      PrefetchHooks Function()
    >;
typedef $$SyncStagingGroupTableCreateCompanionBuilder =
    SyncStagingGroupCompanion Function({
      Value<int> sequence,
      required String collection,
      required String rowID,
      required Uint8List siblings,
    });
typedef $$SyncStagingGroupTableUpdateCompanionBuilder =
    SyncStagingGroupCompanion Function({
      Value<int> sequence,
      Value<String> collection,
      Value<String> rowID,
      Value<Uint8List> siblings,
    });

class $$SyncStagingGroupTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncStagingGroupTable> {
  $$SyncStagingGroupTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowID => $composableBuilder(
    column: $table.rowID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get siblings => $composableBuilder(
    column: $table.siblings,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStagingGroupTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncStagingGroupTable> {
  $$SyncStagingGroupTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowID => $composableBuilder(
    column: $table.rowID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get siblings => $composableBuilder(
    column: $table.siblings,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStagingGroupTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncStagingGroupTable> {
  $$SyncStagingGroupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowID =>
      $composableBuilder(column: $table.rowID, builder: (column) => column);

  GeneratedColumn<Uint8List> get siblings =>
      $composableBuilder(column: $table.siblings, builder: (column) => column);
}

class $$SyncStagingGroupTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncStagingGroupTable,
          SyncStagingGroupData,
          $$SyncStagingGroupTableFilterComposer,
          $$SyncStagingGroupTableOrderingComposer,
          $$SyncStagingGroupTableAnnotationComposer,
          $$SyncStagingGroupTableCreateCompanionBuilder,
          $$SyncStagingGroupTableUpdateCompanionBuilder,
          (
            SyncStagingGroupData,
            BaseReferences<
              _$LedgerDatabase,
              $SyncStagingGroupTable,
              SyncStagingGroupData
            >,
          ),
          SyncStagingGroupData,
          PrefetchHooks Function()
        > {
  $$SyncStagingGroupTableTableManager(
    _$LedgerDatabase db,
    $SyncStagingGroupTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStagingGroupTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStagingGroupTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStagingGroupTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sequence = const Value.absent(),
                Value<String> collection = const Value.absent(),
                Value<String> rowID = const Value.absent(),
                Value<Uint8List> siblings = const Value.absent(),
              }) => SyncStagingGroupCompanion(
                sequence: sequence,
                collection: collection,
                rowID: rowID,
                siblings: siblings,
              ),
          createCompanionCallback:
              ({
                Value<int> sequence = const Value.absent(),
                required String collection,
                required String rowID,
                required Uint8List siblings,
              }) => SyncStagingGroupCompanion.insert(
                sequence: sequence,
                collection: collection,
                rowID: rowID,
                siblings: siblings,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStagingGroupTable, SyncStagingGroupData>(
                    table,
                  ),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncStagingGroupTable,
                    SyncStagingGroupData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStagingGroupTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncStagingGroupTable,
      SyncStagingGroupData,
      $$SyncStagingGroupTableFilterComposer,
      $$SyncStagingGroupTableOrderingComposer,
      $$SyncStagingGroupTableAnnotationComposer,
      $$SyncStagingGroupTableCreateCompanionBuilder,
      $$SyncStagingGroupTableUpdateCompanionBuilder,
      (
        SyncStagingGroupData,
        BaseReferences<
          _$LedgerDatabase,
          $SyncStagingGroupTable,
          SyncStagingGroupData
        >,
      ),
      SyncStagingGroupData,
      PrefetchHooks Function()
    >;

class $LedgerDatabaseManager {
  final _$LedgerDatabase _db;
  $LedgerDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$SubPocketsTableTableManager get subPockets =>
      $$SubPocketsTableTableManager(_db, _db.subPockets);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db, _db.plans);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$StoreMetaTableTableManager get storeMeta =>
      $$StoreMetaTableTableManager(_db, _db.storeMeta);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
  $$SyncWatermarkTableTableManager get syncWatermark =>
      $$SyncWatermarkTableTableManager(_db, _db.syncWatermark);
  $$SyncAcknowledgedVectorTableTableManager get syncAcknowledgedVector =>
      $$SyncAcknowledgedVectorTableTableManager(
        _db,
        _db.syncAcknowledgedVector,
      );
  $$SyncPendingAckTableTableManager get syncPendingAck =>
      $$SyncPendingAckTableTableManager(_db, _db.syncPendingAck);
  $$SyncStagingGroupTableTableManager get syncStagingGroup =>
      $$SyncStagingGroupTableTableManager(_db, _db.syncStagingGroup);
}
