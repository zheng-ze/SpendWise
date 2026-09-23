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

  /// Reserved and never written by this version. Claiming it now avoids a
  /// migration if a future version starts writing it.
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

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backendMeta = const VerificationMeta(
    'backend',
  );
  @override
  late final GeneratedColumn<String> backend = GeneratedColumn<String>(
    'backend',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _writeEnabledMeta = const VerificationMeta(
    'writeEnabled',
  );
  @override
  late final GeneratedColumn<bool> writeEnabled = GeneratedColumn<bool>(
    'write_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("write_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _moneySourcesCursorMeta =
      const VerificationMeta('moneySourcesCursor');
  @override
  late final GeneratedColumn<String> moneySourcesCursor =
      GeneratedColumn<String>(
        'money_sources_cursor',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _entriesCursorMeta = const VerificationMeta(
    'entriesCursor',
  );
  @override
  late final GeneratedColumn<String> entriesCursor = GeneratedColumn<String>(
    'entries_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesCursorMeta = const VerificationMeta(
    'categoriesCursor',
  );
  @override
  late final GeneratedColumn<String> categoriesCursor = GeneratedColumn<String>(
    'categories_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plansCursorMeta = const VerificationMeta(
    'plansCursor',
  );
  @override
  late final GeneratedColumn<String> plansCursor = GeneratedColumn<String>(
    'plans_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _budgetsCursorMeta = const VerificationMeta(
    'budgetsCursor',
  );
  @override
  late final GeneratedColumn<String> budgetsCursor = GeneratedColumn<String>(
    'budgets_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    backend,
    endpoint,
    enrollmentPhase,
    writeEnabled,
    moneySourcesCursor,
    entriesCursor,
    categoriesCursor,
    plansCursor,
    budgetsCursor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
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
    if (data.containsKey('backend')) {
      context.handle(
        _backendMeta,
        backend.isAcceptableOrUnknown(data['backend']!, _backendMeta),
      );
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
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
    if (data.containsKey('write_enabled')) {
      context.handle(
        _writeEnabledMeta,
        writeEnabled.isAcceptableOrUnknown(
          data['write_enabled']!,
          _writeEnabledMeta,
        ),
      );
    }
    if (data.containsKey('money_sources_cursor')) {
      context.handle(
        _moneySourcesCursorMeta,
        moneySourcesCursor.isAcceptableOrUnknown(
          data['money_sources_cursor']!,
          _moneySourcesCursorMeta,
        ),
      );
    }
    if (data.containsKey('entries_cursor')) {
      context.handle(
        _entriesCursorMeta,
        entriesCursor.isAcceptableOrUnknown(
          data['entries_cursor']!,
          _entriesCursorMeta,
        ),
      );
    }
    if (data.containsKey('categories_cursor')) {
      context.handle(
        _categoriesCursorMeta,
        categoriesCursor.isAcceptableOrUnknown(
          data['categories_cursor']!,
          _categoriesCursorMeta,
        ),
      );
    }
    if (data.containsKey('plans_cursor')) {
      context.handle(
        _plansCursorMeta,
        plansCursor.isAcceptableOrUnknown(
          data['plans_cursor']!,
          _plansCursorMeta,
        ),
      );
    }
    if (data.containsKey('budgets_cursor')) {
      context.handle(
        _budgetsCursorMeta,
        budgetsCursor.isAcceptableOrUnknown(
          data['budgets_cursor']!,
          _budgetsCursorMeta,
        ),
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
      backend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend'],
      ),
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      ),
      enrollmentPhase: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enrollment_phase'],
      )!,
      writeEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}write_enabled'],
      )!,
      moneySourcesCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}money_sources_cursor'],
      ),
      entriesCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entries_cursor'],
      ),
      categoriesCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories_cursor'],
      ),
      plansCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plans_cursor'],
      ),
      budgetsCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budgets_cursor'],
      ),
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetadataRow extends DataClass implements Insertable<SyncMetadataRow> {
  final int id;

  /// Selected backend profile (`supabase` or `custom`). Null until enrollment.
  final String? backend;

  /// Endpoint configuration for a custom backend. Null until enrollment and
  /// unused by managed backends.
  final String? endpoint;
  final int enrollmentPhase;

  /// Write-enabled gate. Only a durable reconciliation-complete phase permits
  /// flipping this on; credential presence alone never enables writes.
  final bool writeEnabled;

  /// Durable per-collection pull cursors. Each is the last staged and
  /// acknowledged checkpoint for its collection, null before the first pull.
  final String? moneySourcesCursor;
  final String? entriesCursor;
  final String? categoriesCursor;
  final String? plansCursor;
  final String? budgetsCursor;
  const SyncMetadataRow({
    required this.id,
    this.backend,
    this.endpoint,
    required this.enrollmentPhase,
    required this.writeEnabled,
    this.moneySourcesCursor,
    this.entriesCursor,
    this.categoriesCursor,
    this.plansCursor,
    this.budgetsCursor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || backend != null) {
      map['backend'] = Variable<String>(backend);
    }
    if (!nullToAbsent || endpoint != null) {
      map['endpoint'] = Variable<String>(endpoint);
    }
    map['enrollment_phase'] = Variable<int>(enrollmentPhase);
    map['write_enabled'] = Variable<bool>(writeEnabled);
    if (!nullToAbsent || moneySourcesCursor != null) {
      map['money_sources_cursor'] = Variable<String>(moneySourcesCursor);
    }
    if (!nullToAbsent || entriesCursor != null) {
      map['entries_cursor'] = Variable<String>(entriesCursor);
    }
    if (!nullToAbsent || categoriesCursor != null) {
      map['categories_cursor'] = Variable<String>(categoriesCursor);
    }
    if (!nullToAbsent || plansCursor != null) {
      map['plans_cursor'] = Variable<String>(plansCursor);
    }
    if (!nullToAbsent || budgetsCursor != null) {
      map['budgets_cursor'] = Variable<String>(budgetsCursor);
    }
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      id: Value(id),
      backend: backend == null && nullToAbsent
          ? const Value.absent()
          : Value(backend),
      endpoint: endpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(endpoint),
      enrollmentPhase: Value(enrollmentPhase),
      writeEnabled: Value(writeEnabled),
      moneySourcesCursor: moneySourcesCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(moneySourcesCursor),
      entriesCursor: entriesCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(entriesCursor),
      categoriesCursor: categoriesCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriesCursor),
      plansCursor: plansCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(plansCursor),
      budgetsCursor: budgetsCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetsCursor),
    );
  }

  factory SyncMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataRow(
      id: serializer.fromJson<int>(json['id']),
      backend: serializer.fromJson<String?>(json['backend']),
      endpoint: serializer.fromJson<String?>(json['endpoint']),
      enrollmentPhase: serializer.fromJson<int>(json['enrollmentPhase']),
      writeEnabled: serializer.fromJson<bool>(json['writeEnabled']),
      moneySourcesCursor: serializer.fromJson<String?>(
        json['moneySourcesCursor'],
      ),
      entriesCursor: serializer.fromJson<String?>(json['entriesCursor']),
      categoriesCursor: serializer.fromJson<String?>(json['categoriesCursor']),
      plansCursor: serializer.fromJson<String?>(json['plansCursor']),
      budgetsCursor: serializer.fromJson<String?>(json['budgetsCursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'backend': serializer.toJson<String?>(backend),
      'endpoint': serializer.toJson<String?>(endpoint),
      'enrollmentPhase': serializer.toJson<int>(enrollmentPhase),
      'writeEnabled': serializer.toJson<bool>(writeEnabled),
      'moneySourcesCursor': serializer.toJson<String?>(moneySourcesCursor),
      'entriesCursor': serializer.toJson<String?>(entriesCursor),
      'categoriesCursor': serializer.toJson<String?>(categoriesCursor),
      'plansCursor': serializer.toJson<String?>(plansCursor),
      'budgetsCursor': serializer.toJson<String?>(budgetsCursor),
    };
  }

  SyncMetadataRow copyWith({
    int? id,
    Value<String?> backend = const Value.absent(),
    Value<String?> endpoint = const Value.absent(),
    int? enrollmentPhase,
    bool? writeEnabled,
    Value<String?> moneySourcesCursor = const Value.absent(),
    Value<String?> entriesCursor = const Value.absent(),
    Value<String?> categoriesCursor = const Value.absent(),
    Value<String?> plansCursor = const Value.absent(),
    Value<String?> budgetsCursor = const Value.absent(),
  }) => SyncMetadataRow(
    id: id ?? this.id,
    backend: backend.present ? backend.value : this.backend,
    endpoint: endpoint.present ? endpoint.value : this.endpoint,
    enrollmentPhase: enrollmentPhase ?? this.enrollmentPhase,
    writeEnabled: writeEnabled ?? this.writeEnabled,
    moneySourcesCursor: moneySourcesCursor.present
        ? moneySourcesCursor.value
        : this.moneySourcesCursor,
    entriesCursor: entriesCursor.present
        ? entriesCursor.value
        : this.entriesCursor,
    categoriesCursor: categoriesCursor.present
        ? categoriesCursor.value
        : this.categoriesCursor,
    plansCursor: plansCursor.present ? plansCursor.value : this.plansCursor,
    budgetsCursor: budgetsCursor.present
        ? budgetsCursor.value
        : this.budgetsCursor,
  );
  SyncMetadataRow copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      backend: data.backend.present ? data.backend.value : this.backend,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      enrollmentPhase: data.enrollmentPhase.present
          ? data.enrollmentPhase.value
          : this.enrollmentPhase,
      writeEnabled: data.writeEnabled.present
          ? data.writeEnabled.value
          : this.writeEnabled,
      moneySourcesCursor: data.moneySourcesCursor.present
          ? data.moneySourcesCursor.value
          : this.moneySourcesCursor,
      entriesCursor: data.entriesCursor.present
          ? data.entriesCursor.value
          : this.entriesCursor,
      categoriesCursor: data.categoriesCursor.present
          ? data.categoriesCursor.value
          : this.categoriesCursor,
      plansCursor: data.plansCursor.present
          ? data.plansCursor.value
          : this.plansCursor,
      budgetsCursor: data.budgetsCursor.present
          ? data.budgetsCursor.value
          : this.budgetsCursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataRow(')
          ..write('id: $id, ')
          ..write('backend: $backend, ')
          ..write('endpoint: $endpoint, ')
          ..write('enrollmentPhase: $enrollmentPhase, ')
          ..write('writeEnabled: $writeEnabled, ')
          ..write('moneySourcesCursor: $moneySourcesCursor, ')
          ..write('entriesCursor: $entriesCursor, ')
          ..write('categoriesCursor: $categoriesCursor, ')
          ..write('plansCursor: $plansCursor, ')
          ..write('budgetsCursor: $budgetsCursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    backend,
    endpoint,
    enrollmentPhase,
    writeEnabled,
    moneySourcesCursor,
    entriesCursor,
    categoriesCursor,
    plansCursor,
    budgetsCursor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataRow &&
          other.id == this.id &&
          other.backend == this.backend &&
          other.endpoint == this.endpoint &&
          other.enrollmentPhase == this.enrollmentPhase &&
          other.writeEnabled == this.writeEnabled &&
          other.moneySourcesCursor == this.moneySourcesCursor &&
          other.entriesCursor == this.entriesCursor &&
          other.categoriesCursor == this.categoriesCursor &&
          other.plansCursor == this.plansCursor &&
          other.budgetsCursor == this.budgetsCursor);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetadataRow> {
  final Value<int> id;
  final Value<String?> backend;
  final Value<String?> endpoint;
  final Value<int> enrollmentPhase;
  final Value<bool> writeEnabled;
  final Value<String?> moneySourcesCursor;
  final Value<String?> entriesCursor;
  final Value<String?> categoriesCursor;
  final Value<String?> plansCursor;
  final Value<String?> budgetsCursor;
  const SyncMetaCompanion({
    this.id = const Value.absent(),
    this.backend = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.enrollmentPhase = const Value.absent(),
    this.writeEnabled = const Value.absent(),
    this.moneySourcesCursor = const Value.absent(),
    this.entriesCursor = const Value.absent(),
    this.categoriesCursor = const Value.absent(),
    this.plansCursor = const Value.absent(),
    this.budgetsCursor = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    this.id = const Value.absent(),
    this.backend = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.enrollmentPhase = const Value.absent(),
    this.writeEnabled = const Value.absent(),
    this.moneySourcesCursor = const Value.absent(),
    this.entriesCursor = const Value.absent(),
    this.categoriesCursor = const Value.absent(),
    this.plansCursor = const Value.absent(),
    this.budgetsCursor = const Value.absent(),
  });
  static Insertable<SyncMetadataRow> custom({
    Expression<int>? id,
    Expression<String>? backend,
    Expression<String>? endpoint,
    Expression<int>? enrollmentPhase,
    Expression<bool>? writeEnabled,
    Expression<String>? moneySourcesCursor,
    Expression<String>? entriesCursor,
    Expression<String>? categoriesCursor,
    Expression<String>? plansCursor,
    Expression<String>? budgetsCursor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (backend != null) 'backend': backend,
      if (endpoint != null) 'endpoint': endpoint,
      if (enrollmentPhase != null) 'enrollment_phase': enrollmentPhase,
      if (writeEnabled != null) 'write_enabled': writeEnabled,
      if (moneySourcesCursor != null)
        'money_sources_cursor': moneySourcesCursor,
      if (entriesCursor != null) 'entries_cursor': entriesCursor,
      if (categoriesCursor != null) 'categories_cursor': categoriesCursor,
      if (plansCursor != null) 'plans_cursor': plansCursor,
      if (budgetsCursor != null) 'budgets_cursor': budgetsCursor,
    });
  }

  SyncMetaCompanion copyWith({
    Value<int>? id,
    Value<String?>? backend,
    Value<String?>? endpoint,
    Value<int>? enrollmentPhase,
    Value<bool>? writeEnabled,
    Value<String?>? moneySourcesCursor,
    Value<String?>? entriesCursor,
    Value<String?>? categoriesCursor,
    Value<String?>? plansCursor,
    Value<String?>? budgetsCursor,
  }) {
    return SyncMetaCompanion(
      id: id ?? this.id,
      backend: backend ?? this.backend,
      endpoint: endpoint ?? this.endpoint,
      enrollmentPhase: enrollmentPhase ?? this.enrollmentPhase,
      writeEnabled: writeEnabled ?? this.writeEnabled,
      moneySourcesCursor: moneySourcesCursor ?? this.moneySourcesCursor,
      entriesCursor: entriesCursor ?? this.entriesCursor,
      categoriesCursor: categoriesCursor ?? this.categoriesCursor,
      plansCursor: plansCursor ?? this.plansCursor,
      budgetsCursor: budgetsCursor ?? this.budgetsCursor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (backend.present) {
      map['backend'] = Variable<String>(backend.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (enrollmentPhase.present) {
      map['enrollment_phase'] = Variable<int>(enrollmentPhase.value);
    }
    if (writeEnabled.present) {
      map['write_enabled'] = Variable<bool>(writeEnabled.value);
    }
    if (moneySourcesCursor.present) {
      map['money_sources_cursor'] = Variable<String>(moneySourcesCursor.value);
    }
    if (entriesCursor.present) {
      map['entries_cursor'] = Variable<String>(entriesCursor.value);
    }
    if (categoriesCursor.present) {
      map['categories_cursor'] = Variable<String>(categoriesCursor.value);
    }
    if (plansCursor.present) {
      map['plans_cursor'] = Variable<String>(plansCursor.value);
    }
    if (budgetsCursor.present) {
      map['budgets_cursor'] = Variable<String>(budgetsCursor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('id: $id, ')
          ..write('backend: $backend, ')
          ..write('endpoint: $endpoint, ')
          ..write('enrollmentPhase: $enrollmentPhase, ')
          ..write('writeEnabled: $writeEnabled, ')
          ..write('moneySourcesCursor: $moneySourcesCursor, ')
          ..write('entriesCursor: $entriesCursor, ')
          ..write('categoriesCursor: $categoriesCursor, ')
          ..write('plansCursor: $plansCursor, ')
          ..write('budgetsCursor: $budgetsCursor')
          ..write(')'))
        .toString();
  }
}

class $SyncAcknowledgedVectorsTable extends SyncAcknowledgedVectors
    with TableInfo<$SyncAcknowledgedVectorsTable, AcknowledgedVectorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncAcknowledgedVectorsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<SyncCollection, String>
  collection =
      GeneratedColumn<String>(
        'collection',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncCollection>(
        $SyncAcknowledgedVectorsTable.$convertercollection,
      );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VersionVector, Uint8List>
  versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      ).withConverter<VersionVector>(
        $SyncAcknowledgedVectorsTable.$converterversionData,
      );
  @override
  List<GeneratedColumn> get $columns => [collection, rowId, versionData];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_acknowledged_vectors';
  @override
  VerificationContext validateIntegrity(
    Insertable<AcknowledgedVectorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, rowId};
  @override
  AcknowledgedVectorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AcknowledgedVectorRow(
      collection: $SyncAcknowledgedVectorsTable.$convertercollection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}collection'],
        )!,
      ),
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      versionData: $SyncAcknowledgedVectorsTable.$converterversionData.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}version_data'],
        )!,
      ),
    );
  }

  @override
  $SyncAcknowledgedVectorsTable createAlias(String alias) {
    return $SyncAcknowledgedVectorsTable(attachedDatabase, alias);
  }

  static TypeConverter<SyncCollection, String> $convertercollection =
      const SyncCollectionConverter();
  static TypeConverter<VersionVector, Uint8List> $converterversionData =
      const VersionVectorConverter();
}

class AcknowledgedVectorRow extends DataClass
    implements Insertable<AcknowledgedVectorRow> {
  final SyncCollection collection;
  final String rowId;
  final VersionVector versionData;
  const AcknowledgedVectorRow({
    required this.collection,
    required this.rowId,
    required this.versionData,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['collection'] = Variable<String>(
        $SyncAcknowledgedVectorsTable.$convertercollection.toSql(collection),
      );
    }
    map['row_id'] = Variable<String>(rowId);
    {
      map['version_data'] = Variable<Uint8List>(
        $SyncAcknowledgedVectorsTable.$converterversionData.toSql(versionData),
      );
    }
    return map;
  }

  SyncAcknowledgedVectorsCompanion toCompanion(bool nullToAbsent) {
    return SyncAcknowledgedVectorsCompanion(
      collection: Value(collection),
      rowId: Value(rowId),
      versionData: Value(versionData),
    );
  }

  factory AcknowledgedVectorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AcknowledgedVectorRow(
      collection: serializer.fromJson<SyncCollection>(json['collection']),
      rowId: serializer.fromJson<String>(json['rowId']),
      versionData: serializer.fromJson<VersionVector>(json['versionData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<SyncCollection>(collection),
      'rowId': serializer.toJson<String>(rowId),
      'versionData': serializer.toJson<VersionVector>(versionData),
    };
  }

  AcknowledgedVectorRow copyWith({
    SyncCollection? collection,
    String? rowId,
    VersionVector? versionData,
  }) => AcknowledgedVectorRow(
    collection: collection ?? this.collection,
    rowId: rowId ?? this.rowId,
    versionData: versionData ?? this.versionData,
  );
  AcknowledgedVectorRow copyWithCompanion(
    SyncAcknowledgedVectorsCompanion data,
  ) {
    return AcknowledgedVectorRow(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AcknowledgedVectorRow(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId, ')
          ..write('versionData: $versionData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, rowId, versionData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcknowledgedVectorRow &&
          other.collection == this.collection &&
          other.rowId == this.rowId &&
          other.versionData == this.versionData);
}

class SyncAcknowledgedVectorsCompanion
    extends UpdateCompanion<AcknowledgedVectorRow> {
  final Value<SyncCollection> collection;
  final Value<String> rowId;
  final Value<VersionVector> versionData;
  final Value<int> rowid;
  const SyncAcknowledgedVectorsCompanion({
    this.collection = const Value.absent(),
    this.rowId = const Value.absent(),
    this.versionData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncAcknowledgedVectorsCompanion.insert({
    required SyncCollection collection,
    required String rowId,
    required VersionVector versionData,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       rowId = Value(rowId),
       versionData = Value(versionData);
  static Insertable<AcknowledgedVectorRow> custom({
    Expression<String>? collection,
    Expression<String>? rowId,
    Expression<Uint8List>? versionData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (rowId != null) 'row_id': rowId,
      if (versionData != null) 'version_data': versionData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncAcknowledgedVectorsCompanion copyWith({
    Value<SyncCollection>? collection,
    Value<String>? rowId,
    Value<VersionVector>? versionData,
    Value<int>? rowid,
  }) {
    return SyncAcknowledgedVectorsCompanion(
      collection: collection ?? this.collection,
      rowId: rowId ?? this.rowId,
      versionData: versionData ?? this.versionData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(
        $SyncAcknowledgedVectorsTable.$convertercollection.toSql(
          collection.value,
        ),
      );
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(
        $SyncAcknowledgedVectorsTable.$converterversionData.toSql(
          versionData.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncAcknowledgedVectorsCompanion(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId, ')
          ..write('versionData: $versionData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncPendingAcknowledgementsTable extends SyncPendingAcknowledgements
    with
        TableInfo<
          $SyncPendingAcknowledgementsTable,
          PendingAcknowledgementRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncPendingAcknowledgementsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<SyncCollection, String>
  collection =
      GeneratedColumn<String>(
        'collection',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncCollection>(
        $SyncPendingAcknowledgementsTable.$convertercollection,
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
  static const String $name = 'sync_pending_acknowledgements';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAcknowledgementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
  Set<GeneratedColumn> get $primaryKey => {collection};
  @override
  PendingAcknowledgementRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAcknowledgementRow(
      collection: $SyncPendingAcknowledgementsTable.$convertercollection
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}collection'],
            )!,
          ),
      checkpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint'],
      )!,
    );
  }

  @override
  $SyncPendingAcknowledgementsTable createAlias(String alias) {
    return $SyncPendingAcknowledgementsTable(attachedDatabase, alias);
  }

  static TypeConverter<SyncCollection, String> $convertercollection =
      const SyncCollectionConverter();
}

class PendingAcknowledgementRow extends DataClass
    implements Insertable<PendingAcknowledgementRow> {
  final SyncCollection collection;
  final String checkpoint;
  const PendingAcknowledgementRow({
    required this.collection,
    required this.checkpoint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['collection'] = Variable<String>(
        $SyncPendingAcknowledgementsTable.$convertercollection.toSql(
          collection,
        ),
      );
    }
    map['checkpoint'] = Variable<String>(checkpoint);
    return map;
  }

  SyncPendingAcknowledgementsCompanion toCompanion(bool nullToAbsent) {
    return SyncPendingAcknowledgementsCompanion(
      collection: Value(collection),
      checkpoint: Value(checkpoint),
    );
  }

  factory PendingAcknowledgementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAcknowledgementRow(
      collection: serializer.fromJson<SyncCollection>(json['collection']),
      checkpoint: serializer.fromJson<String>(json['checkpoint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<SyncCollection>(collection),
      'checkpoint': serializer.toJson<String>(checkpoint),
    };
  }

  PendingAcknowledgementRow copyWith({
    SyncCollection? collection,
    String? checkpoint,
  }) => PendingAcknowledgementRow(
    collection: collection ?? this.collection,
    checkpoint: checkpoint ?? this.checkpoint,
  );
  PendingAcknowledgementRow copyWithCompanion(
    SyncPendingAcknowledgementsCompanion data,
  ) {
    return PendingAcknowledgementRow(
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
    return (StringBuffer('PendingAcknowledgementRow(')
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
      (other is PendingAcknowledgementRow &&
          other.collection == this.collection &&
          other.checkpoint == this.checkpoint);
}

class SyncPendingAcknowledgementsCompanion
    extends UpdateCompanion<PendingAcknowledgementRow> {
  final Value<SyncCollection> collection;
  final Value<String> checkpoint;
  final Value<int> rowid;
  const SyncPendingAcknowledgementsCompanion({
    this.collection = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncPendingAcknowledgementsCompanion.insert({
    required SyncCollection collection,
    required String checkpoint,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       checkpoint = Value(checkpoint);
  static Insertable<PendingAcknowledgementRow> custom({
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

  SyncPendingAcknowledgementsCompanion copyWith({
    Value<SyncCollection>? collection,
    Value<String>? checkpoint,
    Value<int>? rowid,
  }) {
    return SyncPendingAcknowledgementsCompanion(
      collection: collection ?? this.collection,
      checkpoint: checkpoint ?? this.checkpoint,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(
        $SyncPendingAcknowledgementsTable.$convertercollection.toSql(
          collection.value,
        ),
      );
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
    return (StringBuffer('SyncPendingAcknowledgementsCompanion(')
          ..write('collection: $collection, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStagedConflictsTable extends SyncStagedConflicts
    with TableInfo<$SyncStagedConflictsTable, StagedConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStagedConflictsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<SyncCollection, String>
  collection =
      GeneratedColumn<String>(
        'collection',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncCollection>(
        $SyncStagedConflictsTable.$convertercollection,
      );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [collection, rowId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_staged_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<StagedConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, rowId};
  @override
  StagedConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StagedConflictRow(
      collection: $SyncStagedConflictsTable.$convertercollection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}collection'],
        )!,
      ),
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
    );
  }

  @override
  $SyncStagedConflictsTable createAlias(String alias) {
    return $SyncStagedConflictsTable(attachedDatabase, alias);
  }

  static TypeConverter<SyncCollection, String> $convertercollection =
      const SyncCollectionConverter();
}

class StagedConflictRow extends DataClass
    implements Insertable<StagedConflictRow> {
  final SyncCollection collection;
  final String rowId;
  const StagedConflictRow({required this.collection, required this.rowId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['collection'] = Variable<String>(
        $SyncStagedConflictsTable.$convertercollection.toSql(collection),
      );
    }
    map['row_id'] = Variable<String>(rowId);
    return map;
  }

  SyncStagedConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncStagedConflictsCompanion(
      collection: Value(collection),
      rowId: Value(rowId),
    );
  }

  factory StagedConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StagedConflictRow(
      collection: serializer.fromJson<SyncCollection>(json['collection']),
      rowId: serializer.fromJson<String>(json['rowId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<SyncCollection>(collection),
      'rowId': serializer.toJson<String>(rowId),
    };
  }

  StagedConflictRow copyWith({SyncCollection? collection, String? rowId}) =>
      StagedConflictRow(
        collection: collection ?? this.collection,
        rowId: rowId ?? this.rowId,
      );
  StagedConflictRow copyWithCompanion(SyncStagedConflictsCompanion data) {
    return StagedConflictRow(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StagedConflictRow(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, rowId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StagedConflictRow &&
          other.collection == this.collection &&
          other.rowId == this.rowId);
}

class SyncStagedConflictsCompanion extends UpdateCompanion<StagedConflictRow> {
  final Value<SyncCollection> collection;
  final Value<String> rowId;
  final Value<int> rowid;
  const SyncStagedConflictsCompanion({
    this.collection = const Value.absent(),
    this.rowId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStagedConflictsCompanion.insert({
    required SyncCollection collection,
    required String rowId,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       rowId = Value(rowId);
  static Insertable<StagedConflictRow> custom({
    Expression<String>? collection,
    Expression<String>? rowId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (rowId != null) 'row_id': rowId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStagedConflictsCompanion copyWith({
    Value<SyncCollection>? collection,
    Value<String>? rowId,
    Value<int>? rowid,
  }) {
    return SyncStagedConflictsCompanion(
      collection: collection ?? this.collection,
      rowId: rowId ?? this.rowId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(
        $SyncStagedConflictsTable.$convertercollection.toSql(collection.value),
      );
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStagedConflictsCompanion(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStagedSiblingsTable extends SyncStagedSiblings
    with TableInfo<$SyncStagedSiblingsTable, StagedSiblingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStagedSiblingsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<SyncCollection, String>
  collection =
      GeneratedColumn<String>(
        'collection',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncCollection>(
        $SyncStagedSiblingsTable.$convertercollection,
      );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siblingIdMeta = const VerificationMeta(
    'siblingId',
  );
  @override
  late final GeneratedColumn<String> siblingId = GeneratedColumn<String>(
    'sibling_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VersionVector, Uint8List>
  versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      ).withConverter<VersionVector>(
        $SyncStagedSiblingsTable.$converterversionData,
      );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
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
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collection,
    rowId,
    siblingId,
    versionData,
    payload,
    lifecycle,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_staged_siblings';
  @override
  VerificationContext validateIntegrity(
    Insertable<StagedSiblingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('sibling_id')) {
      context.handle(
        _siblingIdMeta,
        siblingId.isAcceptableOrUnknown(data['sibling_id']!, _siblingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_siblingIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, rowId, siblingId};
  @override
  StagedSiblingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StagedSiblingRow(
      collection: $SyncStagedSiblingsTable.$convertercollection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}collection'],
        )!,
      ),
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      siblingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sibling_id'],
      )!,
      versionData: $SyncStagedSiblingsTable.$converterversionData.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}version_data'],
        )!,
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SyncStagedSiblingsTable createAlias(String alias) {
    return $SyncStagedSiblingsTable(attachedDatabase, alias);
  }

  static TypeConverter<SyncCollection, String> $convertercollection =
      const SyncCollectionConverter();
  static TypeConverter<VersionVector, Uint8List> $converterversionData =
      const VersionVectorConverter();
}

class StagedSiblingRow extends DataClass
    implements Insertable<StagedSiblingRow> {
  final SyncCollection collection;
  final String rowId;
  final String siblingId;
  final VersionVector versionData;
  final Uint8List payload;

  /// Explicit sibling-lifecycle code: 0 is live, 1 is tombstone.
  final int lifecycle;
  final int position;
  const StagedSiblingRow({
    required this.collection,
    required this.rowId,
    required this.siblingId,
    required this.versionData,
    required this.payload,
    required this.lifecycle,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['collection'] = Variable<String>(
        $SyncStagedSiblingsTable.$convertercollection.toSql(collection),
      );
    }
    map['row_id'] = Variable<String>(rowId);
    map['sibling_id'] = Variable<String>(siblingId);
    {
      map['version_data'] = Variable<Uint8List>(
        $SyncStagedSiblingsTable.$converterversionData.toSql(versionData),
      );
    }
    map['payload'] = Variable<Uint8List>(payload);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['position'] = Variable<int>(position);
    return map;
  }

  SyncStagedSiblingsCompanion toCompanion(bool nullToAbsent) {
    return SyncStagedSiblingsCompanion(
      collection: Value(collection),
      rowId: Value(rowId),
      siblingId: Value(siblingId),
      versionData: Value(versionData),
      payload: Value(payload),
      lifecycle: Value(lifecycle),
      position: Value(position),
    );
  }

  factory StagedSiblingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StagedSiblingRow(
      collection: serializer.fromJson<SyncCollection>(json['collection']),
      rowId: serializer.fromJson<String>(json['rowId']),
      siblingId: serializer.fromJson<String>(json['siblingId']),
      versionData: serializer.fromJson<VersionVector>(json['versionData']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<SyncCollection>(collection),
      'rowId': serializer.toJson<String>(rowId),
      'siblingId': serializer.toJson<String>(siblingId),
      'versionData': serializer.toJson<VersionVector>(versionData),
      'payload': serializer.toJson<Uint8List>(payload),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'position': serializer.toJson<int>(position),
    };
  }

  StagedSiblingRow copyWith({
    SyncCollection? collection,
    String? rowId,
    String? siblingId,
    VersionVector? versionData,
    Uint8List? payload,
    int? lifecycle,
    int? position,
  }) => StagedSiblingRow(
    collection: collection ?? this.collection,
    rowId: rowId ?? this.rowId,
    siblingId: siblingId ?? this.siblingId,
    versionData: versionData ?? this.versionData,
    payload: payload ?? this.payload,
    lifecycle: lifecycle ?? this.lifecycle,
    position: position ?? this.position,
  );
  StagedSiblingRow copyWithCompanion(SyncStagedSiblingsCompanion data) {
    return StagedSiblingRow(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      siblingId: data.siblingId.present ? data.siblingId.value : this.siblingId,
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
      payload: data.payload.present ? data.payload.value : this.payload,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StagedSiblingRow(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId, ')
          ..write('siblingId: $siblingId, ')
          ..write('versionData: $versionData, ')
          ..write('payload: $payload, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    collection,
    rowId,
    siblingId,
    versionData,
    $driftBlobEquality.hash(payload),
    lifecycle,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StagedSiblingRow &&
          other.collection == this.collection &&
          other.rowId == this.rowId &&
          other.siblingId == this.siblingId &&
          other.versionData == this.versionData &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.lifecycle == this.lifecycle &&
          other.position == this.position);
}

class SyncStagedSiblingsCompanion extends UpdateCompanion<StagedSiblingRow> {
  final Value<SyncCollection> collection;
  final Value<String> rowId;
  final Value<String> siblingId;
  final Value<VersionVector> versionData;
  final Value<Uint8List> payload;
  final Value<int> lifecycle;
  final Value<int> position;
  final Value<int> rowid;
  const SyncStagedSiblingsCompanion({
    this.collection = const Value.absent(),
    this.rowId = const Value.absent(),
    this.siblingId = const Value.absent(),
    this.versionData = const Value.absent(),
    this.payload = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStagedSiblingsCompanion.insert({
    required SyncCollection collection,
    required String rowId,
    required String siblingId,
    required VersionVector versionData,
    required Uint8List payload,
    required int lifecycle,
    required int position,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       rowId = Value(rowId),
       siblingId = Value(siblingId),
       versionData = Value(versionData),
       payload = Value(payload),
       lifecycle = Value(lifecycle),
       position = Value(position);
  static Insertable<StagedSiblingRow> custom({
    Expression<String>? collection,
    Expression<String>? rowId,
    Expression<String>? siblingId,
    Expression<Uint8List>? versionData,
    Expression<Uint8List>? payload,
    Expression<int>? lifecycle,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (rowId != null) 'row_id': rowId,
      if (siblingId != null) 'sibling_id': siblingId,
      if (versionData != null) 'version_data': versionData,
      if (payload != null) 'payload': payload,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStagedSiblingsCompanion copyWith({
    Value<SyncCollection>? collection,
    Value<String>? rowId,
    Value<String>? siblingId,
    Value<VersionVector>? versionData,
    Value<Uint8List>? payload,
    Value<int>? lifecycle,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SyncStagedSiblingsCompanion(
      collection: collection ?? this.collection,
      rowId: rowId ?? this.rowId,
      siblingId: siblingId ?? this.siblingId,
      versionData: versionData ?? this.versionData,
      payload: payload ?? this.payload,
      lifecycle: lifecycle ?? this.lifecycle,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(
        $SyncStagedSiblingsTable.$convertercollection.toSql(collection.value),
      );
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (siblingId.present) {
      map['sibling_id'] = Variable<String>(siblingId.value);
    }
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(
        $SyncStagedSiblingsTable.$converterversionData.toSql(versionData.value),
      );
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStagedSiblingsCompanion(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId, ')
          ..write('siblingId: $siblingId, ')
          ..write('versionData: $versionData, ')
          ..write('payload: $payload, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOrphanTombstonesTable extends SyncOrphanTombstones
    with TableInfo<$SyncOrphanTombstonesTable, OrphanTombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOrphanTombstonesTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<SyncCollection, String>
  collection =
      GeneratedColumn<String>(
        'collection',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncCollection>(
        $SyncOrphanTombstonesTable.$convertercollection,
      );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VersionVector, Uint8List>
  versionData =
      GeneratedColumn<Uint8List>(
        'version_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      ).withConverter<VersionVector>(
        $SyncOrphanTombstonesTable.$converterversionData,
      );
  @override
  List<GeneratedColumn> get $columns => [collection, rowId, versionData];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_orphan_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrphanTombstoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, rowId};
  @override
  OrphanTombstoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrphanTombstoneRow(
      collection: $SyncOrphanTombstonesTable.$convertercollection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}collection'],
        )!,
      ),
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      versionData: $SyncOrphanTombstonesTable.$converterversionData.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}version_data'],
        )!,
      ),
    );
  }

  @override
  $SyncOrphanTombstonesTable createAlias(String alias) {
    return $SyncOrphanTombstonesTable(attachedDatabase, alias);
  }

  static TypeConverter<SyncCollection, String> $convertercollection =
      const SyncCollectionConverter();
  static TypeConverter<VersionVector, Uint8List> $converterversionData =
      const VersionVectorConverter();
}

class OrphanTombstoneRow extends DataClass
    implements Insertable<OrphanTombstoneRow> {
  final SyncCollection collection;
  final String rowId;
  final VersionVector versionData;
  const OrphanTombstoneRow({
    required this.collection,
    required this.rowId,
    required this.versionData,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['collection'] = Variable<String>(
        $SyncOrphanTombstonesTable.$convertercollection.toSql(collection),
      );
    }
    map['row_id'] = Variable<String>(rowId);
    {
      map['version_data'] = Variable<Uint8List>(
        $SyncOrphanTombstonesTable.$converterversionData.toSql(versionData),
      );
    }
    return map;
  }

  SyncOrphanTombstonesCompanion toCompanion(bool nullToAbsent) {
    return SyncOrphanTombstonesCompanion(
      collection: Value(collection),
      rowId: Value(rowId),
      versionData: Value(versionData),
    );
  }

  factory OrphanTombstoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrphanTombstoneRow(
      collection: serializer.fromJson<SyncCollection>(json['collection']),
      rowId: serializer.fromJson<String>(json['rowId']),
      versionData: serializer.fromJson<VersionVector>(json['versionData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<SyncCollection>(collection),
      'rowId': serializer.toJson<String>(rowId),
      'versionData': serializer.toJson<VersionVector>(versionData),
    };
  }

  OrphanTombstoneRow copyWith({
    SyncCollection? collection,
    String? rowId,
    VersionVector? versionData,
  }) => OrphanTombstoneRow(
    collection: collection ?? this.collection,
    rowId: rowId ?? this.rowId,
    versionData: versionData ?? this.versionData,
  );
  OrphanTombstoneRow copyWithCompanion(SyncOrphanTombstonesCompanion data) {
    return OrphanTombstoneRow(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      versionData: data.versionData.present
          ? data.versionData.value
          : this.versionData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrphanTombstoneRow(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId, ')
          ..write('versionData: $versionData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, rowId, versionData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrphanTombstoneRow &&
          other.collection == this.collection &&
          other.rowId == this.rowId &&
          other.versionData == this.versionData);
}

class SyncOrphanTombstonesCompanion
    extends UpdateCompanion<OrphanTombstoneRow> {
  final Value<SyncCollection> collection;
  final Value<String> rowId;
  final Value<VersionVector> versionData;
  final Value<int> rowid;
  const SyncOrphanTombstonesCompanion({
    this.collection = const Value.absent(),
    this.rowId = const Value.absent(),
    this.versionData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOrphanTombstonesCompanion.insert({
    required SyncCollection collection,
    required String rowId,
    required VersionVector versionData,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       rowId = Value(rowId),
       versionData = Value(versionData);
  static Insertable<OrphanTombstoneRow> custom({
    Expression<String>? collection,
    Expression<String>? rowId,
    Expression<Uint8List>? versionData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (rowId != null) 'row_id': rowId,
      if (versionData != null) 'version_data': versionData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOrphanTombstonesCompanion copyWith({
    Value<SyncCollection>? collection,
    Value<String>? rowId,
    Value<VersionVector>? versionData,
    Value<int>? rowid,
  }) {
    return SyncOrphanTombstonesCompanion(
      collection: collection ?? this.collection,
      rowId: rowId ?? this.rowId,
      versionData: versionData ?? this.versionData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(
        $SyncOrphanTombstonesTable.$convertercollection.toSql(collection.value),
      );
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (versionData.present) {
      map['version_data'] = Variable<Uint8List>(
        $SyncOrphanTombstonesTable.$converterversionData.toSql(
          versionData.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOrphanTombstonesCompanion(')
          ..write('collection: $collection, ')
          ..write('rowId: $rowId, ')
          ..write('versionData: $versionData, ')
          ..write('rowid: $rowid')
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
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $SyncAcknowledgedVectorsTable syncAcknowledgedVectors =
      $SyncAcknowledgedVectorsTable(this);
  late final $SyncPendingAcknowledgementsTable syncPendingAcknowledgements =
      $SyncPendingAcknowledgementsTable(this);
  late final $SyncStagedConflictsTable syncStagedConflicts =
      $SyncStagedConflictsTable(this);
  late final $SyncStagedSiblingsTable syncStagedSiblings =
      $SyncStagedSiblingsTable(this);
  late final $SyncOrphanTombstonesTable syncOrphanTombstones =
      $SyncOrphanTombstonesTable(this);
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
    syncMeta,
    syncAcknowledgedVectors,
    syncPendingAcknowledgements,
    syncStagedConflicts,
    syncStagedSiblings,
    syncOrphanTombstones,
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
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  Value<int> id,
  Value<String?> backend,
  Value<String?> endpoint,
  Value<int> enrollmentPhase,
  Value<bool> writeEnabled,
  Value<String?> moneySourcesCursor,
  Value<String?> entriesCursor,
  Value<String?> categoriesCursor,
  Value<String?> plansCursor,
  Value<String?> budgetsCursor,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<int> id,
  Value<String?> backend,
  Value<String?> endpoint,
  Value<int> enrollmentPhase,
  Value<bool> writeEnabled,
  Value<String?> moneySourcesCursor,
  Value<String?> entriesCursor,
  Value<String?> categoriesCursor,
  Value<String?> plansCursor,
  Value<String?> budgetsCursor,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
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

  ColumnFilters<String> get backend => $composableBuilder(
    column: $table.backend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enrollmentPhase => $composableBuilder(
    column: $table.enrollmentPhase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get writeEnabled => $composableBuilder(
    column: $table.writeEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moneySourcesCursor => $composableBuilder(
    column: $table.moneySourcesCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entriesCursor => $composableBuilder(
    column: $table.entriesCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriesCursor => $composableBuilder(
    column: $table.categoriesCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plansCursor => $composableBuilder(
    column: $table.plansCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetsCursor => $composableBuilder(
    column: $table.budgetsCursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
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

  ColumnOrderings<String> get backend => $composableBuilder(
    column: $table.backend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enrollmentPhase => $composableBuilder(
    column: $table.enrollmentPhase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get writeEnabled => $composableBuilder(
    column: $table.writeEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moneySourcesCursor => $composableBuilder(
    column: $table.moneySourcesCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entriesCursor => $composableBuilder(
    column: $table.entriesCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriesCursor => $composableBuilder(
    column: $table.categoriesCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plansCursor => $composableBuilder(
    column: $table.plansCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetsCursor => $composableBuilder(
    column: $table.budgetsCursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get backend =>
      $composableBuilder(column: $table.backend, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<int> get enrollmentPhase => $composableBuilder(
    column: $table.enrollmentPhase,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get writeEnabled => $composableBuilder(
    column: $table.writeEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get moneySourcesCursor => $composableBuilder(
    column: $table.moneySourcesCursor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entriesCursor => $composableBuilder(
    column: $table.entriesCursor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriesCursor => $composableBuilder(
    column: $table.categoriesCursor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plansCursor => $composableBuilder(
    column: $table.plansCursor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetsCursor => $composableBuilder(
    column: $table.budgetsCursor,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncMetaTable,
          SyncMetadataRow,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetadataRow,
            BaseReferences<_$LedgerDatabase, $SyncMetaTable, SyncMetadataRow>,
          ),
          SyncMetadataRow,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$LedgerDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> backend = const Value.absent(),
                Value<String?> endpoint = const Value.absent(),
                Value<int> enrollmentPhase = const Value.absent(),
                Value<bool> writeEnabled = const Value.absent(),
                Value<String?> moneySourcesCursor = const Value.absent(),
                Value<String?> entriesCursor = const Value.absent(),
                Value<String?> categoriesCursor = const Value.absent(),
                Value<String?> plansCursor = const Value.absent(),
                Value<String?> budgetsCursor = const Value.absent(),
              }) => SyncMetaCompanion(
                id: id,
                backend: backend,
                endpoint: endpoint,
                enrollmentPhase: enrollmentPhase,
                writeEnabled: writeEnabled,
                moneySourcesCursor: moneySourcesCursor,
                entriesCursor: entriesCursor,
                categoriesCursor: categoriesCursor,
                plansCursor: plansCursor,
                budgetsCursor: budgetsCursor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> backend = const Value.absent(),
                Value<String?> endpoint = const Value.absent(),
                Value<int> enrollmentPhase = const Value.absent(),
                Value<bool> writeEnabled = const Value.absent(),
                Value<String?> moneySourcesCursor = const Value.absent(),
                Value<String?> entriesCursor = const Value.absent(),
                Value<String?> categoriesCursor = const Value.absent(),
                Value<String?> plansCursor = const Value.absent(),
                Value<String?> budgetsCursor = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                id: id,
                backend: backend,
                endpoint: endpoint,
                enrollmentPhase: enrollmentPhase,
                writeEnabled: writeEnabled,
                moneySourcesCursor: moneySourcesCursor,
                entriesCursor: entriesCursor,
                categoriesCursor: categoriesCursor,
                plansCursor: plansCursor,
                budgetsCursor: budgetsCursor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetaTable, SyncMetadataRow>(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncMetaTable,
                    SyncMetadataRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncMetaTable,
      SyncMetadataRow,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetadataRow,
        BaseReferences<_$LedgerDatabase, $SyncMetaTable, SyncMetadataRow>,
      ),
      SyncMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$SyncAcknowledgedVectorsTableCreateCompanionBuilder =
    SyncAcknowledgedVectorsCompanion Function({
      required SyncCollection collection,
      required String rowId,
      required VersionVector versionData,
      Value<int> rowid,
    });
typedef $$SyncAcknowledgedVectorsTableUpdateCompanionBuilder =
    SyncAcknowledgedVectorsCompanion Function({
      Value<SyncCollection> collection,
      Value<String> rowId,
      Value<VersionVector> versionData,
      Value<int> rowid,
    });

class $$SyncAcknowledgedVectorsTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncAcknowledgedVectorsTable> {
  $$SyncAcknowledgedVectorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<SyncCollection, SyncCollection, String>
  get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VersionVector, VersionVector, Uint8List>
  get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$SyncAcknowledgedVectorsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncAcknowledgedVectorsTable> {
  $$SyncAcknowledgedVectorsTableOrderingComposer({
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

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncAcknowledgedVectorsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncAcknowledgedVectorsTable> {
  $$SyncAcknowledgedVectorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<SyncCollection, String> get collection =>
      $composableBuilder(
        column: $table.collection,
        builder: (column) => column,
      );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<VersionVector, Uint8List> get versionData =>
      $composableBuilder(
        column: $table.versionData,
        builder: (column) => column,
      );
}

class $$SyncAcknowledgedVectorsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncAcknowledgedVectorsTable,
          AcknowledgedVectorRow,
          $$SyncAcknowledgedVectorsTableFilterComposer,
          $$SyncAcknowledgedVectorsTableOrderingComposer,
          $$SyncAcknowledgedVectorsTableAnnotationComposer,
          $$SyncAcknowledgedVectorsTableCreateCompanionBuilder,
          $$SyncAcknowledgedVectorsTableUpdateCompanionBuilder,
          (
            AcknowledgedVectorRow,
            BaseReferences<
              _$LedgerDatabase,
              $SyncAcknowledgedVectorsTable,
              AcknowledgedVectorRow
            >,
          ),
          AcknowledgedVectorRow,
          PrefetchHooks Function()
        > {
  $$SyncAcknowledgedVectorsTableTableManager(
    _$LedgerDatabase db,
    $SyncAcknowledgedVectorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncAcknowledgedVectorsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SyncAcknowledgedVectorsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncAcknowledgedVectorsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<SyncCollection> collection = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<VersionVector> versionData = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncAcknowledgedVectorsCompanion(
                collection: collection,
                rowId: rowId,
                versionData: versionData,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required SyncCollection collection,
                required String rowId,
                required VersionVector versionData,
                Value<int> rowid = const Value.absent(),
              }) => SyncAcknowledgedVectorsCompanion.insert(
                collection: collection,
                rowId: rowId,
                versionData: versionData,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SyncAcknowledgedVectorsTable,
                    AcknowledgedVectorRow
                  >(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncAcknowledgedVectorsTable,
                    AcknowledgedVectorRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncAcknowledgedVectorsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncAcknowledgedVectorsTable,
      AcknowledgedVectorRow,
      $$SyncAcknowledgedVectorsTableFilterComposer,
      $$SyncAcknowledgedVectorsTableOrderingComposer,
      $$SyncAcknowledgedVectorsTableAnnotationComposer,
      $$SyncAcknowledgedVectorsTableCreateCompanionBuilder,
      $$SyncAcknowledgedVectorsTableUpdateCompanionBuilder,
      (
        AcknowledgedVectorRow,
        BaseReferences<
          _$LedgerDatabase,
          $SyncAcknowledgedVectorsTable,
          AcknowledgedVectorRow
        >,
      ),
      AcknowledgedVectorRow,
      PrefetchHooks Function()
    >;
typedef $$SyncPendingAcknowledgementsTableCreateCompanionBuilder =
    SyncPendingAcknowledgementsCompanion Function({
      required SyncCollection collection,
      required String checkpoint,
      Value<int> rowid,
    });
typedef $$SyncPendingAcknowledgementsTableUpdateCompanionBuilder =
    SyncPendingAcknowledgementsCompanion Function({
      Value<SyncCollection> collection,
      Value<String> checkpoint,
      Value<int> rowid,
    });

class $$SyncPendingAcknowledgementsTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncPendingAcknowledgementsTable> {
  $$SyncPendingAcknowledgementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<SyncCollection, SyncCollection, String>
  get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncPendingAcknowledgementsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncPendingAcknowledgementsTable> {
  $$SyncPendingAcknowledgementsTableOrderingComposer({
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

class $$SyncPendingAcknowledgementsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncPendingAcknowledgementsTable> {
  $$SyncPendingAcknowledgementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<SyncCollection, String> get collection =>
      $composableBuilder(
        column: $table.collection,
        builder: (column) => column,
      );

  GeneratedColumn<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => column,
  );
}

class $$SyncPendingAcknowledgementsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncPendingAcknowledgementsTable,
          PendingAcknowledgementRow,
          $$SyncPendingAcknowledgementsTableFilterComposer,
          $$SyncPendingAcknowledgementsTableOrderingComposer,
          $$SyncPendingAcknowledgementsTableAnnotationComposer,
          $$SyncPendingAcknowledgementsTableCreateCompanionBuilder,
          $$SyncPendingAcknowledgementsTableUpdateCompanionBuilder,
          (
            PendingAcknowledgementRow,
            BaseReferences<
              _$LedgerDatabase,
              $SyncPendingAcknowledgementsTable,
              PendingAcknowledgementRow
            >,
          ),
          PendingAcknowledgementRow,
          PrefetchHooks Function()
        > {
  $$SyncPendingAcknowledgementsTableTableManager(
    _$LedgerDatabase db,
    $SyncPendingAcknowledgementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncPendingAcknowledgementsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SyncPendingAcknowledgementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncPendingAcknowledgementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<SyncCollection> collection = const Value.absent(),
                Value<String> checkpoint = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncPendingAcknowledgementsCompanion(
                collection: collection,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required SyncCollection collection,
                required String checkpoint,
                Value<int> rowid = const Value.absent(),
              }) => SyncPendingAcknowledgementsCompanion.insert(
                collection: collection,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SyncPendingAcknowledgementsTable,
                    PendingAcknowledgementRow
                  >(table),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncPendingAcknowledgementsTable,
                    PendingAcknowledgementRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncPendingAcknowledgementsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncPendingAcknowledgementsTable,
      PendingAcknowledgementRow,
      $$SyncPendingAcknowledgementsTableFilterComposer,
      $$SyncPendingAcknowledgementsTableOrderingComposer,
      $$SyncPendingAcknowledgementsTableAnnotationComposer,
      $$SyncPendingAcknowledgementsTableCreateCompanionBuilder,
      $$SyncPendingAcknowledgementsTableUpdateCompanionBuilder,
      (
        PendingAcknowledgementRow,
        BaseReferences<
          _$LedgerDatabase,
          $SyncPendingAcknowledgementsTable,
          PendingAcknowledgementRow
        >,
      ),
      PendingAcknowledgementRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStagedConflictsTableCreateCompanionBuilder =
    SyncStagedConflictsCompanion Function({
      required SyncCollection collection,
      required String rowId,
      Value<int> rowid,
    });
typedef $$SyncStagedConflictsTableUpdateCompanionBuilder =
    SyncStagedConflictsCompanion Function({
      Value<SyncCollection> collection,
      Value<String> rowId,
      Value<int> rowid,
    });

class $$SyncStagedConflictsTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncStagedConflictsTable> {
  $$SyncStagedConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<SyncCollection, SyncCollection, String>
  get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStagedConflictsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncStagedConflictsTable> {
  $$SyncStagedConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStagedConflictsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncStagedConflictsTable> {
  $$SyncStagedConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<SyncCollection, String> get collection =>
      $composableBuilder(
        column: $table.collection,
        builder: (column) => column,
      );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);
}

class $$SyncStagedConflictsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncStagedConflictsTable,
          StagedConflictRow,
          $$SyncStagedConflictsTableFilterComposer,
          $$SyncStagedConflictsTableOrderingComposer,
          $$SyncStagedConflictsTableAnnotationComposer,
          $$SyncStagedConflictsTableCreateCompanionBuilder,
          $$SyncStagedConflictsTableUpdateCompanionBuilder,
          (
            StagedConflictRow,
            BaseReferences<
              _$LedgerDatabase,
              $SyncStagedConflictsTable,
              StagedConflictRow
            >,
          ),
          StagedConflictRow,
          PrefetchHooks Function()
        > {
  $$SyncStagedConflictsTableTableManager(
    _$LedgerDatabase db,
    $SyncStagedConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStagedConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStagedConflictsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncStagedConflictsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<SyncCollection> collection = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStagedConflictsCompanion(
                collection: collection,
                rowId: rowId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required SyncCollection collection,
                required String rowId,
                Value<int> rowid = const Value.absent(),
              }) => SyncStagedConflictsCompanion.insert(
                collection: collection,
                rowId: rowId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStagedConflictsTable, StagedConflictRow>(
                    table,
                  ),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncStagedConflictsTable,
                    StagedConflictRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStagedConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncStagedConflictsTable,
      StagedConflictRow,
      $$SyncStagedConflictsTableFilterComposer,
      $$SyncStagedConflictsTableOrderingComposer,
      $$SyncStagedConflictsTableAnnotationComposer,
      $$SyncStagedConflictsTableCreateCompanionBuilder,
      $$SyncStagedConflictsTableUpdateCompanionBuilder,
      (
        StagedConflictRow,
        BaseReferences<
          _$LedgerDatabase,
          $SyncStagedConflictsTable,
          StagedConflictRow
        >,
      ),
      StagedConflictRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStagedSiblingsTableCreateCompanionBuilder =
    SyncStagedSiblingsCompanion Function({
      required SyncCollection collection,
      required String rowId,
      required String siblingId,
      required VersionVector versionData,
      required Uint8List payload,
      required int lifecycle,
      required int position,
      Value<int> rowid,
    });
typedef $$SyncStagedSiblingsTableUpdateCompanionBuilder =
    SyncStagedSiblingsCompanion Function({
      Value<SyncCollection> collection,
      Value<String> rowId,
      Value<String> siblingId,
      Value<VersionVector> versionData,
      Value<Uint8List> payload,
      Value<int> lifecycle,
      Value<int> position,
      Value<int> rowid,
    });

class $$SyncStagedSiblingsTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncStagedSiblingsTable> {
  $$SyncStagedSiblingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<SyncCollection, SyncCollection, String>
  get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siblingId => $composableBuilder(
    column: $table.siblingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VersionVector, VersionVector, Uint8List>
  get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStagedSiblingsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncStagedSiblingsTable> {
  $$SyncStagedSiblingsTableOrderingComposer({
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

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siblingId => $composableBuilder(
    column: $table.siblingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStagedSiblingsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncStagedSiblingsTable> {
  $$SyncStagedSiblingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<SyncCollection, String> get collection =>
      $composableBuilder(
        column: $table.collection,
        builder: (column) => column,
      );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get siblingId =>
      $composableBuilder(column: $table.siblingId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<VersionVector, Uint8List> get versionData =>
      $composableBuilder(
        column: $table.versionData,
        builder: (column) => column,
      );

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$SyncStagedSiblingsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncStagedSiblingsTable,
          StagedSiblingRow,
          $$SyncStagedSiblingsTableFilterComposer,
          $$SyncStagedSiblingsTableOrderingComposer,
          $$SyncStagedSiblingsTableAnnotationComposer,
          $$SyncStagedSiblingsTableCreateCompanionBuilder,
          $$SyncStagedSiblingsTableUpdateCompanionBuilder,
          (
            StagedSiblingRow,
            BaseReferences<
              _$LedgerDatabase,
              $SyncStagedSiblingsTable,
              StagedSiblingRow
            >,
          ),
          StagedSiblingRow,
          PrefetchHooks Function()
        > {
  $$SyncStagedSiblingsTableTableManager(
    _$LedgerDatabase db,
    $SyncStagedSiblingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStagedSiblingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStagedSiblingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStagedSiblingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<SyncCollection> collection = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> siblingId = const Value.absent(),
                Value<VersionVector> versionData = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStagedSiblingsCompanion(
                collection: collection,
                rowId: rowId,
                siblingId: siblingId,
                versionData: versionData,
                payload: payload,
                lifecycle: lifecycle,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required SyncCollection collection,
                required String rowId,
                required String siblingId,
                required VersionVector versionData,
                required Uint8List payload,
                required int lifecycle,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => SyncStagedSiblingsCompanion.insert(
                collection: collection,
                rowId: rowId,
                siblingId: siblingId,
                versionData: versionData,
                payload: payload,
                lifecycle: lifecycle,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStagedSiblingsTable, StagedSiblingRow>(
                    table,
                  ),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncStagedSiblingsTable,
                    StagedSiblingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStagedSiblingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncStagedSiblingsTable,
      StagedSiblingRow,
      $$SyncStagedSiblingsTableFilterComposer,
      $$SyncStagedSiblingsTableOrderingComposer,
      $$SyncStagedSiblingsTableAnnotationComposer,
      $$SyncStagedSiblingsTableCreateCompanionBuilder,
      $$SyncStagedSiblingsTableUpdateCompanionBuilder,
      (
        StagedSiblingRow,
        BaseReferences<
          _$LedgerDatabase,
          $SyncStagedSiblingsTable,
          StagedSiblingRow
        >,
      ),
      StagedSiblingRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOrphanTombstonesTableCreateCompanionBuilder =
    SyncOrphanTombstonesCompanion Function({
      required SyncCollection collection,
      required String rowId,
      required VersionVector versionData,
      Value<int> rowid,
    });
typedef $$SyncOrphanTombstonesTableUpdateCompanionBuilder =
    SyncOrphanTombstonesCompanion Function({
      Value<SyncCollection> collection,
      Value<String> rowId,
      Value<VersionVector> versionData,
      Value<int> rowid,
    });

class $$SyncOrphanTombstonesTableFilterComposer
    extends Composer<_$LedgerDatabase, $SyncOrphanTombstonesTable> {
  $$SyncOrphanTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<SyncCollection, SyncCollection, String>
  get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VersionVector, VersionVector, Uint8List>
  get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$SyncOrphanTombstonesTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SyncOrphanTombstonesTable> {
  $$SyncOrphanTombstonesTableOrderingComposer({
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

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get versionData => $composableBuilder(
    column: $table.versionData,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOrphanTombstonesTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SyncOrphanTombstonesTable> {
  $$SyncOrphanTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<SyncCollection, String> get collection =>
      $composableBuilder(
        column: $table.collection,
        builder: (column) => column,
      );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<VersionVector, Uint8List> get versionData =>
      $composableBuilder(
        column: $table.versionData,
        builder: (column) => column,
      );
}

class $$SyncOrphanTombstonesTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SyncOrphanTombstonesTable,
          OrphanTombstoneRow,
          $$SyncOrphanTombstonesTableFilterComposer,
          $$SyncOrphanTombstonesTableOrderingComposer,
          $$SyncOrphanTombstonesTableAnnotationComposer,
          $$SyncOrphanTombstonesTableCreateCompanionBuilder,
          $$SyncOrphanTombstonesTableUpdateCompanionBuilder,
          (
            OrphanTombstoneRow,
            BaseReferences<
              _$LedgerDatabase,
              $SyncOrphanTombstonesTable,
              OrphanTombstoneRow
            >,
          ),
          OrphanTombstoneRow,
          PrefetchHooks Function()
        > {
  $$SyncOrphanTombstonesTableTableManager(
    _$LedgerDatabase db,
    $SyncOrphanTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOrphanTombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOrphanTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncOrphanTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<SyncCollection> collection = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<VersionVector> versionData = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOrphanTombstonesCompanion(
                collection: collection,
                rowId: rowId,
                versionData: versionData,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required SyncCollection collection,
                required String rowId,
                required VersionVector versionData,
                Value<int> rowid = const Value.absent(),
              }) => SyncOrphanTombstonesCompanion.insert(
                collection: collection,
                rowId: rowId,
                versionData: versionData,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOrphanTombstonesTable, OrphanTombstoneRow>(
                    table,
                  ),
                  BaseReferences<
                    _$LedgerDatabase,
                    $SyncOrphanTombstonesTable,
                    OrphanTombstoneRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOrphanTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SyncOrphanTombstonesTable,
      OrphanTombstoneRow,
      $$SyncOrphanTombstonesTableFilterComposer,
      $$SyncOrphanTombstonesTableOrderingComposer,
      $$SyncOrphanTombstonesTableAnnotationComposer,
      $$SyncOrphanTombstonesTableCreateCompanionBuilder,
      $$SyncOrphanTombstonesTableUpdateCompanionBuilder,
      (
        OrphanTombstoneRow,
        BaseReferences<
          _$LedgerDatabase,
          $SyncOrphanTombstonesTable,
          OrphanTombstoneRow
        >,
      ),
      OrphanTombstoneRow,
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
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$SyncAcknowledgedVectorsTableTableManager get syncAcknowledgedVectors =>
      $$SyncAcknowledgedVectorsTableTableManager(
        _db,
        _db.syncAcknowledgedVectors,
      );
  $$SyncPendingAcknowledgementsTableTableManager
  get syncPendingAcknowledgements =>
      $$SyncPendingAcknowledgementsTableTableManager(
        _db,
        _db.syncPendingAcknowledgements,
      );
  $$SyncStagedConflictsTableTableManager get syncStagedConflicts =>
      $$SyncStagedConflictsTableTableManager(_db, _db.syncStagedConflicts);
  $$SyncStagedSiblingsTableTableManager get syncStagedSiblings =>
      $$SyncStagedSiblingsTableTableManager(_db, _db.syncStagedSiblings);
  $$SyncOrphanTombstonesTableTableManager get syncOrphanTombstones =>
      $$SyncOrphanTombstonesTableTableManager(_db, _db.syncOrphanTombstones);
}
