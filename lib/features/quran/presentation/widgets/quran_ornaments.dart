import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 5 distinct, hand-drawn Islamic corner-ornament styles to choose from
/// (previously there was exactly one, a thin-stroke 8-point star that
/// only read cleanly at large sizes — at the smaller sizes it's actually
/// used at in practice, thin strokes and fine points anti-alias into an
/// illegible smudge, which is what looked like "broken/deformed stars").
/// Every style below is built from simple, mostly *filled* shapes rather
/// than thin outlined paths specifically because filled geometry stays
/// crisp and recognizable at any size, from a 20px share-card corner up
/// to a full-page Mushaf frame.
enum OrnamentStyle { star8, crescent, arch, lattice, laurel }

extension OrnamentStyleX on OrnamentStyle {
  String get arabicLabel {
    switch (this) {
      case OrnamentStyle.star8:
        return 'نجمة ثمانية';
      case OrnamentStyle.crescent:
        return 'هلال ونجمة';
      case OrnamentStyle.arch:
        return 'محراب';
      case OrnamentStyle.lattice:
        return 'شبكية هندسية';
      case OrnamentStyle.laurel:
        return 'غصن مزخرف';
    }
  }
}

class IslamicCornerOrnament extends StatelessWidget {
  const IslamicCornerOrnament({
    super.key,
    this.size = 44,
    this.color = const Color(0xFFC9A227),
    this.style = OrnamentStyle.star8,
  });

  final double size;
  final Color color;
  final OrnamentStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ornamentPainterFor(style, color)),
    );
  }
}

CustomPainter _ornamentPainterFor(OrnamentStyle style, Color color) {
  switch (style) {
    case OrnamentStyle.star8:
      return _Star8Painter(color: color);
    case OrnamentStyle.crescent:
      return _CrescentPainter(color: color);
    case OrnamentStyle.arch:
      return _ArchPainter(color: color);
    case OrnamentStyle.lattice:
      return _LatticePainter(color: color);
    case OrnamentStyle.laurel:
      return _LaurelPainter(color: color);
  }
}

/// Classic 8-point star, anchored in the corner — filled (not stroked)
/// this time, with a thin outline only as a crisp edge, so it stays
/// legible at small sizes instead of dissolving into anti-aliasing noise.
class _Star8Painter extends CustomPainter {
  _Star8Painter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, size.height);
    final radius = size.width * 0.82;
    const points = 8;

    final path = Path();
    for (int i = 0; i <= points * 2; i++) {
      final angle = (math.pi / points) * i + math.pi;
      final r = i.isEven ? radius : radius * 0.46;
      final offset = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02,
    );
    canvas.drawCircle(center, radius * 0.16, Paint()..color = Colors.white.withOpacity(0.35));
  }

  @override
  bool shouldRepaint(covariant _Star8Painter oldDelegate) => oldDelegate.color != color;
}

/// Crescent moon with a small companion star — one of the most
/// immediately recognizable Islamic motifs, and inherently robust at
/// small sizes since it's just two simple filled arcs/shapes.
class _CrescentPainter extends CustomPainter {
  _CrescentPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.62, size.height * 0.62);
    final outerRadius = size.width * 0.42;

    final crescentPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius));
    final cutoutPath = Path()
      ..addOval(Rect.fromCircle(
        center: center.translate(outerRadius * 0.42, -outerRadius * 0.18),
        radius: outerRadius * 0.86,
      ));
    final finalCrescent = Path.combine(PathOperation.difference, crescentPath, cutoutPath);

    canvas.drawPath(finalCrescent, Paint()..color = color.withOpacity(0.9));

    // Companion star (4-point, simple diamond-based) near the crescent tip.
    final starCenter = Offset(size.width * 0.18, size.height * 0.20);
    final starPath = Path();
    const starRadius = 6.0;
    for (int i = 0; i < 8; i++) {
      final angle = math.pi / 4 * i;
      final r = i.isEven ? starRadius : starRadius * 0.4;
      final p = Offset(starCenter.dx + r * math.cos(angle), starCenter.dy + r * math.sin(angle));
      if (i == 0) {
        starPath.moveTo(p.dx, p.dy);
      } else {
        starPath.lineTo(p.dx, p.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = color.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant _CrescentPainter oldDelegate) => oldDelegate.color != color;
}

/// A small pointed mihrab-style arch — a simple, bold, filled silhouette
/// evoking a mosque niche, deliberately kept to a handful of straight and
/// curved segments so it can't turn into visual noise at small sizes.
class _ArchPainter extends CustomPainter {
  _ArchPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.30, h)
      ..lineTo(w * 0.30, h * 0.55)
      ..quadraticBezierTo(w * 0.30, h * 0.15, w * 0.65, h * 0.15)
      ..quadraticBezierTo(w, h * 0.15, w, h * 0.55)
      ..lineTo(w, h)
      ..lineTo(w * 0.86, h)
      ..lineTo(w * 0.86, h * 0.58)
      ..quadraticBezierTo(w * 0.86, h * 0.30, w * 0.65, h * 0.30)
      ..quadraticBezierTo(w * 0.44, h * 0.30, w * 0.44, h * 0.58)
      ..lineTo(w * 0.44, h)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchPainter oldDelegate) => oldDelegate.color != color;
}

/// A small interlocking-diamond lattice corner — the geometric
/// (girih-style) side of Islamic ornamentation, built from plain filled
/// rotated squares so it reads as a clean pattern rather than a fragile
/// linework mesh.
class _LatticePainter extends CustomPainter {
  _LatticePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width * 0.24;
    final origin = Offset(size.width - unit * 0.9, size.height - unit * 0.9);

    void diamond(Offset center, double s, double opacity) {
      final path = Path()
        ..moveTo(center.dx, center.dy - s)
        ..lineTo(center.dx + s, center.dy)
        ..lineTo(center.dx, center.dy + s)
        ..lineTo(center.dx - s, center.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withOpacity(opacity));
    }

    diamond(origin, unit, 0.9);
    diamond(origin.translate(-unit * 1.6, 0), unit * 0.75, 0.55);
    diamond(origin.translate(0, -unit * 1.6), unit * 0.75, 0.55);
    diamond(origin.translate(-unit * 1.6, -unit * 1.6), unit * 0.55, 0.3);
  }

  @override
  bool shouldRepaint(covariant _LatticePainter oldDelegate) => oldDelegate.color != color;
}

/// A gentle vine/leaf flourish curling out of the corner — the more
/// organic (as opposed to strictly geometric) side of traditional
/// Mushaf-margin decoration, drawn as a single bold stroke plus a couple
/// of simple filled leaf shapes.
class _LaurelPainter extends CustomPainter {
  _LaurelPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stem = Path()
      ..moveTo(w, h)
      ..cubicTo(w * 0.55, h * 0.95, w * 0.35, h * 0.65, w * 0.4, h * 0.15);

    canvas.drawPath(
      stem,
      Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );

    void leaf(Offset at, double angle, double scale) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      final leafPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(scale * 0.9, -scale * 0.5, 0, -scale * 1.5)
        ..quadraticBezierTo(-scale * 0.9, -scale * 0.5, 0, 0);
      canvas.drawPath(leafPath, Paint()..color = color.withOpacity(0.7));
      canvas.restore();
    }

    leaf(Offset(w * 0.75, h * 0.72), -0.6, w * 0.18);
    leaf(Offset(w * 0.48, h * 0.42), 0.5, w * 0.16);
    leaf(Offset(w * 0.38, h * 0.16), -0.2, w * 0.14);
  }

  @override
  bool shouldRepaint(covariant _LaurelPainter oldDelegate) => oldDelegate.color != color;
}

/// A full decorative frame (all four corners) wrapping the reading page —
/// the classic Mushaf-margin look, without needing any external image.
class QuranPageFrame extends StatelessWidget {
  const QuranPageFrame({
    super.key,
    required this.child,
    required this.accentColor,
    this.style = OrnamentStyle.star8,
  });

  final Widget child;
  final Color accentColor;
  final OrnamentStyle style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(top: 8, right: 8, child: IslamicCornerOrnament(color: accentColor, style: style)),
        Positioned(
          top: 8,
          left: 8,
          child: Transform.flip(flipX: true, child: IslamicCornerOrnament(color: accentColor, style: style)),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Transform.flip(flipY: true, child: IslamicCornerOrnament(color: accentColor, style: style)),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Transform.flip(
            flipX: true,
            flipY: true,
            child: IslamicCornerOrnament(color: accentColor, style: style),
          ),
        ),
      ],
    );
  }
}

/// A decorative divider used between the Surah title and the Basmalah —
/// two short ornamental strokes flanking a small diamond, a common Mushaf
/// heading motif.
class OrnamentalDivider extends StatelessWidget {
  const OrnamentalDivider({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 40, height: 1.2, color: color.withOpacity(0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 8, height: 8, color: color),
          ),
        ),
        Container(width: 40, height: 1.2, color: color.withOpacity(0.5)),
      ],
    );
  }
}
