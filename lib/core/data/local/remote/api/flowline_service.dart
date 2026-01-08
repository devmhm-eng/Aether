import 'dart:convert';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service_interface.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/global_vars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final flowlineServiceProvider = Provider<IFlowlineService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return FlowlineService(secureStorage);
});

class FlowlineService implements IFlowlineService {
  final ISecureStorage _secureStorage;
  final _vpnBridge = VpnBridge();
  static var _allowToUpdate = true;
  static final _updateFlowlinePerios = int.parse(dotenv.env['UPDATE_FLOWLINE_PERIOD'] ?? "1");

  FlowlineService(this._secureStorage);

  @override
  Future<String> getFlowline() => _vpnBridge.getFlowLine();

  @override
  Future<void> saveFlowline() async {
    if (!_allowToUpdate) {
      return;
    }
    final flowLine = await getFlowline();
    if (flowLine.isNotEmpty && flowLine != "{}") {
      try {
        final decoded = json.decode(flowLine);

        // Check if decoded is a valid map and has required fields
        if (decoded is! Map<String, dynamic>) {
          debugPrint('Flowline is not a valid JSON object');
          return;
        }

        final appBuildType = GlobalVars.appBuildType;
        
        // Safely access version with null checks
        final versionMap = decoded['version'];
        if (versionMap == null || versionMap is! Map) {
          debugPrint('Flowline version is missing or invalid');
          return;
        }
        
        final version = versionMap[appBuildType];
        if (version == null) {
          debugPrint('Flowline version for $appBuildType is missing');
          return;
        }

        // Safely access advertise
        final advertiseStorageMap = {
          'api_advertise': decoded['advertise'] ?? {},
        };
        await _secureStorage.writeMap(apiAvertiseKey, advertiseStorageMap);

        // Safely access forceUpdate and changeLog
        final forceUpdateMap = decoded['forceUpdate'];
        final changeLogMap = decoded['changeLog'];
        
        final versionStorageMap = {
          'api_app_version': version,
          'forceUpdate': (forceUpdateMap is Map && forceUpdateMap[version] != null) 
              ? forceUpdateMap[version] 
              : false,
          'changeLog': (changeLogMap is Map && changeLogMap[version] != null) 
              ? changeLogMap[version] 
              : [],
        };

        await _secureStorage.writeMap(apiVersionParametersKey, versionStorageMap);

        // Safely access flowLine array
        final flowLineArray = decoded['flowLine'];
        if (flowLineArray != null) {
          await _secureStorage.write(flowLineKey, json.encode(flowLineArray));
        }
        
        final ref = ProviderContainer();
        final settings = ref.read(settingsProvider.notifier);
        await settings.updateSettingsBasedOnFlowLine();
        _allowToUpdate = false;
        Future.delayed(Duration(seconds: _updateFlowlinePerios), () {
          _allowToUpdate = true;
        });
      } catch (e) {
        debugPrint('Error parsing flowline: $e');
      }
    } else {
      debugPrint('Flowline is empty, cannot save');
    }
  }
}
