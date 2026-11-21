import 'package:domain/domain.dart';

// MARK: - Helpers
DateRange yearWindow(DateTime year) {
  final start = DateTime.utc(year.year);
  final end = DateTime.utc(year.year + 1);
  return DateRange(start, end);
}
