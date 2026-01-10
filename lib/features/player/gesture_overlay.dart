import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'dart:async';

class GestureOverlay extends StatefulWidget {
  final VoidCallback onDoubleTap;
  final VoidCallback onTap;

  const GestureOverlay({super.key, required this.onDoubleTap, required this.onTap});

  @override
  State<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends State<GestureOverlay> {
  double? _volume;
  double? _brightness;

  // To show feedback
  bool _showVolume = false;
  bool _showBrightness = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initVolume();
    _initBrightness();
  }

  Future<void> _initVolume() async {
    _volume = await FlutterVolumeController.getVolume();
  }

  Future<void> _initBrightness() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (e) {
      _brightness = 0.5;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    // Screen width divided by 2 to separate left and right
    final halfWidth = constraints.maxWidth / 2;
    final dx = details.localPosition.dx;

    // Sensitivity factor
    final delta = details.delta.dy / constraints.maxHeight;

    if (dx < halfWidth) {
      // Left side: Brightness
      _updateBrightness(-delta);
    } else {
      // Right side: Volume
      _updateVolume(-delta);
    }
  }

  Future<void> _updateBrightness(double delta) async {
    double newBrightness = (_brightness ?? 0.5) + delta;
    newBrightness = newBrightness.clamp(0.0, 1.0);

    await ScreenBrightness().setScreenBrightness(newBrightness);

    setState(() {
      _brightness = newBrightness;
      _showBrightness = true;
      _showVolume = false;
    });
    _resetHideTimer();
  }

  Future<void> _updateVolume(double delta) async {
    double newVolume = (_volume ?? 0.5) + delta;
    newVolume = newVolume.clamp(0.0, 1.0);

    await FlutterVolumeController.setVolume(newVolume);

    setState(() {
      _volume = newVolume;
      _showVolume = true;
      _showBrightness = false;
    });
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showVolume = false;
          _showBrightness = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onVerticalDragUpdate: (details) => _handlePanUpdate(details, constraints),
          child: Container(
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_showVolume) _buildIndicator(Icons.volume_up, _volume ?? 0.0, "Volume"),
                if (_showBrightness) _buildIndicator(Icons.brightness_6, _brightness ?? 0.0, "Brightness"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicator(IconData icon, double value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            height: 4,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
