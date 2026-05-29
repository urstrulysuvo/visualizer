import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:developer' as dev;

class WaveFrame {
  final double bass;
  final double mid;
  final double treble;
  final double full;

  const WaveFrame({
    required this.bass,
    required this.mid,
    required this.treble,
    required this.full,
  });

  factory WaveFrame.zero() => const WaveFrame(bass: 0, mid: 0, treble: 0, full: 0);

  // Smoothly blend two frames
  static WaveFrame lerp(WaveFrame a, WaveFrame b, double t) {
    return WaveFrame(
      bass: a.bass + (b.bass - a.bass) * t,
      mid: a.mid + (b.mid - a.mid) * t,
      treble: a.treble + (b.treble - a.treble) * t,
      full: a.full + (b.full - a.full) * t,
    );
  }
}

class AudioWaveData {
  final List<double> bassAmplitudes;
  final List<double> midAmplitudes;
  final List<double> trebleAmplitudes;
  final List<double> fullAmplitudes;
  final int durationMs;
  final int intervalMs;

  AudioWaveData({
    required this.bassAmplitudes,
    required this.midAmplitudes,
    required this.trebleAmplitudes,
    required this.fullAmplitudes,
    required this.durationMs,
    this.intervalMs = 50,
  });

  factory AudioWaveData.empty() {
    return AudioWaveData(
      bassAmplitudes: [],
      midAmplitudes: [],
      trebleAmplitudes: [],
      fullAmplitudes: [],
      durationMs: 0,
    );
  }

  // Generates simulated wave data for MP3s or when decoding fails
  factory AudioWaveData.generateSimulated(int durationMs, {int intervalMs = 50}) {
    final int count = durationMs ~/ intervalMs;
    final List<double> bass = List.filled(count, 0.0);
    final List<double> mid = List.filled(count, 0.0);
    final List<double> treble = List.filled(count, 0.0);
    final List<double> full = List.filled(count, 0.0);

    for (int i = 0; i < count; i++) {
      double t = (i * intervalMs) / 1000.0;
      
      // Simulate beats (bass) at ~120 BPM (every 0.5 seconds)
      double beatTime = t % 0.5;
      double bassPulse = exp(-10.0 * beatTime);
      bass[i] = 0.2 + 0.6 * bassPulse + 0.2 * sin(2 * pi * t * 0.2).abs();

      // Simulate mid-range melodies
      double midVal = 0.3 * sin(2 * pi * t * 1.5).abs() +
                      0.2 * cos(2 * pi * t * 3.7).abs() +
                      0.1 * sin(2 * pi * t * 0.8).abs();
      mid[i] = midVal.clamp(0.0, 1.0);

      // Simulate treble (hi-hats, sparkles)
      double treblePulse = (i % 8 == 2 || i % 8 == 6) ? 0.4 * exp(-8.0 * (t % 0.25)) : 0.05;
      treble[i] = (treblePulse + 0.1 * Random(i).nextDouble()).clamp(0.0, 1.0);

      // Combine
      full[i] = (bass[i] * 0.5 + mid[i] * 0.3 + treble[i] * 0.2).clamp(0.0, 1.0);
    }

    return AudioWaveData(
      bassAmplitudes: bass,
      midAmplitudes: mid,
      trebleAmplitudes: treble,
      fullAmplitudes: full,
      durationMs: durationMs,
      intervalMs: intervalMs,
    );
  }

  WaveFrame getFrameAt(int ms) {
    if (durationMs <= 0 || fullAmplitudes.isEmpty) return WaveFrame.zero();
    
    // Clamp to valid range
    int clampedMs = ms.clamp(0, durationMs);
    double exactIndex = clampedMs / intervalMs;
    int indexA = exactIndex.floor();
    int indexB = (indexA + 1).clamp(0, fullAmplitudes.length - 1);
    
    if (indexA >= fullAmplitudes.length) {
      return WaveFrame(
        bass: bassAmplitudes.last,
        mid: midAmplitudes.last,
        treble: trebleAmplitudes.last,
        full: fullAmplitudes.last,
      );
    }
    
    double t = exactIndex - indexA;

    final frameA = WaveFrame(
      bass: bassAmplitudes[indexA],
      mid: midAmplitudes[indexA],
      treble: trebleAmplitudes[indexA],
      full: fullAmplitudes[indexA],
    );

    final frameB = WaveFrame(
      bass: bassAmplitudes[indexB],
      mid: midAmplitudes[indexB],
      treble: trebleAmplitudes[indexB],
      full: fullAmplitudes[indexB],
    );

    return WaveFrame.lerp(frameA, frameB, t);
  }
}

class WavDecoder {
  static Future<AudioWaveData> decodeWavFile(String path, {int intervalMs = 50}) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final byteData = ByteData.sublistView(bytes);

      if (bytes.length < 44) throw Exception("File too small to be WAV");

      // Verify RIFF
      if (byteData.getUint8(0) != 0x52 || // R
          byteData.getUint8(1) != 0x49 || // I
          byteData.getUint8(2) != 0x46 || // F
          byteData.getUint8(3) != 0x46) { // F
        throw Exception("Not a RIFF file");
      }

      // Verify WAVE
      if (byteData.getUint8(8) != 0x57 || // W
          byteData.getUint8(9) != 0x41 || // A
          byteData.getUint8(10) != 0x56 || // V
          byteData.getUint8(11) != 0x45) { // E
        throw Exception("Not a WAVE file");
      }

      int formatType = 0;
      int numChannels = 0;
      int sampleRate = 0;
      int bitsPerSample = 0;
      int dataOffset = 0;
      int dataSize = 0;

      int pointer = 12;
      while (pointer + 8 < bytes.length) {
        String chunkId = String.fromCharCodes(bytes.sublist(pointer, pointer + 4));
        int chunkSize = byteData.getUint32(pointer + 4, Endian.little);
        pointer += 8;

        if (chunkId == "fmt ") {
          formatType = byteData.getUint16(pointer, Endian.little);
          numChannels = byteData.getUint16(pointer + 2, Endian.little);
          sampleRate = byteData.getUint32(pointer + 4, Endian.little);
          bitsPerSample = byteData.getUint16(pointer + 14, Endian.little);
        } else if (chunkId == "data") {
          dataOffset = pointer;
          dataSize = chunkSize;
          break;
        }
        pointer += chunkSize;
      }

      if (formatType != 1) throw Exception("Only uncompressed PCM WAV files are supported");
      if (bitsPerSample != 8 && bitsPerSample != 16) throw Exception("Only 8-bit or 16-bit WAV supported");
      if (dataOffset == 0 || dataSize == 0) throw Exception("No WAV data chunk found");

      // Extract PCM samples
      final int bytesPerSample = bitsPerSample ~/ 8;
      final int totalSamples = dataSize ~/ (numChannels * bytesPerSample);
      
      final double durationSec = totalSamples / sampleRate;
      final int durationMs = (durationSec * 1000).toInt();

      final List<double> rawSamples = List.filled(totalSamples, 0.0);

      // Extract and mix down to mono if stereo
      if (bitsPerSample == 16) {
        for (int i = 0; i < totalSamples; i++) {
          double sum = 0.0;
          for (int c = 0; c < numChannels; c++) {
            int byteIndex = dataOffset + (i * numChannels + c) * 2;
            if (byteIndex + 1 < bytes.length) {
              int sampleVal = byteData.getInt16(byteIndex, Endian.little);
              sum += sampleVal / 32768.0;
            }
          }
          rawSamples[i] = sum / numChannels;
        }
      } else {
        // 8-bit is unsigned (0 to 255, offset by 128)
        for (int i = 0; i < totalSamples; i++) {
          double sum = 0.0;
          for (int c = 0; c < numChannels; c++) {
            int byteIndex = dataOffset + (i * numChannels + c);
            if (byteIndex < bytes.length) {
              int sampleVal = bytes[byteIndex];
              sum += (sampleVal - 128) / 128.0;
            }
          }
          rawSamples[i] = sum / numChannels;
        }
      }

      // Apply digital low-pass and high-pass filters to extract Bass, Mid, and Treble
      // fc_bass = 150 Hz, fc_treble = 2000 Hz
      double dt = 1.0 / sampleRate;
      
      // LPF Bass coefficients
      double rcBass = 1.0 / (2 * pi * 150.0);
      double alphaBass = dt / (rcBass + dt);
      
      // HPF Treble coefficients
      double rcTreble = 1.0 / (2 * pi * 2000.0);
      double alphaTreble = rcTreble / (rcTreble + dt);

      final List<double> bassFiltered = List.filled(totalSamples, 0.0);
      final List<double> trebleFiltered = List.filled(totalSamples, 0.0);
      final List<double> midFiltered = List.filled(totalSamples, 0.0);

      double prevLowPass = 0.0;
      double prevHighPass = 0.0;
      double prevX = 0.0;

      for (int i = 0; i < totalSamples; i++) {
        double x = rawSamples[i];

        // LPF for Bass
        double lowPass = alphaBass * x + (1.0 - alphaBass) * prevLowPass;
        bassFiltered[i] = lowPass;
        prevLowPass = lowPass;

        // HPF for Treble
        double highPass = alphaTreble * (prevHighPass + x - prevX);
        trebleFiltered[i] = highPass;
        prevHighPass = highPass;
        prevX = x;

        // Mid is the remainder
        midFiltered[i] = x - lowPass - highPass;
      }

      // Downsample to window intervals (e.g. 50ms chunks)
      final int samplesPerInterval = (sampleRate * (intervalMs / 1000.0)).toInt();
      final int numIntervals = durationMs ~/ intervalMs;

      final List<double> bassAmps = [];
      final List<double> midAmps = [];
      final List<double> trebleAmps = [];
      final List<double> fullAmps = [];

      for (int step = 0; step < numIntervals; step++) {
        int startSample = step * samplesPerInterval;
        int endSample = min(startSample + samplesPerInterval, totalSamples);
        int windowLength = endSample - startSample;

        if (windowLength <= 0) break;

        double sumSqBass = 0.0;
        double sumSqMid = 0.0;
        double sumSqTreble = 0.0;
        double sumSqFull = 0.0;

        for (int i = startSample; i < endSample; i++) {
          sumSqBass += bassFiltered[i] * bassFiltered[i];
          sumSqMid += midFiltered[i] * midFiltered[i];
          sumSqTreble += trebleFiltered[i] * trebleFiltered[i];
          sumSqFull += rawSamples[i] * rawSamples[i];
        }

        // Calculate Root-Mean-Square (RMS) for each band and scale/boost for visualization
        double rmsBass = sqrt(sumSqBass / windowLength) * 2.2;
        double rmsMid = sqrt(sumSqMid / windowLength) * 2.5;
        double rmsTreble = sqrt(sumSqTreble / windowLength) * 3.0;
        double rmsFull = sqrt(sumSqFull / windowLength) * 2.0;

        // Clamp to 0..1 range
        bassAmps.add(rmsBass.clamp(0.0, 1.0));
        midAmps.add(rmsMid.clamp(0.0, 1.0));
        trebleAmps.add(rmsTreble.clamp(0.0, 1.0));
        fullAmps.add(rmsFull.clamp(0.0, 1.0));
      }

      // Smooth the signals slightly to make them less jittery
      _smoothArray(bassAmps);
      _smoothArray(midAmps);
      _smoothArray(trebleAmps);
      _smoothArray(fullAmps);

      return AudioWaveData(
        bassAmplitudes: bassAmps,
        midAmplitudes: midAmps,
        trebleAmplitudes: trebleAmps,
        fullAmplitudes: fullAmps,
        durationMs: durationMs,
        intervalMs: intervalMs,
      );
    } catch (e) {
      dev.log("Wav decoding failed: $e. Falling back to simulation.");
      return AudioWaveData.generateSimulated(16000, intervalMs: intervalMs);
    }
  }

  // Simple rolling average filter for visual smoothing
  static void _smoothArray(List<double> array) {
    if (array.length < 3) return;
    for (int i = 1; i < array.length - 1; i++) {
      array[i] = (array[i - 1] + array[i] * 2.0 + array[i + 1]) / 4.0;
    }
  }
}
