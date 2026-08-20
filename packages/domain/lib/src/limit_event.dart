import 'package:decimal/decimal.dart';
import 'package:domain/src/year_month.dart';
import 'package:meta/meta.dart';

enum LimitEventKind {
  defaultLimit(0),
  override(1);

  const LimitEventKind(this.code);

  final int code;

  static LimitEventKind fromCode(int code) {
    return switch (code) {
      0 => defaultLimit,
      1 => override,
      _ => throw ArgumentError.value(code, 'code', 'Unknown LimitEventKind'),
    };
  }
}

@immutable
class LimitEvent {
  const LimitEvent({
    required this.effectiveFromMonth,
    required this.value,
    required this.kind,
  });

  final YearMonth? effectiveFromMonth;
  final Decimal value;
  final LimitEventKind kind;

  @override
  bool operator ==(Object other) =>
      other is LimitEvent &&
      other.effectiveFromMonth == effectiveFromMonth &&
      other.value == value &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(effectiveFromMonth, value, kind);

  @override
  String toString() => 'LimitEvent(${kind.name}, $effectiveFromMonth, $value)';
}
