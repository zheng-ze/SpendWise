import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/category/category_list_view_model.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

void main() {
  testWidgets(
    'a second open request while the form is open does not stack a second form',
    (tester) async {
      await pumpApp(tester, const CategoryListScreen(), ledger: Ledger());
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryForm), findsOneWidget);

      final scope = tester.element(find.byType(CategoryListScreen));
      ProviderScope.containerOf(scope)
          .read(categoryListViewModelProvider.notifier)
          .requestNewCategory();
      await tester.pumpAndSettle();

      expect(find.byType(CategoryForm), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );
}
