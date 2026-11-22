import 'package:spendwise/settings/display_preferences.dart';

class OverviewEditDraft {
  OverviewEditDraft({
    required List<OverviewWidgetKind> kinds,
    required List<OverviewWidgetKind> cardKinds,
  }) : kinds = List.unmodifiable(kinds),
       cardKinds = List.unmodifiable(cardKinds);

  final List<OverviewWidgetKind> kinds;
  final List<OverviewWidgetKind> cardKinds;

  List<OverviewWidgetKind> get shown => [
    for (final kind in kinds)
      if (cardKinds.contains(kind)) kind,
  ];

  List<OverviewWidgetKind> get hidden => [
    for (final kind in cardKinds)
      if (!kinds.contains(kind)) kind,
  ];

  bool get canApply => shown.isNotEmpty;

  /// Indexes address the flattened sheet list: shown rows, the Hidden header
  /// at index `shown.length`, then hidden rows. [to] is the final index after
  /// removal, as `ReorderableListView.onReorderItem` reports it.
  OverviewEditDraft move(int from, int to) {
    final shownCards = shown;
    final headerIndex = shownCards.length;
    final total = headerIndex + 1 + hidden.length;
    final fromRange = from >= 0 && from < total;
    if (!fromRange || from == headerIndex || to < 0 || from == to) return this;

    if (from < headerIndex) {
      return to < headerIndex
          ? _reorderShown(shownCards, from, to)
          : _withKinds([...kinds]..remove(shownCards[from]));
    }
    if (to > headerIndex) return this;
    return _show(hidden[from - headerIndex - 1], shownCards, to);
  }

  OverviewEditDraft restoreDefault() =>
      _withKinds(DisplayPreferences.defaults.overviewWidgets);

  DisplayPreferences applyTo(DisplayPreferences current) =>
      current.copyWith(overviewWidgets: kinds);

  OverviewEditDraft _reorderShown(
    List<OverviewWidgetKind> shownCards,
    int from,
    int to,
  ) {
    shownCards.insert(to, shownCards.removeAt(from));
    final next = [...kinds];
    var slot = 0;
    for (var index = 0; index < next.length; index++) {
      if (cardKinds.contains(next[index])) next[index] = shownCards[slot++];
    }
    return _withKinds(next);
  }

  OverviewEditDraft _show(
    OverviewWidgetKind kind,
    List<OverviewWidgetKind> shownCards,
    int to,
  ) {
    final next = [...kinds];
    final insertAt = to > 0
        ? kinds.indexOf(shownCards[to - 1]) + 1
        : shownCards.isEmpty
        ? kinds.length
        : kinds.indexOf(shownCards.first);
    next.insert(insertAt, kind);
    return _withKinds(next);
  }

  OverviewEditDraft _withKinds(List<OverviewWidgetKind> next) =>
      OverviewEditDraft(kinds: next, cardKinds: cardKinds);
}
