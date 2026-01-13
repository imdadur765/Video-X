import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_x/core/utils/format_utils.dart';
import 'package:video_x/features/player/gesture_overlay.dart';

// Video X Colors
const Color vxPrimary = Color(0xFF2962FF); // Royal Blue to match Home Screen
const Color vxSecondary = Color(0xFF82B1FF); // Light Blue Accent

enum PlayerOverlay { none, equalizer, sleep, speed }

class CustomControls extends StatefulWidget {
  final VideoState state;
  final String title;
  final VoidCallback onAspectRatioToggle;
  final BoxFit currentFit;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;
  final bool isMirrored;
  final VoidCallback onMirrorToggle;
  final bool isNightMode;
  final VoidCallback onNightModeToggle;
  final bool isBgPlayEnabled;
  final ValueChanged<bool>? onBgPlayToggle;

  const CustomControls({
    super.key,
    required this.state,
    required this.title,
    required this.onAspectRatioToggle,
    required this.currentFit,
    this.onSkipNext,
    this.onSkipPrevious,
    required this.isMirrored,
    required this.onMirrorToggle,
    required this.isNightMode,
    required this.onNightModeToggle,
    this.isBgPlayEnabled = false,
    this.onBgPlayToggle,
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
  bool _isMuted = false;
  bool _backgroundPlay = false;
  int _repeatMode = 0; // 0=off, 1=one, 2=all

  // AB Repeat
  Duration? _pointA;
  Duration? _pointB;
  bool _abRepeatActive = false;

  // Equalizer states (gains in dB)
  final List<double> _equalizerGains = [0, 0, 0, 0, 0];
  final List<double> _frequencies = [60, 230, 910, 3600, 14000];

  PlayerOverlay _activeOverlay = PlayerOverlay.none;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Player get player => widget.state.widget.controller.player;

  @override
  void initState() {
    super.initState();
    _backgroundPlay = widget.isBgPlayEnabled;
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
    _startHideTimer();
    _setupABRepeat();

    // Listen for PiP actions
    platform.setMethodCallHandler((call) async {
      if (call.method == 'playPause') {
        player.playOrPause();
      }
    });

    // Sync PiP state
    player.stream.playing.listen((playing) {
      if (mounted) {
        // Ideally should check if in PiP, but simple sync is fine
        platform.invokeMethod('updatePipState', {'playing': playing});
      }
    });
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
    final willBeNight = !widget.isNightMode;
    widget.onNightModeToggle();
    _showSnack(willBeNight ? 'Night mode ON' : 'Night mode OFF');
  }

  // Mirror
  void _toggleMirror() {
    final willBeMirrored = !widget.isMirrored;
    widget.onMirrorToggle();
    _showSnack(willBeMirrored ? 'Mirrored' : 'Normal');
  }

  // Mute
  void _toggleMute() {
    _isMuted = !_isMuted;
    player.setVolume(_isMuted ? 0 : 100);
    setState(() {});
  }

  // Background Play
  void _toggleBackgroundPlay() {
    final newValue = !_backgroundPlay;
    print("CustomControls: Toggling BG Play to $newValue");
    setState(() => _backgroundPlay = newValue);
    widget.onBgPlayToggle?.call(newValue);
    _showSnack(newValue ? 'Background play enabled' : 'Background play disabled');
  }

  // Repeat Mode
  void _cycleRepeatMode() {
    setState(() {
      _repeatMode = (_repeatMode + 1) % 3;
    });

    switch (_repeatMode) {
      case 0:
        player.setPlaylistMode(PlaylistMode.none);
        _showSnack('Repeat Off');
        break;
      case 1:
        player.setPlaylistMode(PlaylistMode.single);
        _showSnack('Repeat One');
        break;
      case 2:
        player.setPlaylistMode(PlaylistMode.loop);
        _showSnack('Repeat All');
        break;
    }
  }

  // AB Repeat
  void _handleABRepeat() {
    if (_pointA == null) {
      setState(() => _pointA = player.state.position);
      _showSnack('Point A set at ${FormatUtils.formatDuration(_pointA!.inSeconds)}', icon: Icons.location_on_rounded);
    } else if (_pointB == null) {
      setState(() {
        _pointB = player.state.position;
        _abRepeatActive = true;
      });
      _showSnack('Point B set. A-B repeat active!', icon: Icons.loop_rounded);
    } else {
      setState(() {
        _pointA = null;
        _pointB = null;
        _abRepeatActive = false;
      });
      _showSnack('A-B repeat cleared', icon: Icons.playlist_remove_rounded);
    }
  }

  // Equalizer Logic
  void _updateEqualizer() {
    // ffmpeg equalizer filter: equalizer=f=FREQ:width_type=o:w=1:g=GAIN
    final filterString = _frequencies
        .asMap()
        .entries
        .map((e) {
          return 'equalizer=f=${e.value.toInt()}:width_type=o:w=1:g=${_equalizerGains[e.key].toInt()}';
        })
        .join(',');

    try {
      // Use dynamic to access setProperty which is available on NativePlayer
      (player.platform as dynamic).setProperty("af", filterString);
    } catch (e) {
      debugPrint('Error setting equalizer: $e');
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

  // MethodChannel for native PiP
  static const platform = MethodChannel('com.example.video_x/pip');

  // Popup Player
  Future<void> _showPopupPlayer() async {
    try {
      await platform.invokeMethod('enterPictureInPicture');
    } catch (e) {
      debugPrint('Error entering PiP: $e');
      _showSnack('PiP failed or not supported', icon: Icons.error_outline_rounded);
    }
  }

  // Equalizer
  void _showEqualizer() {
    setState(() {
      _activeOverlay = _activeOverlay == PlayerOverlay.equalizer ? PlayerOverlay.none : PlayerOverlay.equalizer;
      if (_activeOverlay != PlayerOverlay.none) _visible = true;
    });
  }

  // Sleep Timer
  void _showSleepTimer() {
    setState(() {
      _activeOverlay = _activeOverlay == PlayerOverlay.sleep ? PlayerOverlay.none : PlayerOverlay.sleep;
      if (_activeOverlay != PlayerOverlay.none) _visible = true;
    });
  }

  // Speed Selector
  void _showSpeedSelector() {
    setState(() {
      _activeOverlay = _activeOverlay == PlayerOverlay.speed ? PlayerOverlay.none : PlayerOverlay.speed;
      if (_activeOverlay != PlayerOverlay.none) _visible = true;
    });
  }

  Widget _buildActiveOverlay() {
    switch (_activeOverlay) {
      case PlayerOverlay.equalizer:
        return _buildFeatureOverlay('Equalizer', Icons.equalizer_rounded, _buildEqualizerOverlay());
      case PlayerOverlay.sleep:
        return _buildFeatureOverlay('Sleep Timer', Icons.bedtime, _buildSleepOverlay());
      case PlayerOverlay.speed:
        return _buildFeatureOverlay('Playback Speed', Icons.speed, _buildSpeedOverlay());
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFeatureOverlay(String title, IconData icon, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double vPadding = constraints.maxHeight < 400 ? 12 : 20;
        final double hPadding = constraints.maxWidth < 600 ? 16 : 24;

        return GestureDetector(
          onTap: () => setState(() => _activeOverlay = PlayerOverlay.none),
          behavior: HitTestBehavior.opaque,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.35, 0.65, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.92), // solid base
                      Colors.black.withOpacity(0.75), // lift start
                      vxPrimary.withOpacity(0.35), // smooth blue merge
                      vxPrimary.withOpacity(0.65), // subtle blue glow
                    ],
                  ),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // Prevent dismissal when tapping the content
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
                      padding: EdgeInsets.all(vPadding),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.6, 1.0],
                          colors: [
                            Colors.black.withOpacity(0.9),
                            Colors.black.withOpacity(0.6),
                            vxPrimary.withOpacity(0.15),
                          ],
                        ),

                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, offset: const Offset(0, 20)),
                        ],
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(icon, color: vxPrimary),
                                const SizedBox(width: 12),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                                  onPressed: () => setState(() => _activeOverlay = PlayerOverlay.none),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 32),
                            Flexible(
                              child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: child),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEqualizerOverlay() {
    final Map<String, List<double>> presets = {
      'Normal': [0, 0, 0, 0, 0],
      'Rock': [4, 3, -1, 2, 4],
      'Jazz': [3, 2, 1, 2, 3],
      'Pop': [-1, 2, 4, 3, -1],
      'Electronic': [4, 2, 0, 2, 4],
      'Classical': [3, 2, 0, 2, -2],
    };

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: presets.keys.map((p) {
              final isSelected = presets[p]!.asMap().entries.every((e) => _equalizerGains[e.key] == e.value);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    for (int i = 0; i < _equalizerGains.length; i++) {
                      _equalizerGains[i] = presets[p]![i];
                    }
                  });
                  _updateEqualizer();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? vxPrimary : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_equalizerGains.length, (index) {
            return Column(
              children: [
                Text(
                  '${_equalizerGains[index].toInt()}dB',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: vxPrimary,
                        inactiveTrackColor: Colors.white10,
                      ),
                      child: Slider(
                        value: _equalizerGains[index],
                        min: -10,
                        max: 10,
                        onChanged: (val) {
                          setState(() => _equalizerGains[index] = val);
                          _updateEqualizer();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _frequencies[index] >= 1000
                      ? '${(_frequencies[index] / 1000).toStringAsFixed(1)}k'
                      : '${_frequencies[index].toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSleepOverlay() {
    return SingleChildScrollView(
      child: Column(
        children: [
          ...[5, 10, 15, 30, 45, 60].map(
            (mins) => _buildOverlayItem(
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
                setState(() => _activeOverlay = PlayerOverlay.none);
              },
            ),
          ),
          if (_sleepMinutes > 0)
            _buildOverlayItem('Cancel Timer', Icons.cancel, false, () {
              _sleepTimer?.cancel();
              setState(() => _sleepMinutes = 0);
              setState(() => _activeOverlay = PlayerOverlay.none);
            }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildSpeedOverlay() {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
            .map(
              (speed) => GestureDetector(
                onTap: () {
                  setState(() => _playbackSpeed = speed);
                  player.setRate(speed);
                  setState(() => _activeOverlay = PlayerOverlay.none);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _playbackSpeed == speed ? vxPrimary : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _playbackSpeed == speed ? Colors.white24 : Colors.transparent),
                  ),
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: _playbackSpeed == speed ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildOverlayItem(
    String title,
    IconData icon,
    bool isActive,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : (isActive ? vxPrimary : Colors.grey)),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    // Hide controls if screen is too small (likely PiP)
    if (MediaQuery.of(context).size.width < 300) {
      return const SizedBox.shrink();
    }

    if (_locked) {
      return GestureDetector(
        onTap: _toggleVisibility,
        child: Container(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Align(alignment: Alignment.center, child: _buildLockOverlay()),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureOverlay(
          onTap: _toggleVisibility,
          onDoubleTapSeek: (forward) => forward ? _skip10Forward() : _skip10Backward(),
          onDoubleTapCenter: player.playOrPause,
        ),
        if (_visible)
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _toggleVisibility,
              behavior: HitTestBehavior.opaque,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.25, 0.7, 1.0],
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: _expanded ? 600 : (constraints.maxHeight < 450 ? 450 : constraints.maxHeight),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTopBar(),
                            const SizedBox(height: 12),
                            _buildSecondRow(),
                            const Spacer(),
                            // Orientation specific controls
                            if (constraints.maxHeight > constraints.maxWidth)
                              _buildPortraitControls()
                            else
                              _buildLandscapeControls(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        _buildActiveOverlay(),
      ],
    );
  }

  Widget _buildLockOverlay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: const Icon(Icons.lock_outline, color: Colors.white, size: 40),
        onPressed: _toggleLock,
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            _buildIconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_sleepMinutes > 0)
                    Row(
                      children: [
                        const Icon(Icons.timer_rounded, color: vxSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Sleep in ${_sleepMinutes}m',
                          style: const TextStyle(color: vxSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            _buildIconBtn(Icons.high_quality, () {}),
            _buildIconBtn(Icons.closed_caption, () => _showSnack('Subtitles coming soon')),
            _buildIconBtn(Icons.playlist_play_rounded, () => _showSnack('Playlist coming soon')),
            _buildIconBtn(Icons.more_horiz, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap, {double size = 26}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8), // Reduced from 10
          child: Icon(
            icon,
            color: Colors.white,
            size: size,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
          ),
        ),
      ),
    );
  }

  // Horizontal Sliding Second Row
  Widget _buildSecondRow() {
    final allItems = [
      _ControlItem(Icons.nights_stay_rounded, 'Night', widget.isNightMode, _toggleNightMode),
      _ControlItem(
        Icons.repeat_rounded,
        'Repeat',
        _repeatMode > 0,
        _cycleRepeatMode,
        badge: _repeatMode == 1 ? '1' : (_repeatMode == 2 ? 'A' : null),
      ),
      _ControlItem(Icons.picture_in_picture_rounded, 'Popup', false, _showPopupPlayer),
      _ControlItem(Icons.equalizer_rounded, 'EQ', false, _showEqualizer),
      _ControlItem(Icons.flip_rounded, 'Mirror', widget.isMirrored, _toggleMirror),
      _ControlItem(Icons.volume_off_rounded, 'Mute', _isMuted, _toggleMute),
      _ControlItem(Icons.play_circle_fill_rounded, 'BG Play', _backgroundPlay, _toggleBackgroundPlay),
      _ControlItem(Icons.speed_rounded, '${_playbackSpeed}x', _playbackSpeed != 1.0, _showSpeedSelector),
      _ControlItem(
        Icons.compare_arrows_rounded,
        'A-B',
        _abRepeatActive,
        _handleABRepeat,
        badge: _pointA != null && _pointB == null ? 'A' : null,
      ),
      _ControlItem(
        Icons.timer_rounded,
        'Sleep',
        _sleepMinutes > 0,
        _showSleepTimer,
        badge: _sleepMinutes > 0 ? '${_sleepMinutes}m' : null,
      ),
    ];

    // Split into initial and extra items
    final initialItems = allItems.take(3).toList();
    final extraItems = allItems.skip(3).toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ...initialItems.map((item) => _buildControlChip(item)),
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                child: _expanded
                    ? Row(children: extraItems.map((item) => _buildControlChip(item)).toList())
                    : const SizedBox.shrink(),
              ),
              _buildExpandToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandToggle() {
    return GestureDetector(
      onTap: _toggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _expanded ? vxPrimary.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _expanded ? vxPrimary.withOpacity(0.5) : Colors.white12),
        ),
        child: AnimatedRotation(
          turns: _expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          child: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
            size: 18,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
          ),
        ),
      ),
    );
  }

  Widget _buildControlChip(_ControlItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: item.isActive ? const LinearGradient(colors: [vxPrimary, vxSecondary]) : null,
          color: !item.isActive ? Colors.black.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.isActive ? Colors.white24 : Colors.white10, width: 1.5),
          boxShadow: item.isActive
              ? [BoxShadow(color: vxPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  color: Colors.white,
                  size: 20,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                ),
                if (item.badge != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced from 20
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                  const Spacer(),
                  if (_abRepeatActive || _sleepMinutes > 0)
                    Row(
                      children: [
                        if (_abRepeatActive) _buildMiniBadge('A-B'),
                        if (_sleepMinutes > 0) ...[const SizedBox(width: 8), _buildMiniBadge('${_sleepMinutes}m')],
                      ],
                    ),
                  const Spacer(),
                  Text(
                    FormatUtils.formatDuration(dur.inSeconds),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, pressedElevation: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: vxPrimary,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.white,
                  trackShape: const RoundedRectSliderTrackShape(),
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

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [vxPrimary, vxSecondary]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
    );
  }

  Widget _buildLandscapeControls() {
    return Column(children: [_buildSeekBar(), _buildBottomControls()]);
  }

  Widget _buildPortraitControls() {
    return Column(
      children: [
        _buildSeekBar(),
        const SizedBox(height: 16),
        // Row for Lock and Rotate/Fullscreen
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconBtn(Icons.screen_lock_rotation, _toggleLock, size: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconBtn(Icons.screen_rotation_rounded, _toggleLandscape, size: 28),
                  _buildIconBtn(
                    widget.currentFit == BoxFit.contain ? Icons.fullscreen_rounded : Icons.fullscreen_exit_rounded,
                    widget.onAspectRatioToggle,
                    size: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Centralized Playback Controls
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconBtn(Icons.skip_previous_rounded, widget.onSkipPrevious ?? () {}, size: 40),
              _buildIconBtn(Icons.replay_10_rounded, _skip10Backward, size: 36),
              const SizedBox(width: 16),
              _buildPlayPauseBtn(),
              const SizedBox(width: 16),
              _buildIconBtn(Icons.forward_10_rounded, _skip10Forward, size: 36),
              _buildIconBtn(Icons.skip_next_rounded, widget.onSkipNext ?? () {}, size: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left Side: Portrait Lock
          _buildIconBtn(Icons.screen_lock_rotation, _toggleLock, size: 22),
          const Spacer(),
          // Center: Playback Controls (Scaled down if needed)
          Expanded(
            flex: 8,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconBtn(Icons.skip_previous_rounded, widget.onSkipPrevious ?? () {}, size: 30),
                  _buildIconBtn(Icons.replay_10_rounded, _skip10Backward, size: 26),
                  const SizedBox(width: 6),
                  _buildPlayPauseBtn(),
                  const SizedBox(width: 6),
                  _buildIconBtn(Icons.forward_10_rounded, _skip10Forward, size: 26),
                  _buildIconBtn(Icons.skip_next_rounded, widget.onSkipNext ?? () {}, size: 30),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Right Side: Auto Rotate & Fullscreen
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconBtn(Icons.screen_rotation_rounded, _toggleLandscape, size: 22),
              _buildIconBtn(
                widget.currentFit == BoxFit.contain ? Icons.fullscreen_rounded : Icons.fullscreen_exit_rounded,
                widget.onAspectRatioToggle,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseBtn() {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        return GestureDetector(
          onTap: player.playOrPause,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14), // Reduced from 16
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [vxPrimary, vxSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: vxPrimary.withOpacity(0.4),
                  blurRadius: 16, // Reduced from 20
                  spreadRadius: 1, // Reduced from 2
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 38, // Reduced from 44
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg, {IconData? icon}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
            Text(
              msg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        duration: const Duration(seconds: 2),
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
