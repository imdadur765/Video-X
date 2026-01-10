import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_x/core/services/media_service.dart';
import 'package:video_x/core/services/permission_service.dart';
import 'package:video_x/core/utils/format_utils.dart';
import 'package:video_x/features/player/video_player_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final hasPerm = await _permissionService.checkPermission();
    setState(() {
      _hasPermission = hasPerm;
    });

    if (hasPerm) {
      _loadVideos();
    } else {
      setState(() {
        _isLoading = false;
      });
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
      // Show snackbar or dialog if needed
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
      setState(() {
        _isLoading = false;
      });
      debugPrint("Error loading videos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedIndex == 0
                        ? 'All Videos'
                        : _selectedIndex == 1
                        ? 'Folders'
                        : 'Playlists',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Theme.of(context).primaryColor),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
                ],
              ),
            ),

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
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            // TODO: Load specific data if needed
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Folders'),
          NavigationDestination(
            icon: Icon(Icons.playlist_play_outlined),
            selectedIcon: Icon(Icons.playlist_play),
            label: 'Playlists',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return _videos.isEmpty ? _buildEmptyView() : _buildVideoGrid();
    } else if (_selectedIndex == 1) {
      // Placeholder for folder view
      return _buildFolderList();
    } else {
      return const Center(child: Text("Playlists coming soon"));
    }
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
              title: Text(album.name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: FutureBuilder<int>(
                future: album.assetCountAsync,
                builder: (context, countSnapshot) {
                  return Text('${countSnapshot.data ?? 0} videos', style: Theme.of(context).textTheme.bodySmall);
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to folder detail
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text('Permission Required', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('We need access to your storage to find videos.', textAlign: TextAlign.center),
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
          Icon(
            Icons.video_library_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text('No videos found', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(playlist: _videos, initialIndex: index),
                ),
              );
            },
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
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey[900], child: const Icon(Icons.movie_creation_outlined)),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            FormatUtils.formatDuration(video.duration),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${video.width}x${video.height}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
