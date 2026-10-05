import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/delete_confirmation.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

void main() {
  group('SpendWiseColors', () {
    test('light tokens match the reference hex values', () {
      const colors = SpendWiseColors.light;
      expect(colors.base, const Color(0xFFEDF4F8));
      expect(colors.surface, const Color(0xFFFFFFFF));
      expect(colors.raised, const Color(0xFFFFFFFF));
      expect(colors.tint, const Color(0xFFF0F1F2));
      expect(colors.text, const Color(0xFF25272A));
      expect(colors.subtext, const Color(0xFF5B5F66));
      expect(colors.edge, const Color(0xFFDDDFE2));
      expect(colors.control, const Color(0xFF73777F));
      expect(colors.action, const Color(0xFF205F83));
      expect(colors.selectedMark, const Color(0xFF8B48A0));
      expect(colors.pressed, const Color(0xFF174B6A));
      expect(colors.onAction, const Color(0xFFFFFFFF));
      expect(colors.income, const Color(0xFF28684F));
      expect(colors.expense, const Color(0xFF964B44));
      expect(colors.dining, const Color(0xFF986421));
      expect(colors.groceries, const Color(0xFF29755E));
      expect(colors.transport, const Color(0xFF6861A4));
      expect(colors.supermarket, const Color(0xFF237642));
      expect(colors.freshMarket, const Color(0xFF257B66));
      expect(colors.salary, const Color(0xFF28684F));
      expect(colors.gap, const Color(0xFF73777F));
      expect(colors.incomplete, const Color(0xFF94ADBC));
      expect(colors.focus, const Color(0xFF205F83));
      expect(colors.notice, const Color(0xFF7E5B1C));
      expect(colors.noticeBg, const Color(0xFFF5ECD7));
      expect(colors.error, const Color(0xFF993F3F));
      expect(colors.errorBg, const Color(0xFFF8E9E8));
      expect(colors.onCategory, const Color(0xFFFFFFFF));
      expect(colors.bezel, const Color(0xFF73777F));
      expect(colors.fitness, const Color(0xFF8A4F7D));
      expect(colors.housing, const Color(0xFF5B6B78));
    });

    test('dark tokens match the reference hex values', () {
      const colors = SpendWiseColors.dark;
      expect(colors.base, const Color(0xFF101112));
      expect(colors.surface, const Color(0xFF1C1D1F));
      expect(colors.raised, const Color(0xFF282A2D));
      expect(colors.tint, const Color(0xFF242629));
      expect(colors.text, const Color(0xFFF2F3F5));
      expect(colors.subtext, const Color(0xFFB9BCC2));
      expect(colors.edge, const Color(0xFF4C4F54));
      expect(colors.control, const Color(0xFF8B8F96));
      expect(colors.action, const Color(0xFF98C5E8));
      expect(colors.selectedMark, const Color(0xFFD8A3EB));
      expect(colors.pressed, const Color(0xFF7EB0D7));
      expect(colors.onAction, const Color(0xFF101112));
      expect(colors.income, const Color(0xFFA4D5B5));
      expect(colors.expense, const Color(0xFFEBAEA8));
      expect(colors.dining, const Color(0xFFE6B679));
      expect(colors.groceries, const Color(0xFF8FC69B));
      expect(colors.transport, const Color(0xFFB5A9E6));
      expect(colors.supermarket, const Color(0xFF82C68F));
      expect(colors.freshMarket, const Color(0xFF84CDB9));
      expect(colors.salary, const Color(0xFFA4D5B5));
      expect(colors.gap, const Color(0xFFA1A5AD));
      expect(colors.incomplete, const Color(0xFF8A8F97));
      expect(colors.focus, const Color(0xFFB7D9F4));
      expect(colors.notice, const Color(0xFFE4C48A));
      expect(colors.noticeBg, const Color(0xFF302C24));
      expect(colors.error, const Color(0xFFF0AAA8));
      expect(colors.errorBg, const Color(0xFF352627));
      expect(colors.onCategory, const Color(0xFF101112));
      expect(colors.bezel, const Color(0xFF8B8F96));
      expect(colors.fitness, const Color(0xFFD9A8CC));
      expect(colors.housing, const Color(0xFFAEB9C2));
    });
  });

  group('buildSpendWiseTheme', () {
    test('maps the tokens onto the material scheme', () {
      final theme = buildSpendWiseTheme(Brightness.light);
      final scheme = theme.colorScheme;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFEDF4F8));
      expect(scheme.primary, const Color(0xFF205F83));
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      expect(scheme.surface, const Color(0xFFFFFFFF));
      expect(scheme.surfaceContainerHigh, const Color(0xFFFFFFFF));
      expect(scheme.onSurface, const Color(0xFF25272A));
      expect(scheme.onSurfaceVariant, const Color(0xFF5B5F66));
      expect(scheme.outline, const Color(0xFF73777F));
      expect(scheme.outlineVariant, const Color(0xFFDDDFE2));
      expect(scheme.error, const Color(0xFF993F3F));
      expect(theme.textTheme.bodyMedium?.fontFamily, 'InstrumentSans');
      expect(theme.extension<SpendWiseColors>(), isNotNull);
      expect(theme.extension<SpendWiseText>(), isNotNull);
    });

    test('uses underline inputs in the focus colour', () {
      final theme = buildSpendWiseTheme(Brightness.light);
      final decoration = theme.inputDecorationTheme;
      expect(decoration.border, isA<UnderlineInputBorder>());
      expect(
        decoration.focusedBorder,
        UnderlineInputBorder(
          borderSide: BorderSide(color: const Color(0xFF205F83), width: 2),
        ),
      );
    });

    test('seats sheets on the raised token with rounded top corners', () {
      final theme = buildSpendWiseTheme(Brightness.light);
      final sheet = theme.bottomSheetTheme;
      expect(sheet.backgroundColor, const Color(0xFFFFFFFF));
      expect(
        sheet.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      );
    });

    test('amount roles use Instrument Sans with tabular figures', () {
      final theme = buildSpendWiseTheme(Brightness.light);
      final roles = theme.extension<SpendWiseText>()!;
      expect(roles.headline.fontFamily, 'InstrumentSans');
      expect(roles.headline.fontSize, 26);
      expect(roles.headline.fontWeight, FontWeight.w500);
      expect(roles.headline.letterSpacing, -0.7);
      expect(
        roles.headline.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(roles.hero.fontFamily, 'InstrumentSans');
      expect(
        roles.row.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(
        roles.small.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('button hierarchy', () {
    testWidgets('a destructive confirmation fills with the error token', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSpendWiseTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showDeleteConfirmation(context, itemName: 'plan'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      final style = confirm.style!;
      expect(style.backgroundColor?.resolve({}), const Color(0xFF993F3F));
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });
  });
}
