enum LifecycleState {
  active(0),
  archived(1),
  referenceOnly(2),

  /// Used for persistence only.
  tombstoned(3);

  const LifecycleState(this.code);

  final int code;

  static LifecycleState fromCode(int code) {
    return switch (code) {
      0 => active,
      1 => archived,
      2 => referenceOnly,
      3 => tombstoned,
      _ => throw ArgumentError.value(code, 'code', 'Unknown LifecycleState'),
    };
  }

  bool get isActive => this == active;
}
