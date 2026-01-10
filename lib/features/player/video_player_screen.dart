import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_x/core/services/history_service.dart';
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

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late Player player;
  late VideoController controller;
  BoxFit _videoFit = BoxFit.contain;
  bool _isMirrored = false;
  bool _isNightMode = false;

  StreamSubscription? _posSubscription;
  StreamSubscription? _videoStateSubscription;
  StreamSubscription? _durationSubscription;

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

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    WakelockPlus.enable();

    player = Player();
    controller = VideoController(player);
    _checkAndShowResumeDialog();
  }

  Future<void> _checkAndShowResumeDialog() async {
    _lastPosition = HistoryService.getPosition(_currentAsset.id);

    if (_lastPosition > 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await _showResumeDialog();
        if (result == true) {
          _startFromBeginning = false;
        } else {
          _startFromBeginning = true;
          _lastPosition = 0;
        }
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

    _videoStateSubscription = player.stream.width.listen((width) {
      if (!_orientationSet && width != null && width > 0) {
        final height = player.state.height;
        if (height != null && height > 0) {
          _handleAutoOrientation(width, height);
        }
      }
    });

    if (!_startFromBeginning && _lastPosition > 0) {
      _durationSubscription = player.stream.duration.listen((duration) async {
        if (!_resumeDone && duration > Duration.zero && _lastPosition > 0) {
          _resumeDone = true;
          await player.pause();
          await player.seek(Duration(seconds: _lastPosition));
          await player.play();
        }
      });
    }

    await player.open(Media(file.path));

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

  void _cycleAspectRatio() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
      } else {
        _videoFit = BoxFit.contain;
      }
    });
  }

  void _toggleMirror() {
    setState(() {
      _isMirrored = !_isMirrored;
    });
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
  }

  // Skip to next video
  void _skipNext() {
    if (_currentIndex < widget.playlist.length - 1) {
      _saveAndSwitchTo(_currentIndex + 1);
    }
  }

  // Skip to previous video
  void _skipPrevious() {
    if (_currentIndex > 0) {
      _saveAndSwitchTo(_currentIndex - 1);
    }
  }

  Future<void> _saveAndSwitchTo(int newIndex) async {
    // Save current position
    HistoryService.savePosition(_currentAsset.id, player.state.position.inSeconds);

    // Cleanup
    _posSubscription?.cancel();
    _videoStateSubscription?.cancel();
    _durationSubscription?.cancel();
    await player.stop();

    // Reset state
    setState(() {
      _currentIndex = newIndex;
      _orientationSet = false;
      _resumeDone = false;
      _startFromBeginning = true;
      _lastPosition = 0;
    });

    // Check resume for new video
    _lastPosition = HistoryService.getPosition(_currentAsset.id);
    if (_lastPosition > 5) {
      final result = await _showResumeDialog();
      _startFromBeginning = result != true;
      if (_startFromBeginning) _lastPosition = 0;
    }

    _initializePlayer();
  }

  bool get _canSkipPrevious => _currentIndex > 0;
  bool get _canSkipNext => _currentIndex < widget.playlist.length - 1;

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    WakelockPlus.disable();

    HistoryService.savePosition(_currentAsset.id, player.state.position.inSeconds);

    _posSubscription?.cancel();
    _videoStateSubscription?.cancel();
    _durationSubscription?.cancel();
    player.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
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
              child: Video(
                controller: controller,
                fit: _videoFit,
                controls: (state) {
                  return Transform.flip(
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
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
