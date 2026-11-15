import 'package:flutter/widgets.dart';

import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _unsplitOffset = 0.0;

Widget phoneShell(Widget child) => paneShell(child);

Widget paneShell(
  Widget child, {
  ShellLayoutMode mode = ShellLayoutMode.phone,
  double splitOffset = _unsplitOffset,
  bool sheetCovered = false,
}) => ShellPaneScope(
  mode: mode,
  splitOffset: splitOffset,
  sheetPresented: sheetCovered,
  sheetCovered: sheetCovered,
  child: child,
);
