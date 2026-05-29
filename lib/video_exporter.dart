import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';

import 'wav_decoder.dart';
import 'main.dart'; 
import 'visualizers/vortex_painter.dart';

class VideoExporter {
  static Future<void> exportVideo({
    required AudioWaveData waveData,
    required ColorPreset preset,
    required String trackName,
    required String albumName,
    required ui.Image? albumArt,
    required int durationMs,
    required double volume,
    required String audioFilePath,
    required String outputPath,
    required Function(double progress) onProgress,
  }) async {
    const int fps = 60;
    final int totalFrames = (durationMs / 1000 * fps).ceil();
    const double width = 1920;
    const double height = 1080;

    // Check if ffmpeg exists
    try {
      final result = await Process.run('which', ['ffmpeg']);
      if (result.exitCode != 0) {
        throw Exception('FFmpeg is not installed. Please install it using "sudo dnf install ffmpeg".');
      }
    } catch (e) {
      if (e.toString().contains('FFmpeg is not installed')) rethrow;
      throw Exception('FFmpeg is not installed. Please install it using "sudo dnf install ffmpeg".');
    }

    final process = await Process.start('ffmpeg', [
      '-y',
      '-f', 'rawvideo',
      '-pix_fmt', 'rgba',
      '-s', '${width.toInt()}x${height.toInt()}',
      '-r', '$fps',
      '-i', '-', // input from stdin
      '-i', audioFilePath, // original audio
      '-c:v', 'mpeg4',
      '-q:v', '2',
      '-c:a', 'aac',
      '-pix_fmt', 'yuv420p',
      '-shortest', // stop encoding when the shortest stream ends
      outputPath
    ]);

    for (int i = 0; i < totalFrames; i++) {
      final double timeMs = (i / fps) * 1000.0;
      final rawFrame = waveData.getFrameAt(timeMs.toInt());
      final frame = WaveFrame(
        bass: rawFrame.bass * volume,
        mid: rawFrame.mid * volume,
        treble: rawFrame.treble * volume,
        full: rawFrame.full * volume,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      // 1. Draw Background
      final bgPaint = Paint()
        ..shader = ui.Gradient.radial(
          const Offset(width / 2, height / 2),
          width,
          [const Color(0xFF1E033A), const Color(0xFF090014)],
          null,
          TileMode.clamp,
          Matrix4.diagonal3Values(1.0, height/width, 1.0).storage,
        );
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

      // 2. Draw Visualizer
      final CustomPainter painter = VortexPainter(
        frame: frame,
        animationTime: (timeMs / 1000.0) * 2 * pi * 2.0,
        primaryColor: preset.primary,
        secondaryColor: preset.secondary,
      );
      
      painter.paint(canvas, const Size(width, height));

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      process.stdin.add(byteData!.buffer.asUint8List());
      
      img.dispose();
      picture.dispose();
      
      if (i % 10 == 0) {
        onProgress(i / totalFrames);
        await Future.delayed(Duration.zero);
      }
    }

    await process.stdin.close();
    final exitCode = await process.exitCode;
    
    if (exitCode != 0) {
      throw Exception('FFmpeg failed with exit code $exitCode');
    }
    
    onProgress(1.0);
  }
}
