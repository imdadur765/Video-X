import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  final MediaService _mediaService = MediaService();
  final PermissionService _permissionService = PermissionService();

  List<AssetEntity> _videos = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isGridView = false;

  late AnimationController _animationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _checkPermissionAndLoad();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoad() async {
    final hasPerm = await _permissionService.checkPermission();
    if (mounted) setState(() => _hasPermission = hasPerm);

    if (hasPerm) {
      _loadVideos();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermission() async {
    final granted = await _permissionService.requestStoragePermission();
    if (granted) {
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _isLoading = true;
        });
      }
      _loadVideos();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission required')));
      }
    }
  }

  Future<void> _loadVideos() async {
    final videos = await _mediaService.getAllVideos();
    if (mounted) {
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: false, // User requested: "niche se video nhi dikhna chaiye" (Docked)
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverAppBar()],
        body: !_hasPermission
            ? _buildPermissionView()
            : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 🔥 Premium Header
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0.0, 0.15, 1.0],
            colors: [
              Colors.black,
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
              Theme.of(context).primaryColor.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
          title: Text(_getTitle(), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            cardColor: const Color(0xFF1E1E1E),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
            offset: const Offset(0, 50),
            onSelected: (value) {
              if (value == 'Refresh') _loadVideos();
            },
            itemBuilder: (context) => [
              _buildPopupMenuItem('Refresh', Icons.refresh_rounded),
              _buildPopupMenuItem('Sort Order', Icons.sort_rounded),
              _buildPopupMenuItem('Settings', Icons.settings_rounded),
            ],
          ),
        ),
      ],
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'All Videos';
      case 1:
        return 'Folders';
      case 2:
        return 'Explore';
      case 3:
        return 'Recent';
      case 4:
        return 'Profile';
      default:
        return 'Videos';
    }
  }

  PopupMenuItem<String> _buildPopupMenuItem(String title, IconData icon) {
    return PopupMenuItem(
      value: title,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: Colors.black, // "Puri tarah black" background
      padding: const EdgeInsets.only(top: 10), // Spacing from video area
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            // Docked margin
            margin: const EdgeInsets.only(bottom: 12),
            height: 70,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 0. 🌟 Ambient Under-Glow
                CustomPaint(
                  size: const Size(double.infinity, 55),
                  painter: NeonShadowPainter(progress: _pulseController.value, color: Theme.of(context).primaryColor),
                ),

                // 1. The Split Wings (Spotify Glass Style)
                ClipPath(
                  clipper: NavBarClipper(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      height: 55,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        // Dark Gradient (Opaque)
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [const Color(0xFF252525), const Color(0xFF000000)],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _navItem(0, Icons.home_filled, Icons.home_outlined), // Home
                                _navItem(1, Icons.folder_rounded, Icons.folder_outlined), // Files
                              ],
                            ),
                          ),
                          const SizedBox(width: 70), // Center gap
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _navItem(3, Icons.history_rounded, Icons.history_outlined), // Recent
                                _navItem(4, Icons.person_rounded, Icons.person_outline_rounded), // Profile
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 1.5 💎 Subtle Glass Rim
                IgnorePointer(
                  child: CustomPaint(size: const Size(double.infinity, 55), painter: GlassBorderPainter()),
                ),

                // 2. The Floating Center Button
                Positioned(
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _selectedIndex == 2
                              ? [const Color(0xFF2962FF), const Color(0xFF00B0FF)]
                              : [const Color(0xFF222222), const Color(0xFF111111)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedIndex == 2
                                ? const Color(0xFF2962FF).withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: _selectedIndex == 2 ? 25 : 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: _selectedIndex == 2 ? 0.3 : 0.1),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.explore_rounded,
                        color: _selectedIndex == 2 ? Colors.white : Colors.grey,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Improved Nav Item (Icon Switching for Active State)
  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(
            isSelected ? activeIcon : inactiveIcon,
            key: ValueKey(isSelected),
            color: isSelected ? Colors.white : Colors.white54, // Spotify Style: White vs Grey
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _videos.isEmpty ? _buildEmptyView() : (_isGridView ? _buildVideoGrid() : _buildVideoList());
      case 1:
        return _buildFolderList();
      case 2:
        return _buildExploreView();
      case 3:
        return _buildRecentlyWatched();
      case 4:
        return const ProfileScreen(); // Profile is now embedded in body
      default:
        return const SizedBox();
    }
  }

  // 🌐 Explore View (Placeholder)
  Widget _buildExploreView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.public, size: 80, color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Explore Movie Info',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('(Coming Soon)', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.search), label: const Text('Search Online')),
        ],
      ),
    );
  }

  // 🎬 List View
  Widget _buildVideoList() {
    return ListView.builder(
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];

        return FadeTransition(
          opacity: _animationController,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => _openPlayer(index),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 110,
                height: 62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(image: AssetEntityImageProvider(video, isOriginal: false), fit: BoxFit.cover),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          FormatUtils.formatDuration(video.duration),
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            title: Text(
              video.title ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${video.width}×${video.height}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.more_vert_rounded),
          ),
        );
      },
    );
  }

  // 🧊 Grid View
  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _videos.length,
      itemBuilder: (_, index) {
        final video = _videos[index];

        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openPlayer(index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image(image: AssetEntityImageProvider(video, isOriginal: false), fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    video.title ?? 'Unknown',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 📂 Premium Folder List
  Widget _buildFolderList() {
    return FutureBuilder<List<AssetPathEntity>>(
      future: _mediaService.getVideoFolders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return _buildEmptyView();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final album = snapshot.data![index];
            return FadeTransition(
              opacity: _animationController,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () async {
                  final videos = await album.getAssetListRange(start: 0, end: await album.assetCountAsync);
                  if (mounted && videos.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VideoPlayerScreen(playlist: videos, initialIndex: 0)),
                    );
                  }
                },
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Icon(Icons.folder_rounded, color: Theme.of(context).primaryColor),
                ),
                title: Text(album.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: FutureBuilder<int>(
                  future: album.assetCountAsync,
                  builder: (context, countSnapshot) => Text(
                    '${countSnapshot.data ?? 0} videos',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  // 🕒 Premium History List
  Widget _buildRecentlyWatched() {
    // TODO: Connect to real HistoryService
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('No recent plays', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Videos you watch will show up here', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off, size: 80, color: Colors.white12),
          const SizedBox(height: 16),
          const Text('Permission Required'),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _requestPermission, child: const Text('ALLOW ACCESS')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text('No videos found', style: TextStyle(color: Colors.grey)),
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
}

// 📐 Custom Curve shape
class NavBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _getNavbarPath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// 💎 Glass Border Painter (Subtle Rim)
class GlassBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _getNavbarPath(size);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.05)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 🎨 Ambient Shadow Painter (Soft Glow)
class NeonShadowPainter extends CustomPainter {
  final double progress;
  final Color color;

  NeonShadowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getNavbarPath(size);

    // Ambient Glow: Softer, wider blur, no stroke
    final blur = 20.0 + (progress * 10.0);
    final opacity = 0.4 + (progress * 0.2);

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
      ..style = PaintingStyle.fill; // Fill for ambient glow, not stroke

    // Draw shadow pushed down
    canvas.drawPath(path.shift(const Offset(0, 5)), paint);
  }

  @override
  bool shouldRepaint(NeonShadowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Helper for Split "Wing" Path (===> O <===)
Path _getNavbarPath(Size size) {
  final width = size.width;
  final height = size.height;
  const centerGap = 35.0; // Half of total gap (70 total)
  const cornerRadius = 24.0; // Slightly more rounded for "Spotify" pill feel

  Path path = Path();

  // 1. Left Wing (Rounded Pill)
  final leftRect = RRect.fromRectAndCorners(
    Rect.fromLTRB(0, 0, (width / 2) - centerGap, height),
    topLeft: const Radius.circular(cornerRadius),
    bottomLeft: const Radius.circular(cornerRadius),
    topRight: const Radius.circular(12),
    bottomRight: const Radius.circular(12),
  );
  path.addRRect(leftRect);

  // 2. Right Wing (Rounded Pill)
  final rightRect = RRect.fromRectAndCorners(
    Rect.fromLTRB((width / 2) + centerGap, 0, width, height),
    topLeft: const Radius.circular(12),
    bottomLeft: const Radius.circular(12),
    topRight: const Radius.circular(cornerRadius),
    bottomRight: const Radius.circular(cornerRadius),
  );
  path.addRRect(rightRect);

  return path;
}
