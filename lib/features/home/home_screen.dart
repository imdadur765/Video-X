import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_x/core/services/media_service.dart';
import 'package:video_x/core/services/permission_service.dart';
import 'package:video_x/core/utils/format_utils.dart';
import 'package:video_x/features/player/video_player_screen.dart';
import 'package:video_x/features/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final MediaService _mediaService = MediaService();
  final PermissionService _permissionService = PermissionService();

  List<AssetEntity> _videos = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isGridView = false; // Default to List View

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final hasPerm = await _permissionService.checkPermission();
    setState(() => _hasPermission = hasPerm);

    if (hasPerm) {
      _loadVideos();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermission() async {
    final granted = await _permissionService.requestStoragePermission();
    if (granted) {
      setState(() {
        _hasPermission = true;
        _isLoading = true;
      });
      _loadVideos();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Permission required to access videos')));
      }
    }
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await _mediaService.getAllVideos();
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error loading videos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _selectedIndex == 3
            ? const ProfileScreen()
            : Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: !_hasPermission
                        ? _buildPermissionView()
                        : _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildBody(),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).cardColor,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Videos',
          ),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Folders'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Recent'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    String title = ['All Videos', 'Folders', 'Recently Watched'][_selectedIndex.clamp(0, 2)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // TODO: Search
              },
            ),
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: (value) {
                // TODO: Sort
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
                const PopupMenuItem(value: 'size', child: Text('Sort by Size')),
                const PopupMenuItem(value: 'duration', child: Text('Sort by Duration')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return _videos.isEmpty ? _buildEmptyView() : (_isGridView ? _buildVideoGrid() : _buildVideoList());
    } else if (_selectedIndex == 1) {
      return _buildFolderList();
    } else if (_selectedIndex == 2) {
      return _buildRecentlyWatched();
    }
    return const SizedBox();
  }

  // MX Player Style List View (Default)
  Widget _buildVideoList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () => _openPlayer(index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 70,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: AssetEntityImageProvider(video, isOriginal: false),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.movie, color: Colors.white54),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                FormatUtils.formatDuration(video.duration),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title ?? 'Unknown',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text('${video.width}x${video.height}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  // More button
                  IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showVideoOptions(video)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Grid View (Toggle)
  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _openPlayer(index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: AssetEntityImageProvider(video, isOriginal: false),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie, color: Colors.white54, size: 40),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            FormatUtils.formatDuration(video.duration),
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    video.title ?? 'Unknown',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderList() {
    return FutureBuilder<List<AssetPathEntity>>(
      future: _mediaService.getVideoFolders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return _buildEmptyView();

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final album = snapshot.data![index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(album.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: FutureBuilder<int>(
                future: album.assetCountAsync,
                builder: (context, countSnapshot) => Text('${countSnapshot.data ?? 0} videos'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final videos = await album.getAssetListRange(start: 0, end: await album.assetCountAsync);
                if (mounted && videos.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VideoPlayerScreen(playlist: videos, initialIndex: 0)),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecentlyWatched() {
    // TODO: Implement from Hive history
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('Recently watched videos will appear here', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Permission Required', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('We need access to your storage to find videos.'),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _requestPermission, child: const Text('Grant Access')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('No videos found', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  void _openPlayer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(playlist: _videos, initialIndex: index),
      ),
    );
  }

  void _showVideoOptions(AssetEntity video) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Details'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Add to Favorites'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(leading: const Icon(Icons.share), title: const Text('Share'), onTap: () => Navigator.pop(context)),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
