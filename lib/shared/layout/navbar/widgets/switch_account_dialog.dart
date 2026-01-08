import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/modules/auth/application/subscription_provider.dart';
import 'package:defyx_vpn/shared/services/account_switch_service.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:defyx_vpn/modules/auth/application/branding_provider.dart';
import 'package:defyx_vpn/modules/auth/data/repository/auth_repository.dart';

class SwitchAccountDialog extends ConsumerStatefulWidget {
  const SwitchAccountDialog({super.key});

  @override
  ConsumerState<SwitchAccountDialog> createState() => _SwitchAccountDialogState();
}

class _SwitchAccountDialogState extends ConsumerState<SwitchAccountDialog> {
  bool _isSwitching = false;
  String? _error;

  Future<void> _switchToSubscription(SubscriptionItem sub) async {
    if (sub.token == null || sub.token!.isEmpty) {
      setState(() => _error = 'Invalid Profile: Token missing.');
      return;
    }

    setState(() {
      _isSwitching = true;
      _error = null;
    });

    try {
      final switchService = ref.read(accountSwitchServiceProvider);
      final success = await switchService.switchAccount(sub.token!);

      if (success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${sub.name}'),
            backgroundColor: const Color(0xFFAD7AF1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSwitching = false;
          _error = 'Switch failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final currentSub = subscriptionState.current;
    final otherSubs = subscriptionState.otherSubscriptions;
    final branding = ref.watch(brandingProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        blur: 20,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        child: Container(
          constraints: BoxConstraints(maxWidth: 340.w, maxHeight: 500.h),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Switch Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white54, size: 22.sp),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Account List
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Current Active
                      _buildSubscriptionItem(
                        context,
                        currentSub,
                        isActive: true,
                        appName: branding?.appName ?? 'MetaCore',
                      ),
                      
                      if (otherSubs.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
                        SizedBox(height: 16.h),
                        
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'OTHER PROFILES',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        
                        // List Others
                        ...otherSubs.map((sub) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _buildSubscriptionItem(
                                context,
                                sub,
                                isActive: false,
                                appName: branding?.appName ?? 'MetaCore',
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),

              // Error Display
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(12.w),
                  margin: EdgeInsets.only(top: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading Overlay
              if (_isSwitching)
                Padding(
                  padding: EdgeInsets.only(top: 16.h),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    color: const Color(0xFFAD7AF1),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionItem(BuildContext context, SubscriptionItem sub, {required bool isActive, required String appName}) {
    // Determine status color
    final statusColor = isActive ? const Color(0xFF69F0AE) : const Color(0xFFAD7AF1);
    final borderColor = isActive ? const Color(0xFF69F0AE).withOpacity(0.3) : Colors.white.withOpacity(0.05);
    final bgColor = isActive ? const Color(0xFF69F0AE).withOpacity(0.05) : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive || _isSwitching ? null : () => _switchToSubscription(sub),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: isActive ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.power_settings_new_rounded : Icons.vpn_key_rounded,
                  color: isActive ? Colors.greenAccent : Colors.white54,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 16.w),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        children: [
                            Flexible(
                              child: Text(
                                sub.name.isEmpty ? 'Subscription #${sub.id}' : sub.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isActive) ...[
                                SizedBox(width: 6.w),
                                Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4.r)
                                    ),
                                    child: Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                            fontSize: 10.sp, 
                                            fontWeight: FontWeight.bold, 
                                            color: Colors.greenAccent
                                        )
                                    )
                                )
                            ]
                        ]
                    ),
                    SizedBox(height: 4.h),
                    Row(
                        children: [
                             Text(
                              appName, // VPN Name
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (sub.expiryDate.isNotEmpty) ...[
                                Text('  •  ', style: TextStyle(color: Colors.white12, fontSize: 11.sp)),
                                Icon(Icons.calendar_today_rounded, size: 10.sp, color: Colors.white38),
                                SizedBox(width: 4.w),
                                Text(
                                  sub.expiryDate,
                                  style: TextStyle(
                                    color: Colors.white38, // Faded for expiry
                                    fontSize: 11.sp,
                                  ),
                                ),
                            ]
                        ]
                    )
                  ],
                ),
              ),
              
              if (!isActive)
                Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }
}
