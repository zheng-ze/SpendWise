import 'package:flutter/widgets.dart';

import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _columnDivisor = 2.0;
const _minimumExtent = 0.0;

typedef ShellPaneGeometry = ({double splitOffset, Rect sheetBounds});

ShellPaneGeometry resolveShellPaneGeometry({
  required ShellLayoutMode mode,
  required Size windowSize,
  required EdgeInsets padding,
}) {
  final desktop = mode == ShellLayoutMode.desktop;
  final contentLeft = desktop
      ? padding.left + desktopSidebarWidth + sidebarDividerWidth
      : padding.left;
  final contentRight = windowSize.width - padding.right;
  final midpoint = desktop
      ? contentLeft + (contentRight - contentLeft) / _columnDivisor
      : windowSize.width / _columnDivisor;
  final sheetRight = desktop ? contentRight : windowSize.width;
  final splitOffset = (midpoint - contentLeft).clamp(
    _minimumExtent,
    double.infinity,
  );
  final sheetWidth = (sheetRight - midpoint).clamp(
    _minimumExtent,
    double.infinity,
  );
  final height = (windowSize.height - padding.vertical).clamp(
    _minimumExtent,
    double.infinity,
  );
  return (
    splitOffset: splitOffset,
    sheetBounds: Rect.fromLTWH(midpoint, padding.top, sheetWidth, height),
  );
}
