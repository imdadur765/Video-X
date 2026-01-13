import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'dart:async';
import 'dart:ui' as ui;

class GestureOverlay extends StatefulWidget {
  final VoidCallback onTap;
  final Function(bool isForward) onDoubleTapSeek;
  final Function(bool isSpeedUp) onLongPressSpeedChange;
  final Function(double scale, Offset offset)? onScaleUpdate;
  final VoidCallback onDoubleTapCenter;

  const GestureOverlay({
    super.key,
    required this.onTap,
    required this.onDoubleTapSeek,
    required this.onLongPressSpeedChange,
    this.onScaleUpdate,
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

  // For long press speed
  bool _isLongPressing = false;

  // For pinch to zoom
  double _baseScale = 1.0;
  double _currentScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _currentOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initVolume();
    _initBrightness();
    // Hide system volume UI/HUD
    FlutterVolumeController.updateShowSystemUI(false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekTimer?.cancel();
    // Restore system volume UI on exit
    FlutterVolumeController.updateShowSystemUI(true);
    super.dispose();
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

  // Optimized updates: Update UI immediately, native call in background to prevent lag
  void _updateBrightness(double delta) {
    double newBrightness = (_brightness ?? 0.5) + delta;
    newBrightness = newBrightness.clamp(0.0, 1.0);

    // Immediate UI Update
    setState(() {
      _brightness = newBrightness;
      _showBrightness = true;
      _showVolume = false;
    });

    // Background Native Call (Don't await here to prevent UI glitch)
    ScreenBrightness().setScreenBrightness(newBrightness).catchError((_) {});

    _resetHideTimer();
  }

  void _updateVolume(double delta) {
    double newVolume = (_volume ?? 0.5) + delta;
    newVolume = newVolume.clamp(0.0, 1.0);

    // Immediate UI Update
    setState(() {
      _volume = newVolume;
      _showVolume = true;
      _showBrightness = false;
    });

    // Background Native Call
    FlutterVolumeController.setVolume(newVolume);

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
    if (_currentScale > 1.0) {
      // Reset zoom on double tap if zoomed in
      setState(() {
        _currentScale = 1.0;
        _baseScale = 1.0;
        _currentOffset = Offset.zero;
        _baseOffset = Offset.zero;
      });
      widget.onScaleUpdate?.call(1.0, Offset.zero);
      return;
    }

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
          onLongPressStart: (_) {
            setState(() => _isLongPressing = true);
            widget.onLongPressSpeedChange(true);
            HapticFeedback.mediumImpact();
          },
          onLongPressEnd: (_) {
            setState(() => _isLongPressing = false);
            widget.onLongPressSpeedChange(false);
          },
          onScaleStart: (details) {
            _baseScale = _currentScale;
            _baseOffset = _currentOffset;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount == 2) {
              setState(() {
                _currentScale = (_baseScale * details.scale).clamp(1.0, 5.0);
                // Simple panning while zoomed
                if (_currentScale > 1.0) {
                  _currentOffset = _baseOffset + details.focalPointDelta;
                } else {
                  _currentOffset = Offset.zero;
                }
              });
              widget.onScaleUpdate?.call(_currentScale, _currentOffset);
            }
          },
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Top Speed Indicator
                if (_isLongPressing)
                  Positioned(top: 60, left: 0, right: 0, child: Center(child: _buildSpeedIndicator())),
                // Volume Side Indicator (Right)
                if (_showVolume)
                  Positioned(
                    right: 40, // More padding from edge
                    top: constraints.maxHeight * (constraints.maxWidth > constraints.maxHeight ? 0.2 : 0.3),
                    bottom: constraints.maxHeight * (constraints.maxWidth > constraints.maxHeight ? 0.2 : 0.3),
                    child: _buildVerticalIndicator(Icons.volume_up_rounded, _volume ?? 0.0, const Color(0xFF00B0FF)),
                  ),
                // Brightness Side Indicator (Left)
                if (_showBrightness)
                  Positioned(
                    left: 40,
                    top: constraints.maxHeight * (constraints.maxWidth > constraints.maxHeight ? 0.2 : 0.3),
                    bottom: constraints.maxHeight * (constraints.maxWidth > constraints.maxHeight ? 0.2 : 0.3),
                    child: _buildVerticalIndicator(
                      Icons.brightness_medium_rounded,
                      _brightness ?? 0.5,
                      Colors.amberAccent,
                    ),
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

  Widget _buildVerticalIndicator(IconData icon, double value, Color color) {
    return Container(
      width: 50, // Slightly wider
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Stack(
                      children: [
                        // Track
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${(value * 100).toInt()}',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00B0FF).withOpacity(0.4), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF00B0FF).withOpacity(0.2), blurRadius: 15, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed_rounded, color: Color(0xFF00B0FF), size: 18),
              const SizedBox(width: 10),
              const Text(
                '2.0X SPEED',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
