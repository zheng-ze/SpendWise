import 'dart:ui';

// MARK: - Constants

const _emptyRect = Rect.zero;

const _emptyExtent = 0.0;

// MARK: - Treemap Layout

List<Rect> layoutCategoryMap(List<double> values, Size size) {
  final rects = List<Rect>.filled(values.length, _emptyRect);
  if (values.isEmpty ||
      size.width <= _emptyExtent ||
      size.height <= _emptyExtent) {
    return rects;
  }
  final total = values.fold<double>(_emptyExtent, (sum, value) => sum + value);
  if (total <= _emptyExtent) return rects;
  final scale = size.width * size.height / total;
  final order = List<int>.generate(values.length, (i) => i)
    ..sort((a, b) => values[b].compareTo(values[a]));

  var remaining = Rect.fromLTWH(
    _emptyExtent,
    _emptyExtent,
    size.width,
    size.height,
  );
  var row = <int>[];
  var rowArea = _emptyExtent;

  double worstOf(List<int> candidate, double area) {
    final side = remaining.width < remaining.height
        ? remaining.width
        : remaining.height;
    final thickness = area / side;
    var worst = _emptyExtent;
    for (final i in candidate) {
      final length = values[i] * scale / thickness;
      final ratio = thickness > length
          ? thickness / length
          : length / thickness;
      if (ratio > worst) worst = ratio;
    }
    return worst;
  }

  void layoutRow() {
    if (row.isEmpty) return;
    if (remaining.width < remaining.height) {
      final stripHeight = rowArea / remaining.width;
      var x = remaining.left;
      for (final i in row) {
        final width = values[i] * scale / stripHeight;
        rects[i] = Rect.fromLTWH(x, remaining.top, width, stripHeight);
        x += width;
      }
      remaining = Rect.fromLTWH(
        remaining.left,
        remaining.top + stripHeight,
        remaining.width,
        remaining.height - stripHeight,
      );
    } else {
      final stripWidth = rowArea / remaining.height;
      var y = remaining.top;
      for (final i in row) {
        final height = values[i] * scale / stripWidth;
        rects[i] = Rect.fromLTWH(remaining.left, y, stripWidth, height);
        y += height;
      }
      remaining = Rect.fromLTWH(
        remaining.left + stripWidth,
        remaining.top,
        remaining.width - stripWidth,
        remaining.height,
      );
    }
    row = [];
    rowArea = _emptyExtent;
  }

  for (final i in order) {
    if (values[i] <= _emptyExtent) {
      rects[i] = _emptyRect;
      continue;
    }
    final area = values[i] * scale;
    if (row.isEmpty) {
      row = [i];
      rowArea = area;
    } else if (worstOf([...row, i], rowArea + area) <= worstOf(row, rowArea)) {
      row.add(i);
      rowArea += area;
    } else {
      layoutRow();
      row = [i];
      rowArea = area;
    }
  }
  layoutRow();
  return rects;
}
