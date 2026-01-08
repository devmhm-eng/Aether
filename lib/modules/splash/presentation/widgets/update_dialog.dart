import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  final bool isForceUpdate;
  final String downloadUrl;

  const UpdateDialog({
    super.key,
    required this.isForceUpdate,
    required this.downloadUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Prevent back button on Android if force update
    return WillPopScope(
      onWillPop: () async => !isForceUpdate,
      child: Dialog(
        backgroundColor: const Color(0xFF2B2B2B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.system_update,
                size: 64.w,
                color: const Color(0xFFAD7AF1),
              ),
              16.h.verticalSpace,
              Text(
                isForceUpdate ? 'Update Required' : 'Update Available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              12.h.verticalSpace,
              Text(
                isForceUpdate
                    ? 'A new version is required to continue using the app. Please update to the latest version.'
                    : 'A new version of the app is available. improves performance and adds new features.',
                style: TextStyle(
                  color: const Color(0xFFCFCFCF),
                  fontSize: 14.sp,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              24.h.verticalSpace,
              Row(
                children: [
                   if (!isForceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFAD7AF1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: const Color(0xFFAD7AF1),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    12.w.horizontalSpace,
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.parse(downloadUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFAD7AF1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
