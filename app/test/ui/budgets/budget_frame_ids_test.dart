import 'package:flutter_test/flutter_test.dart';

import '../../support/frame_manifest.dart';

const _inScopeFrameIds = {
  'mo-budget-add',
  'mo-budget-pick',
  'le-budget-add-load',
  'le-budget-add-err',
  'sf-budget',
  'mo-budget-edit-default',
  'sf-limit',
};

void main() {
  test('every in-scope budget frame id exists in the frame manifest', () {
    final known = FrameManifest.load().ids;

    expect(_inScopeFrameIds.difference(known), isEmpty);
  });
}
