import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('startOfDayUtcKeepsTheCalendarDayItNames', () {
    expect(
      startOfDayUtc(DateTime(2026, 3, 14, 23, 59)),
      DateTime.utc(2026, 3, 14),
    );
  });

  test('shiftMonthThenClampDayClampsTheRequestedDayIntoTheShiftedMonth', () {
    final from = DateTime.utc(2026, 3, 31);

    // A naive DateTime.utc(y, m - 1, 31) overflows to March 3rd.
    expect(
      shiftMonthThenClampDayUtc(from, -1, day: 31),
      DateTime.utc(2026, 2, 28),
    );
    expect(
      shiftMonthThenClampDayUtc(from, -1, day: 25),
      DateTime.utc(2026, 2, 25),
    );
    expect(
      shiftMonthThenClampDayUtc(from, 0, day: 31),
      DateTime.utc(2026, 3, 31),
    );
  });

  test('shiftMonthThenClampDayClampsToFebruary29InALeapYear', () {
    expect(
      shiftMonthThenClampDayUtc(DateTime.utc(2028, 1, 15), 1, day: 31),
      DateTime.utc(2028, 2, 29),
    );
  });

  test('shiftMonthThenClampDayCrossesTheYearBoundaryInBothDirections', () {
    expect(
      shiftMonthThenClampDayUtc(DateTime.utc(2026, 1, 15), -1, day: 25),
      DateTime.utc(2025, 12, 25),
    );
    expect(
      shiftMonthThenClampDayUtc(DateTime.utc(2026, 12, 15), 1, day: 3),
      DateTime.utc(2027, 1, 3),
    );
    expect(
      shiftMonthThenClampDayUtc(DateTime.utc(2026, 1, 15), -14, day: 30),
      DateTime.utc(2024, 11, 30),
    );
  });

  test('shiftMonthThenClampDayIgnoresTheSourceDayOfMonth', () {
    expect(
      shiftMonthThenClampDayUtc(DateTime.utc(2026, 3, 31), -2, day: 1),
      DateTime.utc(2026, 1, 1),
    );
    expect(
      shiftMonthThenClampDayUtc(DateTime.utc(2026, 3, 1), -2, day: 1),
      DateTime.utc(2026, 1, 1),
    );
  });

  test('shiftMonthThenClampDayLandsInTheShiftedMonthNotTheClampedOne', () {
    expect(
      shiftMonthThenClampDayUtc(DateTime.utc(2026, 1, 15), 1, day: 30),
      DateTime.utc(2026, 2, 28),
    );
  });
}
