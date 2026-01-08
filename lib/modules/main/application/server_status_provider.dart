import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerMetrics {
  final int? latency;
  final String? countryCode;
  final bool isLoading;
  final String? error;

  ServerMetrics({
    this.latency,
    this.countryCode,
    this.isLoading = false,
    this.error,
  });

  ServerMetrics copyWith({
    int? latency,
    String? countryCode,
    bool? isLoading,
    String? error,
  }) {
    return ServerMetrics(
      latency: latency ?? this.latency,
      countryCode: countryCode ?? this.countryCode,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
  
  String get flagEmoji {
     if (countryCode == null) return "🌍";
     return _countryCodeToEmoji(countryCode!);
  }
  
  String _countryCodeToEmoji(String countryCode) {
    if (countryCode.length != 2) return "🌍";
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}

// Global cache to prevent re-fetching GeoIP for same host
final Map<String, String> _geoIpCache = {};

class ServerMetricsNotifier extends StateNotifier<ServerMetrics> {
  final String profile;
  
  ServerMetricsNotifier(this.profile) : super(ServerMetrics(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    // Check if still mounted before any state access
    if (!mounted) return;
    
    // 0. Heuristic Removed.
    // We only rely on Real IP / Host for location now.

    // 0. Extract Remarks/Name
    String remarks = "";
    if (profile.startsWith("vless://")) {
         if (profile.contains("#")) {
            remarks = Uri.decodeComponent(profile.substring(profile.indexOf("#") + 1));
         }
    } else if (profile.startsWith("vmess://")) {
        try {
           String b64 = profile.substring(8);
           while (b64.length % 4 != 0) b64 += '=';
           final decoded = utf8.decode(base64.decode(b64));
           final json = jsonDecode(decoded);
           if (json is Map<String, dynamic>) {
              remarks = json['ps']?.toString() ?? "";
           }
        } catch (_) {}
    }

    // 1. Heuristic Check: Extract Country from Remarks (Emoji or Name)
    // This solves the Tunnel issue (Iran IP -> Germany Server labeled "Germany")
    final heuristicCode = _extractCountryCodeFromRemarks(remarks);
    if (heuristicCode != null) {
        if (mounted) state = state.copyWith(countryCode: heuristicCode);
    }
    
    String connectHost = "";
    int connectPort = 443;
    
    // ... Parsing ...
    
    // Parse Host/Port
    try {
       if (profile.startsWith("vless://")) {
          // ... existing vless parse ...
          String cleanProfile = profile;
          if (profile.contains("#")) cleanProfile = profile.substring(0, profile.indexOf("#"));
          final uri = Uri.parse(cleanProfile);
          connectHost = uri.host;
          connectPort = uri.port;
           if (connectHost.isEmpty) {
               final parts = profile.split("@");
               if (parts.length > 1) {
                  final addressParts = parts[1].split(":");
                  if (addressParts.isNotEmpty) {
                      connectHost = addressParts[0];
                      if (addressParts.length > 1) {
                        connectPort = int.tryParse(addressParts[1].split("?")[0]) ?? 443;
                      }
                  }
               }
           }
       } else if (profile.startsWith("vmess://")) {
           try {
             String b64 = profile.substring(8);
             while (b64.length % 4 != 0) b64 += '=';
             final decoded = utf8.decode(base64.decode(b64));
             final json = jsonDecode(decoded);
             if (json is Map<String, dynamic>) {
                 connectHost = json['add']?.toString() ?? "";
                 connectPort = int.tryParse(json['port']?.toString() ?? "") ?? 443;
             }
           } catch (_) {}
       }
    } catch (e) {
       if (connectHost.isEmpty && heuristicCode == null) {
           state = state.copyWith(isLoading: false, error: "Parse Error");
           return;
       }
    }
    
    if (connectHost.isEmpty) { 
        if (mounted) state = state.copyWith(isLoading: false, error: heuristicCode != null ? null : "Invalid Host");
        return;
    }

    // 2. Check Latency (Ping Entry Point)
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(connectHost, connectPort, timeout: const Duration(seconds: 3));
      stopwatch.stop();
      await socket.close();
      
      if (!mounted) return;
      final latency = stopwatch.elapsedMilliseconds;
      state = state.copyWith(latency: latency);
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: "Timeout");
    }

    if (!mounted) return;
    
    // 3. Check GeoIP - REMOVED per User Guide
    // "GeoIP of entry address does not show exit country"
    // We strictly rely on:
    // A. User-provided Name/Emoji (Heuristic)
    // B. Real-IP Check (Phase 2, after connection)
    if (mounted) state = state.copyWith(isLoading: false);
  }

  String? _extractCountryCodeFromRemarks(String name) {
     if (name.isEmpty) return null;
     
     // A. Check for Emoji Flags (Regex)
     // Range: 1F1E6-1F1FF (Regional Indicator Symbols)
     final emojiRegex = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);
     final match = emojiRegex.firstMatch(name);
     if (match != null) {
         final flag = match.group(0)!;
         if (flag.runes.length == 2) {
             final first = flag.runes.first - 0x1F1E6 + 0x41;
             final second = flag.runes.last - 0x1F1E6 + 0x41;
             return String.fromCharCode(first) + String.fromCharCode(second);
         }
     }

     // B. Check for Common Keywords (Case Insensitive)
     final lower = name.toLowerCase();
     if (lower.contains('germany') || lower.contains('deutchland')) return 'DE';
     if (lower.contains('united states') || lower.contains('usa') || lower.contains('america')) return 'US';
     if (lower.contains('united kingdom') || lower.contains('uk') || lower.contains('britain')) return 'GB';
     if (lower.contains('frence') || lower.contains('france')) return 'FR'; // 'frence' typo handling
     if (lower.contains('netherlands') || lower.contains('nl') || lower.contains('holland')) return 'NL';
     if (lower.contains('turkey')) return 'TR';
     if (lower.contains('uae') || lower.contains('emirates')) return 'AE';
     if (lower.contains('finland')) return 'FI';
     if (lower.contains('russia')) return 'RU';
     if (lower.contains('canada')) return 'CA';
     
     return null;
  }
  
  // Clean up unused stuff
  static final List<Future<void> Function()> _geoIpQueue = [];
  static bool _isQueueProcessing = false;

  void _scheduleGeoIpCheck(String host) {
      if (host.isEmpty) return;
      
      _geoIpQueue.add(() async {
         if (_disposed) return;
         
         if (_geoIpCache.containsKey(host)) {
             if (mounted) state = state.copyWith(countryCode: _geoIpCache[host], isLoading: false);
             return;
         }
         
         try {
             final dio = Dio(); 
             dio.options.connectTimeout = const Duration(seconds: 5);
             final res = await dio.get("http://ip-api.com/json/$host");
             if (res.statusCode == 200 && res.data['status'] == 'success') {
                final code = res.data['countryCode'] as String;
                _geoIpCache[host] = code;
                if (mounted) state = state.copyWith(countryCode: code, isLoading: false);
             } else {
                if (mounted) state = state.copyWith(isLoading: false);
             }
         } catch (_) {
             if (mounted) state = state.copyWith(isLoading: false);
         }
      });
      _processQueue();
  }

  static Future<void> _processQueue() async {
      if (_isQueueProcessing) return;
      _isQueueProcessing = true;
      while (_geoIpQueue.isNotEmpty) {
          final task = _geoIpQueue.removeAt(0);
          await task();
          await Future.delayed(const Duration(milliseconds: 1500)); 
      }
      _isQueueProcessing = false;
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }


}

final serverMetricsProvider = StateNotifierProvider.autoDispose.family<ServerMetricsNotifier, ServerMetrics, String>((ref, profile) {
  return ServerMetricsNotifier(profile);
});
