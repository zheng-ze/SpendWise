import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';

import 'pump_app.dart';

const categoryFormLauncherLabel = 'Open category form';

class _Launcher extends StatelessWidget {
  const _Launcher({this.category, this.presetParentID});

  final TransactionCategory? category;
  final String? presetParentID;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => showCategoryFormSheet(
          context: context,
          category: category,
          presetParentID: presetParentID,
        ),
        child: const Text(categoryFormLauncherLabel),
      ),
    );
  }
}

Future<void> openCategoryFormSheet(
  WidgetTester tester,
  Ledger ledger, {
  TransactionCategory? category,
  String? presetParentID,
  List<Override> overrides = const [],
}) async {
  final launcher = _Launcher(
    category: category,
    presetParentID: presetParentID,
  );
  await pumpApp(tester, launcher, ledger: ledger, overrides: overrides);
  await tester.tap(find.text(categoryFormLauncherLabel));
  await tester.pumpAndSettle();
}
