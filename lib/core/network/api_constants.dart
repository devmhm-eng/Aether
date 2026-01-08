import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'https://my.themetacore.app';
  }

  static const String login = '/api/client/login';
  static const String status = '/api/client/status';
  static const String heartbeat = '/api/heartbeat';
  static const String version = '/api/client/version';
  static const String secureUnlink = '/api/client/secure_unlink';
  static const String deleteDevice = '/api/client/delete_device';
}
