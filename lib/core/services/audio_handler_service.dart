import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // For IsolateNameServer

/// AudioHandlerService acts as a bridge between the Flutter Player and the Android MediaSession.
class AudioHandlerService extends BaseAudioHandler {
  static const _nativeChannel = MethodChannel('com.example.video_x/native_utils');
  static AudioHandlerService? _instance;
  static AudioHandlerService get instance => _instance!;
  static bool get isInitialized => _instance != null;

  // ISOLATE LOCAL GUARD: This stays in the UI Isolate.
  static bool uiNotificationsEnabled = false;

  // Background Isolate Guard

  static Future<void> init() async {
    if (_instance != null) return;

    try {
      // HOT RESTART FIX: Check if the port already exists and remove it to prevent stale callbacks
      // The background isolate might be dead, but the name registration persists.
      const portName = 'audio_service_port';
      if (IsolateNameServer.lookupPortByName(portName) != null) {
        IsolateNameServer.removePortNameMapping(portName);
        debugPrint("AudioHandlerService: Cleaned up stale isolate port mapping");
      }

      _instance = await AudioService.init(
        builder: () => AudioHandlerService._internal(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.video_x.channel.audio',
          androidNotificationChannelName: 'Vision X Playback',
          androidNotificationOngoing: false,
          notificationColor: Color(0xFF8B5CF6),
          androidStopForegroundOnPause: false,
          androidNotificationClickStartsActivity: true,
          androidResumeOnClick: true,
        ),
      );

      // CRITICAL: Clear any stale callbacks from the previous isolate (Hot Restart safety)
      await _instance!.customAction('clearStaleCallbacks');
      debugPrint("AudioHandlerService: Initialized & Stale Callbacks Cleared");
    } catch (e) {
      debugPrint("AudioHandlerService: Init failed: $e");
      _instance = AudioHandlerService._internal();
    }
  }

  AudioHandlerService._internal();

  final _indexController = StreamController<int>.broadcast();
  Stream<int> get currentIndexStream => _indexController.stream;

  void updateIndex(int index) {
    if (!_indexController.isClosed) {
      _indexController.add(index);
    }
  }

  // Callbacks to communicate back to the UI Isolate / Player
  void Function()? onPlayHandler;
  void Function()? onPauseHandler;
  void Function()? onSkipToNextHandler;
  void Function()? onSkipToPreviousHandler;
  void Function(Duration)? onSeekHandler;

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'clearStaleCallbacks') {
      onPlayHandler = null;
      onPauseHandler = null;
      onSkipToNextHandler = null;
      onSkipToPreviousHandler = null;
      onSeekHandler = null;
      debugPrint("AudioHandlerService: Background Isolate Callbacks Reset");
      return null;
    }
    return super.customAction(name, extras);
  }

  /// Sync the current playback state to the system notification.
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    if (!uiNotificationsEnabled) return;

    final effectiveProcessingState = uiNotificationsEnabled ? processingState : AudioProcessingState.idle;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: effectiveProcessingState,
        playing: uiNotificationsEnabled ? playing : false,
        updatePosition: position,
        bufferedPosition: position,
      ),
    );
  }

  void setMediaItem(MediaItem item) {
    mediaItem.add(item);
  }

  /// Completely stops the service and removes the notification.
  @override
  Future<void> stop() async {
    uiNotificationsEnabled = false;

    playbackState.add(
      playbackState.value.copyWith(controls: [], processingState: AudioProcessingState.idle, playing: false),
    );

    await Future.delayed(const Duration(milliseconds: 100));
    await super.stop();

    try {
      await _nativeChannel.invokeMethod('clearNotifications');
    } catch (e) {
      debugPrint("AudioHandlerService: Native clear failed: $e");
    }

    debugPrint("AudioHandlerService: Service Stopped & UI Bridge Sealed");
  }

  @override
  Future<void> play() async => onPlayHandler?.call();

  @override
  Future<void> pause() async => onPauseHandler?.call();

  @override
  Future<void> seek(Duration position) async => onSeekHandler?.call(position);

  @override
  Future<void> skipToNext() async => onSkipToNextHandler?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPreviousHandler?.call();
}
