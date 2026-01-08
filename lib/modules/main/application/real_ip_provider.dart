import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/foundation.dart';

class RealIpState {
  final String? countryCode;
  final String? query; // The IP itself
  final bool isLoading;
  final String statusMessage; // New field for UI feedback

  RealIpState({
      this.countryCode, 
      this.query, 
      this.isLoading = false,
      this.statusMessage = ""
  });
  
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

class RealIpNotifier extends StateNotifier<RealIpState> {
  final Ref ref;
  
  RealIpNotifier(this.ref) : super(RealIpState()) {
     // Check initial state
     if (ref.read(connectionStateProvider).status == ConnectionStatus.connected) {
         fetchRealIp();
     }

     // Listen to connection changes
     ref.listen<ConnectionState>(connectionStateProvider, (prev, next) {
        if (next.status == ConnectionStatus.connected) {
           debugPrint("REAL_IP: VPN Connected. Fetching real location...");
           fetchRealIp();
        } else if (next.status == ConnectionStatus.disconnected) {
           debugPrint("REAL_IP: VPN Disconnected. Resetting.");
           state = RealIpState(statusMessage: "Disconnected"); // Reset
        }
     });
  }

  Future<void> fetchRealIp() async {
     state = RealIpState(isLoading: true, statusMessage: "Verifying Location...");
     
     int attempt = 0;
     while (true) {
        final isConnected = ref.read(connectionStateProvider).status == ConnectionStatus.connected;
        if (!isConnected) break;
        if (state.countryCode != null) break;

        attempt++;
        // Feedback: Show Attempt info
        if (mounted) state = RealIpState(isLoading: true, statusMessage: "Verifying... ($attempt)");
        
        // FASTER START: Wait only 0.5s for first attempt, then 3s loop
        await Future.delayed(Duration(milliseconds: attempt == 1 ? 500 : 3000)); 

        try {
           final dio = Dio();
           dio.options.connectTimeout = const Duration(seconds: 8); // Shorter timeout
           
           // Primary: Cloudflare Trace (Text)
           debugPrint("REAL_IP: Attempt $attempt fetching from Cloudflare...");
           final response = await dio.get('https://1.1.1.1/cdn-cgi/trace');
           
           if (response.statusCode == 200 && response.data != null) {
              final data = response.data.toString();
              final locMatch = RegExp(r'loc=([A-Z]{2})').firstMatch(data);
              final ipMatch = RegExp(r'ip=([0-9\.]+)').firstMatch(data);
              
              if (locMatch != null) {
                  final cc = locMatch.group(1);
                  final ip = ipMatch?.group(1);
                  
                  debugPrint("REAL_IP: Success! Cloudflare confirmed: $cc");
                  if (mounted) {
                      state = RealIpState(
                          countryCode: cc,
                          query: ip,
                          isLoading: false,
                          statusMessage: "Verified Location" 
                      );
                  }
                  return;
              }
           }
        } catch (e) {
           debugPrint("REAL_IP: Cloudflare check failed: $e");
           
           // Show Error in UI momentarily so user knows it's failing
           if (mounted) {
               String err = e.runtimeType.toString();
               if (e is DioException) {
                   err = e.type.name; // e.g. connectionTimeout
               }
               state = RealIpState(isLoading: true, statusMessage: "Retry: $err");
           }

           // Fallback only after failure
           try {
              if (attempt % 2 == 0) {
                 final dio2 = Dio();
                 dio2.options.connectTimeout = const Duration(seconds: 5);
                 final res2 = await dio2.get('https://api.myip.com'); // JSON: {ip, country, cc}
                 final cc = res2.data['cc'];
                 if (cc != null && cc.toString().length == 2) {
                     if (mounted) {
                        state = RealIpState(
                            countryCode: cc, 
                            isLoading: false, 
                            statusMessage: "Verified Location"
                        );
                     }
                     return;
                 }
              }
           } catch(e2) {
               debugPrint("REAL_IP: Fallback failed: $e2");
           }
        }
     }
     
     if (mounted && state.countryCode == null) {
         state = RealIpState(isLoading: false, statusMessage: "Failed.");
     }
  }
}

// Keep alive to ensure it listens
final realIpProvider = StateNotifierProvider<RealIpNotifier, RealIpState>((ref) {
  return RealIpNotifier(ref);
});
