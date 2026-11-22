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

  bool get canHide => shown.length > 1;

  List<OverviewWidgetKind> get addable => [
    for (final kind in cardKinds)
      if (!kinds.contains(kind)) kind,
  ];

  bool isAdded(OverviewWidgetKind kind) => kinds.contains(kind);

  OverviewEditDraft hide(OverviewWidgetKind kind) {
    if (!canHide) return this;
    return _withKinds([
      for (final existing in kinds)
        if (existing != kind) existing,
    ]);
  }

  OverviewEditDraft add(OverviewWidgetKind kind) {
    if (!cardKinds.contains(kind) || kinds.contains(kind)) return this;
    return _withKinds([...kinds, kind]);
  }

  /// [to] is the final index, as `ReorderableListView.onReorderItem` reports
  /// it. Cardless kinds keep their exact index in [kinds].
  OverviewEditDraft moveShown(int from, int to) {
    final reordered = shown;
    final inRange = from >= 0 && from < reordered.length;
    if (!inRange || to < 0 || to >= reordered.length) return this;
    reordered.insert(to, reordered.removeAt(from));

    final next = [...kinds];
    var slot = 0;
    for (var index = 0; index < next.length; index++) {
      if (cardKinds.contains(next[index])) next[index] = reordered[slot++];
    }
    return _withKinds(next);
  }

  OverviewEditDraft restoreDefault() =>
      _withKinds(DisplayPreferences.defaults.overviewWidgets);

  DisplayPreferences applyTo(DisplayPreferences current) =>
      current.copyWith(overviewWidgets: kinds);

  OverviewEditDraft _withKinds(List<OverviewWidgetKind> next) =>
      OverviewEditDraft(kinds: next, cardKinds: cardKinds);
}
