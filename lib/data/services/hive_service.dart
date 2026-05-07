import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HiveService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _guestModeKey = 'is_guest_mode';
  static const String _languageLevelKey = 'guest_language_level';

  Box? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('starmory_box');
  }

  // Onboarding
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  // Guest Mode
  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  Future<void> setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, isGuest);
  }

  // Language Level (for guest mode)
  Future<String?> getGuestLanguageLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageLevelKey);
  }

  Future<void> setGuestLanguageLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageLevelKey, level);
  }

  // Guest data storage
  Future<void> saveGuestData(String key, dynamic value) async {
    await _box?.put(key, value);
  }

  Future<dynamic> getGuestData(String key) async {
    return _box?.get(key);
  }

  Future<void> clearGuestData() async {
    await _box?.clear();
  }
}
