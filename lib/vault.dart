import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Secrets live only here (Keychain on iOS, EncryptedSharedPreferences on Android),
// keyed by the account UUID. The database never stores a token or cookie.
class Vault {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String _key(String accountId) => 'cred_$accountId';

  static Future<void> save(String accountId, Map<String, String> bundle) =>
      _storage.write(key: _key(accountId), value: jsonEncode(bundle));

  static Future<Map<String, String>?> read(String accountId) async {
    final raw = await _storage.read(key: _key(accountId));
    if (raw == null) return null;
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  static Future<void> delete(String accountId) => _storage.delete(key: _key(accountId));
}
