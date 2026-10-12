part of 'mappers.dart';

// MARK: - Codes

AccountType _accountType(int code) => switch (code) {
  0 => AccountType.cash,
  1 => AccountType.checking,
  2 => AccountType.savings,
  3 => AccountType.card,
  4 => AccountType.prepaid,
  5 => AccountType.investment,
  6 => AccountType.insurance,
  8 => AccountType.loan,
  9 => AccountType.overdraft,
  _ => AccountType.other,
};

CategoryKind _categoryKind(int code) => code == CategoryKind.income.code
    ? CategoryKind.income
    : CategoryKind.expense;

LifecycleState _lifecycle(int code) => switch (code) {
  1 => LifecycleState.archived,
  2 => LifecycleState.referenceOnly,
  3 => LifecycleState.tombstoned,
  _ => LifecycleState.active,
};

RecurrenceFrequency _frequency(int code) => switch (code) {
  0 => RecurrenceFrequency.weekly,
  1 => RecurrenceFrequency.biweekly,
  3 => RecurrenceFrequency.quarterly,
  4 => RecurrenceFrequency.yearly,
  _ => RecurrenceFrequency.monthly,
};

// MARK: - Versions

VersionVector versionFromRow(Uint8List blob) => VersionVector.decode(blob);

Uint8List _versionToBlob(VersionVector version) =>
    Uint8List.fromList(version.encode());

// MARK: - Days

DateTime dayFromMillis(int millis) =>
    startOfDayUtc(DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true));

int millisFromDay(DateTime date) => date.millisecondsSinceEpoch;
