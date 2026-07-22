import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores each bed's ThingSpeak Read API key in encrypted device storage
/// (Android Keystore-backed EncryptedSharedPreferences), keyed by bed ID.
///
/// Everything else about a bed (name, channel ID, thresholds) stays in the
/// plain SharedPreferences blob — only the API key is sensitive enough to
/// warrant encrypted storage. Used from both the foreground app and the
/// background-service isolate, so it must not depend on Riverpod state.
class SecureKeyStore {
  SecureKeyStore._();
  static final instance = SecureKeyStore._();

  static const _storage = FlutterSecureStorage();

  String _keyFor(String bedId) => 'iv_sentinel_apikey_$bedId';

  Future<String?> read(String bedId) => _storage.read(key: _keyFor(bedId));

  Future<void> write(String bedId, String apiKey) =>
      _storage.write(key: _keyFor(bedId), value: apiKey);

  Future<void> delete(String bedId) => _storage.delete(key: _keyFor(bedId));
}
