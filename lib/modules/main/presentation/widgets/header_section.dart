import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/connection_state_widgets.dart';
import 'package:defyx_vpn/modules/auth/application/subscription_provider.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/auth/application/branding_provider.dart';

 class HeaderSection extends ConsumerWidget {
  final VoidCallback onSecretTap;
  final VoidCallback? onPingRefresh;
  final VoidCallback? onConfigRefresh;

  const HeaderSection({
    super.key,
    required this.onSecretTap,
    this.onPingRefresh,
    this.onConfigRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final userId = subscriptionState.current.id;
    final l10n = AppLocalizations.of(context)!;

    final branding = ref.watch(brandingProvider);
    // Use dynamic branding on all platforms
    debugPrint('HEADER: branding appName=${branding?.appName}, l10n.appTitle=${l10n.appTitle}');
    final title = branding?.appName ?? l10n.appTitle;
    final subtitle = branding?.appName != null ? '' : l10n.appSubtitle;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onSecretTap,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 35.sp,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFAD7AF1),
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              l10n.appSlogan,
              style: TextStyle(
                fontSize: 32.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 0,
              ),
            ),
          ],
        ),
        // User ID Display & Refresh Button
        if (userId > 0)
        Positioned.directional(
           textDirection: Directionality.of(context),
           top: 0,
           end: 0,
           child: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               // Refresh Config Button
               if (onConfigRefresh != null)
               GestureDetector(
                 onTap: onConfigRefresh,
                 child: Container(
                   padding: EdgeInsets.all(8.w),
                   decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.08),
                     borderRadius: BorderRadius.circular(12.r),
                     border: Border.all(color: Colors.white12),
                   ),
                   child: Icon(
                     Icons.refresh_rounded,
                     color: const Color(0xFFAD7AF1),
                     size: 16.sp,
                   ),
                 ),
               ),
               if (onConfigRefresh != null) SizedBox(width: 8.w),
               // User ID
               Container(
                 padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.08),
                   borderRadius: BorderRadius.circular(12.r),
                   border: Border.all(color: Colors.white12),
                 ),
                 child: Row(
                   children: [
                      Icon(Icons.person_outline_rounded, color: Colors.white54, size: 12.sp),
                      SizedBox(width: 4.w),
                      Text(
                        l10n.userId(userId),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                   ],
                 ),
               ),
             ],
           ),
        ),
      ],
    );
  }
}

class ConnectionStatusText extends ConsumerWidget {
  const ConnectionStatusText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    final l10n = AppLocalizations.of(context)!;
    final text = _getStatusText(connectionState.status, l10n);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(text),
        duration: const Duration(milliseconds: 300),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.9 + (0.1 * value),
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 32.sp,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getStatusText(ConnectionStatus status, AppLocalizations l10n) {
    switch (status) {
      case ConnectionStatus.loading:
      case ConnectionStatus.connected:
      case ConnectionStatus.analyzing:
        return l10n.statusTitleNormal;
      case ConnectionStatus.error:
        return l10n.statusTitleFailed;
      case ConnectionStatus.noInternet:
        return l10n.statusTitleNoInternet;
      case ConnectionStatus.disconnecting:
        return l10n.statusTitleDisconnecting;
      default:
        return l10n.statusTitleDefault;
    }
  }
}

class ConnectionStateWidget extends ConsumerWidget {
  final VoidCallback? onPingRefresh;

  const ConnectionStateWidget({super.key, this.onPingRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    final l10n = AppLocalizations.of(context)!;
    final stateInfo = _getConnectionStateInfo(connectionState.status, l10n);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<String>(connectionState.status.name),
        alignment: Alignment.centerLeft,
        child: StateSpecificWidget(
          status: connectionState.status,
          text: stateInfo.text,
          color: stateInfo.color,
          fontSize: 32.sp,
          onPingRefresh: onPingRefresh,
        ),
      ),
    );
  }

  ({String text, Color color}) _getConnectionStateInfo(
    ConnectionStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case ConnectionStatus.disconnecting:
        return (text: l10n.statusDescDisconnecting, color: Colors.white);
      case ConnectionStatus.loading:
        return (text: l10n.statusDescLoading, color: Colors.white);
      case ConnectionStatus.connected:
        return (text: l10n.statusDescConnected, color: const Color(0xFFB2FFB9));
      case ConnectionStatus.analyzing:
        return (text: l10n.statusDescAnalyzing, color: Colors.white);
      case ConnectionStatus.noInternet:
        return (text: l10n.statusDescNoInternet, color: const Color(0xFFFFC0C0));
      case ConnectionStatus.error:
        return (text: l10n.statusDescError, color: Colors.white);
      default:
        return (text: l10n.statusDescDefault, color: Colors.white);
    }
  }
}

class StateSpecificWidget extends StatelessWidget {
  final ConnectionStatus status;
  final String text;
  final Color color;
  final double fontSize;
  final VoidCallback? onPingRefresh;

  const StateSpecificWidget({
    super.key,
    required this.status,
    required this.text,
    required this.color,
    required this.fontSize,
    this.onPingRefresh,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ConnectionStatus.noInternet:
        return NoInternetWidget(
          text: text,
          textColor: color,
          fontSize: fontSize,
        );
      case ConnectionStatus.connected:
        return ConnectedWidget(
          text: text,
          textColor: color,
          fontSize: fontSize,
          onPingRefresh: onPingRefresh,
        );
      default:
        return DefaultStateWidget(
          text: text,
          textColor: color,
          fontSize: fontSize,
          status: status,
        );
    }
  }
}

class AnalyzingStatus extends ConsumerWidget {
  const AnalyzingStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider).status;
    final isAnalyzing = status == ConnectionStatus.analyzing;

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: Alignment.centerLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isAnalyzing ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: isAnalyzing ? 1.0 : 0.9,
          alignment: Alignment.centerLeft,
          child: isAnalyzing
              ? AnalyzingContent()
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
