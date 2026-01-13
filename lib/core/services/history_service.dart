import 'package:hive_flutter/hive_flutter.dart';

class HistoryService {
  static const String _boxName = 'video_history';

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  // Save playback position
  static Future<void> savePosition(String videoId, int positionSeconds) async {
    final box = Hive.box(_boxName);
    await box.put(videoId, positionSeconds);
    await box.put('last_played_id', videoId); // Track the most recent video
  }

  // Get last playback position
  static int getPosition(String videoId) {
    if (!Hive.isBoxOpen(_boxName)) return 0;
    final box = Hive.box(_boxName);
    return box.get(videoId, defaultValue: 0);
  }

  // Get last played video ID
  static String? getLastPlayedId() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    return Hive.box(_boxName).get('last_played_id');
  }
}
