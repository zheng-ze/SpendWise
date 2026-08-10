import 'package:meta/meta.dart';

/// Half-open `[start, end)`. Adjacent ranges sharing an instant place it in the
/// later one, so windows tiled end-to-end never double-count a boundary item.
@immutable
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  @override
  bool operator ==(Object other) {
    return other is DateRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}
