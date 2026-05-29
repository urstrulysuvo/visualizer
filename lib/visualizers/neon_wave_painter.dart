import 'dart:math';
import 'package:flutter/material.dart';
import '../wav_decoder.dart';

class NeonWavePainter extends CustomPainter {
  final WaveFrame frame;
  final double animationTime;
  final Color primaryColor;
  final Color secondaryColor;

  NeonWavePainter({
    required this.frame,
    required this.animationTime,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    // We use a high number of points to simulate the dense dot/particle structure of the image
    final int numPoints = 250;
    final double stepX = size.width / numPoints;

    final Path baseWavePath = Path();

    // The image has a blueish outer glow and a magenta inner core
    final Paint outerGlowPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.6)
      ..strokeWidth = 24.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0)
      ..style = PaintingStyle.stroke;

    final Paint innerGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.9)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
      ..style = PaintingStyle.stroke;
      
    final Paint corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // To simulate the vertical ribbon lines from the image
    final Paint strandPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    bool first = true;

    for (int i = 0; i <= numPoints; i++) {
      final double x = i * stepX;
      // Normalize x from 0 to 1
      final double nx = i / numPoints;

      double amplitude = 0.0;
      
      // Bass creates large, slow rolling waves
      amplitude += sin(nx * pi * 3 + animationTime * 4.0) * frame.bass * 120.0;
      
      // Mid creates secondary tighter waves
      amplitude += sin(nx * pi * 7 - animationTime * 6.0) * frame.mid * 60.0;
      
      // Treble creates high frequency ripples
      amplitude += sin(nx * pi * 15 + animationTime * 10.0) * frame.treble * 25.0;

      // Pinch the ends so the wave originates and terminates at the exact middle edges
      // Use a power function to make the pinch smooth but allow the center to expand fully
      final double edgeMultiplier = sin(nx * pi);
      amplitude *= edgeMultiplier;

      final double y = midY + amplitude;

      if (first) {
        baseWavePath.moveTo(x, y);
        first = false;
      } else {
        baseWavePath.lineTo(x, y);
      }

      // Draw the vertical strands (the "ribbon" texture)
      // The thickness of the ribbon is driven by overall audio volume (frame.full)
      // and also gets wider where the wave amplitude is steeper to give 3D perspective
      final double waveSteepness = cos(nx * pi * 3 + animationTime * 4.0).abs();
      final double strandHeight = 4.0 + (frame.full * 35.0 * edgeMultiplier) + (waveSteepness * 15.0 * edgeMultiplier);
      
      canvas.drawLine(
        Offset(x, y - strandHeight),
        Offset(x, y + strandHeight),
        strandPaint,
      );
    }

    // Draw the continuous horizontal wave layers on top of the strands
    canvas.drawPath(baseWavePath, outerGlowPaint);
    canvas.drawPath(baseWavePath, innerGlowPaint);
    canvas.drawPath(baseWavePath, corePaint);
  }

  @override
  bool shouldRepaint(covariant NeonWavePainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.animationTime != animationTime;
  }
}
