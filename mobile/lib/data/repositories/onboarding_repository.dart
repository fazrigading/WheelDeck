import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for first-run onboarding completion.
///
/// Owns the completion flag so the routing shell and the onboarding flow never
/// touch [SharedPreferences] directly.
class OnboardingRepository {
  const OnboardingRepository();

  static const String prefsKey = 'wheeldeck.onboarding_complete';

  /// True once the user finished or skipped onboarding.
  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  /// Persists onboarding completion.
  Future<void> setComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }
}
