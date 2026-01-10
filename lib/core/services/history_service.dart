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
    // debugPrint("HistoryService: Saved $positionSeconds for $videoId");
  }

  // Get last playback position
  static int getPosition(String videoId) {
    if (!Hive.isBoxOpen(_boxName)) return 0;
    final box = Hive.box(_boxName);
    final pos = box.get(videoId, defaultValue: 0);
    // debugPrint("HistoryService: Retrieved $pos for $videoId");
    return pos;
  }
}
