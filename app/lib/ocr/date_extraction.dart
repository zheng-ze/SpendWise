import 'dart:ui' show PlatformDispatcher;

import 'package:ocr/ocr.dart';

const _monthFirstRegions = {'US', 'PH', 'PW', 'FM', 'CA'};

const _monthsInYear = 12;
const _firstDateComponentGroup = 1;
const _secondDateComponentGroup = 2;
const _yearComponentGroup = 3;
const _fourDigitYearLength = 4;
const _twoDigitYearCenturyBase = 2000;

final _dateShapedPattern = RegExp(
  r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2}|\d{4})\b',
);

DateTime extractDate(RecognizedText text, {String? locale, DateTime? now}) {
  for (final line in text.lines) {
    final match = _dateShapedPattern.firstMatch(line.text);
    if (match == null) continue;

    final parsed = _resolveDate(match, locale);
    if (parsed != null) return parsed;
  }

  return _today(now);
}

DateTime _today(DateTime? now) {
  final today = now ?? DateTime.now();
  return DateTime.utc(today.year, today.month, today.day);
}

DateTime? _resolveDate(RegExpMatch match, String? locale) {
  final first = int.parse(match.group(_firstDateComponentGroup)!);
  final second = int.parse(match.group(_secondDateComponentGroup)!);
  final year = _fullYear(match.group(_yearComponentGroup)!);

  int day;
  int month;
  if (first > _monthsInYear && second <= _monthsInYear) {
    day = first;
    month = second;
  } else if (second > _monthsInYear && first <= _monthsInYear) {
    day = second;
    month = first;
  } else if (first > _monthsInYear && second > _monthsInYear) {
    return null;
  } else if (_localeIsDayFirst(locale)) {
    day = first;
    month = second;
  } else {
    day = second;
    month = first;
  }

  return DateTime.utc(year, month, day);
}

int _fullYear(String yearText) {
  if (yearText.length == _fourDigitYearLength) return int.parse(yearText);
  return _twoDigitYearCenturyBase + int.parse(yearText);
}

bool _localeIsDayFirst(String? locale) {
  final region = locale != null
      ? _regionOf(locale)
      : PlatformDispatcher.instance.locale.countryCode;
  return !_monthFirstRegions.contains(region);
}

String? _regionOf(String locale) {
  final parts = locale.split(RegExp('[_-]'));
  return parts.length > 1 ? parts.last.toUpperCase() : null;
}
