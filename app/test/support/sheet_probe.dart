import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

Finder get sheetSurface => find
    .descendant(of: find.byType(AppSheet), matching: find.byType(Material))
    .first;

double sheetTop(WidgetTester tester) => tester.getRect(sheetSurface).top;
