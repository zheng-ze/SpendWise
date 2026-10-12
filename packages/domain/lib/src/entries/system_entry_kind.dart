enum SystemEntryKind {
  openingBalance(0),
  balanceAdjustment(1);

  const SystemEntryKind(this.code);

  final int code;

  static SystemEntryKind? fromCode(int? code) => switch (code) {
    0 => openingBalance,
    1 => balanceAdjustment,
    _ => null,
  };
}
