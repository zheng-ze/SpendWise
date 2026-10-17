import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';

double padReservedHeight(WidgetTester tester) {
  final pad = find.byType(NumberPad);
  if (pad.evaluate().isEmpty) return 0;
  final clip = find.ancestor(of: pad, matching: find.byType(ClipRect)).first;
  return tester.getSize(clip).height;
}
