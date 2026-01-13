import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:audio_service/audio_service.dart';
import 'package:video_x/core/services/audio_handler_service.dart';
import 'package:video_x/core/services/history_service.dart';
import 'package:video_x/core/services/playback_manager.dart';
import 'package:video_x/features/player/custom_controls.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';

class VideoPlayerScreen extends StatefulWidget {
  final List<AssetEntity> playlist;
  final int initialIndex;

  const VideoPlayerScreen({super.key, required this.playlist, required this.initialIndex});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  late Player player;
  late VideoController controller;
  BoxFit _videoFit = BoxFit.contain;
  bool _isMirrored = false;
  bool _isNightMode = false;
  bool _bgPlayEnabled = false;
  double _videoScale = 1.0;
  Offset _videoOffset = Offset.zero;

  StreamSubscription? _posSubscription;
  StreamSubscription? _videoStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _indexSubscription;

  bool _orientationSet = false;
  int _lastPosition = 0;
  bool _startFromBeginning = false;

  late int _currentIndex;
  AssetEntity get _currentAsset => widget.playlist[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);

    _bgPlayEnabled = false; // Default behavior
    // _bgPlayEnabled = false; // Default behavior - Removed as per instruction
    AudioHandlerService.uiNotificationsEnabled = false;

    player = PlaybackManager.instance.player;
    controller = VideoController(player);

    _syncNotificationMetadata();
    _setupListeners();

    _lastPosition = HistoryService.getPosition(_currentAsset.id);
    _startFromBeginning = _lastPosition <= 5;
    _initializePlayer();
  }

  void _setupListeners() {
    if (AudioHandlerService.isInitialized) {}
  }

  void _syncNotificationMetadata() {
    if (!AudioHandlerService.isInitialized) return;
    // We allow metadata updates even if !uiNotificationsEnabled
    // to keep the MediaSession carousel fresh.
    AudioHandlerService.instance.setMediaItem(
      MediaItem(
        id: _currentAsset.id,
        title: _currentAsset.title ?? 'Video',
        duration: Duration(seconds: _currentAsset.duration),
      ),
    );
    AudioHandlerService.instance.updatePlaybackState(
      playing: player.state.playing,
      position: player.state.position,
      duration: player.state.duration,
    );
  }

  Future<void> _initializePlayer() async {
    final file = await _currentAsset.file;
    if (file == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _videoStateSubscription?.cancel();
    _videoStateSubscription = player.stream.width.listen((width) {
      if (!_orientationSet && width != null && width > 0) {
        final height = player.state.height;
        if (height != null && height > 0) _handleAutoOrientation(width, height);
      }
    });

    await player.open(
      Media(file.path, start: !_startFromBeginning && _lastPosition > 0 ? Duration(seconds: _lastPosition) : null),
    );

    _posSubscription?.cancel();
    _posSubscription = player.stream.position.listen((pos) {
      if (pos.inSeconds > 0 && pos.inSeconds % 2 == 0) {
        HistoryService.savePosition(_currentAsset.id, pos.inSeconds);
      }
    });
  }

  void _handleAutoOrientation(int width, int height) {
    _orientationSet = true;
    if (width > height) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  void _cycleAspectRatio() => setState(() {
    if (_videoFit == BoxFit.contain)
      _videoFit = BoxFit.cover;
    else if (_videoFit == BoxFit.cover)
      _videoFit = BoxFit.fill;
    else
      _videoFit = BoxFit.contain;
  });

  void _toggleMirror() => setState(() => _isMirrored = !_isMirrored);
  void _toggleNightMode() => setState(() => _isNightMode = !_isNightMode);

  void _skipNext() {
    if (_currentIndex < widget.playlist.length - 1) {
      _saveAndSwitchTo(_currentIndex + 1);
      AudioHandlerService.instance.updateIndex(_currentIndex + 1);
    }
  }

  void _skipPrevious() {
    if (_currentIndex > 0) {
      _saveAndSwitchTo(_currentIndex - 1);
      AudioHandlerService.instance.updateIndex(_currentIndex - 1);
    }
  }

  Future<void> _saveAndSwitchTo(int newIndex) async {
    HistoryService.savePosition(_currentAsset.id, player.state.position.inSeconds);
    _posSubscription?.cancel();
    _videoStateSubscription?.cancel();
    _durationSubscription?.cancel();

    await player.stop();

    final int nextLastPos = HistoryService.getPosition(widget.playlist[newIndex].id);

    setState(() {
      _currentIndex = newIndex;
      _orientationSet = false;
      _lastPosition = nextLastPos;
      _startFromBeginning = nextLastPos <= 5;
    });

    _initializePlayer();
    _syncNotificationMetadata();
  }

  bool get _canSkipPrevious => _currentIndex > 0;
  bool get _canSkipNext => _currentIndex < widget.playlist.length - 1;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    WakelockPlus.disable();

    HistoryService.savePosition(_currentAsset.id, player.state.position.inSeconds);

    _posSubscription?.cancel();
    _videoStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _indexSubscription?.cancel();

    if (!_bgPlayEnabled) {
      AudioHandlerService.instance.stop();
      // CRITICAL: Fully dispose player to prevent native callback leaks on Hot Restart.
      // The "warm" strategy was causing FFI crashes because the Engine survived Dart Isolate death.
      PlaybackManager.instance.dispose();
    } else {
      // If BG Play is on, explicitly ensure notification is up to date before leaving screen
      _syncNotificationMetadata();
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_bgPlayEnabled) {
        AudioHandlerService.instance.stop(); // Use our instance stop for local guard
        player.pause();
      } else {
        // Ensure notification is active
        _syncNotificationMetadata();
        // FORCE PLAY: Some Android versions auto-pause when surface is lost
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_bgPlayEnabled && !player.state.playing) {
            player.play();
          }
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_bgPlayEnabled) {
        // Double check it stays off
        AudioHandlerService.uiNotificationsEnabled = false;
        AudioHandlerService.instance.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Center(
          child: ColorFiltered(
            colorFilter: _isNightMode
                ? const ColorFilter.matrix([0.9, 0, 0, 0, 0, 0, 0.7, 0, 0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 1, 0])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Transform.flip(
              flipX: _isMirrored,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translate(_videoOffset.dx, _videoOffset.dy)
                  ..scale(_videoScale),
                child: Video(
                  controller: controller,
                  fit: _videoFit,
                  controls: (state) => Transform.flip(
                    flipX: _isMirrored,
                    child: CustomControls(
                      state: state,
                      title: _currentAsset.title ?? 'Video',
                      onAspectRatioToggle: _cycleAspectRatio,
                      currentFit: _videoFit,
                      resumePosition: _lastPosition > 5 ? _lastPosition : null,
                      onSkipNext: _canSkipNext ? _skipNext : null,
                      onSkipPrevious: _canSkipPrevious ? _skipPrevious : null,
                      isMirrored: _isMirrored,
                      onMirrorToggle: _toggleMirror,
                      isNightMode: _isNightMode,
                      onNightModeToggle: _toggleNightMode,
                      isBgPlayEnabled: _bgPlayEnabled,
                      onDoubleTapSeek: (forward) => forward ? _skipNext() : _skipPrevious(),
                      onLongPressSpeedChange: (speedup) {},
                      onDoubleTapCenter: player.playOrPause,
                      onScaleUpdate: (scale, offset) {
                        setState(() {
                          _videoScale = scale;
                          _videoOffset = offset;
                        });
                      },
                      onBgPlayToggle: (enabled) {
                        setState(() => _bgPlayEnabled = enabled);
                        AudioHandlerService.uiNotificationsEnabled = enabled;
                        if (enabled) {
                          _syncNotificationMetadata();
                        } else {
                          AudioHandlerService.instance.stop();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
