enum CategoryKind {
  income(0),
  expense(1);

  const CategoryKind(this.code);

  final int code;

  static CategoryKind fromCode(int code) {
    return switch (code) {
      0 => income,
      1 => expense,
      _ => throw ArgumentError.value(code, 'code', 'Unknown CategoryKind'),
    };
  }
}
