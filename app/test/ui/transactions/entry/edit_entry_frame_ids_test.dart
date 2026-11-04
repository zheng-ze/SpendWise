import 'package:flutter_test/flutter_test.dart';

import '../../../support/frame_manifest.dart';

const _inScopeFrameIds = {'edit-entry', 'edit-system'};

void main() {
  test('every in-scope edit entry frame id exists in the frame manifest', () {
    final known = FrameManifest.load().ids;

    expect(_inScopeFrameIds.difference(known), isEmpty);
  });
}
