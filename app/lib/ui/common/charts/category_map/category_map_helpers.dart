part of '../category_map.dart';

// MARK: - Helpers

String _shareText(double share) =>
    '${(share * _percentFactor).toStringAsFixed(_shareFractionDigits)}%';

Color _selectionFill(bool selected, Color mark, Color fallback) =>
    selected ? mark : fallback;

Widget _tappable(Widget child, VoidCallback? onTap) {
  if (onTap == null) return child;
  return GestureDetector(onTap: onTap, child: child);
}

TextPainter _measure(
  String text,
  TextStyle style,
  TextScaler scaler,
  double maxWidth,
  int maxLines,
  String? ellipsis,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: maxLines,
    ellipsis: ellipsis,
  )..layout(maxWidth: maxWidth);
  return painter;
}

bool _labelFits(Rect rect, String name, String share, TextScaler scaler) {
  final available = Size(rect.width - _labelInset, rect.height - _labelInset);
  if (available.width <= _emptyExtent || available.height <= _emptyExtent) {
    return false;
  }
  const style = TextStyle(
    fontSize: _labelFontSize,
    fontWeight: _semiBoldWeight,
  );
  final namePainter = _measure(
    name,
    style,
    scaler,
    available.width,
    _nameMaxLines,
    '...',
  );
  if (namePainter.didExceedMaxLines) return false;
  final sharePainter = _measure(
    share,
    style,
    scaler,
    available.width,
    _shareMaxLines,
    null,
  );
  if (sharePainter.didExceedMaxLines) return false;
  return namePainter.height + _nameShareGap + sharePainter.height <=
      available.height;
}

Rect _paddedBlock(Rect rect) {
  if (rect.width <= _minBlockSize || rect.height <= _minBlockSize) return rect;
  return rect.deflate(_blockInset);
}
