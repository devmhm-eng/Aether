import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSource();
});

class AuthLocalDataSource {
  final FlutterSecureStorage _storage;

  AuthLocalDataSource() : _storage = const FlutterSecureStorage();

  static const _keyAuthKey = 'auth_key';

  Future<void> saveKey(String key) async {
    await _storage.write(key: _keyAuthKey, value: key);
  }

  Future<String?> getKey() async {
    return await _storage.read(key: _keyAuthKey);
  }

  Future<void> deleteKey() async {
    await _storage.delete(key: _keyAuthKey);
  }

  // --- Name Caching ---
  Future<void> saveSubscriptionName(int id, String name) async {
    await _storage.write(key: 'sub_name_$id', value: name);
  }

  Future<String?> getSubscriptionName(int id) async {
    return await _storage.read(key: 'sub_name_$id');
  }
}
