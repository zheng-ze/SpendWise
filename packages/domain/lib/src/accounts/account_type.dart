enum AccountType {
  cash(0),
  checking(1),
  savings(2),
  card(3),
  prepaid(4),
  investment(5),
  insurance(6),
  other(7),
  loan(8),
  overdraft(9);

  const AccountType(this.code);

  final int code;

  bool get allowsTransfersAsExpense => switch (this) {
    cash || checking || card || prepaid => false,
    savings || investment || insurance || other || loan || overdraft => true,
  };

  static AccountType fromCode(int code) {
    return switch (code) {
      0 => cash,
      1 => checking,
      2 => savings,
      3 => card,
      4 => prepaid,
      5 => investment,
      6 => insurance,
      7 => other,
      8 => loan,
      9 => overdraft,
      _ => throw ArgumentError.value(code, 'code', 'Unknown AccountType'),
    };
  }
}
