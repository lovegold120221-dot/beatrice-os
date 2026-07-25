import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:beatrice/ui/core/theme.dart';

/// Full-screen voice overlay mirroring the root app's Live API UI:
/// animated background blobs, a status pill, a radar ping (listening),
/// a rotating playback ring (speaking), a PCM-driven microphone meter, live
/// transcription, and a microphone stop button.
class VoiceScreen extends StatefulWidget {
  final bool isLiveActive;
  final bool isSpeaking;
  final String liveTranscription;
  final double micInputLevel;
  final VoidCallback onStop;
  final bool isCameraActive;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final CameraController? cameraController;

  const VoiceScreen({
    super.key,
    required this.isLiveActive,
    required this.isSpeaking,
    required this.liveTranscription,
    required this.micInputLevel,
    required this.onStop,
    required this.isCameraActive,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.cameraController,
  });

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ping;
  late final AnimationController _ring;
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _ping = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ping.dispose();
    _ring.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speaking = widget.isSpeaking;
    final listening = widget.isLiveActive && !speaking;

    return Container(
      color: AppColors.black,
      child: Stack(
        children: [
          if (widget.isCameraActive &&
              widget.cameraController?.value.isInitialized == true)
            Positioned.fill(
              child: _buildCameraPreview(widget.cameraController!),
            ),
          // Animated background blobs.
          if (!widget.isCameraActive)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: MediaQuery.of(context).size.width * 0.25,
              child: AnimatedOpacity(
                opacity: speaking ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: Container(
                  width: 384,
                  height: 384,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x1A3B82F6), // blue-500/10
                  ),
                ),
              ),
            ),
          if (!widget.isCameraActive)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              right: MediaQuery.of(context).size.width * 0.25,
              child: AnimatedOpacity(
                opacity: listening ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: Container(
                  width: 384,
                  height: 384,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x1A10B981), // emerald-500/10
                  ),
                ),
              ),
            ),
          // Backdrop blur over blobs.
          if (!widget.isCameraActive)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: const SizedBox.shrink(),
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;
                return Column(
                  children: [
                    _buildStatusBar(speaking, listening, compact: compact),
                    if (widget.isCameraActive)
                      const Text(
                        'CAMERA ON · frames sent online only during this Live session',
                        style: TextStyle(color: AppColors.yellow, fontSize: 10),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: widget.isCameraActive
                                  ? (listening
                                        ? _buildCompactMicMeter()
                                        : const SizedBox.shrink())
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _buildVisualization(
                                        speaking,
                                        listening,
                                      ),
                                    ),
                            ),
                          ),
                          _buildTranscription(compact: compact),
                          _buildMicStop(compact: compact),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    final size = controller.value.previewSize;
    if (size == null) return const SizedBox.expand();
    return ColoredBox(
      color: AppColors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(
    bool speaking,
    bool listening, {
    required bool compact,
  }) {
    final Color dotColor;
    final String label;
    if (!widget.isLiveActive) {
      dotColor = AppColors.yellow;
      label = 'Connecting to Beatrice...';
    } else if (speaking) {
      dotColor = AppColors.blue;
      label = 'Beatrice is speaking';
    } else {
      dotColor = AppColors.emerald;
      label = 'Beatrice is listening';
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 12 : 24,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.8),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isCameraActive)
                IconButton(
                  onPressed: widget.onSwitchCamera,
                  tooltip: 'Switch front or back camera',
                  icon: const Icon(
                    Icons.cameraswitch_outlined,
                    color: AppColors.white,
                  ),
                ),
              IconButton(
                onPressed: widget.onToggleCamera,
                tooltip: widget.isCameraActive
                    ? 'Stop sharing camera'
                    : 'Share camera with Gemini Live',
                icon: Icon(
                  widget.isCameraActive
                      ? Icons.videocam
                      : Icons.videocam_outlined,
                  color: widget.isCameraActive
                      ? AppColors.yellow
                      : AppColors.white,
                ),
              ),
              GestureDetector(
                onTap: widget.onStop,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualization(bool speaking, bool listening) {
    return SizedBox(
      width: 256,
      height: 256,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar ping (listening).
          if (listening)
            AnimatedBuilder(
              animation: _ping,
              builder: (_, _) {
                final t = _ping.value;
                return Opacity(
                  opacity: (1 - t) * 0.3,
                  child: Transform.scale(
                    scale: 0.5 + t * 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x4D34D399),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Playback ring (speaking).
          if (speaking)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x333B82F6), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x333B82F6),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          if (speaking)
            AnimatedBuilder(
              animation: _ring,
              builder: (_, _) {
                return Transform.rotate(
                  angle: _ring.value * 2 * 3.1415926,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: const Border(
                        top: BorderSide(color: AppColors.blue, width: 2),
                        left: BorderSide(color: AppColors.blue, width: 2),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Five bars use measured microphone PCM while listening. Beatrice
          // output keeps a separate animated playback treatment.
          _buildWaveform(speaking, listening),
        ],
      ),
    );
  }

  Widget _buildWaveform(bool speaking, bool listening) {
    final inactive = !speaking && !listening;
    // Per-bar peak heights and colors, mirroring the root motion keyframes.
    const heights = [16.0, 64.0, 24.0, 80.0, 16.0];
    const colors = [
      AppColors.blue,
      AppColors.blueBg,
      AppColors.blue,
      AppColors.blueBg,
      AppColors.blue,
    ];
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (i) {
          return AnimatedBuilder(
            animation: _wave,
            builder: (_, _) {
              double h = 8;
              Color color = const Color(0xFF52525B);
              List<BoxShadow>? glow;
              if (speaking) {
                // Oscillate each bar between 30% and 100% of its peak.
                final phase = (_wave.value + i * 0.1) % 1.0;
                h = heights[i] * (0.3 + 0.7 * phase);
                color = colors[i];
                glow = [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.6),
                    blurRadius: 15,
                  ),
                ];
              } else if (listening) {
                const responseShape = [0.52, 0.78, 1.0, 0.72, 0.46];
                final input = widget.micInputLevel.clamp(0.0, 1.0);
                h = 8 + 76 * input * responseShape[i];
                color = AppColors.emerald;
                glow = [
                  BoxShadow(
                    color: AppColors.emerald.withValues(
                      alpha: 0.15 + input * 0.55,
                    ),
                    blurRadius: 6 + input * 12,
                  ),
                ];
              }
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: inactive ? 8 : h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: glow,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildCompactMicMeter() {
    const responseShape = [0.5, 0.78, 1.0, 0.72, 0.46];
    final input = widget.micInputLevel.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, size: 15, color: AppColors.emerald),
          const SizedBox(width: 8),
          for (var index = 0; index < responseShape.length; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              width: 4,
              height: 4 + 18 * input * responseShape[index],
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTranscription({required bool compact}) {
    final hasText = widget.liveTranscription.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        top: compact ? 8 : 20,
        left: compact ? 20 : 32,
        right: compact ? 20 : 32,
      ),
      child: SizedBox(
        height: compact ? 72 : 100,
        child: Center(
          child: hasText
              ? SingleChildScrollView(
                  child: Text(
                    '"${widget.liveTranscription.trim()}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                )
              : Text(
                  widget.isLiveActive
                      ? 'Start speaking...'
                      : 'Establishing connection...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMicStop({required bool compact}) {
    return Padding(
      padding: EdgeInsets.only(
        top: compact ? 12 : 20,
        bottom: compact ? 12 : 24,
      ),
      child: Semantics(
        button: true,
        label: 'Stop Live Voice microphone',
        child: GestureDetector(
          onTap: widget.onStop,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.5),
                  blurRadius: 30,
                ),
              ],
            ),
            child: const Icon(Icons.mic_off, color: AppColors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
