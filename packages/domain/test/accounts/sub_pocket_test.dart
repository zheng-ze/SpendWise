import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const pocketID = 'abcdefab-0000-4000-8000-000000000002';

  test('setting lifecycle preserves pocket settings', () {
    final pocket = SubPocket(
      id: pocketID,
      name: 'Reserve',
      incomingTransfersAsExpenses: true,
    ).settingLifecycle(LifecycleState.archived);

    expect(pocket.id, pocketID);
    expect(pocket.name, 'Reserve');
    expect(pocket.incomingTransfersAsExpenses, isTrue);
    expect(pocket.lifecycle, LifecycleState.archived);
  });

  test('equal pockets behave as equal identity values', () {
    final first = SubPocket(id: pocketID, name: 'Reserve');
    final second = SubPocket(id: pocketID, name: 'Reserve');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect({first: 'reserve'}[second], 'reserve');
  });
}
