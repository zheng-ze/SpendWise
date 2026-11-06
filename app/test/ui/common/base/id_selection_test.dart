import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/base/id_selection.dart';

final _selectionProvider =
    NotifierProvider.autoDispose<IdSelectionNotifier, String?>(
      IdSelectionNotifier.new,
    );

void main() {
  test('starts with no selection, then select, clear and reselect', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(_selectionProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(container.read(_selectionProvider), isNull);

    container.read(_selectionProvider.notifier).select('id-a');
    expect(container.read(_selectionProvider), 'id-a');

    container.read(_selectionProvider.notifier).clear();
    expect(container.read(_selectionProvider), isNull);

    container.read(_selectionProvider.notifier).select('id-b');
    expect(container.read(_selectionProvider), 'id-b');
  });
}
