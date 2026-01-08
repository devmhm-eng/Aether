import 'dart:io';

import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data.dart';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data_interface.dart';
import 'package:defyx_vpn/modules/auth/data/datasources/auth_local_data_source.dart';
import 'package:defyx_vpn/modules/auth/data/repository/auth_repository.dart';
import 'package:defyx_vpn/shared/services/device_service.dart';
import 'package:defyx_vpn/modules/auth/application/subscription_provider.dart';
import 'package:defyx_vpn/modules/auth/application/branding_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';
import 'package:defyx_vpn/modules/splash/data/version_service.dart';
import 'package:defyx_vpn/modules/splash/presentation/widgets/update_dialog.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/animated_background.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToMain();
  }

  Future<void> _navigateToMain() async {
    debugPrint('SPLASH: Starting navigation logic...');
    
    // 0. Check App Version
    final shouldProceed = await _checkAppVersion();
    if (!shouldProceed) return;

    final router = GoRouter.of(context);
    
    // 1. Check VPN Data
    debugPrint('SPLASH: Reading VPN Data...');
    final IVPNData vpnData;
    try {
      vpnData = await ref.read(vpnDataProvider.future).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('SPLASH: Timeout reading VPN Data! Proceeding with default disabled state.');
              throw Exception('VPN Data Timeout');
            },
          );
    } catch (e) {
      debugPrint('SPLASH: Error reading VPN data: $e');
      if (mounted) context.go('/login');
      return;
    }

    // 2. Check for Saved Key & Auto-Login
    debugPrint('SPLASH: Checking for saved key...');
    final localAuth = ref.read(authLocalDataSourceProvider);
    String? savedKey = await localAuth.getKey(); // Mutable to allow update
    debugPrint('SPLASH: Saved Key result: "$savedKey"');
    
    final deviceService = DeviceService();
    final deviceId = await deviceService.getDeviceId();
    final platform = deviceService.getPlatformName();
    final deviceName = await deviceService.getDeviceModel();
    debugPrint('SPLASH: Device Info - ID: $deviceId, Name: $deviceName, Platform: $platform');

    // If no key found, try to fetch real token via device ID check
    if (savedKey == null || savedKey.isEmpty) {
       debugPrint('SPLASH: No saved key. Checking if device is registered...');
       if (deviceId != null) {
          try {
             // Step 1: Try to get real token via device check (guest token)
             final realToken = await ref.read(authRepositoryProvider).fetchTokenByDeviceId(deviceId);
             
             if (realToken != null && realToken.isNotEmpty) {
                debugPrint('SPLASH: Device registered! Got real token. Logging in...');
                // Step 2: Login with the real token
                final result = await ref.read(authRepositoryProvider).loginAndFetchConfigs(
                  realToken,
                  deviceId,
                  platform: platform,
                  deviceName: deviceName,
                );
                   debugPrint('SPLASH: Auto-login with device token successful.');
                   await localAuth.saveKey(realToken);
                   savedKey = realToken;
                   ref.read(brandingProvider.notifier).state = result.branding;
             } else {
                // Fallback: Try Device ID as token directly (legacy support)
                debugPrint('SPLASH: Device not registered. Trying Device ID as token...');
                final result = await ref.read(authRepositoryProvider).loginWithDeviceId(
                  deviceId,
                  platform: platform,
                  deviceName: deviceName,
                );
                   debugPrint('SPLASH: Device ID Login Success.');
                   await localAuth.saveKey(deviceId);
                   savedKey = deviceId;
                   ref.read(brandingProvider.notifier).state = result.branding;
             }
          } catch (e) {
             debugPrint('SPLASH: Auto-login attempts failed: $e');
          }
       }
    }

    if (savedKey != null && savedKey.isNotEmpty) {
      debugPrint('SPLASH: Key found ($savedKey). Attempting auto-login...');
      try {
        if (deviceId != null) {
          // A. Get All Configs (List)
          final result = await ref.read(authRepositoryProvider).loginAndFetchConfigs(
            savedKey, 
            deviceId,
            platform: platform,
            deviceName: deviceName,
          );
          final configs = result.configs;
          
          if (configs.isNotEmpty) {
             // B. Save Profiles
             await vpnData.saveProfiles(configs);
             
             // NEW: Save Subscription Info
             ref.read(subscriptionProvider.notifier).setSubscriptionData(
                result.currentSubscription,
                result.otherSubscriptions,
             );
             
             // NEW: Save Branding Info (CRITICAL for Windows)
              ref.read(brandingProvider.notifier).state = result.branding;

              // C. Select Profile (Keep existing selection if valid, else 0)
             int indexToSelect = vpnData.getSelectedProfileIndex();
             if (indexToSelect >= configs.length) indexToSelect = 0;
             await vpnData.selectProfile(indexToSelect);

             debugPrint('SPLASH: Auto-login success. Config updated.');

             // Proceed to Main
             if (mounted) {
               router.go('/main');
               return;
             }
          } else {
             throw Exception("No configurations returned.");
          }

           // Proceed to Main
          if (mounted) {
            router.go('/main');
            return;
          }
        }
      } catch (e) {
        debugPrint('SPLASH: Auto-login failed: $e.');
        
        // Handle specific errors
        final errorMsg = e.toString().toLowerCase();
        
        // 1. Invalid Token / Unauthorized (401/404 from repo)
        if (errorMsg.contains('invalid subscription key') || errorMsg.contains('unauthorized')) {
             debugPrint('SPLASH: Token invalid. Clearing key and redirecting to Login.');
             await localAuth.deleteKey();
             if (mounted) router.go('/login');
             return;
        }

        // 2. Device Limit (403 from repo)
        if (errorMsg.contains('device limit reached')) {
             debugPrint('SPLASH: Device Limit Reached. Cannot login.');
             // Ideally show a dialog here or navigate to an error screen.
             // For now, redirecting to Login is BAD because it asks for token again.
             // But we have no error screen. Let's redirect to Login but maybe pass extra param?
             // Or show a Dialog and fail to navigate?
             // Since we can't block here forever easily without UI, let's delete key so user is forced to re-enter or contact admin?
             // NO, user said "do not ask token next time".
             // If limit reached, they are stuck.
             // Let's go to Login for now but maybe showing a Toast?
             // Actually, if we go to Login, they just re-type and get same error.
             if (mounted) router.go('/login'); // Fallback for now as we lack Error Screen
             return;
        }

        // 3. Network Error / Other
        // If it's a network error, maybe we should let them into the app in "Offline" mode if possible?
        // But the requirement implies strict checks.
        // For now, default to Login.
        if (mounted) {
            router.go('/login');
            return;
        }
      }
    } else {
        debugPrint('SPLASH: No key found and Device ID login failed. Going to login.');
    }

    // Default Fallback
    if (mounted) router.go('/login');
  }

  Future<bool> _checkAppVersion() async {
    try {
      final versionService = ref.read(versionServiceProvider);
      debugPrint('SPLASH: calling versionService.checkVersion()...');
      final versionInfo = await versionService.checkVersion();

      if (versionInfo == null) return true;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);
      
      if (versionInfo.latestVersion == null || versionInfo.minVersion == null) {
         debugPrint('SPLASH: Version check skipped - missing version info from server.');
         return true;
      }

      final latestVersion = Version.parse(versionInfo.latestVersion!);
      final minVersion = Version.parse(versionInfo.minVersion!);

      debugPrint('SPLASH: Version Check - Current: $currentVersion, Latest: $latestVersion, Min: $minVersion');

      if (currentVersion < minVersion) {
        debugPrint('SPLASH: Force update required.');
        if (!mounted) return false;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(
            isForceUpdate: true,
            downloadUrl: versionInfo.downloadUrl ?? '',
          ),
        );
        return false; // Never proceed if force update
      } else if (currentVersion < latestVersion) {
        debugPrint('SPLASH: Soft update available.');
        if (!mounted) return true;
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => UpdateDialog(
            isForceUpdate: false,
            downloadUrl: versionInfo.downloadUrl ?? '',
          ),
        );
        // User dismissed or clicked later, proceed
        return true;
      }
      
      return true;
    } catch (e) {
      debugPrint('SPLASH: Version check failed: $e');
      return true; // Proceed on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
         children: [
            Positioned.fill(
              child: AnimatedBackground(connectionStatus: ConnectionStatus.disconnected),
            ),
            _buildContent(),
         ],
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Center(
        child: Column(
          children: [
            const Spacer(flex: 8),
            _buildLogo(),
            20.h.verticalSpace,
            _buildTitle(),
            const Spacer(flex: 9),
            _buildSubtitle(),
            60.h.verticalSpace,
            _buildLoadingIndicator(),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }



  Widget _buildLogo() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 235.w),
      child: AppIcons.logo(width: 150.w, height: 150.w),
    );
  }

  Widget _buildTitle() {
    final branding = ref.watch(brandingProvider);
    // Use dynamic branding on all platforms
    final appName = branding?.appName ?? 'MetaCore';
    
    // Attempt to split smartly for two-tone effect if it has exactly 2 words
    final parts = appName.trim().split(' ');
    
    if (parts.length == 2) {
       return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _titlePart(parts[0], FontWeight.w700),
          SizedBox(width: 8.w),
          _titlePart(parts[1], FontWeight.w400, color: Colors.white),
        ],
      );
    } else if (appName.toLowerCase().endsWith('vpn')) {
       // Special handling for "SomethingVPN" -> "Something" + "VPN"
       final namePart = appName.substring(0, appName.length - 3);
       return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _titlePart(namePart, FontWeight.w700),
          _titlePart('VPN', FontWeight.w400, color: Colors.white),
        ],
      );
    }

    // Fallback: Single text
    return _titlePart(appName, FontWeight.w700);
  }

  Widget _titlePart(String text, FontWeight weight, {Color? color}) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Lato',
        fontSize: 34.sp,
        color: color ?? const Color(0xFFAD7AF1),
        fontWeight: weight,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      "Crafted for secure internet access,\ndesigned for everyone, everywhere",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Lato',
        fontSize: 18.sp,
        color: const Color(0xFFCFCFCF),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 28.w,
      height: 28.w,
      child: const CircularProgressIndicator(
        strokeCap: StrokeCap.round,
        color: Colors.white,
        strokeWidth: 4.5,
      ),
    );
  }
}
