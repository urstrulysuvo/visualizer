import 'dart:math';
import 'package:flutter/material.dart';
import '../wav_decoder.dart';

class HorizonPainter extends CustomPainter {
  final WaveFrame frame;
  final double animationTime;
  final Color primaryColor;
  final Color secondaryColor;

  HorizonPainter({
    required this.frame,
    required this.animationTime,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.40;

    // Draw dark space background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF070014),
          const Color(0xFF14002C),
          const Color(0xFF220038),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw Retro Synthwave Sun at the horizon
    _drawRetroSun(canvas, size, horizonY);

    // Draw Grid perspective lines (vertical grid lines running from horizon to bottom)
    _drawPerspectiveGridLines(canvas, size, horizonY);

    // Draw Horizontal Wavefront lines (reacting to bass, mid, treble)
    _drawWavefrontLines(canvas, size, horizonY);
  }

  void _drawRetroSun(Canvas canvas, Size size, double horizonY) {
    final double sunRadius = min(size.width, size.height) * 0.25;
    final Offset sunCenter = Offset(size.width / 2, horizonY + 10);

    final sunPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.orange.shade700,
          primaryColor,
          secondaryColor,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));

    // Clip the sun to create horizontal scanlines (grille effect)
    canvas.save();
    
    // Draw sun base circle
    final sunPath = Path()..addOval(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    
    // We will clip out horizontal lines that get thicker towards the bottom
    final clipPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    int numStripes = 8;
    for (int i = 0; i < numStripes; i++) {
      // Calculate stripe vertical position (increasing gaps as we go down)
      double stripeHeight = 4 + i * 2.5;
      double yOffset = horizonY - (i * (sunRadius / numStripes)) - stripeHeight;
      clipPath.addRect(Rect.fromLTWH(sunCenter.dx - sunRadius - 10, yOffset, sunRadius * 2 + 20, stripeHeight));
    }

    // Clip out the scanlines
    canvas.clipPath(Path.combine(PathOperation.difference, sunPath, clipPath));
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);
    canvas.restore();

    // Draw glowing sun halo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.3 * (1.0 + 0.3 * frame.bass)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius * 1.8));
    canvas.drawCircle(sunCenter, sunRadius * 1.8, glowPaint);
  }

  void _drawPerspectiveGridLines(Canvas canvas, Size size, double horizonY) {
    final int numGridLines = 14;
    final double gridPaintWidth = 1.0;
    
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = gridPaintWidth
      ..shader = LinearGradient(
        colors: [
          secondaryColor.withValues(alpha: 0.05),
          secondaryColor.withValues(alpha: 0.30),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, horizonY, size.width, size.height));

    for (int i = 0; i <= numGridLines; i++) {
      // Linear spacing on the horizon, but expand outwards at the bottom
      double t = i / numGridLines;
      double xHorizon = size.width / 2 + (t - 0.5) * (size.width * 0.2);
      double xBottom = size.width / 2 + (t - 0.5) * (size.width * 1.5);
      
      canvas.drawLine(
        Offset(xHorizon, horizonY),
        Offset(xBottom, size.height),
        linePaint,
      );
    }
  }

  void _drawWavefrontLines(Canvas canvas, Size size, double horizonY) {
    const int numWaves = 10;
    final double gridHeight = size.height - horizonY;

    for (int w = 0; w < numWaves; w++) {
      // Perspective spacing (closer waves are further apart)
      double wavePct = w / (numWaves - 1);
      // Curve to compress lines towards the horizon
      double normY = pow(wavePct, 2.2).toDouble(); 
      double y = horizonY + normY * gridHeight;

      // Stroke width gets thicker as wave gets closer
      double strokeWidth = 0.5 + 2.5 * normY;
      
      // Select audio amplitude based on distance: Bass in distance, Mid in middle, Treble in front
      double amp = 0.0;
      Color waveColor;
      if (w < 3) {
        amp = frame.bass;
        waveColor = primaryColor;
      } else if (w < 7) {
        amp = frame.mid;
        waveColor = Color.lerp(primaryColor, secondaryColor, (w - 3) / 4.0)!;
      } else {
        amp = frame.treble;
        waveColor = secondaryColor;
      }

      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = waveColor.withValues(alpha: 0.1 + 0.8 * normY);

      final path = Path();
      const int numPoints = 40;
      final double widthStep = size.width / numPoints;

      for (int i = 0; i <= numPoints; i++) {
        double px = i * widthStep;
        
        // Calculate dynamic wave displacement
        // Amplitude is highest in the center and decays at the edges (to align with screen borders)
        double centerFactor = sin(i / numPoints * pi); // 0 at edges, 1 in center
        
        // Rolling wave phase based on time
        double wavePhase = (i * 0.4) - (animationTime * 4.0) + (w * 1.5);
        double displacement = sin(wavePhase) * cos(wavePhase * 0.5) * 15.0 * amp * centerFactor * (0.3 + 0.7 * normY);

        double py = y + displacement;

        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }

      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant HorizonPainter oldDelegate) {
    return oldDelegate.animationTime != animationTime || oldDelegate.frame != frame;
  }
}
