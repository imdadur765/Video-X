import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_x/core/theme/app_theme.dart';
import 'package:video_x/features/home/home_screen.dart';
import 'package:video_x/core/services/history_service.dart';

import 'package:video_x/core/services/audio_handler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await HistoryService.init();
  try {
    await AudioHandlerService.init();
  } catch (e) {
    debugPrint("Failed to initialize AudioService: $e");
  }
  runApp(const VideoXApp());
}

class VideoXApp extends StatelessWidget {
  const VideoXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video X',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
