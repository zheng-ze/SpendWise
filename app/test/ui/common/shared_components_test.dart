import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AmountField prefix', () {
    testWidgets('is absent while the field is empty', (tester) async {
      await tester.pumpWidget(
        _host(
          AmountField(
            controller: TextEditingController(),
            allowsNegative: false,
          ),
        ),
      );

      expect(find.text(r'$'), findsNothing);
    });

    testWidgets('appears once text is typed and goes away when cleared', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _host(AmountField(controller: controller, allowsNegative: false)),
      );

      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(find.text(r'$'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text(r'$'), findsNothing);
    });

    testWidgets('drops a minus sign when negatives are not allowed', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _host(AmountField(controller: controller, allowsNegative: false)),
      );

      await tester.enterText(find.byType(TextField), '-5');
      await tester.pump();

      expect(controller.text, '5');
    });

    testWidgets('keeps a minus sign when negatives are allowed', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _host(AmountField(controller: controller, allowsNegative: true)),
      );

      await tester.enterText(find.byType(TextField), '-5');
      await tester.pump();

      expect(controller.text, '-5');
    });
  });

  group('FormScaffold save enablement', () {
    testWidgets('Save is disabled while canSave is false', (tester) async {
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FormScaffold(
            title: 'Account',
            canSave: false,
            onSave: () async => saved = true,
            error: const SizedBox.shrink(),
            child: const SizedBox.shrink(),
          ),
        ),
      );

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(save.onPressed, isNull);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved, isFalse);
    });

    testWidgets('Save runs onSave once canSave is true', (tester) async {
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FormScaffold(
            title: 'Account',
            canSave: true,
            onSave: () async => saved = true,
            error: const SizedBox.shrink(),
            child: const SizedBox.shrink(),
          ),
        ),
      );

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(save.onPressed, isNotNull);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
    });

    testWidgets('tapping outside the sheet dismisses it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => FormScaffold(
                    title: 'Account',
                    canSave: false,
                    onSave: () async {},
                    error: const SizedBox.shrink(),
                    child: const Text('form body'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('form body'), findsOneWidget);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('form body'), findsNothing);
    });
  });

  group('ErrorSection', () {
    testWidgets('renders nothing before a save has failed', (tester) async {
      await tester.pumpWidget(
        _host(const ErrorSection(subject: 'account', error: null)),
      );

      expect(find.textContaining('Could not save'), findsNothing);
    });

    testWidgets('names the subject and the friendly message after a failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ErrorSection(subject: 'account', error: CategoryKindMismatch()),
        ),
      );

      expect(
        find.text(
          'Could not save account: ${friendlyLedgerErrorMessage(const CategoryKindMismatch())}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('inside a form it stays hidden until the save throws', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: _FailingSaveForm()));

      expect(find.textContaining('Could not save'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not save account: '
          '${friendlyLedgerErrorMessage(const CategoryKindMismatch())}',
        ),
        findsOneWidget,
      );
    });
  });
}

class _FailingSaveForm extends StatefulWidget {
  @override
  State<_FailingSaveForm> createState() => _FailingSaveFormState();
}

class _FailingSaveFormState extends State<_FailingSaveForm> {
  LedgerError? _error;

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Account',
      canSave: true,
      onSave: () async {
        try {
          throw const CategoryKindMismatch();
        } on LedgerError catch (error) {
          setState(() => _error = error);
        }
      },
      error: ErrorSection(subject: 'account', error: _error),
      child: const SizedBox.shrink(),
    );
  }
}
