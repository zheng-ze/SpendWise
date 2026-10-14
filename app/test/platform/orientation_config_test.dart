import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _plistPath = 'ios/Runner/Info.plist';
const _iphoneKey = 'UISupportedInterfaceOrientations';
const _ipadKey = 'UISupportedInterfaceOrientations~ipad';
const _orientationPrefix = 'UIInterfaceOrientation';
const _iphoneOrientations = ['Portrait'];
const _ipadOrientations = [
  'Portrait',
  'PortraitUpsideDown',
  'LandscapeLeft',
  'LandscapeRight',
];

List<String> _orientationsFor(String plist, String key) {
  final block = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist)!.group(1)!;
  return RegExp('<string>$_orientationPrefix(\\w+)</string>')
      .allMatches(block)
      .map((match) => match.group(1)!)
      .toList();
}

void main() {
  final plist = File(_plistPath).readAsStringSync();

  test('iPhone is portrait only', () {
    expect(_orientationsFor(plist, _iphoneKey), _iphoneOrientations);
  });

  test('iPad keeps all four orientations', () {
    expect(_orientationsFor(plist, _ipadKey), _ipadOrientations);
  });
}
