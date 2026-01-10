import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_x/core/utils/format_utils.dart';
import 'package:video_x/features/player/gesture_overlay.dart';

// Video X Custom Colors
class VXColors {
  static const primary = Color(0xFF8B5CF6); // Violet
  static const secondary = Color(0xFFEC4899); // Pink
  static const accent = Color(0xFF06B6D4); // Cyan
  static const surface = Color(0xFF1E1B2E); // Dark purple
  static const glassBg = Color(0x40000000); // Glass effect
}

enum RepeatMode { off, one, all }

class CustomControls extends StatefulWidget {
  final VideoState state;
  final String title;
  final VoidCallback onAspectRatioToggle;
  final BoxFit currentFit;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;

  const CustomControls({
    super.key,
    required this.state,
    required this.title,
    required this.onAspectRatioToggle,
    required this.currentFit,
    this.onSkipNext,
    this.onSkipPrevious,
  });

  @override
  State<CustomControls> createState() => _CustomControlsState();
}

class _CustomControlsState extends State<CustomControls> with SingleTickerProviderStateMixin {
  bool _visible = true;
  bool _locked = false;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  final RepeatMode _repeatMode = RepeatMode.off;
  Timer? _sleepTimer;
  int _sleepMinutes = 0;

  Player get player => widget.state.widget.controller.player;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _setupRepeatListener();
  }

  void _setupRepeatListener() {
    player.stream.completed.listen((completed) {
      if (completed && _repeatMode == RepeatMode.one) {
        player.seek(Duration.zero);
        player.play();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _toggleVisibility() {
    setState(() => _visible = !_visible);
    if (_visible) _startHideTimer();
  }

  void _skip10Forward() {
    player.seek(player.state.position + const Duration(seconds: 10));
    _startHideTimer();
  }

  void _skip10Backward() {
    final pos = player.state.position - const Duration(seconds: 10);
    player.seek(pos < Duration.zero ? Duration.zero : pos);
    _startHideTimer();
  }

  void _toggleLock() => setState(() {
    _locked = !_locked;
    _startHideTimer();
  });

  void _showSpeedSelector() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Playback Speed',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map(
              (speed) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: speed == _playbackSpeed
                        ? const LinearGradient(colors: [VXColors.primary, VXColors.secondary])
                        : null,
                    color: speed != _playbackSpeed ? Colors.white12 : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.speed, color: Colors.white, size: 18),
                ),
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: speed == _playbackSpeed ? VXColors.primary : Colors.white,
                    fontWeight: speed == _playbackSpeed ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _playbackSpeed = speed);
                  player.setRate(speed);
                  Navigator.pop(context);
                  _startHideTimer();
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showSleepTimer() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.bedtime, color: VXColors.accent),
                  SizedBox(width: 8),
                  Text(
                    'Sleep Timer',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ...([5, 10, 15, 30, 45, 60].map(
              (mins) => ListTile(
                leading: Icon(
                  _sleepMinutes == mins ? Icons.check_circle : Icons.timer_outlined,
                  color: _sleepMinutes == mins ? VXColors.accent : Colors.white54,
                ),
                title: Text('$mins minutes', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  _sleepTimer?.cancel();
                  setState(() => _sleepMinutes = mins);
                  _sleepTimer = Timer(Duration(minutes: mins), () {
                    player.pause();
                    if (mounted) setState(() => _sleepMinutes = 0);
                  });
                  Navigator.pop(context);
                  _startHideTimer();
                },
              ),
            )),
            if (_sleepMinutes > 0)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                title: const Text('Cancel Timer', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  _sleepTimer?.cancel();
                  setState(() => _sleepMinutes = 0);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSheet({required Widget child}) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: VXColors.surface.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: VXColors.primary.withValues(alpha: 0.3)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Locked mode
    if (_locked) {
      return GestureDetector(
        onTap: _toggleVisibility,
        child: Container(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildGlassButton(Icons.lock_open, _toggleLock, label: 'Unlock'),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureOverlay(onTap: _toggleVisibility, onDoubleTap: player.playOrPause),
        AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !_visible,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.25, 0.7, 1.0],
                ),
              ),
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildSecondRow(),
                  const Spacer(),
                  _buildSeekBar(),
                  const SizedBox(height: 12),
                  _buildBottomControls(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Top Bar with gradient accent
  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            _buildCircleBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildCircleBtn(Icons.high_quality_outlined, () {}),
            _buildCircleBtn(Icons.subtitles_outlined, () => _showSnack('Subtitles coming soon')),
            _buildCircleBtn(Icons.queue_music, () => _showSnack('Playlist coming soon')),
            _buildCircleBtn(Icons.more_horiz, () {}),
          ],
        ),
      ),
    );
  }

  // Second Row with pill buttons
  Widget _buildSecondRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPillBtn(Icons.picture_in_picture_alt_rounded, 'PIP', () => _showSnack('PIP coming soon')),
            const SizedBox(width: 8),
            StreamBuilder<double>(
              stream: player.stream.volume,
              builder: (context, snapshot) {
                final vol = snapshot.data ?? 100;
                return _buildPillBtn(
                  vol == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  vol == 0 ? 'Muted' : 'Sound',
                  () => player.setVolume(vol == 0 ? 100 : 0),
                  isActive: vol == 0,
                );
              },
            ),
            const SizedBox(width: 8),
            _buildPillBtn(Icons.headphones_rounded, 'Audio', () => _showSnack('Audio tracks coming soon')),
            const SizedBox(width: 8),
            _buildSpeedPill(),
            const SizedBox(width: 8),
            _buildPillBtn(
              Icons.bedtime_rounded,
              _sleepMinutes > 0 ? '${_sleepMinutes}m' : 'Sleep',
              _showSleepTimer,
              isActive: _sleepMinutes > 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedPill() {
    return GestureDetector(
      onTap: _showSpeedSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: _playbackSpeed != 1.0 ? const LinearGradient(colors: [VXColors.primary, VXColors.secondary]) : null,
          color: _playbackSpeed == 1.0 ? Colors.white.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              '${_playbackSpeed}x',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBtn(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive ? const LinearGradient(colors: [VXColors.primary, VXColors.secondary]) : null,
          color: !isActive ? Colors.white.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.transparent : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // Custom Seekbar with gradient thumb
  Widget _buildSeekBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        builder: (context, snapshot) {
          final pos = snapshot.data ?? Duration.zero;
          final dur = player.state.duration;
          final maxDur = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
          final progress = pos.inSeconds / (maxDur > 0 ? maxDur : 1);

          return Column(
            children: [
              // Custom progress bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          width: constraints.maxWidth * progress.clamp(0, 1),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [VXColors.primary, VXColors.secondary, VXColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Thumb
                        Positioned(
                          left: (constraints.maxWidth * progress.clamp(0, 1)) - 8,
                          top: -5,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              final newPos = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                              player.seek(Duration(seconds: (newPos * maxDur).toInt()));
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [VXColors.primary, VXColors.accent]),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: VXColors.primary.withValues(alpha: 0.5), blurRadius: 8)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    FormatUtils.formatDuration(pos.inSeconds),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                  Text(
                    FormatUtils.formatDuration(dur.inSeconds),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // Bottom Controls with gradient play button
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlBtn(Icons.lock_outline, _toggleLock),
          _buildControlBtn(Icons.replay_10_rounded, _skip10Backward, size: 30),
          _buildControlBtn(
            Icons.skip_previous_rounded,
            widget.onSkipPrevious,
            size: 32,
            enabled: widget.onSkipPrevious != null,
          ),
          // Gradient Play Button
          StreamBuilder<bool>(
            stream: player.stream.playing,
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;
              return GestureDetector(
                onTap: player.playOrPause,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [VXColors.primary, VXColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: VXColors.primary.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                ),
              );
            },
          ),
          _buildControlBtn(Icons.skip_next_rounded, widget.onSkipNext, size: 32, enabled: widget.onSkipNext != null),
          _buildControlBtn(Icons.forward_10_rounded, _skip10Forward, size: 30),
          _buildControlBtn(
            widget.currentFit == BoxFit.contain ? Icons.fullscreen_rounded : Icons.fullscreen_exit_rounded,
            widget.onAspectRatioToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback? onTap, {double size = 26, bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: size),
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap, {String? label}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VXColors.primary.withValues(alpha: 0.3), VXColors.secondary.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: VXColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
