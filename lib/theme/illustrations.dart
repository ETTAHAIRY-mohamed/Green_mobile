import 'package:flutter/material.dart';

import 'app_theme.dart';

enum Illustration { tomato, potato, apple, peach, leaf, leafSick }

/// Illustrations au trait (≈1,5 px, or ou vert sauge), dessinées en code :
/// aucune dépendance SVG. Repère de dessin : carré 100 × 100.
class IllustrationView extends StatelessWidget {
  const IllustrationView(
    this.kind, {
    super.key,
    this.size = 72,
    this.color,
  });

  final Illustration kind;
  final double size;

  /// Couleur du trait (or par défaut ; vert sauge pour les feuilles).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isLeaf = kind == Illustration.leaf || kind == Illustration.leafSick;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IllustrationPainter(
          kind,
          color ?? (isLeaf ? AppColors.leafGreen : AppColors.gold),
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter(this.kind, this.color);

  final Illustration kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 100;
    canvas.save();
    canvas.scale(unit);

    // Trait d'épaisseur visuelle constante (~1,6 px) quelle que soit la taille.
    final stroke = (1.6 / unit).clamp(1.2, 4.0);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case Illustration.tomato:
        _tomato(canvas, line);
      case Illustration.potato:
        _potato(canvas, line);
      case Illustration.apple:
        _apple(canvas, line);
      case Illustration.peach:
        _peach(canvas, line);
      case Illustration.leaf:
        _leaf(canvas, line, spots: false, thick: false);
      case Illustration.leafSick:
        _leaf(canvas, line, spots: true, thick: true);
    }
    canvas.restore();
  }

  void _tomato(Canvas c, Paint p) {
    c.drawOval(Rect.fromCenter(center: const Offset(50, 58), width: 50, height: 46), p);
    // sépales
    final calyx = Path()
      ..moveTo(50, 36)
      ..quadraticBezierTo(42, 30, 33, 38)
      ..moveTo(50, 36)
      ..quadraticBezierTo(58, 30, 67, 38)
      ..moveTo(50, 36)
      ..quadraticBezierTo(44, 40, 38, 44)
      ..moveTo(50, 36)
      ..quadraticBezierTo(56, 40, 62, 44);
    c.drawPath(calyx, p);
    // tige
    c.drawLine(const Offset(50, 36), const Offset(52, 22), p);
  }

  void _potato(Canvas c, Paint p) {
    c.save();
    c.translate(50, 52);
    c.rotate(-0.12);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 56, height: 36), p);
    c.restore();
    for (final eye in const [
      Offset(41, 50),
      Offset(57, 44),
      Offset(47, 59),
      Offset(63, 55),
    ]) {
      c.drawCircle(eye, 1.9, p);
    }
  }

  void _apple(Canvas c, Paint p) {
    final body = Path()
      ..moveTo(50, 40)
      ..cubicTo(42, 33, 26, 37, 26, 56)
      ..cubicTo(26, 72, 38, 84, 47, 80)
      ..cubicTo(49.5, 79, 50.5, 79, 53, 80)
      ..cubicTo(62, 84, 74, 72, 74, 56)
      ..cubicTo(74, 37, 58, 33, 50, 40);
    c.drawPath(body, p);
    c.drawLine(const Offset(50, 40), const Offset(53, 28), p);
    final leaf = Path()
      ..moveTo(53, 33)
      ..quadraticBezierTo(58, 22, 72, 24)
      ..quadraticBezierTo(66, 36, 53, 33);
    c.drawPath(leaf, p);
  }

  void _peach(Canvas c, Paint p) {
    c.drawCircle(const Offset(48, 60), 24, p);
    final seam = Path()
      ..moveTo(48, 37)
      ..quadraticBezierTo(37, 60, 48, 83);
    c.drawPath(seam, p);
    final leaf = Path()
      ..moveTo(51, 38)
      ..quadraticBezierTo(57, 25, 74, 24)
      ..quadraticBezierTo(68, 38, 51, 38);
    c.drawPath(leaf, p);
    c.drawLine(const Offset(48, 37), const Offset(46, 27), p);
  }

  void _leaf(Canvas c, Paint p, {required bool spots, required bool thick}) {
    // La feuille « malade » (analyse, résultat) est tracée plus épaisse.
    final leafPaint = thick
        ? (Paint()
          ..color = p.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth * 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round)
        : p;

    final outline = Path()
      ..moveTo(24, 78)
      ..cubicTo(20, 46, 48, 20, 80, 22)
      ..cubicTo(82, 52, 56, 80, 24, 78);
    c.drawPath(outline, leafPaint);

    // nervure centrale
    c.drawLine(const Offset(24, 78), const Offset(66, 36), leafPaint);

    // nervures secondaires
    const veins = [
      [Offset(36, 66), Offset(34, 53)],
      [Offset(46, 56), Offset(44, 42)],
      [Offset(55, 47), Offset(55, 35)],
      [Offset(40, 62), Offset(54, 61)],
      [Offset(50, 52), Offset(64, 52)],
    ];
    for (final v in veins) {
      c.drawLine(v[0], v[1], leafPaint);
    }

    if (spots) {
      final fill = Paint()..color = AppColors.leafSpot;
      c.drawCircle(const Offset(58, 40), 4.2, fill);
      c.drawCircle(const Offset(68, 54), 2.6, fill);
      c.drawCircle(const Offset(46, 60), 5.4, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) =>
      old.kind != kind || old.color != color;
}

/// Logo : feuille dorée (en-tête de l'accueil).
class LeafLogo extends StatelessWidget {
  const LeafLogo({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 40;
    canvas.scale(unit);
    final p = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 / unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outline = Path()
      ..moveTo(7, 33)
      ..cubicTo(4, 18, 16, 6, 33, 6)
      ..cubicTo(34, 22, 22, 34, 7, 33);
    canvas.drawPath(outline, p);
    canvas.drawLine(const Offset(7, 33), const Offset(27, 13), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
