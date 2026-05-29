import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'wav_generator.dart';
import 'wav_decoder.dart';

class FaithlessDashboard extends StatefulWidget {
  const FaithlessDashboard({super.key});

  @override
  State<FaithlessDashboard> createState() => _FaithlessDashboardState();
}

class _FaithlessDashboardState extends State<FaithlessDashboard> with SingleTickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  late final AnimationController _animationController;

  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  final double _volume = 0.8;
  DateTime? _lastPositionUpdateTime;

  final String _trackName = "Faithles";
  final String _trackSubtitle = "Solomun Set";
  AudioWaveData _waveData = AudioWaveData.empty();

  @override
  void initState() {
    super.initState();
    
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(_volume);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
          _lastPositionUpdateTime = DateTime.now();
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      // Not used in this dashboard
    });

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() {
          _isPlaying = s == PlayerState.playing;
          if (_isPlaying) {
            _lastPositionUpdateTime = DateTime.now();
            _animationController.repeat();
          } else {
            _lastPositionUpdateTime = null;
            _animationController.stop();
          }
        });
      }
    });

    _loadDefaultTrack();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultTrack() async {
    setState(() => _isLoading = true);
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final defaultWavPath = "${appDocDir.path}/demo_synth.wav";
      await WavGenerator.generateDemoWav(defaultWavPath);
      final waveData = await WavDecoder.decodeWavFile(defaultWavPath);
      await _audioPlayer.setSource(DeviceFileSource(defaultWavPath));
      if (mounted) {
        setState(() {
          _waveData = waveData;
          _isLoading = false;
        });
        _audioPlayer.resume();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF110E19),
        body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF110E19),
      body: Stack(
        children: [
          // Background Gradient Overlay
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF2A1B38), Color(0xFF110E19)],
                center: Alignment.centerLeft,
                radius: 1.5,
              ),
            ),
          ),
          
          // Visualizer & Dashed Line
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                Duration currentPos = _position;
                if (_isPlaying && _lastPositionUpdateTime != null) {
                  final elapsed = DateTime.now().difference(_lastPositionUpdateTime!);
                  currentPos = _position + elapsed;
                }
                
                final rawFrame = _waveData.getFrameAt(currentPos.inMilliseconds);
                final frame = WaveFrame(
                  bass: rawFrame.bass * _volume,
                  mid: rawFrame.mid * _volume,
                  treble: rawFrame.treble * _volume,
                  full: rawFrame.full * _volume,
                );

                return CustomPaint(
                  painter: FaithlessPainter(frame: frame),
                );
              },
            ),
          ),

          // Left side text (Bottom Left)
          Positioned(
            left: 60,
            bottom: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trackName,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
                Text(
                  _trackSubtitle,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFFFF5EED).withValues(alpha: 0.8),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Center Play Button
          Positioned(
            left: size.width / 2 - 50,
            top: size.height / 2 - 50,
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5EED), Color(0xFF8A2BE2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5EED).withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 40,
                ),
              ),
            ),
          ),

          // Right side Album Art
          Positioned(
            right: 60,
            top: size.height / 2 - 250,
            child: Container(
              width: 380,
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5EED), Color(0xFF4A00E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A00E0).withValues(alpha: 0.6),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8), // Border thickness
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.network(
                  "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80",
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.2),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FaithlessPainter extends CustomPainter {
  final WaveFrame frame;

  FaithlessPainter({required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;

    // 1. Draw dashed line across the screen
    final linePaint = Paint()
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double dashWidth = 16.0;
    final double dashSpace = 12.0;
    double startX = 0;

    while (startX < size.width) {
      // Create a gradient effect for the dashed line from blue to pink
      final double progress = startX / size.width;
      linePaint.color = Color.lerp(const Color(0xFF4A00E0), const Color(0xFFFF5EED), progress)!;
      
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(startX + dashWidth, centerY),
        linePaint,
      );
      startX += dashWidth + dashSpace;
    }

    // 2. Draw the Pyramid Visualizer
    final int numRows = 16;
    final double blockHeight = 6.0;
    final double rowSpacing = 8.0;
    final double maxBlockWidth = 24.0;
    final double blockSpacing = 6.0;

    final double pyramidCenterX = size.width * 0.25; 
    
    // Scale intensity by full frequency
    final double intensity = 0.2 + (frame.full * 0.8);

    for (int row = 0; row < numRows; row++) {
      // The higher the row, the fewer blocks it has
      final int blocksInRow = (numRows - row); 
      
      final double rowWidth = (blocksInRow * maxBlockWidth) + ((blocksInRow - 1) * blockSpacing);
      double currentX = pyramidCenterX - (rowWidth / 2);
      
      final double currentY = centerY - 20 - (row * (blockHeight + rowSpacing));

      // Calculate block color based on height and intensity
      final double heightProgress = row / numRows;
      final Color blockColor = Color.lerp(
        const Color(0xFF8A2BE2), 
        const Color(0xFFFF5EED), 
        heightProgress
      )!.withValues(alpha: (1.0 - heightProgress * 0.4) * intensity);

      final Paint blockPaint = Paint()
        ..color = blockColor
        ..style = PaintingStyle.fill;
        
      final Paint glowPaint = Paint()
        ..color = blockColor.withValues(alpha: 0.6 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

      // We use mid and treble for the higher rows, bass for the base
      double requiredIntensity = row / numRows;
      double currentBand = row < 4 ? frame.bass : (row < 10 ? frame.mid : frame.treble);
      
      // Add a tiny bit of base intensity so the bottom few rows are always slightly visible
      double baseVisibility = row < 3 ? 0.3 : 0.0;
      
      if (currentBand + baseVisibility > requiredIntensity) {
        for (int b = 0; b < blocksInRow; b++) {
          final RRect rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(currentX, currentY, maxBlockWidth, blockHeight),
            const Radius.circular(2.0),
          );
          
          canvas.drawRRect(rect, glowPaint);
          canvas.drawRRect(rect, blockPaint);
          
          currentX += maxBlockWidth + blockSpacing;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaithlessPainter oldDelegate) {
    return oldDelegate.frame.bass != frame.bass ||
           oldDelegate.frame.mid != frame.mid ||
           oldDelegate.frame.treble != frame.treble;
  }
}
