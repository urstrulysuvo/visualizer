import 'dart:math';
import 'package:flutter/material.dart';
import '../wav_decoder.dart';

class NebulaPainter extends CustomPainter {
  final WaveFrame frame;
  final double animationTime; // continuously incrementing value for smooth movement
  final Color primaryColor;
  final Color secondaryColor;

  NebulaPainter({
    required this.frame,
    required this.animationTime,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = min(size.width, size.height);
    final baseRadius = minDim * 0.20;

    // Draw glowing background aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.25 * (0.6 + 0.4 * frame.bass)),
          secondaryColor.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 2.8));
    canvas.drawCircle(center, baseRadius * 2.8, auraPaint);

    // Draw bass ripples (concentric expanding rings)
    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = primaryColor.withValues(alpha: (1.0 - (animationTime % 1.0)) * 0.3 * frame.bass);
    double rippleRadius = baseRadius * (1.0 + 1.5 * (animationTime % 1.0)) * (1.0 + 0.2 * frame.bass);
    canvas.drawCircle(center, rippleRadius, ripplePaint);

    // Draw secondary ripple
    final ripplePaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = secondaryColor.withValues(alpha: (1.0 - ((animationTime + 0.5) % 1.0)) * 0.2 * frame.mid);
    double rippleRadius2 = baseRadius * (1.0 + 1.5 * ((animationTime + 0.5) % 1.0)) * (1.0 + 0.1 * frame.mid);
    canvas.drawCircle(center, rippleRadius2, ripplePaint2);

    // Draw the morphing fluid blob layers
    _drawBlobLayer(canvas, center, baseRadius * (1.0 + 0.15 * frame.bass), 0.7, 8, 0.0, 0.65);
    _drawBlobLayer(canvas, center, baseRadius * (0.85 + 0.10 * frame.mid), 0.5, 6, 1.5, 0.5);
    _drawBlobLayer(canvas, center, baseRadius * (0.70 + 0.05 * frame.treble), 0.4, 5, 3.0, 0.35);

    // Draw orbiting particle ring
    _drawOrbitingParticles(canvas, center, baseRadius);
  }

  void _drawBlobLayer(
    Canvas canvas,
    Offset center,
    double radius,
    double speedCoeff,
    int numPoints,
    double phaseShift,
    double opacity,
  ) {
    final path = Path();
    final double angleStep = 2 * pi / numPoints;
    final List<Offset> points = [];

    for (int i = 0; i < numPoints; i++) {
      double angle = i * angleStep;
      
      // Modulate the radius of each point using sine waves driven by animationTime and audio
      double noise = sin(angle * 2 + animationTime * speedCoeff * 3.0 + phaseShift) * 0.15 +
                     cos(angle * 3 - animationTime * speedCoeff * 2.0 + phaseShift) * 0.10;
      
      // Scale noise by audio amplitude (bass and mid)
      double modulatedRadius = radius * (1.0 + noise * (0.3 + 0.7 * frame.bass));
      
      double x = center.dx + cos(angle) * modulatedRadius;
      double y = center.dy + sin(angle) * modulatedRadius;
      points.add(Offset(x, y));
    }

    // Connect points using a smooth Bezier path
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < numPoints; i++) {
      final p1 = points[(i + 1) % numPoints];
      final p2 = points[(i + 2) % numPoints];
      
      // Control points for smooth curves
      final xc2 = (p1.dx + p2.dx) / 2;
      final yc2 = (p1.dy + p2.dy) / 2;

      path.quadraticBezierTo(p1.dx, p1.dy, xc2, yc2);
    }
    path.close();

    final blobPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: opacity),
          secondaryColor.withValues(alpha: opacity * 0.5),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, blobPaint);
  }

  void _drawOrbitingParticles(Canvas canvas, Offset center, double baseRadius) {
    const int numParticles = 40;
    
    for (int i = 0; i < numParticles; i++) {
      // Deterministic particle variables based on index
      double initialAngle = (i * (2 * pi / numParticles));
      double distanceCoeff = 1.3 + (i % 5) * 0.15;
      double speedFactor = 0.5 + (i % 3) * 0.25;
      double pSize = 1.5 + (i % 4);

      // Orbital angle updates with time, modulated by treble
      double currentAngle = initialAngle + animationTime * speedFactor * (1.0 + 1.2 * frame.treble);
      double currentRadius = baseRadius * distanceCoeff * (1.0 + 0.12 * frame.bass * sin(currentAngle * 4));

      double px = center.dx + cos(currentAngle) * currentRadius;
      double py = center.dy + sin(currentAngle) * currentRadius;

      final pPaint = Paint()
        ..color = Color.lerp(
          secondaryColor,
          primaryColor,
          (sin(currentAngle + i) + 1.0) / 2.0,
        )!.withValues(alpha: 0.4 + 0.6 * frame.treble)
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, pSize * 0.5);

      canvas.drawCircle(Offset(px, py), pSize * (1.0 + 0.8 * frame.treble), pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant NebulaPainter oldDelegate) {
    return oldDelegate.animationTime != animationTime || oldDelegate.frame != frame;
  }
}
