import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/navigation/compact_labelled_fab.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/category/category_list_view_model.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _barrierTap = Offset(160, 10);
const _launchLabel = 'Open categories';

class _ListLauncher extends StatelessWidget {
  const _ListLauncher();

  @override
  Widget build(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (_) => const CategoryListScreen(),
    );
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(route),
        child: const Text(_launchLabel),
      ),
    );
  }
}

final _addCategoryButton = find.byType(CompactLabelledFab);

void main() {
  testWidgets(
    'a second open request while the form is open does not stack a second form',
    (tester) async {
      await pumpApp(tester, const CategoryListScreen(), ledger: Ledger());
      await tester.tap(_addCategoryButton);
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

  testWidgets('the form opens again after it was dismissed', (tester) async {
    await pumpApp(tester, const CategoryListScreen(), ledger: Ledger());
    await tester.tap(_addCategoryButton);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryForm), findsOneWidget);

    await tester.tapAt(_barrierTap);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryForm), findsNothing);

    await tester.tap(_addCategoryButton);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsOneWidget);
  }, timeout: uiTestTimeout);

  test('the subcategory meta is absent for zero, singular for one', () {
    expect(categorySubcategoriesMeta(0), isNull);
    expect(categorySubcategoriesMeta(1), '1 subcategory');
    expect(categorySubcategoriesMeta(3), '3 subcategories');
  });

  testWidgets(
    'the header shows the title and a Settings back control that pops',
    (tester) async {
      await pumpApp(tester, const _ListLauncher(), ledger: Ledger());
      await tester.tap(find.text(_launchLabel));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryListScreen), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryListScreen), findsNothing);
    },
    timeout: uiTestTimeout,
  );
}
