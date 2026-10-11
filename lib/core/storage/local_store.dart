import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Typed key-value store over shared_preferences.
///
/// One instance per app; all storage keys live in [StorageKeys] so we never
/// have stringly-typed key collisions. Profile-scoped stores wrap this.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  double? getDouble(String key) => _prefs.getDouble(key);
  Future<void> setDouble(String key, double value) => _prefs.setDouble(key, value);

  List<String>? getStringList(String key) => _prefs.getStringList(key);
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  bool containsKey(String key) => _prefs.containsKey(key);
}

/// All storage keys in one namespace so nothing collides.
class StorageKeys {
  const StorageKeys._();

  // Profiles
  static const profiles = 'profiles';
  static const activeProfileId = 'activeProfileId';

  // Addons
  static const addons = 'addons';

  // Watch progress
  static const watchProgress = 'watchProgress';
  static const watchedItems = 'watchedItems';

  // Library
  static const savedLibrary = 'savedLibrary';
  static const collections = 'collections';

  // Settings
  static const playerSettings = 'playerSettings';
  static const torrentSettings = 'torrentSettings';
  static const debridSettings = 'debridSettings';
  static const themeSettings = 'themeSettings';
  static const tmdbSettings = 'tmdbSettings';
  static const layoutPreferences = 'layoutPreferences';
  static const experienceMode = 'experienceMode';

  // Plugins
  static const pluginState = 'pluginState';

  // Search
  static const searchHistory = 'searchHistory';

  // Onboarding
  static const onboardingComplete = 'onboardingComplete';
}

/// Wraps [LocalStore] with per-profile key namespacing.
///
/// Every user-scoped store (addons, progress, library, settings) goes
/// through this so profiles never see each other's data.
class ProfileScopedStore {
  ProfileScopedStore(this._store, this._profileId);

  final LocalStore _store;
  final String _profileId;

  String _key(String baseKey) => 'profile:$_profileId:$baseKey';

  String? getString(String baseKey) => _store.getString(_key(baseKey));
  Future<void> setString(String baseKey, String value) =>
      _store.setString(_key(baseKey), value);

  bool? getBool(String baseKey) => _store.getBool(_key(baseKey));
  Future<void> setBool(String baseKey, bool value) =>
      _store.setBool(_key(baseKey), value);

  List<String>? getStringList(String baseKey) =>
      _store.getStringList(_key(baseKey));
  Future<void> setStringList(String baseKey, List<String> value) =>
      _store.setStringList(_key(baseKey), value);

  Future<void> remove(String baseKey) => _store.remove(_key(baseKey));
}
