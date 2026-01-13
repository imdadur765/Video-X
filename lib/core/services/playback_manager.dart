import 'package:media_kit/media_kit.dart';
import 'package:video_x/core/services/audio_handler_service.dart';

/// PlaybackManager manages the singleton Player instance.
/// It ensures that only one player exists and provides state synchronization with AudioHandlerService.
class PlaybackManager {
  static final PlaybackManager _instance = PlaybackManager._internal();
  static PlaybackManager get instance => _instance;

  Player? _player;
  Player get player {
    if (_player == null) {
      _player = Player();
      _setupListeners();
    }
    return _player!;
  }

  PlaybackManager._internal();

  void _setupListeners() {
    final p = _player!;

    p.stream.playing.listen((playing) => _syncState());
    p.stream.position.listen((pos) => _syncState());
    p.stream.duration.listen((dur) => _syncState());
    p.stream.completed.listen((completed) {
      if (completed) {
        AudioHandlerService.instance.skipToNext();
      }
    });

    // Wire up AudioHandler callbacks to our player
    AudioHandlerService.instance.onPlayHandler = () => p.play();
    AudioHandlerService.instance.onPauseHandler = () => p.pause();
    AudioHandlerService.instance.onSeekHandler = (pos) => p.seek(pos);
  }

  void _syncState() {
    if (_player == null) return;
    AudioHandlerService.instance.updatePlaybackState(
      playing: _player!.state.playing,
      position: _player!.state.position,
      duration: _player!.state.duration,
    );
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
