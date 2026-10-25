import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _windowSize = Size(800, 700);
const _safeInsets = EdgeInsets.fromLTRB(31, 0, 17, 0);
const _pageMarkerKey = ValueKey('geometry-page-marker');

void main() {
  testWidgets('open pane boundary and detail align under asymmetric insets', (
    tester,
  ) async {
    tester.view.physicalSize = _windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: _windowSize, padding: _safeInsets),
            child: AppShell(
              bodies: {
                ShellDestination.overview: (_) => ShellPaneHost(
                  detail: ShellDetail(
                    id: 'geometry',
                    title: 'Detail',
                    bodyBuilder: (_) => const SizedBox.expand(),
                    onClose: () {},
                  ),
                  pageBuilder: (context, presentation) =>
                      SizedBox.expand(key: _pageMarkerKey),
                ),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageRect = tester.getRect(find.byKey(_pageMarkerKey));
    final dividerRect = tester.getRect(
      find.descendant(
        of: find.byKey(shellDetailDividerKey),
        matching: find.byType(ColoredBox),
      ),
    );
    final detailRect = tester.getRect(find.byKey(shellDetailPaneKey));
    final viewportSplit = _windowSize.width / 2 - _safeInsets.left;
    final viewportRight = _windowSize.width - openRailGutter;

    expect(pageRect.width, viewportSplit);
    expect(dividerRect.left, _windowSize.width / 2);
    expect(detailRect.left, dividerRect.left);
    expect(detailRect.right, viewportRight);
  });
}
