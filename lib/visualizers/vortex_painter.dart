import 'dart:math';
import 'package:flutter/material.dart';
import '../wav_decoder.dart';

class VortexPainter extends CustomPainter {
  final WaveFrame frame;
  final double animationTime;
  final Color primaryColor;
  final Color secondaryColor;

  VortexPainter({
    required this.frame,
    required this.animationTime,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = min(size.width, size.height);
    
    // Global bouncy scale based on bass to make the whole visualizer pulse
    final double bounceScale = 1.0 + (0.25 * frame.bass);
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(bounceScale);
    canvas.translate(-center.dx, -center.dy);

    final double innerRadius = minDim * 0.18 * (1.0 + 0.10 * frame.bass);
    final double maxBarHeight = minDim * 0.22;

    // Glowing core in the center
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.4 * (0.5 + 0.5 * frame.bass)),
          secondaryColor.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius * 1.5));
    canvas.drawCircle(center, innerRadius * 1.5, corePaint);

    // Draw central pulsing ring
    final coreRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + 3.0 * frame.bass
      ..color = primaryColor.withValues(alpha: 0.6 + 0.4 * frame.bass);
    canvas.drawCircle(center, innerRadius, coreRingPaint);

    // Draw inner rotating dashboard/scope rings
    _drawScopeRings(canvas, center, innerRadius);

    // Draw radial equalizer bars
    _drawRadialBars(canvas, center, innerRadius, maxBarHeight);
    
    canvas.restore(); // Restore from global bounce scale
  }

  void _drawScopeRings(Canvas canvas, Offset center, double innerRadius) {
    // Ring 1 (rotates clockwise)
    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = secondaryColor.withValues(alpha: 0.3 + 0.3 * frame.mid);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animationTime * 0.5);
    _drawDashedCircle(canvas, Offset.zero, innerRadius - 12, 12, 0.4, paint1);
    canvas.restore();

    // Ring 2 (rotates counter-clockwise)
    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = primaryColor.withValues(alpha: 0.2 + 0.3 * frame.treble);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-animationTime * 0.8);
    _drawDashedCircle(canvas, Offset.zero, innerRadius - 24, 6, 0.6, paint2);
    canvas.restore();
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, int segments, double fillRatio, Paint paint) {
    final double step = 2 * pi / segments;
    final double drawAngle = step * fillRatio;

    for (int i = 0; i < segments; i++) {
      double startAngle = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        drawAngle,
        false,
        paint,
      );
    }
  }

  void _drawRadialBars(Canvas canvas, Offset center, double innerRadius, double maxBarHeight) {
    const int totalBars = 80;
    final double angleStep = 2 * pi / totalBars;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Slow overall rotation of the vortex
    canvas.rotate(animationTime * 0.12);

    for (int i = 0; i < totalBars; i++) {
      double angle = i * angleStep;

      // Classify bars into frequency sections symmetrically:
      // We map bars symmetrically around the circle so bass is at top/bottom, mids at sides, treble in between.
      double intensity = 0.0;
      Color barColor;

      // Map index into symmetric quadrants
      int quadIndex = i % (totalBars ~/ 2);
      if (quadIndex < 10 || quadIndex > 30) {
        // Bass region (ends of the semi-circles)
        intensity = frame.bass;
        barColor = primaryColor;
      } else if (quadIndex >= 14 && quadIndex <= 26) {
        // Treble region (center of the semi-circles)
        intensity = frame.treble;
        barColor = secondaryColor;
      } else {
        // Mid region (transitional areas)
        intensity = frame.mid;
        // Interpolate color
        double t = (quadIndex - 10) / 4.0;
        if (quadIndex > 26) t = (30 - quadIndex) / 4.0;
        barColor = Color.lerp(primaryColor, secondaryColor, t.clamp(0.0, 1.0))!;
      }

      // Procedural variation so bars aren't completely identical, 
      // but the length is strictly scaled by the audio intensity (gain).
      double variation = 0.7 + 0.3 * sin(angle * 24 + animationTime * 2.0);
      double barLength = maxBarHeight * intensity * variation;
      
      // Ensure a minimum height for visual aesthetics
      barLength = max(4.0, barLength);

      final double startX = cos(angle) * (innerRadius + 6);
      final double startY = sin(angle) * (innerRadius + 6);
      final double endX = cos(angle) * (innerRadius + 6 + barLength);
      final double endY = sin(angle) * (innerRadius + 6 + barLength);

      final barPaint = Paint()
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            barColor,
            barColor.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)));

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        barPaint,
      );

      // Add a tiny glowing dot at the end of the active bars
      if (intensity > 0.3) {
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
        canvas.drawCircle(Offset(endX, endY), 1.2 * intensity, dotPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VortexPainter oldDelegate) {
    return oldDelegate.animationTime != animationTime || oldDelegate.frame != frame;
  }
}
