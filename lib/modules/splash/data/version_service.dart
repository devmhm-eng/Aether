import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:defyx_vpn/core/network/api_constants.dart';
import 'package:defyx_vpn/modules/splash/data/version_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple provider for the service
final versionServiceProvider = Provider((ref) => VersionService());

class VersionService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  Future<VersionResponse?> checkVersion() async {
    try {
      // Create a full URL using the base URL from ApiConstants
      final baseUrl = ApiConstants.baseUrl;
      final url = '$baseUrl${ApiConstants.version}';
      
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('SPLASH: Version Response Raw: ${response.data}');
        return VersionResponse.fromJson(response.data);
      }
    } catch (e) {
      // Fail silently for version check issues to avoid blocking the app on network errors
      // unless it's critical, but typically we let the user proceed if check fails.
       debugPrint('SPLASH: Version check failed: $e'); 
    }
    return null;
  }
}
