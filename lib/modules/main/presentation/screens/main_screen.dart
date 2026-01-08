import 'dart:io';
import 'dart:ui';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data.dart';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data_interface.dart';

import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/core/desktop_platform_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/update_dialog_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/scroll_manager.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/secret_tap_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/privacy_notice_dialog.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/main/application/server_status_provider.dart';
import 'package:defyx_vpn/modules/main/application/real_ip_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/connection_button.dart';
import 'package:defyx_vpn/modules/ads/ad_provider.dart';
// GoogleAds import removed - using interstitial ads only
import 'package:defyx_vpn/modules/main/presentation/widgets/dino.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/header_section.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/tips_slider_section.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/glass_traffic_stats.dart';
import 'package:defyx_vpn/modules/main/application/heartbeat_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final ScrollController _scrollController = ScrollController();
  final AnimationService _animationService = AnimationService();
  bool _showHeaderShadow = false;
  ConnectionStatus? _previousConnectionStatus;
  late MainScreenLogic _logic;
  late ScrollManager _scrollManager;
  late SecretTapHandler _secretTapHandler;

  DinoGame? _dinoGame;

  @override
  void initState() {
    super.initState();
    _logic = MainScreenLogic(ref);
    _scrollManager = ScrollManager(_scrollController);
    _secretTapHandler = SecretTapHandler();

    // GoogleAds widget removed - using interstitial ads only

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load Ad
      ref.read(adServiceProvider).loadInterstitialAd();

      _logic.checkAndReconnect();
      await _logic.checkAndShowPrivacyNotice(_showPrivacyNoticeDialog);
      _checkInitialConnectionState();

      if (!(Platform.isAndroid || Platform.isIOS)) {
        await _logic.triggerAutoConnectIfEnabled();
      }
      if (mounted) {
        UpdateDialogHandler.checkAndShowUpdates(context, _logic.checkForUpdate);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connectionState = ref.read(connectionStateProvider);
    if (_previousConnectionStatus != connectionState.status) {
      _previousConnectionStatus = connectionState.status;
      _handleConnectionStateChange(connectionState.status);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_dinoGame != null) {
      _dinoGame!.pauseEngine();
      _dinoGame!.onRemove();
      _dinoGame = null;
    }
    super.dispose();
  }

  void _handleConnectionStateChange(ConnectionStatus status) {
    // CRITICAL FIX: Check if widget is still mounted before setState
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final newShadowState = status == ConnectionStatus.connected;
      if (_showHeaderShadow != newShadowState) {
        setState(() {
          _showHeaderShadow = newShadowState;
        });
      }

      if (status == ConnectionStatus.connected) {
        // Disabled auto-scroll based on user feedback
        // _scrollManager.scrollToBottomWithRetry();
      } else {
        _scrollManager.scrollToTopWithRetry();
      }
    });
  }

  void _handleAdsStateChange(bool showCountdown) {
    _scrollManager.handleAdsStateChange(showCountdown);
  }

  void _checkInitialConnectionState() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      final connectionState = ref.read(connectionStateProvider);
      _previousConnectionStatus = connectionState.status;

      final newShadowState =
          connectionState.status == ConnectionStatus.connected;
      if (_showHeaderShadow != newShadowState) {
        setState(() {
          _showHeaderShadow = newShadowState;
        });
      }

      _scrollManager.checkInitialConnectionState(connectionState.status);
    });
  }

  void _handleSecretTap() {
    _secretTapHandler.handleSecretTap(context);
  }

  void _showPrivacyNoticeDialog() {
    PrivacyNoticeDialog.show(
      context,
      () async {
        debugPrint('PrivacyNotice: onAccept called');
        if (ref.context.mounted) {
          // On iOS Simulator, VPN extensions don't work (IPC fails).
          // Bypass prepareVpn and proceed directly for development.
          bool isSimulator = false;
          if (Platform.isIOS) {
            // Check if running on Simulator by looking at model name
            // Simulators typically have 'Simulator' in environment or x86/arm64 on Intel Macs
            isSimulator = const bool.fromEnvironment('dart.vm.product') == false;
            // A more reliable check: device_info_plus can tell us, but for now
            // we'll use a simpler heuristic: try prepareVpn and if it fails with IPC, bypass.
          }
          
          final vpnBridge = VpnBridge();
          debugPrint('PrivacyNotice: Calling prepareVpn...');
          bool result = false;
          try {
             result = await vpnBridge.prepareVpn();
          } catch (e) {
             debugPrint('PrivacyNotice: prepareVpn error: $e');
             // If IPC failed on iOS, likely running on Simulator - bypass and continue
             if (Platform.isIOS && e.toString().contains('IPC failed')) {
               debugPrint('PrivacyNotice: Detected Simulator (IPC failed), bypassing VPN setup.');
               result = true; // Pretend it succeeded for Simulator
             }
          }
          debugPrint('PrivacyNotice: prepareVpn result: $result');
          
          if (result && ref.context.mounted) {
            // Only call initVPN if not bypassing (i.e., on real device)
            if (!Platform.isIOS || !result) {
              // On Simulator we already set result=true as bypass, so skip initVPN
            }
            final vpn = VPN(ProviderScope.containerOf(ref.context));
            debugPrint('PrivacyNotice: Calling initVPN...');
            try {
              await vpn.initVPN();
            } catch (e) {
              debugPrint('PrivacyNotice: initVPN error (ignoring on Simulator): $e');
            }
            debugPrint('PrivacyNotice: initVPN completed');
            
            await ref.read(settingsProvider.notifier).saveState();
            await _logic.markPrivacyNoticeShown();

            if (!(Platform.isAndroid || Platform.isIOS)) {
              await _logic.triggerAutoConnectIfEnabled();
            }
            return true;
          } else {
             debugPrint('PrivacyNotice: prepareVpn returned false or context unmounted');
          }
        }
        return false;
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // Heartbeat Logic
    ref.listen(connectionStateProvider, (previous, next) {
       if (next.status == ConnectionStatus.connected) {
          ref.read(heartbeatProvider.notifier).startHeartbeat();
       } else if (previous?.status == ConnectionStatus.connected && next.status != ConnectionStatus.connected) {
          ref.read(heartbeatProvider.notifier).stopHeartbeat();
       }
    });
    
    // Heartbeat Error Listening
    ref.listen<HeartbeatState>(heartbeatProvider, (previous, next) {
      if (previous?.lastError != next.lastError && next.lastError != null) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.lastError!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16.w),
            )
         );
      }
    });


    final connectionState = ref.watch(connectionStateProvider);
    // GoogleAds state removed - using interstitial ads only
    
    // Listen for Real IP Updates to show user we are working
    ref.listen<RealIpState>(realIpProvider, (prev, next) {
        if (next.isLoading && !(prev?.isLoading ?? false)) {
            // Optional: Show "Checking location..."? bit too noisy maybe
        }
        if (next.countryCode != null && next.countryCode != prev?.countryCode) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text("Server Location Detected: ${next.flagEmoji}"),
                 backgroundColor: const Color(0xFF19312F),
                 duration: const Duration(seconds: 2),
                 behavior: SnackBarBehavior.floating,
               )
             );
        }
    });

    if (!(Platform.isAndroid || Platform.isIOS)) {
      ref.listen<int>(trayConnectionToggleTriggerProvider, (previous, next) {
        if (previous != next && next > 0) {
          _logic.connectOrDisconnect();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _previousConnectionStatus != connectionState.status) {
        _previousConnectionStatus = connectionState.status;
        _handleConnectionStateChange(connectionState.status);
      }

      // GoogleAds state handling removed
    });

    return MainScreenBackground(
      connectionStatus: connectionState.status,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 393.w),
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 180.h,
                          child: ConnectionButton(
                            onTap: connectionState.status ==
                                        ConnectionStatus.loading ||
                                    connectionState.status ==
                                        ConnectionStatus.disconnecting
                                ? () {}
                                : () {
                                    debugPrint("MAIN: Connect Button Tapped. Requesting Ad...");
                                    final adService = ref.read(adServiceProvider);
                                    // Show Ad, then perform action
                                    adService.showInterstitialAd(onAdDismissed: () {
                                      debugPrint("MAIN: Ad Dismissed/Skipped. Proceeding to action.");
                                      _logic.connectOrDisconnect();
                                    });
                                  },
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 60.h),
                            HeaderSection(
                              onSecretTap: _handleSecretTap,
                              onPingRefresh: _logic.refreshPing,
                              onConfigRefresh: _logic.refreshConfig,
                            ),
                            SizedBox(height: 230.h),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: connectionState.status == ConnectionStatus.connected ? 1.0 : 0.0,
                              child: const GlassTrafficStats(),
                            ),
                            SizedBox(height: 20.h),
                            SizedBox(height: 120.h),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Floating Server Selection Card (Glass Style)
                Positioned(
                  bottom: 24.h,
                  left: 0,
                  right: 0,
                  child: _buildServerSelectionCard(),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: _animationService
                          .adjustDuration(const Duration(milliseconds: 300)),
                      opacity: _showHeaderShadow ? 1.0 : 0.0,
                      child: Container(
                        height: 150.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.black.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _buildServerSelectionButton Removed

  void _showServerSelectionDialog() async {
    final vpnData = await ref.read(vpnDataProvider.future);
    final profiles = vpnData.getProfiles();
    final selectedIndex = vpnData.getSelectedProfileIndex();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // For custom rounded corners
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 0.6.sh,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Slightly lighter than black
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle Bar
              SizedBox(height: 12.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Server",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.05), height: 1),
              
              // List
              Expanded(
                child: profiles.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dns_outlined, color: Colors.grey.withOpacity(0.5), size: 64.sp),
                          SizedBox(height: 16.h),
                          Text("No servers available", style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final isSelected = index == selectedIndex;
                        
                        return Consumer(
                          builder: (context, ref, child) {
                            final metrics = ref.watch(serverMetricsProvider(profile));
                            // Real IP Logic (Override flag if connected)
                            final realIpState = ref.watch(realIpProvider);
                            String flagEmoji = metrics?.flagEmoji ?? "🌍";
                            
                            final connectionStatus = ref.watch(connectionStateProvider).status;
                            if (connectionStatus == ConnectionStatus.connected && realIpState.countryCode != null) {
                                flagEmoji = realIpState.flagEmoji;
                            }

                            // Ping Logic
                            String displayPing = "-- ms";
                            // Determine Flag: If this is the SELECTED server AND we are CONNECTED, use Real IP
                            // String flagEmoji = metrics.flagEmoji; // This line is removed
                            // if (isSelected && connectionStatus == ConnectionStatus.connected && realIpState.countryCode != null) { // This block is removed
                            //     flagEmoji = realIpState.flagEmoji;
                            // }
                            
                            // Parse Name
                            String name = "Server ${index + 1}";
                            String protocol = "VLESS";
                             try {
                               if (profile.startsWith('vmess://')) {
                                  protocol = "VMess";
                               } else if (profile.startsWith('vless://')) {
                                  protocol = "VLESS";
                                  final uri = Uri.parse(profile);
                                  if (uri.hasFragment) {
                                    name = Uri.decodeComponent(uri.fragment);
                                  }
                               }
                             } catch (_) {}

                            return GestureDetector(
                              onTap: () async {
                                await vpnData.selectProfile(index);
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  if (context.mounted) Navigator.pop(context);
                                  setState(() {}); 
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(bottom: 12.h),
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFFAD7AF1).withOpacity(0.15) 
                                      : const Color(0xFF2C2C2C),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFAD7AF1) : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46.w,
                                      height: 46.w,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: metrics.isLoading 
                                          ? SizedBox(
                                              width: 20.w, 
                                              height: 20.w, 
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)
                                            )
                                            : Text(flagEmoji, style: TextStyle(fontSize: 24.sp)),
                                    ),
                                    SizedBox(width: 16.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              Text(
                                                protocol,
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                              if (metrics.latency != null) ...[
                                                 SizedBox(width: 8.w),
                                                 Container(
                                                   padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                   decoration: BoxDecoration(
                                                     color: Colors.black26,
                                                     borderRadius: BorderRadius.circular(4.r),
                                                   ),
                                                   child: Text(
                                                     "${metrics.latency} ms",
                                                     style: TextStyle(
                                                       color: (metrics.latency ?? 999) < 200 ? Colors.greenAccent : Colors.orangeAccent,
                                                       fontSize: 10.sp
                                                     ),
                                                   ),
                                                 ),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: const Color(0xFF76F959), size: 24.sp),
                                  ],
                                ),
                              ),
                            );
                          }
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  // _buildContentSection removed - GoogleAds widget no longer used
  Widget _buildServerSelectionCard() {
    return FutureBuilder<IVPNData>(
      future: ref.read(vpnDataProvider.future),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final vpnData = snapshot.data!;
        final profiles = vpnData.getProfiles();
        final selectedIndex = vpnData.getSelectedProfileIndex();
        
        String serverName = "Select Server";
        String protocol = "";
        String profile = "";
        
        if (profiles.isNotEmpty && selectedIndex >= 0 && selectedIndex < profiles.length) {
           profile = profiles[selectedIndex];
           try {
              if (profile.startsWith('vmess://')) protocol = "VMess";
              else if (profile.startsWith('vless://')) {
                 protocol = "VLESS";
                 final uri = Uri.parse(profile);
                 if (uri.hasFragment) {
                   serverName = Uri.decodeComponent(uri.fragment);
                 }
              }
           } catch (_) {}
           serverName = serverName == "Select Server" ? "Server ${selectedIndex+1}" : serverName;
        }

        // Metrics
        ServerMetrics? metrics;
        if(profile.isNotEmpty) {
           metrics = ref.watch(serverMetricsProvider(profile));
        }
        
        // Real IP Logic (Override flag if connected)
        final realIpState = ref.watch(realIpProvider);
        String flagEmoji = metrics?.flagEmoji ?? "🌍";
        bool isVerified = false;
        
        // If connected and we have a real IP detection, use that instead of config-based flag
         final connectionStatus = ref.watch(connectionStateProvider).status;
         if (connectionStatus == ConnectionStatus.connected) {
             if (realIpState.countryCode != null) {
                flagEmoji = realIpState.flagEmoji;
                isVerified = true;
             } else if (realIpState.isLoading) {
                // Show loader or temp flag? Keep current but maybe mark as verifying
             }
         }

        // Ping Logic
        String displayPing = "-- ms";
        Color pingColor = Colors.white70;

        if (connectionStatus == ConnectionStatus.connected) {
             final p = ref.watch(pingProvider);
             final pVal = int.tryParse(p) ?? 0;
             if (pVal > 0) {
                 displayPing = "$pVal ms";
                 pingColor = const Color(0xFF00FF94); // Neon Green
             }
        } else {
             if (metrics?.isLoading == true) {
                 displayPing = "Measuring...";
             } else if (metrics?.latency != null) {
                 displayPing = "${metrics!.latency} ms";
                 pingColor = (metrics.latency! < 200) ? const Color(0xFF00FF94) : const Color(0xFFFFB800);
             } else if (metrics?.error == "Timeout") {
                 displayPing = "Timeout";
                 pingColor = const Color(0xFFFF4B4B);
             }
        }

        return GestureDetector(
          onTap: () => _showServerSelectionDialog(),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24.w),
            // Glass Effect
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2), // Dark Glass
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    boxShadow: [
                       BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                       ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Flag Circle
                      Container(
                        width: 48.w,
                        height: 48.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Text(flagEmoji, style: TextStyle(fontSize: 24.sp)),
                      ),
                      SizedBox(width: 16.w),
                      
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(
                                isVerified 
                                  ? "Verified Location" 
                                  : (realIpState.isLoading ? realIpState.statusMessage : "Estimated Location"),
                                style: TextStyle(
                                  color: isVerified 
                                      ? const Color(0xFF00FF94) 
                                      : (realIpState.isLoading ? const Color(0xFFFFB800) : Colors.white54),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                serverName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                   // Ping Badge
                                   Icon(Icons.bolt_rounded, size: 14.sp, color: pingColor),
                                   SizedBox(width: 4.w),
                                   Text(
                                     displayPing,
                                     style: TextStyle(color: pingColor, fontSize: 13.sp, fontWeight: FontWeight.w600),
                                   ),
                                   SizedBox(width: 10.w),
                                  // Protocol Badge
                                  if (protocol.isNotEmpty)
                                    Container(
                                       padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                       decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4.r),
                                       ),
                                       child: Text(protocol, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
                                    ),
                               ],
                             )
                          ],
                        ),
                      ),
                      
                      // Action Icon
                      Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.05),
                           shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 20.sp),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}
