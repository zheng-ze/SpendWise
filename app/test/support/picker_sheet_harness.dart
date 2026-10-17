import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import 'sheet_contract.dart';

const phoneTallSize = Size(320, 760);
const phoneShortSize = Size(320, 560);
const desktopSize = Size(1000, 800);

class PickerOpener<T> {
  Future<T?>? pending;
  bool completed = false;
  T? result;
}

Future<PickerOpener<T>> openPicker<T>(
  WidgetTester tester, {
  required Size size,
  required Future<T?> Function(BuildContext context) open,
}) async {
  useSheetSize(tester, size);
  final opener = PickerOpener<T>();
  final launcher = Builder(
    builder: (context) => TextButton(
      onPressed: () {
        opener.pending = open(context)
          ..then((value) {
            opener.completed = true;
            opener.result = value;
          });
      },
      child: const Text('open picker'),
    ),
  );
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: launcher)));
  await tester.tap(find.text('open picker'));
  await tester.pumpAndSettle();
  return opener;
}

AppSheetPresentation presentationFor(Size size) => size == desktopSize
    ? AppSheetPresentation.desktop
    : AppSheetPresentation.phone;
