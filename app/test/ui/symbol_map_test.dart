import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/symbol_map.dart';

void main() {
  group('the catalog', () {
    test('has nine sections of ten names', () {
      expect(categoryIconSections, hasLength(9));
      for (final entry in categoryIconSections.entries) {
        expect(entry.value, hasLength(10), reason: entry.key);
      }
      expect(categoryIconNames, hasLength(90));
    });

    test('names no icon twice, so the picker shows no duplicate', () {
      expect(categoryIconNames.toSet(), hasLength(categoryIconNames.length));
    });
  });

  group('symbolIcon', () {
    test('resolves every catalog name to a real icon', () {
      for (final name in categoryIconNames) {
        expect(
          symbolIcon(name),
          isNot(fallbackSymbolIcon),
          reason: '$name fell through to the fallback',
        );
      }
    });

    test('resolves the chrome names the shell and forms use', () {
      const chrome = [
        'menu_book',
        'pie_chart_outline',
        'wallet',
        'settings_outlined',
        'add',
        'edit',
        'delete',
        'undo',
        'close',
        'check',
        'chevron_left',
        'chevron_right',
        'expand_more',
        'repeat',
        'change_circle',
        'inbox',
        'payments_outlined',
        'label_outline',
        'remove_circle',
        'add_circle',
        'bar_chart',
        'swap_horiz',
        'help_outline',
        'radio_button_checked',
      ];

      expect(chrome, hasLength(24));
      for (final name in chrome) {
        expect(
          symbolIcon(name),
          isNot(fallbackSymbolIcon),
          reason: '$name fell through to the fallback',
        );
      }
    });

    test('an unknown name yields the fallback', () {
      expect(symbolIcon('not_a_symbol'), fallbackSymbolIcon);
      expect(symbolIcon(''), fallbackSymbolIcon);
    });

    test('lookup is exact, so a near miss does not borrow an icon', () {
      expect(symbolIcon('Shopping_cart'), fallbackSymbolIcon);
      expect(symbolIcon('shopping_cart '), fallbackSymbolIcon);
      expect(symbolIcon('restaurant_menu'), fallbackSymbolIcon);
    });

    test('distinct catalog names mostly reach distinct icons', () {
      final icons = {for (final name in categoryIconNames) symbolIcon(name)};
      expect(icons.length, greaterThanOrEqualTo(70));
    });
  });
}
