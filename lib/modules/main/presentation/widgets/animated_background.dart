import 'dart:math';
import 'package:flutter/material.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class AnimatedBackground extends StatefulWidget {
  final ConnectionStatus connectionStatus;

  const AnimatedBackground({super.key, required this.connectionStatus});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_GoldPoint> _points = [];
  final List<_GoldEdge> _edges = [];

  @override
  void initState() {
    super.initState();
    _initGoldGlobe();
    
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 25)) // Slow, majestic
      ..repeat();
  }
  
  void _initGoldGlobe() {
    // 1. Generate Points (Fibonacci Sphere subset)
    const int numPoints = 100; // Minimalist, fine
    final double phi = pi * (3.0 - sqrt(5.0));

    for (int i = 0; i < numPoints; i++) {
        final double y = 1 - (i / (numPoints - 1)) * 2;
        final double radius = sqrt(1 - y * y);
        final double theta = phi * i;

        final double x = cos(theta) * radius;
        final double z = sin(theta) * radius;

        _points.add(_GoldPoint(x, y, z));
    }
    
    // 2. Generate Fine Connections (Web)
    for (int i = 0; i < numPoints; i++) {
      for (int j = i + 1; j < numPoints; j++) {
         final p1 = _points[i];
         final p2 = _points[j];
         final distSq = (p1.x - p2.x)*(p1.x - p2.x) + 
                        (p1.y - p2.y)*(p1.y - p2.y) + 
                        (p1.z - p2.z)*(p1.z - p2.z);
         
         if (distSq < 0.25) {
            _edges.add(_GoldEdge(i, j));
         }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getPrimaryColor() {
    // Luxury Palette
    switch (widget.connectionStatus) {
      case ConnectionStatus.connected:
        return const Color(0xFF00FF94); // Keep Green for success (Safety)
      case ConnectionStatus.error:
        return const Color(0xFFFF3333); // Red
      default:
        // Default is GOLD
        return const Color(0xFFFFD700); // Polished Gold
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF020210), // Deep Midnight Blue
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _GoldenGlobePainter(
              points: _points,
              edges: _edges,
              rotation: _controller.value * 2 * pi,
              color: _getPrimaryColor(),
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _GoldPoint {
  final double x, y, z;
  _GoldPoint(this.x, this.y, this.z);
}
class _GoldEdge {
  final int i1, i2;
  _GoldEdge(this.i1, this.i2);
}

class _GoldenGlobePainter extends CustomPainter {
  final List<_GoldPoint> points;
  final List<_GoldEdge> edges;
  final double rotation;
  final Color color;

  _GoldenGlobePainter({
    required this.points,
    required this.edges,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final radius = size.width * 0.45;

    final cosRot = cos(rotation);
    final sinRot = sin(rotation);
    final tilt = 0.3; 
    final cosTilt = cos(tilt);
    final sinTilt = sin(tilt);

    // Cache transformed
    final List<List<double>> tPoints = List.generate(points.length, (i) => [0,0,0]);
    for(int i=0; i<points.length; i++){
       final p = points[i];
       // Rot Y
       double x1 = p.x * cosRot - p.z * sinRot;
       double z1 = p.z * cosRot + p.x * sinRot;
       double y1 = p.y;
       // Rot X (Tilt)
       double y2 = y1 * cosTilt - z1 * sinTilt;
       double z2 = z1 * cosTilt + y1 * sinTilt; // Depth
       double x2 = x1;
       
       tPoints[i][0] = center.dx + x2 * radius;
       tPoints[i][1] = center.dy + y2 * radius;
       tPoints[i][2] = z2;
    }

    // Draw Edges (Gold Threads)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8; // Fine thread

    for (var edge in edges) {
       final p1 = tPoints[edge.i1];
       final p2 = tPoints[edge.i2];
       final zAvg = (p1[2] + p2[2]) / 2;
       
       if (zAvg < -0.5) continue; // Cull back
       
       double alpha = (zAvg + 1.2) / 2.2;
       alpha = alpha.clamp(0.0, 0.4); // Very subtle lines
       
       linePaint.color = color.withOpacity(alpha);
       canvas.drawLine(Offset(p1[0], p1[1]), Offset(p2[0], p2[1]), linePaint);
    }
    
    // Draw Nodes (Gold Dust / Joints)
    final dotPaint = Paint()..style = PaintingStyle.fill;
    
    for (var p in tPoints) {
       double z = p[2];
       if (z < -0.6) continue;
       
       double alpha = (z + 1.2) / 2.2;
       double r = 1.5 + z * 1.0;
       
       dotPaint.color = color.withOpacity(alpha.clamp(0.1, 1.0));
       canvas.drawCircle(Offset(p[0], p[1]), r, dotPaint);
       
       // Shine
       if (z > 0.8) {
          dotPaint.color = Colors.white.withOpacity(0.5);
          canvas.drawCircle(Offset(p[0], p[1]), r * 0.5, dotPaint);
       }
    }
    
    // Vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, const Color(0xFF020210)],
        stops: const [0.4, 1.0],
        radius: 1.0,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(covariant _GoldenGlobePainter oldDelegate) => true;
}
