import 'package:ocr/ocr.dart';

// 75% of the shorter line's height is the point past which two ML Kit
// lines reliably belong to the same printed row rather than two adjacent
// ones that happen to touch.
const _minVerticalOverlapFraction = 0.75;

/// Groups lines into visual rows by vertical overlap. Within a row, lines
/// are ordered left to right. Rows are ordered top to bottom by their
/// earliest line, falling back to original input order for ties or when a
/// row has no geometry to sort by.
List<List<RecognizedLine>> groupIntoRows(List<RecognizedLine> lines) {
  final rows = <_Row>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final bounds = line.bounds;
    // A line with no geometry can't be compared for vertical overlap, so it
    // gets its own row rather than being dropped or guessed at.
    final row = bounds == null ? null : _rowToJoin(rows, bounds);
    if (row != null) {
      row.add(line, bounds, i);
    } else {
      rows.add(_Row()..add(line, bounds, i));
    }
  }

  rows.sort(_compareRows);
  return rows.map((row) => row.sortedLines()).toList();
}

/// Joins rows into a single block of reading-order text: one row per line,
/// lines within a row separated by a single space.
String toReadingOrderText(List<RecognizedLine> lines) {
  return groupIntoRows(
    lines,
  ).map((row) => row.map((line) => line.text).join(' ')).join('\n');
}

_Row? _rowToJoin(List<_Row> rows, RecognizedLineBounds bounds) {
  for (final row in rows) {
    if (row.overlapsEnoughToJoin(bounds)) return row;
  }
  return null;
}

int _compareRows(_Row a, _Row b) {
  final aTop = a.top;
  final bTop = b.top;
  // A row with no geometry has nothing to compare tops against, so it
  // falls back to where it originally appeared in the input.
  if (aTop != null && bTop != null) {
    final topCompare = aTop.compareTo(bTop);
    if (topCompare != 0) return topCompare;
  }
  return a.firstIndex.compareTo(b.firstIndex);
}

// Tracks the row's envelope (min top, max bottom) so a candidate is
// compared against the whole row, not just one existing member.
class _Row {
  final _lines = <RecognizedLine>[];
  double? _top;
  double? _bottom;
  int firstIndex = 0;

  double? get top => _top;

  void add(RecognizedLine line, RecognizedLineBounds? bounds, int index) {
    if (_lines.isEmpty) firstIndex = index;
    _lines.add(line);
    if (bounds == null) return;
    _top = _top == null ? bounds.top : _min(_top!, bounds.top);
    _bottom = _bottom == null ? bounds.bottom : _max(_bottom!, bounds.bottom);
  }

  bool overlapsEnoughToJoin(RecognizedLineBounds bounds) {
    final top = _top;
    final bottom = _bottom;
    if (top == null || bottom == null) return false;

    final overlap = _clampedOverlap(top, bottom, bounds.top, bounds.bottom);
    final shorterHeight = _min(bottom - top, bounds.height);
    if (shorterHeight <= 0) return false;

    return overlap / shorterHeight >= _minVerticalOverlapFraction;
  }

  List<RecognizedLine> sortedLines() {
    final sorted = [..._lines];
    sorted.sort((a, b) => _left(a).compareTo(_left(b)));
    return sorted;
  }
}

double _clampedOverlap(
  double top1,
  double bottom1,
  double top2,
  double bottom2,
) {
  final overlap = _min(bottom1, bottom2) - _max(top1, top2);
  return overlap < 0 ? 0 : overlap;
}

double _left(RecognizedLine line) => line.bounds?.left ?? 0;

double _min(double a, double b) => a < b ? a : b;

double _max(double a, double b) => a > b ? a : b;
