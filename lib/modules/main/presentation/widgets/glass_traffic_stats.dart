import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/modules/main/application/traffic_stats_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class GlassTrafficStats extends ConsumerWidget {
  const GlassTrafficStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider).status;
    final stats = ref.watch(trafficStatsProvider);

    // Only show when connected
    if (status != ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          width: 350.w,
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stats Values
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    label: "DOWNLOAD",
                    value: stats.formattedDownload,
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFF00FF94), // Neon Green
                  ),
                  Container(
                    width: 1,
                    height: 40.h,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  _buildStatItem(
                    label: "UPLOAD",
                    value: stats.formattedUpload,
                    icon: Icons.arrow_upward_rounded,
                    color: const Color(0xFF00C2FF), // Neon Blue
                  ),
                ],
              ),
              
              SizedBox(height: 24.h),
              
              // Speed Graph
              SizedBox(
                height: 50.h,
                width: double.infinity,
                child: CustomPaint(
                   painter: _TrafficGraphPainter(
                     uploadHistory: stats.uploadHistory,
                     downloadHistory: stats.downloadHistory,
                     upColor: const Color(0xFF00C2FF),
                     downColor: const Color(0xFF00FF94),
                   ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
           mainAxisSize: MainAxisSize.min,
           children: [
              Icon(icon, color: color, size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
           ],
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lato',
            letterSpacing: 0.5,
            shadows: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 15,
              )
            ]
          ),
        ),
      ],
    );
  }
}

class _TrafficGraphPainter extends CustomPainter {
  final List<int> uploadHistory;
  final List<int> downloadHistory;
  final Color upColor;
  final Color downColor;
  
  _TrafficGraphPainter({
    required this.uploadHistory,
    required this.downloadHistory,
    required this.upColor,
    required this.downColor
  });

  @override
  void paint(Canvas canvas, Size size) {
     if (downloadHistory.isEmpty && uploadHistory.isEmpty) return;
     
     final w = size.width;
     final h = size.height;
     // Assuming history max 40
     final stepX = w / 40.0;
     
     // Normalize based on max value in recent history
     int maxVal = 1024 * 1024; // Min 1MB for scale stability
     for (var v in downloadHistory) maxVal = math.max(maxVal, v);
     for (var v in uploadHistory) maxVal = math.max(maxVal, v);
     // Add head room
     maxVal = (maxVal * 1.2).toInt();
     
     // Helper to draw
     void drawSeries(List<int> history, Color color, bool filled) {
         if (history.isEmpty) return;
         final path = Path();
         bool first = true;
         
         for (int i = 0; i < history.length; i++) {
             final x = i * stepX;
             final val = history[i];
             // Invert Y
             final y = h - ((val / maxVal) * h);
             if (first) {
                 path.moveTo(x, y);
                 first = false;
             } else {
                 if (filled) {
                    // For filled area, use quadratic bezier for smoother curve
                    final prevX = (i - 1) * stepX;
                    final prevY = h - ((history[i-1] / maxVal) * h);
                    final cX = (prevX + x) / 2;
                    path.quadraticBezierTo(cX, prevY, x, y);
                 } else {
                    path.lineTo(x, y);
                 }
             }
         }
         
         if (filled) {
             final lastX = (history.length - 1) * stepX;
             path.lineTo(lastX, h);
             path.lineTo(0, h);
             path.close();
             
             final paint = Paint()
               ..shader = LinearGradient(
                  colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
               ).createShader(Rect.fromLTWH(0, 0, w, h));
             canvas.drawPath(path, paint);
             
             // Draw Top Stroke
             final strokePath = Path();
             first = true;
             for (int i = 0; i < history.length; i++) {
                 final x = i * stepX;
                 final val = history[i];
                 final y = h - ((val / maxVal) * h);
                 if (first) {
                     strokePath.moveTo(x, y);
                     first = false;
                 } else {
                     final prevX = (i - 1) * stepX;
                     final prevY = h - ((history[i-1] / maxVal) * h);
                     final cX = (prevX + x) / 2;
                     strokePath.quadraticBezierTo(cX, prevY, x, y);
                 }
             }
             final strokePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
             canvas.drawPath(strokePath, strokePaint);
         } else {
            final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
            canvas.drawPath(path, paint);
         }
     }
     
     // Draw Download (Filled, Primary)
     drawSeries(downloadHistory, downColor, true);
     
     // Draw Upload (Line, Secondary)
     drawSeries(uploadHistory, upColor, false);
  }

  @override
  bool shouldRepaint(_TrafficGraphPainter old) {
      return old.uploadHistory != uploadHistory || old.downloadHistory != downloadHistory;
  }
}
