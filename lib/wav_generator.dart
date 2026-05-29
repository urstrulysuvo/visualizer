import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

class WavGenerator {
  static Future<String> generateDemoWav(String outputPath) async {
    final file = File(outputPath);
    if (await file.exists()) {
      return outputPath; // Return existing file path
    }

    const int sampleRate = 22050;
    const double duration = 16.0; // 16 seconds loop
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const int blockAlign = numChannels * (bitsPerSample ~/ 8);

    final int numSamples = (sampleRate * duration).toInt();
    final int dataSize = numSamples * blockAlign;
    final int fileSize = 44 + dataSize;

    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize - 8, Endian.little);
    
    // WAVE
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    
    // fmt subchunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Chunk size (16 for PCM)
    header.setUint16(20, 1, Endian.little);  // Audio format (1 for PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // data subchunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final pcmData = Int16List(numSamples);

    // Progression of notes (frequencies in Hz)
    // A2 (110.0), C3 (130.81), F2 (87.31), G2 (98.0)
    final bassNotes = [110.0, 130.81, 87.31, 98.0];
    
    // Arpeggio notes for melody (A4, C5, E5, G5, etc.)
    final melodyPatterns = [
      [440.0, 523.25, 659.25, 783.99], // Amin7
      [523.25, 659.25, 783.99, 987.77], // Cmaj7
      [349.23, 440.0, 523.25, 659.25], // Fmaj7
      [392.00, 493.88, 587.33, 698.46], // Gdom7
    ];

    double bassPhase = 0.0;
    double melodyPhase = 0.0;

    // Use a fixed seed for reproducible random generation of hats
    final random = Random(42);

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;

      // 1. Kick Drum (every 0.5s)
      double beatTime = t % 0.5;
      // Exponentially decay frequency and amplitude
      double kickFreq = 140.0 * exp(-30.0 * beatTime) + 40.0;
      double kickAmp = exp(-12.0 * beatTime);
      double kickPhase = 2 * pi * kickFreq * beatTime;
      double kickVal = sin(kickPhase) * kickAmp;

      // 2. Bassline (note changes every 1.0s)
      int bassIndex = (t ~/ 1.0) % bassNotes.length;
      double bassFreq = bassNotes[bassIndex];
      bassPhase += 2 * pi * bassFreq / sampleRate;
      double bassVal = ((bassPhase % (2 * pi)) / pi - 1.0).abs() * 2.0 - 1.0;
      
      // Filter sweep simulation
      double filterSweep = 0.5 + 0.5 * sin(2 * pi * t / 4.0); // 4s sweep cycle
      bassVal *= filterSweep;

      // 3. Melody Arpeggio (changes every 0.125s, i.e., 8th note)
      int chordIndex = (t ~/ 2.0) % melodyPatterns.length;
      final currentChord = melodyPatterns[chordIndex];
      int noteIndex = (t ~/ 0.125 % 4).toInt();
      double melodyFreq = currentChord[noteIndex];
      
      double noteTime = t % 0.125;
      double melodyAmp = exp(-15.0 * noteTime);
      melodyPhase += 2 * pi * melodyFreq / sampleRate;
      double melodyVal = sin(melodyPhase) * melodyAmp;

      // 4. Hi-Hat (on off-beats, every 0.25s offset by 0.125s)
      double hatTime = (t + 0.125) % 0.25;
      double hatAmp = exp(-40.0 * hatTime);
      double hatVal = (random.nextDouble() * 2.0 - 1.0) * hatAmp * 0.15;

      // Mix sounds
      double mixed = (kickVal * 0.45) + (bassVal * 0.35) + (melodyVal * 0.15) + hatVal;
      
      // Clip to avoid distortion
      if (mixed > 1.0) mixed = 1.0;
      if (mixed < -1.0) mixed = -1.0;

      // Convert to 16-bit signed integer
      pcmData[i] = (mixed * 32767).toInt();
    }

    final bytes = Uint8List(fileSize);
    bytes.setRange(0, 44, header.buffer.asUint8List());
    bytes.setRange(44, fileSize, pcmData.buffer.asUint8List());

    // Create directory if not exists
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return outputPath;
  }
}
