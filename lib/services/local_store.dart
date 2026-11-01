import 'package:shared_preferences/shared_preferences.dart';

/// Small injectable boundary around on-device storage.
abstract interface class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class PreferencesStore implements LocalStore {
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _store.getString(key);

  @override
  Future<void> write(String key, String value) => _store.setString(key, value);

  @override
  Future<void> remove(String key) => _store.remove(key);
}
