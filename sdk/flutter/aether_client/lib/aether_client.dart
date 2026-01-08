import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;

// FFI Signatures
typedef StartFunc = Pointer<Utf8> Function(Pointer<Utf8> config);
typedef Start = Pointer<Utf8> Function(Pointer<Utf8> config);

typedef StopFunc = Void Function();
typedef Stop = void Function();

typedef GetStatsFunc = Pointer<Utf8> Function();
typedef GetStats = Pointer<Utf8> Function();

class AetherClient {
  static const MethodChannel _channel = MethodChannel('aether_client');
  static DynamicLibrary? _nativeLib;

  static void _loadNativeLib() {
    if (_nativeLib != null) return;

    if (Platform.isMacOS) {
      _nativeLib = DynamicLibrary.open('libaether.dylib');
    } else if (Platform.isWindows) {
      _nativeLib = DynamicLibrary.open('aether.dll');
    }
  }

  /// Starts the Aether Client with the given [configJSON].
  static Future<String?> start(String configJSON) async {
    // 1. Inject Hardware ID
    String hardwareID = await getHardwareId();

    try {
        Map<String, dynamic> configMap = jsonDecode(configJSON);
        configMap['hardware_id'] = hardwareID;
        configJSON = jsonEncode(configMap);
    } catch (e) {
        print("Error injecting hardware_id: $e");
    }

    // 2. Platform Specific Start
    if (Platform.isAndroid || Platform.isIOS) {
      final String? result = await _channel.invokeMethod('start', {'config': configJSON});
      return result;
    } else if (Platform.isMacOS || Platform.isWindows) {
      _loadNativeLib();
      final start = _nativeLib!
          .lookup<NativeFunction<StartFunc>>('Start')
          .asFunction<Start>();

      final configPtr = configJSON.toNativeUtf8();
      final resultPtr = start(configPtr);
      malloc.free(configPtr);

      if (resultPtr != nullptr) {
         final error = resultPtr.toDartString();
         throw Exception("Aether Start Failed: $error");
      }
    }
  }

  /// Stops the Aether Client.
  static Future<void> stop() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _channel.invokeMethod('stop');
    } else {
      _loadNativeLib();
      final stop = _nativeLib!
          .lookup<NativeFunction<StopFunc>>('Stop')
          .asFunction<Stop>();
      stop();
    }
  }

  /// Returns current stats as a JSON string.
  static Future<String> getStats() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await _channel.invokeMethod('getStats');
    } else {
      _loadNativeLib();
      final getStats = _nativeLib!
          .lookup<NativeFunction<GetStatsFunc>>('GetStats')
          .asFunction<GetStats>();
      
      final resultPtr = getStats();
      return resultPtr.toDartString();
    }
  }
  /// Sends a secure request to the Aether backend.
  static Future<String> request(String endpoint, String payload) async {
    if (Platform.isAndroid || Platform.isIOS) {
       final String result = await _channel.invokeMethod('request', {
         'endpoint': endpoint,
         'payload': payload
       });
       return result;
    } else {
       // Desktop support TODO
       // For now return dummy or error
       return '{"error": "Desktop Secure Request Not Implemented"}';
    }
  }

  static Future<String> getHardwareId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String id = 'unknown';
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id; 
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        id = iosInfo.identifierForVendor ?? 'unknown_ios';
      }
    } catch (_) {}
    return id;
  }
}
