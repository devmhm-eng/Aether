import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/introduction_dialog.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/social_icon_button.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/switch_account_dialog.dart';
import 'package:defyx_vpn/modules/auth/application/subscription_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:defyx_vpn/modules/auth/application/branding_provider.dart';
import 'package:defyx_vpn/modules/auth/data/repository/auth_repository.dart';
import 'package:defyx_vpn/shared/providers/locale_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';

class QuickMenuDialog extends ConsumerStatefulWidget {
  const QuickMenuDialog({super.key});

  @override
  ConsumerState<QuickMenuDialog> createState() => _QuickMenuDialogState();
}

class _QuickMenuDialogState extends ConsumerState<QuickMenuDialog> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final hasOtherSubs = subscriptionState.otherSubscriptions.isNotEmpty;
    final currentLocale = ref.watch(localeProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: 20.h),
        child: Stack(
          children: [
            // Backdrop tap to close
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              bottom: 80.h,
              right: 24.w,
              child: GlassContainer(
                blur: 25,
                opacity: 0.1,
                borderRadius: BorderRadius.circular(32.r),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
                child: Container(
                  width: 300.w, // Wider for grid
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212).withOpacity(0.95), // Very dark BG
                    borderRadius: BorderRadius.circular(32.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      )
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // --- App Info Header ---
                         Row(
                           children: [
                             Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: AppIcons.logo(width: 24.w, height: 24.w), 
                             ),
                             SizedBox(width: 12.w),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     branding?.appName ?? 'MetaCore',
                                     style: TextStyle(
                                       color: Colors.white,
                                       fontSize: 16.sp,
                                       fontWeight: FontWeight.bold,
                                       fontFamily: 'Lato'
                                     ),
                                   ),
                                   Text(
                                     'Version $_version',
                                     style: TextStyle(
                                       color: Colors.white38,
                                       fontSize: 11.sp,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             // Close Button
                             GestureDetector(
                               onTap: () => Navigator.of(context).pop(),
                               child: Icon(Icons.close_rounded, color: Colors.white54, size: 20.sp),
                             ),
                           ],
                         ),
                         
                         SizedBox(height: 24.h),
                         Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                         SizedBox(height: 20.h),
                      
                         // --- Social Grid (Control Center Style) ---
                         if (branding != null)
                            Builder(
                              builder: (context) {
                                final cards = <Widget>[];
                                final addedUrls = <String>{};

                                // Helper to generate card data
                                void addCard(String? rawUrl, String defaultTitle) {
                                  if (!_isValid(rawUrl)) return;
                                  
                                  // Format URL
                                  String url = rawUrl!;
                                  if (defaultTitle == 'Instagram') url = _formatUrl(url, 'https://instagram.com/');
                                  else url = _formatUrl(url, 'https://t.me/');
                                  
                                  // Avoid duplicates
                                  if (addedUrls.contains(url)) return;
                                  addedUrls.add(url);

                                  final isTelegram = url.contains('t.me') || url.contains('telegram');
                                  
                                  // Determine Title
                                  String title = defaultTitle; 
                                  
                                  if (isTelegram) {
                                     // Refine title if it was generic "Instagram"
                                     if (defaultTitle == 'Instagram') title = 'Group'; 
                                     else title = defaultTitle;
                                  }

                                  cards.add(_buildSocialCard(
                                     title: title,
                                     iconPath: isTelegram ? AppIcons.telegramPath : AppIcons.instagramPath,
                                     isInstagram: !isTelegram,
                                     color: isTelegram ? const Color(0xFF2FA6D9) : null,
                                     onTap: () => _launch(url),
                                  ));
                                }

                                // 1. Telegram Group
                                addCard(branding.telegramGroup, 'Group');
                                
                                // 2. Telegram Channel (Support Channel)
                                addCard(branding.supportChannel, 'Channel');

                                // 3. Instagram
                                addCard(branding.instagram, 'Instagram');
                                
                                if (cards.isEmpty) return const SizedBox.shrink();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("COMMUNITY", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                    SizedBox(height: 12.h),
                                    Wrap(
                                      spacing: 12.w,
                                      runSpacing: 12.w,
                                      children: cards,
                                    ),
                                    SizedBox(height: 24.h),
                                  ],
                                );
                              }
                            ),

                       // --- Settings List ---
                       _buildMenuItem(
                          icon: Icons.language,
                          title: 'Language',
                          trailing: Text(currentLocale.languageCode.toUpperCase(), style: TextStyle(color: Colors.white54, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                          onTap: () => _showLanguageSheet(context),
                       ),
                       SizedBox(height: 8.h),
                       
                       if (hasOtherSubs)
                         _buildMenuItem(
                            icon: Icons.swap_horiz_rounded,
                            title: 'Switch Account',
                            onTap: () {
                              Navigator.of(context).pop();
                              showDialog(context: context, builder: (_) => const SwitchAccountDialog());
                            },
                         ),
                       if (hasOtherSubs) SizedBox(height: 8.h),

                       _buildMenuItem(
                          icon: Icons.support_agent_rounded,
                          title: 'Support',
                          onTap: () => _launch(_getSupportUrl(branding)),
                       ),
                       SizedBox(height: 8.h),

                       _buildMenuItem(
                          icon: Icons.info_outline_rounded,
                          title: 'About',
                          onTap: () => showCupertinoDialog(context: context, barrierDismissible: true, builder: (_) => const IntroductionDialog()),
                       ),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // --- Components ---
  
  Widget _buildSocialCard({
    required String title,
    required String iconPath,
    Color? color,
    bool isInstagram = false,
    required VoidCallback onTap,
  }) {
    // 3 cards per row approx, or 2 depending on width.
    // Let's make them flexible width but min width.
    // Actually Wrap with fixed width items is safest.
    final width = (300.w - 48.w - 12.w) / 2 - 2; // (Total - Padding - Spacing) / 2

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: width,
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                Container(
                   width: 36.w,
                   height: 36.w,
                   padding: EdgeInsets.all(8.w),
                   decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isInstagram ? null : color,
                      gradient: isInstagram ? const LinearGradient(
                         colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
                         begin: Alignment.bottomLeft,
                         end: Alignment.topRight,
                      ) : null,
                   ),
                   child: SvgPicture.asset(
                     iconPath,
                     colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                   ),
                ),
                SizedBox(height: 10.h),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                )
             ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
           padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
           decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12.r),
           ),
           child: Row(
             children: [
               Icon(icon, color: Colors.white70, size: 20.sp),
               SizedBox(width: 12.w),
               Expanded(
                 child: Text(
                   title,
                   style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w500),
                 ),
               ),
               if (trailing != null) ...[trailing!, SizedBox(width: 8.w)],
               Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12.sp),
             ],
           ),
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
         debugPrint("Could not launch $url");
         if (url.startsWith("http")) {
            if (mounted) {
               Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomWebViewScreen(url: url, title: 'MetaCore Link')));
            }
         }
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  void _showLanguageSheet(BuildContext context) {
      // Simple bottom sheet for language
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
               color: const Color(0xFF1E1E1E),
               borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                  Text("Select Language", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                        _buildLangItem('English', '🇬🇧', const Locale('en')),
                        _buildLangItem('فارسی', '🇮🇷', const Locale('fa')),
                        _buildLangItem('Русский', '🇷🇺', const Locale('ru')),
                        _buildLangItem('中文', '🇨🇳', const Locale('zh')),
                    ],
                  ),
                  SizedBox(height: 24.h),
               ],
            ),
        ),
      );
  }
  
  Widget _buildLangItem(String name, String flag, Locale locale) {
     return GestureDetector(
        onTap: () {
           ref.read(localeProvider.notifier).setLocale(locale);
           Navigator.pop(context);
        },
        child: Column(
           children: [
              Text(flag, style: TextStyle(fontSize: 32.sp)),
              SizedBox(height: 8.h),
              Text(name, style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
           ],
        ),
     );
  }

  bool _isValid(String? value) => value != null && value.trim().isNotEmpty;
  
  String _formatUrl(String value, String prefix) {
      if (value.startsWith('http')) return value;
      final clean = value.replaceAll('@', '');
      return '$prefix$clean';
  }

  // Support helper
  String _getSupportUrl(Branding? branding) {
      if (_isValid(branding?.supportContact)) return _formatUrl(branding!.supportContact!, 'https://t.me/');
      if (_isValid(branding?.supportChannel)) return _formatUrl(branding!.supportChannel!, 'https://t.me/');
      return 'https://metacorevpn.com';
  }

}
