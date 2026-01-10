import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'dart:async';

class GestureOverlay extends StatefulWidget {
  final VoidCallback onTap;
  final Function(bool isForward) onDoubleTapSeek;
  final VoidCallback onDoubleTapCenter;

  const GestureOverlay({
    super.key,
    required this.onTap,
    required this.onDoubleTapSeek,
    required this.onDoubleTapCenter,
  });

  @override
  State<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends State<GestureOverlay> {
  double? _volume;
  double? _brightness;

  bool _showVolume = false;
  bool _showBrightness = false;
  Timer? _hideTimer;

  // For seeking feedback
  bool _showSeekVisual = false;
  bool _seekForward = true;
  Timer? _seekTimer;

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
    final halfWidth = constraints.maxWidth / 2;
    final dx = details.localPosition.dx;
    final delta = details.delta.dy / constraints.maxHeight;

    if (dx < halfWidth) {
      _updateBrightness(-delta);
    } else {
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

  void _handleDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    final x = details.localPosition.dx;
    final width = constraints.maxWidth;

    if (x < width / 3) {
      // Left 1/3
      widget.onDoubleTapSeek(false);
      _showSeek(false);
    } else if (x > (width * 2) / 3) {
      // Right 1/3
      widget.onDoubleTapSeek(true);
      _showSeek(true);
    } else {
      // Center 1/3
      widget.onDoubleTapCenter();
    }
  }

  void _showSeek(bool forward) {
    setState(() {
      _showSeekVisual = true;
      _seekForward = forward;
    });
    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showSeekVisual = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: widget.onTap,
          onDoubleTapDown: (details) => _handleDoubleTap(details, constraints),
          onVerticalDragUpdate: (details) => _handlePanUpdate(details, constraints),
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Volume Side Indicator (Right)
                if (_showVolume)
                  Positioned(
                    right: 20,
                    top: constraints.maxHeight * 0.25,
                    bottom: constraints.maxHeight * 0.25,
                    child: _buildVerticalIndicator(Icons.volume_up, _volume ?? 0.0),
                  ),
                // Brightness Side Indicator (Left)
                if (_showBrightness)
                  Positioned(
                    left: 20,
                    top: constraints.maxHeight * 0.25,
                    bottom: constraints.maxHeight * 0.25,
                    child: _buildVerticalIndicator(Icons.brightness_6, _brightness ?? 0.5),
                  ),
                // Seeking Visual Feedback
                if (_showSeekVisual)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: Icon(_seekForward ? Icons.fast_forward : Icons.fast_rewind, color: Colors.white, size: 40),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalIndicator(IconData icon, double value) {
    return Container(
      width: 40,
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: RotatedBox(
                quarterTurns: 3,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${(value * 100).toInt()}',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
