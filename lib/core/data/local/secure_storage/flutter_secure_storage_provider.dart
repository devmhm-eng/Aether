import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) {
    const androidOptions = AndroidOptions(
      encryptedSharedPreferences: true,
    );
    const iosOptions = IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    );
    const macOsOptions = MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
    );
    // Windows uses DPAPI (Data Protection API) for encryption
    const windowsOptions = WindowsOptions();
    const linuxOptions = LinuxOptions();
    return FlutterSecureStorage(
      aOptions: androidOptions,
      iOptions: iosOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
  },
);
