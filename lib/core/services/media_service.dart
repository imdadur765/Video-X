import 'package:photo_manager/photo_manager.dart';

class MediaService {
  /// Requests permission and returns all video assets found on the device.
  Future<List<AssetEntity>> getAllVideos() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    // Check if permission is granted or limited (iOS)
    if (!ps.isAuth && !ps.hasAccess) {
      // If denied, we can't do anything
      return [];
    }

    // Get all directories containing videos
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      filterOption: FilterOptionGroup(orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)]),
    );

    if (albums.isEmpty) return [];

    // The first album is usually "Recents" or "All Videos"
    // Fetch videos from the first album (up to 500 for now to be safe on memory)
    // TODO: Implement pagination for very large libraries
    final List<AssetEntity> videos = await albums[0].getAssetListRange(start: 0, end: 500);

    return videos;
  }

  /// Get recently added videos
  Future<List<AssetEntity>> getRecentlyAdded() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) return [];

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      filterOption: FilterOptionGroup(orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)]),
    );

    if (albums.isEmpty) return [];
    return await albums[0].getAssetListRange(start: 0, end: 10);
  }

  /// Get list of video folders
  Future<List<AssetPathEntity>> getVideoFolders() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) return [];

    return await PhotoManager.getAssetPathList(type: RequestType.video);
  }
}
