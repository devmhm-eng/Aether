import 'package:defyx_vpn/shared/layout/navbar/widgets/copyable_link.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/intro_link_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/modules/auth/application/branding_provider.dart';

class IntroductionDialog extends ConsumerWidget {
  const IntroductionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);
    final appName = branding?.appName ?? 'MetaCore';

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      child: Container(
        padding: EdgeInsets.all(25.w),
        width: 343.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Introduction',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 15.h),
            Text(
              'The goal of $appName is to ensure secure access to public information and provide a free browsing experience.',
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 10.h),
            // Show website link only (no open source or beta links)
            if (branding == null) ...[
                SizedBox(height: 15.h),
                CopyableLink(text: 'themetacore.app'),
                SizedBox(height: 20.h),
            ],
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
