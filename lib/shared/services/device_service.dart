import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:android_id/android_id.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final _secureStorage = const FlutterSecureStorage();
  final _androidIdPlugin = const AndroidId();

  Future<String?> getDeviceId() async {
    String? deviceId;
    try {
      if (Platform.isAndroid) {
        // Android: Direct System ID (Persistent)
        deviceId = await _androidIdPlugin.getId();
      } else if (Platform.isIOS) {
        // iOS: Keychain Strategy
        deviceId = await _secureStorage.read(key: 'unique_device_id');
        if (deviceId == null) {
          deviceId = const Uuid().v4();
          await _secureStorage.write(key: 'unique_device_id', value: deviceId);
        }
      } else if (Platform.isLinux) {
        final LinuxDeviceInfo linuxInfo = await _deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId;
      } else if (Platform.isWindows) {
        final WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final MacOsDeviceInfo macOsInfo = await _deviceInfo.macOsInfo;
        deviceId = macOsInfo.systemGUID;
      }
    } on PlatformException {
      deviceId = 'Failed to get deviceId.';
    }
    return deviceId;
  }

  Future<String> getDeviceModel() async {
    String model = 'Unknown Device';
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        model = info.model; 
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        model = info.name; 
      } else if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        model = info.computerName;
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        model = info.computerName;
      } else if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        model = info.name;
      }
    } catch (_) {}

    final id = await getDeviceId();
    if (id != null && id.length > 4) {
        return '$model (${id.substring(0, 4)})';
    }
    return model;
  }

  String getPlatformName() {
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    if (Platform.isWindows) return 'WINDOWS';
    if (Platform.isMacOS) return 'MAC';
    if (Platform.isLinux) return 'LINUX';
    return 'UNKNOWN';
  }
}
