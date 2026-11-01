import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/core/app_info.dart';

void main() {
  test('app version matches pubspec and forms a valid tag', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml must declare a version');
    final declared = match!.group(1)!;

    expect(
      LjodAppInfo.version,
      declared,
      reason:
          'Bump LjodAppInfo.version with pubspec, or the Settings screen and '
          'the release tag check will disagree.',
    );

    // A tag push must match v<versionName> or the release workflow refuses.
    final parts = declared.split('+');
    expect(parts.length, 2, reason: 'version must be <name>+<build>');
    expect(LjodAppInfo.versionName, parts.first);
    expect(LjodAppInfo.buildNumber, int.parse(parts[1]));
    expect(LjodAppInfo.tag, 'v${parts.first}');
  });
}
