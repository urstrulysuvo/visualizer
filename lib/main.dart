import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'wav_generator.dart';
import 'wav_decoder.dart';
import 'visualizers/nebula_painter.dart';
import 'visualizers/horizon_painter.dart';
import 'visualizers/vortex_painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aether Visualizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0016),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD300C5),
          secondary: Color(0xFF00F0FF),
          surface: Color(0xFF1E0A30),
        ),
      ),
      home: const VisualizerDashboard(),
    );
  }
}

enum VisualizerMode { nebula, horizon, vortex }

class ColorPreset {
  final String name;
  final Color primary;
  final Color secondary;

  const ColorPreset(this.name, this.primary, this.secondary);
}

const List<ColorPreset> colorPresets = [
  ColorPreset("Cyberpunk", Color(0xFFD300C5), Color(0xFF00F0FF)),
  ColorPreset("Sunset Glow", Color(0xFFFF4B2B), Color(0xFFFF416C)),
  ColorPreset("Forest Aurora", Color(0xFF00FF87), Color(0xFF60EFFF)),
  ColorPreset("Deep Space", Color(0xFF7F00FF), Color(0xFFE100FF)),
];

class VisualizerDashboard extends StatefulWidget {
  const VisualizerDashboard({super.key});

  @override
  State<VisualizerDashboard> createState() => _VisualizerDashboardState();
}

class _VisualizerDashboardState extends State<VisualizerDashboard>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  late final AnimationController _animationController;

  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 0.8;

  String _trackName = "demo_synth.wav";
  bool _isRealAnalysis = true;
  AudioWaveData _waveData = AudioWaveData.empty();
  VisualizerMode _currentMode = VisualizerMode.nebula;
  int _selectedPresetIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize audio player
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(_volume);

    // Set up continuous rotation and ripple animation at 60fps
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    // Setup listener streams
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
          
          // Regenerate simulation to exact length if not doing real WAV analysis
          if (!_isRealAnalysis && _waveData.durationMs != d.inMilliseconds) {
            _waveData = AudioWaveData.generateSimulated(
              max(1000, d.inMilliseconds),
              intervalMs: 50,
            );
          }
        });
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() {
          _isPlaying = s == PlayerState.playing;
          if (_isPlaying) {
            _animationController.repeat();
          } else {
            _animationController.stop();
          }
        });
      }
    });

    // Generate demo synth file and load it
    _loadDefaultTrack();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultTrack() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final defaultWavPath = "${appDocDir.path}/demo_synth.wav";

      // 1. Generate synth track
      await WavGenerator.generateDemoWav(defaultWavPath);

      // 2. Decode waveform data (bass, mids, highs)
      final waveData = await WavDecoder.decodeWavFile(defaultWavPath);

      // 3. Configure audio player source
      await _audioPlayer.setSource(DeviceFileSource(defaultWavPath));

      if (mounted) {
        setState(() {
          _waveData = waveData;
          _trackName = "demo_synth.wav (Procedural Synth)";
          _isRealAnalysis = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed loading default track: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndLoadAudio() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isLoading = true;
      });

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final isWav = fileName.toLowerCase().endsWith('.wav');

      // Stop current audio before loading new
      await _audioPlayer.stop();

      AudioWaveData loadedWave;
      if (isWav) {
        // Decode real frequency bands for WAV
        loadedWave = await WavDecoder.decodeWavFile(filePath);
      } else {
        // Generate simulated dynamic frequency bands for MP3/AAC
        // Set duration to a default 3 minutes (180,000 ms); it will resize when GStreamer/MediaPlayer triggers onDurationChanged
        loadedWave = AudioWaveData.generateSimulated(180000);
      }

      await _audioPlayer.setSource(DeviceFileSource(filePath));

      if (mounted) {
        setState(() {
          _waveData = loadedWave;
          _trackName = fileName;
          _isRealAnalysis = isWav;
          _position = Duration.zero;
          _isLoading = false;
        });
        
        // Auto play on select
        _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("Failed loading picked audio: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading audio file: $e")),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final activePreset = colorPresets[_selectedPresetIndex];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0xFF1E033A),
              Color(0xFF090014),
            ],
            center: Alignment.center,
            radius: 1.4,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.purpleAccent),
                    SizedBox(height: 20),
                    Text(
                      "Generating synth beat & analyzing audio data...",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      // Header Row
                      _buildHeader(),
                      const SizedBox(height: 16),

                      // Visualizer Main Frame
                      Expanded(
                        child: _buildVisualizerContainer(activePreset),
                      ),
                      const SizedBox(height: 20),

                      // Info Tag & Track Info
                      _buildTrackInfoCard(),
                      const SizedBox(height: 16),

                      // Timeline Progress Bar
                      _buildTimelineSlider(activePreset),
                      const SizedBox(height: 16),

                      // Controls Bar (Play/Pause, volume, presets, selector)
                      _buildControlsPanel(activePreset),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AETHER VISUALIZER",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.purpleAccent, blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Premium Generative Audio Dashboard",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _pickAndLoadAudio,
          icon: const Icon(Icons.library_music_rounded, size: 18),
          label: const Text(
            "LOAD AUDIO FILE",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualizerContainer(ColorPreset preset) {
    // Read the current audio data frame based on position
    final frame = _waveData.getFrameAt(_position.inMilliseconds);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: preset.primary.withValues(alpha: 0.03),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Draw visualizer matching chosen mode
            CustomPainter painter;
            switch (_currentMode) {
              case VisualizerMode.nebula:
                painter = NebulaPainter(
                  frame: frame,
                  animationTime: _animationController.value * 2 * pi * 4.0, // Scale phase for good speed
                  primaryColor: preset.primary,
                  secondaryColor: preset.secondary,
                );
                break;
              case VisualizerMode.horizon:
                painter = HorizonPainter(
                  frame: frame,
                  animationTime: _animationController.value * 2 * pi,
                  primaryColor: preset.primary,
                  secondaryColor: preset.secondary,
                );
                break;
              case VisualizerMode.vortex:
                painter = VortexPainter(
                  frame: frame,
                  animationTime: _animationController.value * 2 * pi * 2.0,
                  primaryColor: preset.primary,
                  secondaryColor: preset.secondary,
                );
                break;
            }

            return RepaintBoundary(
              child: CustomPaint(
                painter: painter,
                child: Container(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrackInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_isPlaying ? colorPresets[_selectedPresetIndex].primary : Colors.grey)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.music_note : Icons.music_off,
              color: _isPlaying ? colorPresets[_selectedPresetIndex].secondary : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isRealAnalysis
                      ? "Spectrum Analysis: Real-time WAV Filtering (Bass / Mid / Treble)"
                      : "Spectrum Analysis: Synthetic Audio-Frequency Modeling",
                  style: TextStyle(
                    fontSize: 11,
                    color: _isRealAnalysis ? Colors.cyan : Colors.amberAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSlider(ColorPreset preset) {
    double progress = 0.0;
    if (_duration.inMilliseconds > 0) {
      progress = _position.inMilliseconds / _duration.inMilliseconds;
    }
    progress = progress.clamp(0.0, 1.0);

    return Row(
      children: [
        Text(
          _formatDuration(_position),
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: preset.primary,
              inactiveTrackColor: Colors.white12,
              trackHeight: 4.0,
              thumbColor: preset.secondary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayColor: preset.secondary.withValues(alpha: 0.15),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            ),
            child: Slider(
              value: progress,
              onChanged: (val) {
                final targetMs = (val * _duration.inMilliseconds).toInt();
                _audioPlayer.seek(Duration(milliseconds: targetMs));
              },
            ),
          ),
        ),
        Text(
          _formatDuration(_duration),
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }

  Widget _buildControlsPanel(ColorPreset preset) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Playback controls (Play, Pause, Reset)
              Row(
                children: [
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [preset.primary, preset.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: preset.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    icon: const Icon(Icons.replay_rounded),
                    color: Colors.white60,
                    onPressed: () {
                      _audioPlayer.seek(Duration.zero);
                      _audioPlayer.resume();
                    },
                  ),
                ],
              ),

              // Volume Slider
              Row(
                children: [
                  Icon(
                    _volume == 0
                        ? Icons.volume_mute_rounded
                        : _volume < 0.4
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  SizedBox(
                    width: 100,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white10,
                        trackHeight: 3.0,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: (val) {
                          setState(() {
                            _volume = val;
                          });
                          _audioPlayer.setVolume(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Visualizer Style Switcher & Theme Presets
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Style Selector Segmented Control
              _buildVisualizerSelector(preset),

              // Theme Dot Pickers
              _buildThemePicker(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerSelector(ColorPreset preset) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: VisualizerMode.values.map((mode) {
          final isSelected = _currentMode == mode;
          String label;
          IconData icon;
          switch (mode) {
            case VisualizerMode.nebula:
              label = "Nebula";
              icon = Icons.blur_on_rounded;
              break;
            case VisualizerMode.horizon:
              label = "Horizon";
              icon = Icons.grid_view_rounded;
              break;
            case VisualizerMode.vortex:
              label = "Vortex";
              icon = Icons.donut_large_rounded;
              break;
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _currentMode = mode;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: preset.primary.withValues(alpha: 0.4))
                    : Border.all(color: Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? preset.secondary : Colors.white60,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemePicker() {
    return Row(
      children: List.generate(colorPresets.length, (index) {
        final preset = colorPresets[index];
        final isSelected = _selectedPresetIndex == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPresetIndex = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? preset.secondary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [preset.primary, preset.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
