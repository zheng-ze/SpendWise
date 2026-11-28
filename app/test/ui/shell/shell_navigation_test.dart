import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/shell/shell_navigation.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

ProviderContainer _newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

ShellNavigationController _controller(ProviderContainer container) =>
    container.read(shellNavigationProvider.notifier);

ShellRequest _pendingRequest(ProviderContainer container) {
  final request = container.read(shellNavigationProvider);
  if (request == null) throw StateError('expected a pending request');
  return request;
}

void main() {
  test('starts with no pending request', () {
    final container = _newContainer();

    expect(container.read(shellNavigationProvider), isNull);
  });

  test('selectHistory selects History without creating a request', () {
    final container = _newContainer();

    _controller(container).selectHistory();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(container.read(shellNavigationProvider), isNull);
  });

  test('openHistoryTrends stores a request and selects History', () {
    final container = _newContainer();

    _controller(container).openHistoryTrends();

    expect(container.read(shellNavigationProvider), isNotNull);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
  });

  test('two openHistoryTrends calls leave only the latest pending', () {
    final container = _newContainer();
    final controller = _controller(container);

    controller.openHistoryTrends();
    final first = _pendingRequest(container);
    controller.openHistoryTrends();
    final second = _pendingRequest(container);

    expect(second.occurrence, greaterThan(first.occurrence));
    expect(second, isNot(equals(first)));
    expect(container.read(shellNavigationProvider), second);
  });

  test('consume clears the pending request when it matches', () {
    final container = _newContainer();
    final controller = _controller(container);
    controller.openHistoryTrends();

    controller.consume(_pendingRequest(container));

    expect(container.read(shellNavigationProvider), isNull);
  });

  test('consume of a stale request leaves the replacement pending', () {
    final container = _newContainer();
    final controller = _controller(container);
    controller.openHistoryTrends();
    final stale = _pendingRequest(container);
    controller.openHistoryTrends();
    final replacement = _pendingRequest(container);

    controller.consume(stale);

    expect(container.read(shellNavigationProvider), replacement);
  });

  test('requests do not leak between containers', () {
    final first = _newContainer();
    final second = _newContainer();

    _controller(first).openHistoryTrends();

    expect(first.read(shellNavigationProvider), isNotNull);
    expect(second.read(shellNavigationProvider), isNull);
    expect(second.read(selectedDestinationProvider), ShellDestination.overview);
  });
}
