import 'dart:convert';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:defyx_vpn/utils/singbox_config_converter.dart';

const _vpnEnabledKey = 'vpn_enabled';
const _keyProfiles = 'vpn_profiles_secure';
const _keySelectedProfile = 'selected_profile_index';
const _keyConfig = 'vpn_config_secure';

/// Secure VPN Data storage using DPAPI encryption on Windows
final vpnDataProvider = FutureProvider<IVPNData>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final isEnabled = prefs.getBool(_vpnEnabledKey) ?? false;
  
  // Use secure storage for sensitive data
  const secureStorage = FlutterSecureStorage(
    wOptions: WindowsOptions(),  // Uses DPAPI encryption
    lOptions: LinuxOptions(),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  
  return VPNData._(isEnabled, prefs, secureStorage);
});



final class VPNData implements IVPNData {
  bool _isVPNEnabled;
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  
  // Cache for profiles (loaded from secure storage)
  List<String>? _cachedProfiles;

  VPNData._(this._isVPNEnabled, this._prefs, this._secureStorage);

  @override
  bool get isVPNEnabled => _isVPNEnabled;

  @override
  Future<void> enableVPN() async {
    _isVPNEnabled = true;
    await _prefs.setBool(_vpnEnabledKey, true);
  }

  @override
  Future<void> disableVPN() async {
    _isVPNEnabled = false;
    await _prefs.setBool(_vpnEnabledKey, false);
  }

  @override
  Future<void> saveConfig(String jsonContent) async {
    // Store encrypted in secure storage instead of plaintext file
    await _secureStorage.write(key: _keyConfig, value: jsonContent);
    
    // Also write to file for Sing-box core (required - core reads from file)
    // This is a necessary trade-off, but the file is in app-private directory
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/config.json');
    await file.writeAsString(jsonContent);
  }

  /// Save VPN profiles securely (encrypted)
  @override
  Future<void> saveProfiles(List<String> profiles) async {
    // Store as encrypted JSON array in secure storage
    final jsonString = jsonEncode(profiles);
    await _secureStorage.write(key: _keyProfiles, value: jsonString);
    
    // Update cache
    _cachedProfiles = profiles;
  }

  @override
  Future<void> selectProfile(int index) async {
    final profiles = await getProfilesAsync();
    if (index < 0 || index >= profiles.length) return;

    await _prefs.setInt(_keySelectedProfile, index);

    // Convert selected profile to JSON and save
    final String configUri = profiles[index];
    final String jsonConfig;
    if (configUri.startsWith('vmess://')) {
      jsonConfig = SingboxConfigConverter.convertVmessUrlToSingbox(configUri);
    } else if (configUri.startsWith('vless://')) {
      jsonConfig = SingboxConfigConverter.convertVlessUrlToSingbox(configUri);
    } else if (configUri.startsWith('ss://')) {
      jsonConfig = SingboxConfigConverter.convertShadowsocksUrlToSingbox(configUri);
    } else if (configUri.startsWith('trojan://')) {
      jsonConfig = SingboxConfigConverter.convertTrojanUrlToSingbox(configUri);
    } else if (configUri.startsWith('wireguard://')) {
      jsonConfig = SingboxConfigConverter.convertWireguardUrlToSingbox(configUri);
    } else if (configUri.startsWith('hy2://') || configUri.startsWith('hysteria2://')) {
      jsonConfig = SingboxConfigConverter.convertHysteria2UrlToSingbox(configUri);
    } else {
      // Fallback or Unknown
       jsonConfig = "{}";
    }
    await saveConfig(jsonConfig);
  }

  /// Load profiles from secure storage (async)
  Future<List<String>> getProfilesAsync() async {
    if (_cachedProfiles != null) {
      return _cachedProfiles!;
    }
    
    try {
      final jsonString = await _secureStorage.read(key: _keyProfiles);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _cachedProfiles = decoded.cast<String>();
        return _cachedProfiles!;
      }
    } catch (e) {
      // Fall back to legacy SharedPreferences if migration needed
      final legacy = _prefs.getStringList('vpn_profiles');
      if (legacy != null && legacy.isNotEmpty) {
        // Migrate to secure storage
        await saveProfiles(legacy);
        // Remove from insecure storage
        await _prefs.remove('vpn_profiles');
        return legacy;
      }
    }
    return [];
  }

  @override
  List<String> getProfiles() {
    // Return cached profiles or empty list
    // Note: Caller should prefer getProfilesAsync() for guaranteed fresh data
    return _cachedProfiles ?? [];
  }

  @override
  int getSelectedProfileIndex() {
    return _prefs.getInt(_keySelectedProfile) ?? 0;
  }

  @override
  Future<void> clearAll() async {
    await _prefs.remove(_vpnEnabledKey);
    await _prefs.remove(_keySelectedProfile);
    
    // Clear secure storage
    await _secureStorage.delete(key: _keyProfiles);
    await _secureStorage.delete(key: _keyConfig);
    
    // Clear legacy insecure storage if exists
    await _prefs.remove('vpn_profiles');
    
    // Clear cache
    _cachedProfiles = null;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/config.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore file deletion errors
    }
  }
}
