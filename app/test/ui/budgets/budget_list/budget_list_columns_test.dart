import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';

void main() {
  test('open layout without a selection or Add uses two columns', () {
    expect(
      budgetListColumnCount(
        openLayout: true,
        addPresented: false,
        selectionPresent: false,
      ),
      2,
    );
  });

  test('a selected budget in open layout uses one column', () {
    expect(
      budgetListColumnCount(
        openLayout: true,
        addPresented: false,
        selectionPresent: true,
      ),
      1,
    );
  });

  test('an Add sheet in open layout uses one column', () {
    expect(
      budgetListColumnCount(
        openLayout: true,
        addPresented: true,
        selectionPresent: false,
      ),
      1,
    );
  });

  test('phone and desktop layouts use one column', () {
    expect(
      budgetListColumnCount(
        openLayout: false,
        addPresented: false,
        selectionPresent: false,
      ),
      1,
    );
  });
}
