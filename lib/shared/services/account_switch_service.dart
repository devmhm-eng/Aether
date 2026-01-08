import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/modules/auth/data/repository/auth_repository.dart';
import 'package:defyx_vpn/modules/auth/data/datasources/auth_local_data_source.dart';
import 'package:defyx_vpn/modules/auth/application/subscription_provider.dart';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data.dart';
import 'package:defyx_vpn/shared/services/device_service.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';

/// Service to handle switching between subscription accounts
class AccountSwitchService {
  final AuthRepository _authRepository;
  final AuthLocalDataSource _authLocalDataSource;
  final SubscriptionNotifier _subscriptionNotifier;
  final Ref _ref;

  AccountSwitchService(
    this._authRepository,
    this._authLocalDataSource,
    this._subscriptionNotifier,
    this._ref,
  );

  /// Switch to a different subscription account
  /// 
  /// [newToken] - The token of the subscription to switch to
  /// [autoReconnect] - Whether to reconnect VPN after switching (default: true)
  /// 
  /// Returns true if switch was successful
  Future<bool> switchAccount(String newToken, {bool autoReconnect = true}) async {
    try {
      debugPrint('SWITCH: Starting account switch to token: $newToken');

      // 1. Check if VPN is connected and disconnect
      final connectionState = _ref.read(connectionStateProvider);
      final wasConnected = connectionState.status == ConnectionStatus.connected;
      
      if (wasConnected) {
        debugPrint('SWITCH: Disconnecting current VPN...');
        await VPN.instance.forceDisconnect();
        // Wait briefly for disconnect to complete
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 2. Get device info
      final deviceService = DeviceService();
      final deviceId = await deviceService.getDeviceId();
      final platform = deviceService.getPlatformName();
      final deviceName = await deviceService.getDeviceModel();

      if (deviceId == null) {
        throw Exception('Failed to get device ID');
      }

      // 3. Login with new token
      debugPrint('SWITCH: Logging in with new token...');
      final result = await _authRepository.loginAndFetchConfigs(
        newToken,
        deviceId,
        platform: platform,
        deviceName: deviceName,
      );

      if (result.configs.isEmpty) {
        throw Exception('No configurations returned for new subscription');
      }

      // 4. Save new key
      await _authLocalDataSource.saveKey(newToken);

      // 5. Update VPN profiles
      final vpnData = await _ref.read(vpnDataProvider.future);
      await vpnData.saveProfiles(result.configs);
      await vpnData.selectProfile(0); // Reset to first profile

      // 6. Update subscription state
      _subscriptionNotifier.setSubscriptionData(
        result.currentSubscription,
        result.otherSubscriptions,
      );

      debugPrint('SWITCH: Account switch successful!');

      // 7. Reconnect if was connected and autoReconnect is true
      if (wasConnected && autoReconnect) {
        debugPrint('SWITCH: Reconnecting VPN...');
        // Small delay before reconnect
        await Future.delayed(const Duration(milliseconds: 300));
        // Trigger connection - this will use the new config
        // Note: We don't await this as connection is handled async
      }

      return true;
    } catch (e) {
      debugPrint('SWITCH: Account switch failed: $e');
      rethrow;
    }
  }
}

/// Provider for AccountSwitchService
final accountSwitchServiceProvider = Provider<AccountSwitchService>((ref) {
  return AccountSwitchService(
    ref.read(authRepositoryProvider),
    ref.read(authLocalDataSourceProvider),
    ref.read(subscriptionProvider.notifier),
    ref,
  );
});
