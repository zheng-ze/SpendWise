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
  group('shown and addable', () {
    test('a stored cardless kind is in neither list', () {
      final draft = _draft([_today, _cardless, _recent]);

      expect(draft.shown, [_today, _recent]);
      expect(draft.addable, [_thisMonth, _comingUp]);
    });

    test('isAdded reports kinds held in the working list', () {
      final draft = _draft([_today]);

      expect(draft.isAdded(_today), isTrue);
      expect(draft.isAdded(_recent), isFalse);
    });

    test('an injected fifth card kind appears in addable', () {
      final draft = _draft(
        [_today],
        cardKinds: [..._cardKinds, OverviewWidgetKind.insights],
      );

      expect(draft.addable, contains(OverviewWidgetKind.insights));
    });
  });

  group('hide', () {
    test('returns the kind to addable and keeps cardless kinds in place', () {
      final draft = _draft([_today, _cardless, _recent]).hide(_today);

      expect(draft.kinds, [_cardless, _recent]);
      expect(draft.addable, contains(_today));
    });

    test('canHide is true with two shown kinds', () {
      expect(_draft([_today, _recent]).canHide, isTrue);
    });

    test('canHide is false with one shown kind', () {
      expect(_draft([_today]).canHide, isFalse);
    });

    test('hiding the last shown kind keeps the draft with a cardless kind', () {
      final draft = _draft([_cardless, _today]);

      expect(draft.hide(_today), same(draft));
    });
  });

  group('add', () {
    test('appends to the end of shown', () {
      final draft = _draft([_today, _cardless]).add(_comingUp);

      expect(draft.kinds, [_today, _cardless, _comingUp]);
      expect(draft.shown.last, _comingUp);
    });

    test('a present kind is a no-op', () {
      final draft = _draft([_today]);

      expect(draft.add(_today), same(draft));
    });

    test('a non-card kind is a no-op', () {
      final draft = _draft([_today]);

      expect(draft.add(_cardless), same(draft));
    });
  });

  group('moveShown', () {
    test('moves a row up', () {
      final draft = _draft([_today, _thisMonth, _recent]).moveShown(2, 0);

      expect(draft.kinds, [_recent, _today, _thisMonth]);
    });

    test('moves a row down using the final index', () {
      final draft = _draft([_today, _thisMonth, _recent]).moveShown(0, 2);

      expect(draft.kinds, [_thisMonth, _recent, _today]);
    });

    test('cardless kinds keep their exact index', () {
      final draft = _draft([_today, _cardless, _recent]).moveShown(1, 0);

      expect(draft.kinds, [_recent, _cardless, _today]);
    });

    test('an out-of-range index is a no-op', () {
      final draft = _draft([_today, _recent]);

      expect(draft.moveShown(0, 2), same(draft));
    });
  });

  group('restoreDefault and applyTo', () {
    test('restoreDefault drops a cardless kind', () {
      final draft = _draft([_cardless, _today]).restoreDefault();

      expect(draft.kinds, DisplayPreferences.defaults.overviewWidgets);
      expect(draft.shown, isNotEmpty);
    });

    test('applyTo changes only overviewWidgets', () {
      final current = DisplayPreferences(
        appearance: Appearance.dark,
        savingsPocketID: 'pocket',
      );

      final applied = _draft([_recent, _today]).applyTo(current);

      expect(applied.overviewWidgets, [_recent, _today]);
      expect(
        applied,
        current.copyWith(overviewWidgets: [_recent, _today]),
      );
      expect(applied.appearance, Appearance.dark);
      expect(applied.savingsPocketID, 'pocket');
    });
  });
}
