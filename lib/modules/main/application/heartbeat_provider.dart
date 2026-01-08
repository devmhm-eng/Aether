import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:defyx_vpn/modules/auth/data/repository/auth_repository.dart';
import 'package:defyx_vpn/shared/services/device_service.dart';
import 'package:defyx_vpn/modules/auth/data/datasources/auth_local_data_source.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/auth/application/subscription_provider.dart';

class HeartbeatState {
  final int intervalSeconds;
  final bool isActive;
  final String? lastError;

  HeartbeatState({
    this.intervalSeconds = 30, // Default 30s
    this.isActive = false,
    this.lastError,
  });

  HeartbeatState copyWith({
    int? intervalSeconds,
    bool? isActive,
    String? lastError,
  }) {
    return HeartbeatState(
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      isActive: isActive ?? this.isActive,
      lastError: lastError,
    );
  }
}

class HeartbeatNotifier extends StateNotifier<HeartbeatState> {
  final AuthRepository _authRepository;
  final AuthLocalDataSource _authLocalDataSource;
  final SubscriptionNotifier _subscriptionNotifier;
  Timer? _timer;
  int _consecutiveFailures = 0;
  bool _isReconnecting = false;

  HeartbeatNotifier(this._authRepository, this._authLocalDataSource, this._subscriptionNotifier) : super(HeartbeatState());

  void setInterval(int seconds) {
    if (seconds < 10) seconds = 10; // Min safety
    state = state.copyWith(intervalSeconds: seconds);
  }

  void startHeartbeat() {
    stopHeartbeat(); // Clear existing
    state = state.copyWith(isActive: true, lastError: null);
    
    _sendHeartbeat(); // Immediate first ping
    
    _timer = Timer.periodic(Duration(seconds: state.intervalSeconds), (timer) {
       _sendHeartbeat();
    });
  }

  void stopHeartbeat() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isActive: false);
  }

  Future<void> _sendHeartbeat() async {
    try {
      final key = await _authLocalDataSource.getKey();
      final deviceId = await DeviceService().getDeviceId();

      if (key == null || deviceId == null) {
        // Missing auth info, stop
        stopHeartbeat();
        return;
      }

      // 1. CHECK VPN TUNNEL HEALTH FIRST
      final isTunnelHealthy = await _checkTunnelHealth();
      
      if (!isTunnelHealthy) {
        _consecutiveFailures++;
        debugPrint('HEARTBEAT: Tunnel health check failed ($_consecutiveFailures/3)');
        
        if (_consecutiveFailures >= 3) {
          debugPrint('HEARTBEAT: Tunnel unhealthy after 3 checks, reconnecting...');
          await _reconnect();
        }
        return;
      }

      // 2. SEND HEARTBEAT
      await _authRepository.sendHeartbeat(key, deviceId);
      
      // 3. POLL STATUS (Multi-Sub)
      final statusResponse = await _authRepository.fetchClientStatus(key, deviceId);
      
      // Reset failure counter on success
      _consecutiveFailures = 0;
      
      // Update Other Subs
      if (statusResponse.others.isNotEmpty) {
         _subscriptionNotifier.updateOtherSubscriptions(statusResponse.others);
      }
      
      // Update Current Sub (Metadata like expiry)
      if (statusResponse.current != null) {
         _subscriptionNotifier.updateCurrent(statusResponse.current!);
         
         // FORCE DISCONNECT IF INACTIVE
         if (statusResponse.current!.status == 'Inactive') {
            stopHeartbeat();
            await VPN.instance.forceDisconnect();
            state = state.copyWith(lastError: "Subscription Expired or Inactive.");
         }
      }
      
    } catch (e) {
      debugPrint('HEARTBEAT: Error: $e');
      _consecutiveFailures++;
      
      if (e.toString().contains('Unauthorized') || e.toString().contains('401')) {
         // KICK DEVICE
         stopHeartbeat();
         await VPN.instance.forceDisconnect();
         state = state.copyWith(lastError: "Device Limit Reached. Disconnected.");
      } else if (_consecutiveFailures >= 3) {
         // Generic failure - likely stale connection
         debugPrint('HEARTBEAT: Multiple failures ($_consecutiveFailures), reconnecting...');
         await _reconnect();
      }
    }
  }

  /// Check if VPN tunnel is healthy by pinging through it
  Future<bool> _checkTunnelHealth() async {
    try {
      // Simple HTTP request that should go through VPN tunnel
      // Using Cloudflare's 1.1.1.1 which always returns 200 OK
      final response = await http.get(
        Uri.parse('http://1.1.1.1'),
      ).timeout(Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('HEARTBEAT: Tunnel health check failed: $e');
      return false;
    }
  }

  /// Automatically reconnect VPN
  Future<void> _reconnect() async {
    if (_isReconnecting) {
      debugPrint('HEARTBEAT: Reconnect already in progress, skipping');
      return;
    }
    
    _isReconnecting = true;
    
    try {
      debugPrint('HEARTBEAT: Starting auto-reconnect');
      
      // Call VPN reconnect method
      await VPN.instance.reconnect();
      
      // Reset counters
      _consecutiveFailures = 0;
      
      debugPrint('HEARTBEAT: Auto-reconnect completed');
    } catch (e) {
      debugPrint('HEARTBEAT: Auto-reconnect failed: $e');
      state = state.copyWith(lastError: 'Auto-reconnect failed');
    } finally {
      _isReconnecting = false;
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final heartbeatProvider = StateNotifierProvider<HeartbeatNotifier, HeartbeatState>((ref) {
  return HeartbeatNotifier(
    ref.read(authRepositoryProvider),
    ref.read(authLocalDataSourceProvider),
    ref.read(subscriptionProvider.notifier),
  );
});

// Watcher to auto-start/stop based on connection status

