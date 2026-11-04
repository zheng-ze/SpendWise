import 'package:flutter/widgets.dart';

import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

Widget phoneShell(Widget child) => ShellPaneScope(
  mode: ShellLayoutMode.phone,
  splitOffset: 0,
  sheetPresented: false,
  sheetCovered: false,
  child: child,
);
