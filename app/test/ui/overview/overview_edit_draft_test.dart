import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_edit_draft.dart';

const _today = OverviewWidgetKind.today;
const _thisMonth = OverviewWidgetKind.thisMonth;
const _recent = OverviewWidgetKind.recentEntries;
const _comingUp = OverviewWidgetKind.comingUp;
const _cardless = OverviewWidgetKind.topCategories;
const _cardKinds = [_today, _thisMonth, _recent, _comingUp];

OverviewEditDraft _draft(
  List<OverviewWidgetKind> kinds, {
  List<OverviewWidgetKind> cardKinds = _cardKinds,
}) => OverviewEditDraft(kinds: kinds, cardKinds: cardKinds);

void main() {
  group('shown and hidden', () {
    test('a stored cardless kind is in neither list', () {
      final draft = _draft([_today, _cardless, _recent]);

      expect(draft.shown, [_today, _recent]);
      expect(draft.hidden, [_thisMonth, _comingUp]);
    });

    test('shown follows stored order and hidden follows catalogue order', () {
      final draft = _draft([_comingUp, _today]);

      expect(draft.shown, [_comingUp, _today]);
      expect(draft.hidden, [_thisMonth, _recent]);
    });

    test('an injected fifth card kind appears in hidden', () {
      final draft = _draft(
        [_today],
        cardKinds: [..._cardKinds, OverviewWidgetKind.insights],
      );

      expect(draft.hidden, contains(OverviewWidgetKind.insights));
    });
  });

  group('move within shown', () {
    test('moves a row up', () {
      final draft = _draft([_today, _thisMonth, _recent]).move(2, 0);

      expect(draft.kinds, [_recent, _today, _thisMonth]);
    });

    test('moves a row down using the final index', () {
      final draft = _draft([_today, _thisMonth, _recent]).move(0, 2);

      expect(draft.kinds, [_thisMonth, _recent, _today]);
    });

    test('cardless kinds keep their exact index', () {
      final draft = _draft([_today, _cardless, _recent]).move(1, 0);

      expect(draft.kinds, [_recent, _cardless, _today]);
    });

    test('the Today, topCategories, recentEntries case', () {
      final draft = _draft([_today, _cardless, _recent]).move(1, 0);

      expect(draft.shown, [_recent, _today]);
      expect(draft.kinds, [_recent, _cardless, _today]);
    });
  });

  group('move shown to hidden', () {
    test('hides the row and lists it in catalogue order', () {
      final draft = _draft([_recent, _today]).move(0, 2);

      expect(draft.kinds, [_today]);
      expect(draft.hidden, [_thisMonth, _recent, _comingUp]);
    });

    test('dropping past hidden rows also hides', () {
      final draft = _draft([_today, _recent]).move(0, 4);

      expect(draft.shown, [_recent]);
    });

    test('keeps cardless kinds in place', () {
      final draft = _draft([_today, _cardless, _recent]).move(0, 2);

      expect(draft.kinds, [_cardless, _recent]);
    });

    test('hiding the last shown card leaves nothing to apply', () {
      final draft = _draft([_today]).move(0, 1);

      expect(draft.shown, isEmpty);
      expect(draft.canApply, isFalse);
    });

    test('canApply is true while a card is shown', () {
      expect(_draft([_today]).canApply, isTrue);
    });
  });

  group('move hidden to shown', () {
    final base = _draft([_today, _cardless, _recent]);

    test('drop at the start lands first', () {
      final draft = base.move(3, 0);

      expect(draft.shown, [_thisMonth, _today, _recent]);
      expect(draft.kinds, [_thisMonth, _today, _cardless, _recent]);
    });

    test('drop in the middle lands between its neighbours', () {
      final draft = base.move(3, 1);

      expect(draft.shown, [_today, _thisMonth, _recent]);
      expect(draft.kinds, [_today, _thisMonth, _cardless, _recent]);
    });

    test('drop at the end of shown lands last', () {
      final draft = base.move(4, 2);

      expect(draft.shown, [_today, _recent, _comingUp]);
      expect(draft.kinds, [_today, _cardless, _recent, _comingUp]);
    });

    test('showing into an empty shown list keeps the cardless kind first', () {
      final draft = _draft([_cardless]).move(1, 0);

      expect(draft.kinds, [_cardless, _today]);
      expect(draft.canApply, isTrue);
    });

    test('showing before a leading cardless kind keeps its index', () {
      final draft = _draft([_cardless, _today]).move(2, 0);

      expect(draft.kinds, [_cardless, _thisMonth, _today]);
    });
  });

  group('moves that change nothing', () {
    final draft = _draft([_today, _recent]);

    test('hidden to hidden is a no-op', () {
      expect(draft.move(3, 4), same(draft));
      expect(draft.move(4, 3), same(draft));
    });

    test('moving the Hidden header is a no-op', () {
      expect(draft.move(2, 0), same(draft));
    });

    test('out-of-range and negative indexes are a no-op', () {
      expect(draft.move(9, 0), same(draft));
      expect(draft.move(-1, 0), same(draft));
      expect(draft.move(0, -1), same(draft));
    });

    test('dropping a row where it started is a no-op', () {
      expect(draft.move(1, 1), same(draft));
    });
  });

  group('restoreDefault and applyTo', () {
    test('restoreDefault drops a cardless kind', () {
      final draft = _draft([_cardless]).restoreDefault();

      expect(draft.kinds, DisplayPreferences.defaults.overviewWidgets);
      expect(draft.canApply, isTrue);
    });

    test('applyTo changes only overviewWidgets', () {
      final current = DisplayPreferences(
        appearance: Appearance.dark,
        savingsPocketID: 'pocket',
      );

      final applied = _draft([_recent, _today]).applyTo(current);

      expect(applied.overviewWidgets, [_recent, _today]);
      expect(applied, current.copyWith(overviewWidgets: [_recent, _today]));
      expect(applied.appearance, Appearance.dark);
      expect(applied.savingsPocketID, 'pocket');
    });
  });
}
