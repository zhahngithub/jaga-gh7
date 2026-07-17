import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class ActiveDistressMarker extends StatefulWidget {
  const ActiveDistressMarker({super.key});

  @override
  State<ActiveDistressMarker> createState() => _ActiveDistressMarkerState();
}

class _ActiveDistressMarkerState extends State<ActiveDistressMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _coreScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _coreScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        label: 'Sinyal SOS aktif dan sedang disiarkan',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DistressSignalPainter(_controller)),
            ),
            ScaleTransition(
              scale: _coreScale,
              child: Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.distress,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistressSignalPainter extends CustomPainter {
  _DistressSignalPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maximumRadius = size.shortestSide / 2 - 2;

    for (final delay in const [0.0, 0.5]) {
      final progress = (animation.value + delay) % 1;
      final radius = lerpDouble(31, maximumRadius, progress)!;
      final opacity = (1 - progress) * 0.38;
      final paint = Paint()
        ..color = AppColors.distress.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(3, 1, progress)!;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DistressSignalPainter oldDelegate) => false;
}
