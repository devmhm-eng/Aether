import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class ConnectionButton extends ConsumerStatefulWidget {
  final VoidCallback onTap;

  const ConnectionButton({super.key, required this.onTap});

  @override
  ConsumerState<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends ConsumerState<ConnectionButton> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 2000)
    )..repeat();
    
    _pulseController = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 2)
    )..repeat(reverse: true);
    
    _ringController = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 10)
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Color _getButtonColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected: return const Color(0xFF00FF94); // Green
      case ConnectionStatus.error: return const Color(0xFFFF4B4B); // Red
      case ConnectionStatus.loading:
      case ConnectionStatus.analyzing: return const Color(0xFFFFB800); // Orange
      case ConnectionStatus.disconnecting: return const Color(0xFFFFB800);
      default: return const Color(0xFFAD7AF1); // Purple/Default
    }
  }

  double _getFillHeight(ConnectionStatus status) {
    // 0.0 to 1.0
    switch (status) {
       case ConnectionStatus.connected: return 1.0;
       case ConnectionStatus.loading: return 0.5;
       case ConnectionStatus.analyzing: return 0.75;
       case ConnectionStatus.disconnecting: return 0.2;
       default: return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStateProvider).status;
    final primaryColor = _getButtonColor(status);
    final fillLevel = _getFillHeight(status);
    final isConnected = status == ConnectionStatus.connected;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
           // Cyber Ring Animation (Behind button)
           AnimatedBuilder(
             animation: Listenable.merge([_ringController, _pulseController]),
             builder: (context, child) {
                double pulse = 0;
                if (isConnected) pulse = _pulseController.value * 5;
                
                return CustomPaint(
                   size: Size(180.w + pulse, 180.w + pulse),
                   painter: _CyberRingPainter(
                     rotation: _ringController.value, 
                     color: primaryColor
                   ),
                );
             },
           ),
           
           // Main Liquid Button
           AnimatedBuilder(
            animation: Listenable.merge([_waveController, _pulseController]),
            builder: (context, child) {
               double pulse = 0;
               if (isConnected) {
                  pulse = _pulseController.value * 10;
               }

               return Container(
                 width: 140.w + pulse,
                 height: 140.w + pulse,
                 decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                       BoxShadow(
                          color: primaryColor.withOpacity(0.4),
                          blurRadius: 20 + pulse,
                          spreadRadius: 2,
                       )
                    ]
                 ),
                 child: CustomPaint(
                    painter: _LiquidButtonPainter(
                       waveValue: _waveController.value,
                       fillLevel: fillLevel,
                       color: primaryColor,
                       backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Center(
                       child: Icon(
                          Icons.power_settings_new_rounded,
                          color: Colors.white,
                          size: 48.sp,
                       ),
                    ),
                 ),
               );
            },
          ),
        ],
      ),
    );
  }
}

class _CyberRingPainter extends CustomPainter {
  final double rotation;
  final Color color;
  
  _CyberRingPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
     final center = size.center(Offset.zero);
     final radius = (size.width / 2) - 2; // Inset slightly
     final paint = Paint()..color = color.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 2;
     
     canvas.save();
     canvas.translate(center.dx, center.dy);
     canvas.rotate(rotation * 2 * math.pi);
     
     // 1. Draw 4 Arc Segments
     for (int i=0; i<4; i++) {
        canvas.drawArc(
           Rect.fromCircle(center: Offset.zero, radius: radius),
           (i * 90 + 15) * math.pi / 180,
           60 * math.pi / 180,
           false,
           paint
        );
     }
     
     // 2. Draw Ticks outside
     final tickPaint = Paint()..color = color.withOpacity(0.5)..strokeWidth = 2;
     for (int i=0; i<12; i++) {
        final angle = (i * 30) * math.pi / 180;
        final p1 = Offset(math.cos(angle) * (radius + 5), math.sin(angle) * (radius + 5));
        final p2 = Offset(math.cos(angle) * (radius + 12), math.sin(angle) * (radius + 12));
        canvas.drawLine(p1, p2, tickPaint);
     }
     
     // 3. Draw Inner Decoration
     final innerPaint = Paint()..color = color.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1;
     canvas.drawCircle(Offset.zero, radius - 15, innerPaint);
     
     canvas.restore();
  }

  @override
  bool shouldRepaint(_CyberRingPainter old) {
      return old.rotation != rotation || old.color != color;
  }
}

class _LiquidButtonPainter extends CustomPainter {
  final double waveValue;
  final double fillLevel;
  final Color color;
  final Color backgroundColor;

  _LiquidButtonPainter({
    required this.waveValue,
    required this.fillLevel,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
     final center = size.center(Offset.zero);
     final radius = size.width / 2;
     
     // 1. Draw Background Ring/Circle
     final bgPaint = Paint()..color = backgroundColor;
     canvas.drawCircle(center, radius, bgPaint);
     
     // 2. Draw Border
     final borderPaint = Paint()
       ..color = color.withOpacity(0.5)
       ..style = PaintingStyle.stroke
       ..strokeWidth = 3;
     canvas.drawCircle(center, radius, borderPaint);

     // 3. Draw Liquid Fill (Clipped to Circle)
     if (fillLevel > 0) {
        final fillPaint = Paint()..color = color;
        
        final path = Path();
        
        // Clip to circle
        path.addOval(Rect.fromCircle(center: center, radius: radius - 4)); // Inset slightly
        canvas.save();
        canvas.clipPath(path);

        // Wave Logic
        final wavePath = Path();
        final width = size.width;
        final height = size.height;
        
        // Remap fillLevel (0..1) to y position (heigth..0)
        // Animating the fill level creates the "filling up" effect
        // We can't really animate the transition here easily without an explicit animation controller driving "currentFillLevel".
        // For now, it jumps to specific levels which is fine for "states".
        
        double baseHeight = height * (1 - fillLevel);
        if (fillLevel >= 1.0) baseHeight = -10; // Full fill

        wavePath.moveTo(0, height);
        wavePath.lineTo(0, baseHeight);

        // Draw sine wave
        for (double x = 0; x <= width; x++) {
           double y = baseHeight + 5 * math.sin((x / width * 2 * math.pi) + (waveValue * 2 * math.pi));
           wavePath.lineTo(x, y);
        }
        
        wavePath.lineTo(width, height);
        wavePath.close();
        
        canvas.drawPath(wavePath, fillPaint);
        canvas.restore();
     }
  }

  @override
  bool shouldRepaint(_LiquidButtonPainter old) {
     return old.waveValue != waveValue || 
            old.fillLevel != fillLevel ||
            old.color != color;
  }
}
