import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _plansTestDirectory = 'test/ui/plans';
const _testFileSuffix = '_test.dart';
const _manifestFileName = 'plans_frame_ids_test.dart';
const _frameIdBoundary = r'(?![\w-])';
const _frameIdLeadingBoundary = r'(?<![\w-])';

const _inScopeFrameIds = [
  'mo-plans',
  'mo-plans-attention',
  'mo-plan-detail',
  'mo-plan-edit',
  'mo-plan-end',
  'mo-plan-delete',
  'mo-desk-plans',
  'money-plans',
  'phone-plans',
  'fr-plans',
  'le-plans-err',
  'le-plan-edit-err',
];

bool _isPlanTestFile(FileSystemEntity entity) {
  if (entity is! File) {
    return false;
  }
  final fileName = entity.uri.pathSegments.last;
  return fileName.endsWith(_testFileSuffix) && fileName != _manifestFileName;
}

List<String> _planTestSources() {
  final planTestFiles = Directory(
    _plansTestDirectory,
  ).listSync(recursive: true).where(_isPlanTestFile);
  return [for (final file in planTestFiles) (file as File).readAsStringSync()];
}

RegExp _frameIdPattern(String frameId) {
  return RegExp(
    '$_frameIdLeadingBoundary${RegExp.escape(frameId)}$_frameIdBoundary',
  );
}

void main() {
  final planTestSources = _planTestSources();

  for (final frameId in _inScopeFrameIds) {
    test('a plans test references frame id $frameId', () {
      final pattern = _frameIdPattern(frameId);
      final isReferenced = planTestSources.any(pattern.hasMatch);

      expect(
        isReferenced,
        isTrue,
        reason:
            'No test in $_plansTestDirectory/*$_testFileSuffix references frame id "$frameId" in a test or group name.',
      );
    });
  }
}
