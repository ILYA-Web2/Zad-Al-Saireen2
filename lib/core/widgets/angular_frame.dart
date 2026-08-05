import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A gaming-HUD-style frame: a thin, bright accent-colored border with
/// **cut (chamfered) corners** instead of rounded ones, plus a slightly
/// thicker accent "bracket" at each corner — the same visual language as
/// the frame around a game's START button (sharp angles, crisp bright
/// lines, no blur/glow). Wrap any content (an image, a card, a button)
/// with this to give it that frame without needing a full custom-painted
/// background.
///
/// Deliberately paints only strokes, never a filled glow/shadow, staying
/// consistent with the app's flat, no-glow visual direction.
class AngularFrame extends StatelessWidget {
  const AngularFrame({
    super.key,
    required this.child,
    this.cornerSize = 14,
    this.strokeWidth = 1.4,
    this.color,
    this.padding = const EdgeInsets.all(3),
  });

  final Widget child;
  final double cornerSize;
  final double strokeWidth;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _AngularFramePainter(
        color: color ?? AppColors.accent,
        cornerSize: cornerSize,
        strokeWidth: strokeWidth,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AngularFramePainter extends CustomPainter {
  _AngularFramePainter({
    required this.color,
    required this.cornerSize,
    required this.strokeWidth,
  });

  final Color color;
  final double cornerSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      // Rounded joins soften the corner vertex itself instead of a hard
      // 90° point — this is what was reading as visually "off" against
      // the slightly-rounded clip underneath; a fully sharp point at the
      // exact corner doesn't sit well next to a rounded image edge.
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final c = cornerSize;

    // Four independent corner brackets (not a continuous rectangle) —
    // this is what actually reads as a "tech HUD frame" rather than a
    // plain bordered box: each corner is its own sharp two-segment mark.
    final paths = <Path>[
      // top-left
      Path()
        ..moveTo(0, c)
        ..lineTo(0, 0)
        ..lineTo(c, 0),
      // top-right
      Path()
        ..moveTo(w - c, 0)
        ..lineTo(w, 0)
        ..lineTo(w, c),
      // bottom-right
      Path()
        ..moveTo(w, h - c)
        ..lineTo(w, h)
        ..lineTo(w - c, h),
      // bottom-left
      Path()
        ..moveTo(c, h)
        ..lineTo(0, h)
        ..lineTo(0, h - c),
    ];

    for (final p in paths) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AngularFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cornerSize != cornerSize ||
      oldDelegate.strokeWidth != strokeWidth;
}
