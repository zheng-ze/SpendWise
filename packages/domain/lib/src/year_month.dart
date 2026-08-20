import 'package:meta/meta.dart';

@immutable
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);

  YearMonth.fromUtc(DateTime date) : year = date.year, month = date.month;

  final int year;
  final int month;

  @override
  int compareTo(YearMonth other) {
    final years = year.compareTo(other.year);
    if (years != 0) return years;
    return month.compareTo(other.month);
  }

  bool operator <(YearMonth other) => compareTo(other) < 0;
  bool operator <=(YearMonth other) => compareTo(other) <= 0;
  bool operator >(YearMonth other) => compareTo(other) > 0;
  bool operator >=(YearMonth other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'YearMonth($year-$month)';
}
