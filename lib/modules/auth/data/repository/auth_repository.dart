import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/http_client.dart';
import '../../../../core/network/http_client_interface.dart';
import '../datasources/auth_local_data_source.dart';
import 'dart:convert';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(httpClientProvider),
    ref.read(authLocalDataSourceProvider),
  );
});

class AuthRepository {
  final IHttpClient _httpClient;
  final AuthLocalDataSource _localDataSource;

  AuthRepository(this._httpClient, this._localDataSource);

  Future<LoginResponse> loginAndFetchConfigs(
    String token,
    String deviceId, {
    String platform = 'UNKNOWN',
    String deviceName = 'Unknown Device',
  }) async {
    try {
      // 1. Login Request (Master Guide)
      debugPrint('AUTH: Login Request V2 (Key Fix) - Token: $token');
      final response = await _httpClient.post(
        '${ApiConstants.baseUrl}${ApiConstants.login}',
        data: {
          'key': token,
          'device_id': deviceId,
          'platform': platform,
          'device_name': deviceName,
        },
      );
      
      final data = response.data;
      debugPrint('AUTH: Response data: $data');

      if (data == null) {
        throw Exception('Login failed: No data');
      }

      // Handle 403 Forbidden (Logic handled by Dio usually, but checking status if 200 returned with error)
      if (data['error'] != null) {
         throw Exception(data['error']);
      }
      
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Login failed');
      }

      await _localDataSource.saveKey(token);
      
      final subscription = data['subscription'] ?? {};
      String configPayload = data['config'] as String;
      
      // Parse Metadata
      final int deviceLimit = (subscription['max_devices'] is int) ? subscription['max_devices'] : 5;
      final int activeDevices = (subscription['active_devices'] is int) ? subscription['active_devices'] : 0; 
      final int heartbeatInterval = (data['heartbeat_interval'] is int) ? data['heartbeat_interval'] : 30;
      
      // NEW: Parse Current Subscription
      debugPrint('Parsed Current Subscription: $subscription');
      var currentSub = SubscriptionItem.fromJson(subscription);
      
      // CACHE NAME LOGIC
      if (!currentSub.name.startsWith('Subscription ')) {
          await _localDataSource.saveSubscriptionName(currentSub.id, currentSub.name);
      } else {
          final cachedName = await _localDataSource.getSubscriptionName(currentSub.id);
          if (cachedName != null) {
              currentSub = SubscriptionItem(
                  id: currentSub.id,
                  name: cachedName,
                  status: currentSub.status,
                  expiryDate: currentSub.expiryDate,
                  activeDevices: currentSub.activeDevices,
                  maxDevices: currentSub.maxDevices,
                  token: currentSub.token
              );
          }
      }

      // NEW: Parse Other Subscriptions
      final List<SubscriptionItem> otherSubs = [];
      if (data['other_subscriptions'] != null) {
          debugPrint('Raw Other Subs: ${data['other_subscriptions']}');
          if (data['other_subscriptions'] is List) {
            for (var item in data['other_subscriptions']) {
                if (item is Map<String, dynamic>) {
                   try {
                     var subItem = SubscriptionItem.fromJson(item);
                     
                     // CACHE NAME LOGIC
                     if (!subItem.name.startsWith('Subscription ')) {
                        await _localDataSource.saveSubscriptionName(subItem.id, subItem.name);
                     } else {
                        final cachedName = await _localDataSource.getSubscriptionName(subItem.id);
                        if (cachedName != null) {
                            subItem = SubscriptionItem(
                                id: subItem.id,
                                name: cachedName,
                                status: subItem.status,
                                expiryDate: subItem.expiryDate,
                                activeDevices: subItem.activeDevices,
                                maxDevices: subItem.maxDevices,
                                token: subItem.token
                            );
                        }
                     }
                     
                     otherSubs.add(subItem);
                   } catch (e) {
                     debugPrint('Error parsing other sub item: $e');
                   }
                }
            }
          }
      } else {
        debugPrint('No other_subscriptions field found in response.');
      }
      debugPrint('Final Parsed Other Subs Count: ${otherSubs.length}');

      // 2. configPayload can be a URL (http) or Raw (vmess://...)
      String rawConfigs = '';
      if (configPayload.startsWith('http')) {
        // It's a subscription link
        final subResponse = await _httpClient.get(configPayload);
        rawConfigs = subResponse.data.toString();
      } else {
        // It's raw configs
        rawConfigs = configPayload;
      }

      // 3. Parse content
      String finalConfigStr = rawConfigs;
      if (!finalConfigStr.contains('://')) {
        try {
           final decoded = utf8.decode(base64Decode(base64.normalize(finalConfigStr)));
           finalConfigStr = decoded;
        } catch (_) {}
      }

      List<String> configs = finalConfigStr.split(RegExp(r'[,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

         
       // Parse Branding
       Branding? branding;
       if (data['branding'] != null) {
          try {
             branding = Branding.fromJson(data['branding']);
          } catch(e) {
             debugPrint('Error parsing branding: $e');
          }
       }

      return LoginResponse(
        configs: configs,
        deviceLimit: deviceLimit,
        activeDevices: activeDevices,
        heartbeatInterval: heartbeatInterval,
        currentSubscription: currentSub,
        otherSubscriptions: otherSubs,
        branding: branding,
      );

    } catch (e) {
      if (e is DioException) {
         if (e.response?.statusCode == 403) {
            throw Exception("Device limit reached. Contact admin.");
         }
         if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
             throw Exception("Invalid Subscription Key");
         }
         if (e.response?.statusCode == 429) {
            throw Exception("License limit reached. Please contact your provider.");
         }
      }
      rethrow;
    }
  }

  Future<LoginResponse> loginWithDeviceId(String deviceId, {String platform = 'UNKNOWN', String deviceName = 'Unknown'}) async {
    // Attempt to login using the Device ID as the token
    return loginAndFetchConfigs(deviceId, deviceId, platform: platform, deviceName: deviceName);
  }

  Future<void> sendHeartbeat(String key, String deviceId) async {
    try {
      await _httpClient.post(
        '${ApiConstants.baseUrl}${ApiConstants.heartbeat}',
        data: {
          'key': key,
          'device_id': deviceId,
        },
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
         throw Exception('Unauthorized'); // Standardize for service
      }
      rethrow;
    }
  }

  Future<StatusResponse> fetchClientStatus(String token, String deviceId) async {
    try {
      final response = await _httpClient.post(
        '${ApiConstants.baseUrl}${ApiConstants.status}',
        data: {
           'token': token,
           'device_id': deviceId,
        },
      );
      
      final data = response.data;
      final List<SubscriptionItem> otherSubs = [];
      SubscriptionItem? currentSub;
      
      if (data != null) {
          // Parse Current
          if (data['subscription'] != null) {
              try {
                  var sub = SubscriptionItem.fromJson(data['subscription']);
                  // CACHE NAME
                  if (!sub.name.startsWith('Subscription ')) {
                      await _localDataSource.saveSubscriptionName(sub.id, sub.name);
                  } else {
                      final cachedName = await _localDataSource.getSubscriptionName(sub.id);
                      if (cachedName != null) {
                          sub = SubscriptionItem(
                              id: sub.id, name: cachedName, status: sub.status,
                              expiryDate: sub.expiryDate, activeDevices: sub.activeDevices,
                              maxDevices: sub.maxDevices, token: sub.token
                          );
                      }
                  }
                  currentSub = sub;
              } catch (_) {}
          }

          // Parse Others
          if (data['other_subscriptions'] != null && data['other_subscriptions'] is List) {
            for (var item in data['other_subscriptions']) {
                if (item is Map<String, dynamic>) {
                   try {
                     var subItem = SubscriptionItem.fromJson(item);
                     
                     // CACHE NAME LOGIC
                     // If server sent NO name (missing or empty), prefer CACHE over parsed config name
                     String? serverName = item['name']?.toString();
                     bool hasServerName = serverName != null && serverName.isNotEmpty;
                     
                     if (hasServerName) {
                        // We have a real name, save it
                        if (!subItem.name.startsWith('Subscription ')) {
                           await _localDataSource.saveSubscriptionName(subItem.id, subItem.name);
                        }
                     } else {
                        // No server name, try cache (overriding config-parsed name)
                        final cachedName = await _localDataSource.getSubscriptionName(subItem.id);
                        if (cachedName != null && cachedName.isNotEmpty) {
                            subItem = SubscriptionItem(
                                id: subItem.id,
                                name: cachedName,
                                status: subItem.status,
                                expiryDate: subItem.expiryDate,
                                activeDevices: subItem.activeDevices,
                                maxDevices: subItem.maxDevices,
                                token: subItem.token
                            );
                        }
                     }
                     
                     otherSubs.add(subItem);
                   } catch (_) {}
                }
            }
          }
      }
      return StatusResponse(current: currentSub, others: otherSubs);
    } catch (e) {
      debugPrint('Error fetching client status: $e');
      return StatusResponse(current: null, others: []); // Fail silent
    }
  }

  /// Attempts to fetch a real token for a registered device.
  /// Sends a status request with 'guest' token and device_id.
  /// If device is recognized, server returns the real token in other_subscriptions.
  /// 
  /// Returns the real token if found, null otherwise.
  Future<String?> fetchTokenByDeviceId(String deviceId) async {
    try {
      debugPrint('AUTH: Checking if device $deviceId is registered...');
      final response = await _httpClient.post(
        '${ApiConstants.baseUrl}${ApiConstants.status}',
        data: {
           'token': 'guest', // Placeholder token
           'device_id': deviceId,
        },
      );
      
      final data = response.data;
      debugPrint('AUTH: Device check response: $data');
      
      if (data != null && data['valid'] == true && data['other_subscriptions'] != null) {
          if (data['other_subscriptions'] is List && (data['other_subscriptions'] as List).isNotEmpty) {
            final firstSub = data['other_subscriptions'][0];
            if (firstSub is Map<String, dynamic> && firstSub['token'] != null) {
               final realToken = firstSub['token'].toString();
               debugPrint('AUTH: Found real token for device: $realToken');
               return realToken;
            }
          }
      }
      
      debugPrint('AUTH: Device not registered or no token found');
      return null;
    } catch (e) {
      debugPrint('AUTH: Error checking device registration: $e');
      return null;
    }
  }
  Future<bool> secureUnlink(String token, String deviceId) async {
    try {
      final response = await _httpClient.post(
        '${ApiConstants.baseUrl}${ApiConstants.secureUnlink}',
        data: {
          'token': token,
          'device_id': deviceId,
        },
      );
      
      // Spec: Returns 200 OK on success.
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error calling secure_unlink: $e');
      return false;
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    try {
      await _httpClient.post(
        '${ApiConstants.baseUrl}${ApiConstants.deleteDevice}',
        data: {
          'device_id': deviceId,
        },
      );
    } catch (e) {
      debugPrint('Error calling delete_device: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _localDataSource.deleteKey();
  }
}

class LoginResponse {
  final List<String> configs;
  final int deviceLimit;
  final int activeDevices;
  final int heartbeatInterval;
  final SubscriptionItem currentSubscription; // Changed from int ID
  final List<SubscriptionItem> otherSubscriptions;
  final Branding? branding;

  LoginResponse({
    required this.configs,
    required this.deviceLimit,
    required this.activeDevices,
    required this.heartbeatInterval,
    required this.currentSubscription,
    required this.otherSubscriptions,
    this.branding,
  });
}

class StatusResponse {
  final SubscriptionItem? current;
  final List<SubscriptionItem> others;
  
  StatusResponse({this.current, required this.others});
}

class Branding {
  final String? appName;
  final String? supportChannel; // telegram_channel
  final String? supportContact; // support_contact
  final String? telegramGroup;
  final String? instagram;

  Branding({
    this.appName, 
    this.supportChannel, 
    this.supportContact,
    this.telegramGroup,
    this.instagram,
  });

  factory Branding.fromJson(Map<String, dynamic> json) {
    debugPrint('AUTH: Parsing Branding keys: ${json.keys.toList()}');
    return Branding(
      appName: json['app_name'],
      // Fallbacks for Support Channel
      supportChannel: json['support_channel'] ?? json['telegram_channel'],
      // Fallbacks for Support Contact
      supportContact: json['support_contact'] ?? json['support_url'] ?? json['admin_contact'],
      // Fallbacks for Telegram Group
      telegramGroup: json['telegram_group'] ?? json['telegram_link'] ?? json['telegram'],
      // Prioritize instagram_link, fall back to instagram
      instagram: json['instagram_link'] ?? json['instagram'],
    );
  }
}

class SubscriptionItem {
  final int id;
  final String name;
  final String status;
  final String expiryDate;
  final int activeDevices;
  final int maxDevices;
  final String? token; // Added token for switching

  SubscriptionItem({
      required this.id, 
      required this.name, 
      required this.status, 
      required this.expiryDate,
      required this.activeDevices,
      required this.maxDevices,
      this.token,
  });
  
  factory SubscriptionItem.fromJson(Map<String, dynamic> json) {
      // Try multiple field names for token
      String? tokenValue = json['token']?.toString();
      if (tokenValue == null || tokenValue.isEmpty) {
        tokenValue = json['subscription_token']?.toString();
      }
      if (tokenValue == null || tokenValue.isEmpty) {
        tokenValue = json['sub_token']?.toString();
      }

      // Parse Name Logic
      String? parsedName = json['name']?.toString();
      if (parsedName == null || parsedName.isEmpty) {
          // Try to extract from config
          final config = json['config']?.toString();
          if (config != null && config.isNotEmpty) {
             try {
                if (config.startsWith('vmess://')) {
                   // Decode VMess
                   String base64Str = config.substring(8).trim();
                   // Fix padding
                   int padding = base64Str.length % 4;
                   if (padding > 0) {
                     base64Str += '=' * (4 - padding);
                   }
                   final decoded = utf8.decode(base64Decode(base64Str));
                   final map = jsonDecode(decoded);
                   parsedName = map['ps']?.toString();
                } else {
                   // Try fragment for VLESS, Trojan, etc.
                   final uri = Uri.tryParse(config);
                   if (uri != null && uri.hasFragment && uri.fragment.isNotEmpty) {
                      parsedName = Uri.decodeComponent(uri.fragment);
                   }
                }
             } catch (e) {
                debugPrint('Error parsing config name: $e');
             }
          }
      }

      // Fallback
      if (parsedName == null || parsedName.isEmpty) {
         parsedName = 'Subscription ${json['id']}';
      }
      
      // Log the parsed data for debugging
      debugPrint('SubscriptionItem.fromJson: id=${json['id']}, name=$parsedName, token=$tokenValue');
      
      // Status Logic (Prioritize is_active)
      String status = json['status']?.toString() ?? 'Active';
      final isActiveVal = json['is_active'];
      if (isActiveVal == false || isActiveVal == 0 || isActiveVal == 'false' || isActiveVal == '0') {
         status = 'Inactive';
      }
      
      return SubscriptionItem(
          id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
          name: parsedName,
          status: status,
          expiryDate: json['expired_at']?.toString() ?? json['expiry']?.toString() ?? 'Unknown',
          activeDevices: json['active_devices'] is int ? json['active_devices'] : 0,
          maxDevices: json['max_devices'] is int ? json['max_devices'] : 5,
          token: tokenValue,
      );
  }
}
