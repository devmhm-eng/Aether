import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/modules/auth/data/repository/auth_repository.dart';
import 'package:defyx_vpn/shared/services/device_service.dart';
import 'package:defyx_vpn/modules/auth/application/subscription_provider.dart';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/animated_background.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/widgets/power_button.dart';
import 'package:defyx_vpn/modules/auth/application/branding_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceService = DeviceService();
      final deviceId = await deviceService.getDeviceId();
      if (deviceId == null) {
        throw Exception("Failed to get device ID");
      }
      final platform = deviceService.getPlatformName();
      final deviceName = await deviceService.getDeviceModel();

      // 1. Get All Configs (List)
      final result = await ref.read(authRepositoryProvider).loginAndFetchConfigs(
            _keyController.text,
            deviceId,
            platform: platform,
            deviceName: deviceName,
          );

      if (result.configs.isEmpty) {
        throw Exception("No configurations found.");
      }
      
      // Extract configs for saving
      final configs = result.configs;
      
      // NEW: Save Subscription Info
       ref.read(subscriptionProvider.notifier).setSubscriptionData(
          result.currentSubscription,
          result.otherSubscriptions,
       );
       ref.read(brandingProvider.notifier).state = result.branding;

      // 2. Save Profiles & Select Default
      final vpnData = await ref.read(vpnDataProvider.future);
      await vpnData.saveProfiles(configs);
      await vpnData.selectProfile(0); // Default to first

      if (mounted) {
        context.go(DefyxVPNRoutes.main.route);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Cyber Aurora Background
          const Positioned.fill(
            child: AnimatedBackground(connectionStatus: ConnectionStatus.disconnected),
          ),
          
          // Login Card
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: EdgeInsets.all(32.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(32.r),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        )
                      ],
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.01),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon or Brand
                        Icon(
                           Icons.vpn_key_rounded,
                           size: 48.sp,
                           color: const Color(0xFFFFD700), // Gold Icon
                        ),
                        SizedBox(height: 16.h),
                        
                        Text(
                          l10n.appTitle,
                          style: TextStyle(
                            color: const Color(0xFFFFD700), // Gold
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Lato',
                            letterSpacing: 1.0,
                            shadows: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.4),
                                blurRadius: 20,
                              )
                            ]
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          l10n.loginEnterKey,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14.sp,
                            fontFamily: 'Lato',
                          ),
                        ),
                        SizedBox(height: 48.h),
                        
                        // Input Field
                        TextField(
                          controller: _keyController,
                          style: TextStyle(
                             color: Colors.white,
                             fontSize: 16.sp,
                             letterSpacing: 1.2
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.loginFindKey, // Using "Where to find key?" concept as hint or similar
                            hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'Lato'),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5), // Gold Focus
                            ),
                            errorText: _errorMessage,
                            errorStyle: const TextStyle(color: Color(0xFFFF4B4B)),
                            prefixIcon: const Icon(Icons.password, color: Colors.white38),
                          ),
                          obscureText: true,
                          onSubmitted: (_) => _handleLogin(),
                          enabled: !_isLoading,
                        ),
                        SizedBox(height: 32.h),
                        
                        // Login Button
                        // Power Orb Button
                        SizedBox(height: 24.h),
                        PowerButton(
                          label: l10n.loginConnect,
                          isLoading: _isLoading,
                          onTap: _handleLogin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
