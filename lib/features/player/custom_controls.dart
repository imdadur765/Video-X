import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_x/core/utils/format_utils.dart';
import 'package:video_x/features/player/gesture_overlay.dart';

// Video X Colors
const Color vxPrimary = Color(0xFF8B5CF6);
const Color vxSecondary = Color(0xFFEC4899);

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

class _CustomControlsState extends State<CustomControls> with TickerProviderStateMixin {
  bool _visible = true;
  bool _locked = false;
  bool _expanded = false; // Second row expanded
  Timer? _hideTimer;

  // Feature states
  double _playbackSpeed = 1.0;
  Timer? _sleepTimer;
  int _sleepMinutes = 0;
  bool _nightMode = false;
  bool _mirrored = false;
  bool _isMuted = false;
  bool _backgroundPlay = false;
  int _repeatMode = 0; // 0=off, 1=one, 2=all

  // AB Repeat
  Duration? _pointA;
  Duration? _pointB;
  bool _abRepeatActive = false;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Player get player => widget.state.widget.controller.player;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
    _startHideTimer();
    _setupABRepeat();
  }

  void _setupABRepeat() {
    player.stream.position.listen((pos) {
      if (_abRepeatActive && _pointA != null && _pointB != null) {
        if (pos >= _pointB!) {
          player.seek(_pointA!);
        }
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sleepTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_expanded) {
        _fadeController.reverse().then((_) {
          if (mounted) setState(() => _visible = false);
        });
      }
    });
  }

  void _toggleVisibility() {
    if (_visible) {
      _fadeController.reverse().then((_) {
        if (mounted)
          setState(() {
            _visible = false;
            _expanded = false;
          });
      });
    } else {
      setState(() => _visible = true);
      _fadeController.forward();
      _startHideTimer();
    }
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

  void _toggleExpand() => setState(() {
    _expanded = !_expanded;
    if (_expanded)
      _hideTimer?.cancel();
    else
      _startHideTimer();
  });

  // Night Mode
  void _toggleNightMode() {
    setState(() => _nightMode = !_nightMode);
    _showSnack(_nightMode ? 'Night mode ON' : 'Night mode OFF');
  }

  // Mirror
  void _toggleMirror() {
    setState(() => _mirrored = !_mirrored);
    _showSnack(_mirrored ? 'Mirrored' : 'Normal');
  }

  // Mute
  void _toggleMute() {
    _isMuted = !_isMuted;
    player.setVolume(_isMuted ? 0 : 100);
    setState(() {});
  }

  // Background Play
  void _toggleBackgroundPlay() {
    setState(() => _backgroundPlay = !_backgroundPlay);
    _showSnack(_backgroundPlay ? 'Background play enabled' : 'Background play disabled');
  }

  // Repeat Mode
  void _cycleRepeatMode() {
    setState(() {
      _repeatMode = (_repeatMode + 1) % 3;
    });
    String msg = ['Repeat Off', 'Repeat One', 'Repeat All'][_repeatMode];
    _showSnack(msg);
  }

  // AB Repeat
  void _handleABRepeat() {
    if (_pointA == null) {
      setState(() => _pointA = player.state.position);
      _showSnack('Point A set at ${FormatUtils.formatDuration(_pointA!.inSeconds)}');
    } else if (_pointB == null) {
      setState(() {
        _pointB = player.state.position;
        _abRepeatActive = true;
      });
      _showSnack('Point B set. A-B repeat active!');
    } else {
      setState(() {
        _pointA = null;
        _pointB = null;
        _abRepeatActive = false;
      });
      _showSnack('A-B repeat cleared');
    }
  }

  // Rotate to landscape
  void _toggleLandscape() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  // Popup Player
  void _showPopupPlayer() {
    _showSnack('Popup player coming soon');
  }

  // Equalizer
  void _showEqualizer() {
    _showSnack('Equalizer coming soon');
  }

  // Sleep Timer
  void _showSleepTimer() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _buildBottomSheet('Sleep Timer', Icons.bedtime, [
        ...[5, 10, 15, 30, 45, 60].map(
          (mins) => _buildSheetItem(
            '$mins minutes',
            _sleepMinutes == mins ? Icons.check_circle : Icons.timer_outlined,
            _sleepMinutes == mins,
            () {
              _sleepTimer?.cancel();
              setState(() => _sleepMinutes = mins);
              _sleepTimer = Timer(Duration(minutes: mins), () {
                player.pause();
                if (mounted) setState(() => _sleepMinutes = 0);
              });
              Navigator.pop(context);
            },
          ),
        ),
        if (_sleepMinutes > 0)
          _buildSheetItem('Cancel Timer', Icons.cancel, false, () {
            _sleepTimer?.cancel();
            setState(() => _sleepMinutes = 0);
            Navigator.pop(context);
          }, isDestructive: true),
      ]),
    );
  }

  // Speed Selector
  void _showSpeedSelector() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _buildBottomSheet('Playback Speed', Icons.speed, [
        ...[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map(
          (speed) => _buildSheetItem(
            '${speed}x',
            _playbackSpeed == speed ? Icons.check_circle : Icons.circle_outlined,
            _playbackSpeed == speed,
            () {
              setState(() => _playbackSpeed = speed);
              player.setRate(speed);
              Navigator.pop(context);
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildBottomSheet(String title, IconData icon, List<Widget> children) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: vxPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSheetItem(String title, IconData icon, bool isActive, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : (isActive ? vxPrimary : Colors.grey)),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Night mode overlay
    Widget content = _buildContent();
    if (_nightMode) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.matrix([0.9, 0, 0, 0, 0, 0, 0.7, 0, 0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 1, 0]),
        child: content,
      );
    }

    // Mirror
    if (_mirrored) {
      content = Transform.flip(flipX: true, child: content);
    }

    return content;
  }

  Widget _buildContent() {
    if (_locked) {
      return GestureDetector(
        onTap: _toggleVisibility,
        child: Container(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(padding: const EdgeInsets.all(24), child: _buildGlassButton(Icons.lock_open, _toggleLock)),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureOverlay(onTap: _toggleVisibility, onDoubleTap: player.playOrPause),
        if (_visible)
          FadeTransition(
            opacity: _fadeAnimation,
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
                  stops: const [0.0, 0.2, 0.7, 1.0],
                ),
              ),
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildSecondRow(),
                  const Spacer(),
                  _buildSeekBar(),
                  _buildBottomControls(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [vxPrimary.withValues(alpha: 0.3), vxSecondary.withValues(alpha: 0.3)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            _buildIconBtn(Icons.arrow_back, () => Navigator.pop(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildIconBtn(Icons.hd_outlined, () {}),
            _buildIconBtn(Icons.closed_caption_outlined, () => _showSnack('Subtitles coming soon')),
            _buildIconBtn(Icons.playlist_play, () => _showSnack('Playlist coming soon')),
            _buildIconBtn(Icons.more_vert, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // Expandable Second Row
  Widget _buildSecondRow() {
    final row1 = [
      _ControlItem(Icons.nights_stay, 'Night', _nightMode, _toggleNightMode),
      _ControlItem(
        Icons.repeat,
        'Repeat',
        _repeatMode > 0,
        _cycleRepeatMode,
        badge: _repeatMode == 1 ? '1' : (_repeatMode == 2 ? 'A' : null),
      ),
      _ControlItem(Icons.picture_in_picture, 'Popup', false, _showPopupPlayer),
      _ControlItem(Icons.equalizer, 'EQ', false, _showEqualizer),
      _ControlItem(Icons.flip, 'Mirror', _mirrored, _toggleMirror),
    ];

    final row2 = [
      _ControlItem(Icons.screen_rotation, 'Rotate', false, _toggleLandscape),
      _ControlItem(Icons.lock_outline, 'Lock', _locked, _toggleLock),
      _ControlItem(Icons.volume_off, 'Mute', _isMuted, _toggleMute),
      _ControlItem(Icons.play_circle_outline, 'BG Play', _backgroundPlay, _toggleBackgroundPlay),
      _ControlItem(Icons.speed, '${_playbackSpeed}x', _playbackSpeed != 1.0, _showSpeedSelector),
    ];

    final row3 = [
      _ControlItem(
        Icons.compare_arrows,
        'A-B',
        _abRepeatActive,
        _handleABRepeat,
        badge: _pointA != null && _pointB == null ? 'A' : null,
      ),
      _ControlItem(
        Icons.bedtime,
        'Sleep',
        _sleepMinutes > 0,
        _showSleepTimer,
        badge: _sleepMinutes > 0 ? '${_sleepMinutes}m' : null,
      ),
    ];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              ...row1.map((item) => _buildControlChip(item)),
              GestureDetector(
                onTap: _toggleExpand,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(
                  children: [
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(children: row2.map((item) => _buildControlChip(item)).toList()),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(children: row3.map((item) => _buildControlChip(item)).toList()),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildControlChip(_ControlItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: item.isActive ? const LinearGradient(colors: [vxPrimary, vxSecondary]) : null,
          color: !item.isActive ? Colors.white.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: item.isActive ? Colors.transparent : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(item.icon, color: Colors.white, size: 18),
                if (item.badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(item.badge!, style: const TextStyle(color: Colors.white, fontSize: 8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        builder: (context, snapshot) {
          final pos = snapshot.data ?? Duration.zero;
          final dur = player.state.duration;
          final maxDur = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
          return Column(
            children: [
              Row(
                children: [
                  Text(
                    FormatUtils.formatDuration(pos.inSeconds),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  if (_abRepeatActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [vxPrimary, vxSecondary]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'A-B',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (_sleepMinutes > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [vxPrimary, vxSecondary]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_sleepMinutes}m', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  const Spacer(),
                  Text(
                    FormatUtils.formatDuration(dur.inSeconds),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  activeTrackColor: vxPrimary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: pos.inSeconds.toDouble().clamp(0, maxDur),
                  max: maxDur,
                  onChanged: (v) {
                    _startHideTimer();
                    player.seek(Duration(seconds: v.toInt()));
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlBtn(Icons.lock_outline, _toggleLock),
          _buildControlBtn(Icons.replay_10, _skip10Backward, size: 30),
          _buildControlBtn(
            Icons.skip_previous,
            widget.onSkipPrevious,
            size: 34,
            enabled: widget.onSkipPrevious != null,
          ),
          _buildPlayPauseBtn(),
          _buildControlBtn(Icons.skip_next, widget.onSkipNext, size: 34, enabled: widget.onSkipNext != null),
          _buildControlBtn(Icons.forward_10, _skip10Forward, size: 30),
          _buildControlBtn(
            widget.currentFit == BoxFit.contain ? Icons.fullscreen : Icons.fullscreen_exit,
            widget.onAspectRatioToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseBtn() {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        return GestureDetector(
          onTap: player.playOrPause,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [vxPrimary, vxSecondary]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: vxPrimary.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
          ),
        );
      },
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback? onTap, {double size = 26, bool enabled = true}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: size),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1a1a2e),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _ControlItem {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  _ControlItem(this.icon, this.label, this.isActive, this.onTap, {this.badge});
}
