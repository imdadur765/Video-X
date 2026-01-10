import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      // Android 13 (API 33) and above use granular media permissions
      if (androidInfo.version.sdkInt >= 33) {
        final videos = await Permission.videos.request();
        // We can request audio/images if we want a complete gallery view,
        // but for a video player, videos is the critical one.
        return videos.isGranted;
      } else {
        // Android 12 and below use READ_EXTERNAL_STORAGE
        final storage = await Permission.storage.request();
        // On Android 11+ (API 30+), Manage External Storage might be needed for full access
        // but READ_EXTERNAL_STORAGE is usually enough for media reading.
        return storage.isGranted;
      }
    }
    // iOS and others
    return true;
  }

  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.videos.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true;
  }
}
