import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class PowerButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final String label;

  const PowerButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
    required this.label,
  });

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Outer Gold Ring (Rotating slowly)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * pi,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                           color: const Color(0xFFFFD700).withOpacity(0.3), // Faint Gold
                           width: 1,
                        ),
                        gradient: SweepGradient(
                           colors: [
                              Colors.transparent, 
                              const Color(0xFFFFD700).withOpacity(0.5),
                              Colors.transparent
                           ],
                           stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // 2. Inner Gold Ring (Rotating Fast if loading)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                   double angle = widget.isLoading 
                     ? -_controller.value * 4 * pi 
                     : -_controller.value * pi; // Counter rotate
                     
                   return Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           border: Border.all(
                              color: const Color(0xFFFFD700), // Solid Gold
                              width: 2,
                           ),
                           boxShadow: [
                              BoxShadow(
                                 color: const Color(0xFFFFD700).withOpacity(0.3),
                                 blurRadius: 10,
                                 spreadRadius: 1,
                              )
                           ]
                        ),
                        child: CustomPaint(
                           painter: _DashedRingPainter(),
                        ),
                      ),
                   );
                },
              ),

              // 3. Obsidian Core (Glass)
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: Colors.black, // Obsidian
                   boxShadow: [
                      BoxShadow(
                         color: Colors.white.withOpacity(0.1),
                         offset: const Offset(-2, -2),
                         blurRadius: 4,
                      ),
                      BoxShadow(
                         color: Colors.black.withOpacity(0.8),
                         offset: const Offset(4, 4),
                         blurRadius: 8,
                      )
                   ]
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.power_settings_new_rounded,
                      color: Color(0xFFFFD700), // Gold Icon
                      size: 48,
                    ),
                    if (widget.label.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.label.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              
              // 4. Gloss Reflection (Top)
              Positioned(
                 top: 40,
                 child: Container(
                    width: 80,
                    height: 40,
                    decoration: BoxDecoration(
                       borderRadius: BorderRadius.all(Radius.elliptical(80, 40)),
                       gradient: LinearGradient(
                          colors: [
                             Colors.white.withOpacity(0.15),
                             Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                       ),
                    ),
                 ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Draw 4 segments
    for (int i = 0; i < 4; i++) {
       double start = (pi / 2) * i + 0.2;
       double sweep = (pi / 2) - 0.4;
       canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
