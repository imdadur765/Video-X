import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPlay = true;
  bool _rememberPosition = true;
  bool _hardwareDecoding = true;
  double _defaultSpeed = 1.0;
  String _defaultAspectRatio = 'Fit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        children: [
          _buildSectionHeader('Playback'),
          SwitchListTile(
            title: const Text('Auto-play next video'),
            subtitle: const Text('Automatically play next video in playlist'),
            value: _autoPlay,
            onChanged: (v) => setState(() => _autoPlay = v),
          ),
          SwitchListTile(
            title: const Text('Remember playback position'),
            subtitle: const Text('Resume videos from where you left off'),
            value: _rememberPosition,
            onChanged: (v) => setState(() => _rememberPosition = v),
          ),
          ListTile(
            title: const Text('Default playback speed'),
            subtitle: Text('${_defaultSpeed}x'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSpeedPicker,
          ),
          ListTile(
            title: const Text('Default aspect ratio'),
            subtitle: Text(_defaultAspectRatio),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAspectRatioPicker,
          ),

          _buildSectionHeader('Performance'),
          SwitchListTile(
            title: const Text('Hardware decoding'),
            subtitle: const Text('Use GPU for video decoding (recommended)'),
            value: _hardwareDecoding,
            onChanged: (v) => setState(() => _hardwareDecoding = v),
          ),

          _buildSectionHeader('Storage'),
          ListTile(
            title: const Text('Clear playback history'),
            subtitle: const Text('Remove all saved positions'),
            trailing: const Icon(Icons.delete_outline, color: Colors.red),
            onTap: _clearHistory,
          ),
          ListTile(
            title: const Text('Clear thumbnail cache'),
            subtitle: const Text('Free up storage space'),
            trailing: const Icon(Icons.cleaning_services_outlined),
            onTap: _clearCache,
          ),

          _buildSectionHeader('About'),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
            leading: const Icon(Icons.info_outline),
          ),
          ListTile(
            title: const Text('Developer'),
            subtitle: const Text('Video X Team'),
            leading: const Icon(Icons.code),
          ),
          ListTile(
            title: const Text('Rate this app'),
            leading: const Icon(Icons.star_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Share with friends'),
            leading: const Icon(Icons.share_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
            .map(
              (speed) => ListTile(
                title: Text('${speed}x'),
                trailing: speed == _defaultSpeed ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() => _defaultSpeed = speed);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _showAspectRatioPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: ['Fit', 'Fill', 'Stretch', '16:9', '4:3']
            .map(
              (ratio) => ListTile(
                title: Text(ratio),
                trailing: ratio == _defaultAspectRatio ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() => _defaultAspectRatio = ratio);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will remove all saved playback positions. Videos will start from the beginning.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              // TODO: Clear Hive box
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History cleared')));
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }
}
