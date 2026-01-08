// Stub for flutter_secure_storage when not available
class FlutterSecureStorage {
  FlutterSecureStorage({
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    MacOsOptions? mOptions,
  });

  Future<void> write({required String key, required String? value}) async {
    // Stub: does nothing on Windows without ATL
    print('[SecureStorage] STUB: Would write $key');
  }

  Future<String?> read({required String key}) async {
    // Stub: always returns null
    print('[SecureStorage] STUB: Would read $key');
    return null;
  }

  Future<void> delete({required String key}) async {
    // Stub: does nothing
    print('[SecureStorage] STUB: Would delete $key');
  }

  Future<void> deleteAll() async {
    // Stub: does nothing
    print('[SecureStorage] STUB: Would delete all');
  }
}

class AndroidOptions {
  const AndroidOptions({this.encryptedSharedPreferences});
  final bool? encryptedSharedPreferences;
}

class IOSOptions {
  const IOSOptions({this.accessibility});
  final KeychainAccessibility? accessibility;
}

class MacOsOptions {
  const MacOsOptions({this.accessibility});
  final KeychainAccessibility? accessibility;
}

enum KeychainAccessibility {
  first_unlock,
  unlocked,
}
