/// Release identity, kept in one place so the Settings screen and the LRCLIB
/// client cannot drift from `pubspec.yaml`.
///
/// The order of `version` is `<name>+<buildNumber>`; a tag must be
/// `v<versionName>` for the release workflow to publish.
abstract final class LjodAppInfo {
  /// Matches the `version:` field in pubspec.yaml. `test/app_info_test.dart`
  /// fails if these disagree.
  static const String version = '0.3.0+3';

  static const String versionName = '0.3.0';

  static const int buildNumber = 3;

  static const String tag = 'v$versionName';

  /// Public package id, used where a client identifier is required.
  static const String applicationId = 'dev.vz.ljod';
}
