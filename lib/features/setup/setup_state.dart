import 'package:shared_preferences/shared_preferences.dart';

/// Preferences key marking that the first-run setup flow has been completed
/// (or explicitly skipped).
const String setupCompletedKey = 'ljod.setup.completed';

Future<bool> hasCompletedSetup(SharedPreferences preferences) async {
  return preferences.getBool(setupCompletedKey) ?? false;
}

Future<void> markSetupComplete(SharedPreferences preferences) async {
  await preferences.setBool(setupCompletedKey, true);
}
