import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:audio_service/audio_service.dart';
import 'package:video_x/core/services/audio_handler_service.dart';
import 'package:video_x/core/services/history_service.dart';
import 'package:video_x/core/services/playback_manager.dart';
import 'package:video_x/core/utils/format_utils.dart';
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

  StreamSubscription? _posSubscription;
  StreamSubscription? _videoStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _indexSubscription;

  bool _orientationSet = false;
  bool _resumeDone = false;
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

    // Get player from PlaybackManager
    player = PlaybackManager.instance.player;
    controller = VideoController(player);

    _syncNotificationMetadata(); // ALWAYS sync metadata on start to prevent stale data
    _setupListeners();

    _checkAndShowResumeDialog();
  }

  void _setupListeners() {
    if (AudioHandlerService.isInitialized) {
      // Setup callbacks for notification button presses
      AudioHandlerService.instance.onSkipToNextHandler = () {
        if (_canSkipNext) _skipNext();
      };
      AudioHandlerService.instance.onSkipToPreviousHandler = () {
        if (_canSkipPrevious) _skipPrevious();
      };

      _indexSubscription = AudioHandlerService.instance.currentIndexStream.listen((index) {
        if (index != _currentIndex && mounted) {
          _saveAndSwitchTo(index);
        }
      });

      // We don't call _syncNotificationMetadata here anymore.
      // Notification will only appear if user enables BG Play or minimizes with it enabled.
    }

    _checkAndShowResumeDialog();
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

  Future<void> _checkAndShowResumeDialog() async {
    _lastPosition = HistoryService.getPosition(_currentAsset.id);
    if (_lastPosition > 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await _showResumeDialog();
        _startFromBeginning = result != true;
        if (_startFromBeginning) _lastPosition = 0;
        _initializePlayer();
      });
    } else {
      _startFromBeginning = true;
      _initializePlayer();
    }
  }

  Future<bool?> _showResumeDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Resume Playback?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You were at ${FormatUtils.formatDuration(_lastPosition)}. Continue?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Start Over', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              child: const Text('Continue', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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

    if (!_startFromBeginning && _lastPosition > 0) {
      _durationSubscription?.cancel();
      _durationSubscription = player.stream.duration.listen((duration) async {
        if (!_resumeDone && duration > Duration.zero && _lastPosition > 0) {
          _resumeDone = true;
          await player.seek(Duration(seconds: _lastPosition));
        }
      });
    }

    await player.open(Media(file.path));

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
    setState(() {
      _currentIndex = newIndex;
      _orientationSet = false;
      _resumeDone = false;
      _startFromBeginning = true;
      _lastPosition = 0;
    });

    _lastPosition = HistoryService.getPosition(_currentAsset.id);
    if (_lastPosition > 5) {
      final result = await _showResumeDialog();
      _startFromBeginning = result != true;
      if (_startFromBeginning) _lastPosition = 0;
    }

    _initializePlayer();
    _syncNotificationMetadata(); // ALWAYS sync metadata on skip
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
      backgroundColor: Colors.black, // Pure black for immersive video
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
                    onSkipNext: _canSkipNext ? _skipNext : null,
                    onSkipPrevious: _canSkipPrevious ? _skipPrevious : null,
                    isMirrored: _isMirrored,
                    onMirrorToggle: _toggleMirror,
                    isNightMode: _isNightMode,
                    onNightModeToggle: _toggleNightMode,
                    isBgPlayEnabled: _bgPlayEnabled,
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
    );
  }
}
