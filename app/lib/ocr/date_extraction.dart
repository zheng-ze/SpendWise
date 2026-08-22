import 'dart:ui' show PlatformDispatcher;

import 'package:ocr/ocr.dart';

// Regions that write numeric dates month first (M/d/y). Everywhere else
// defaults to day first (d/M/y), the more common order worldwide.
const _monthFirstRegions = {'US', 'PH', 'PW', 'FM', 'CA'};

final _dateShapedPattern = RegExp(
  r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2}|\d{4})\b',
);

/// Extracts the receipt's date, defaulting to today when no date-shaped text
/// is found. [locale] lets a test fix the day/month order instead of reading
/// the device locale. [now] lets a test fix what "today" means.
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
  final first = int.parse(match.group(1)!);
  final second = int.parse(match.group(2)!);
  final year = _fullYear(match.group(3)!);

  int day;
  int month;
  if (first > 12 && second <= 12) {
    day = first;
    month = second;
  } else if (second > 12 && first <= 12) {
    day = second;
    month = first;
  } else if (first > 12 && second > 12) {
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
  if (yearText.length == 4) return int.parse(yearText);
  return 2000 + int.parse(yearText);
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
