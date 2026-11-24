import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Bouton principal : hauteur 56, fond or, texte vert-noir, graisse 600.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            onTap: onPressed,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: AppText.button),
                  if (icon != null) ...[
                    const SizedBox(width: 10),
                    Icon(icon, size: 20, color: AppColors.onGold),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire : hauteur 52, fond surface, bordure dorée fine.
class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.secondaryButtonRadius),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.secondaryButtonRadius),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 21, color: AppColors.gold),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppText.buttonOutline,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond 44×44 à bordure dorée (retour, fermer, infos).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: AppColors.ivory),
          ),
        ),
      ),
    );
  }
}

/// Sur-titre doré en majuscules (« ÉTAPE 1 SUR 2 »).
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: color == null ? AppText.overline : AppText.overline.copyWith(color: color),
    );
  }
}

/// Carte standard : surface, rayon 22, bordure dorée 18 %.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = AppColors.surface,
    this.radius = AppSpacing.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: child,
    );
  }
}

/// Badge arrondi (« Maladie détectée », « Aucune maladie détectée »…).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Barre de progression/probabilité (piste #2A3830, remplissage or).
class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color = AppColors.gold,
    this.trackColor = AppColors.track,
  });

  final double value;
  final double height;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            Container(height: height, color: trackColor),
            FractionallySizedBox(
              widthFactor: t,
              child: Container(
                height: height,
                // Un point minimal reste visible pour les très petites valeurs.
                constraints: BoxConstraints(minWidth: v > 0 ? height : 0),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cadre à bordure dorée en pointillés (zone d'aperçu de l'écran 2).
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    this.radius = AppSpacing.dropZoneRadius,
    this.color,
    this.fill = AppColors.surfaceAlt,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        radius: radius,
        color: color ?? AppColors.gold.withValues(alpha: 0.55),
        fill: fill,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.radius,
    required this.color,
    required this.fill,
  });

  final double radius;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.75);
    canvas.drawRRect(rrect, Paint()..color = fill);

    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.radius != radius || old.color != color || old.fill != fill;
}

/// Quatre coins dorés de « visée » (écran d'analyse et écran caméra).
class CornerBrackets extends StatelessWidget {
  const CornerBrackets({
    super.key,
    this.inset = 16,
    this.length = 26,
    this.thickness = 2.2,
    this.radius = 6,
    this.color = AppColors.gold,
  });

  final double inset;
  final double length;
  final double thickness;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BracketsPainter(inset, length, thickness, radius, color),
      ),
    );
  }
}

class _BracketsPainter extends CustomPainter {
  _BracketsPainter(this.inset, this.length, this.thickness, this.radius, this.color);

  final double inset;
  final double length;
  final double thickness;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final l = inset;
    final t = inset;
    final r = size.width - inset;
    final b = size.height - inset;
    final k = length;
    final c = radius;

    // haut-gauche
    canvas.drawPath(
      Path()
        ..moveTo(l, t + k)
        ..lineTo(l, t + c)
        ..quadraticBezierTo(l, t, l + c, t)
        ..lineTo(l + k, t),
      paint,
    );
    // haut-droite
    canvas.drawPath(
      Path()
        ..moveTo(r - k, t)
        ..lineTo(r - c, t)
        ..quadraticBezierTo(r, t, r, t + c)
        ..lineTo(r, t + k),
      paint,
    );
    // bas-gauche
    canvas.drawPath(
      Path()
        ..moveTo(l, b - k)
        ..lineTo(l, b - c)
        ..quadraticBezierTo(l, b, l + c, b)
        ..lineTo(l + k, b),
      paint,
    );
    // bas-droite
    canvas.drawPath(
      Path()
        ..moveTo(r - k, b)
        ..lineTo(r - c, b)
        ..quadraticBezierTo(r, b, r, b - c)
        ..lineTo(r, b - k),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BracketsPainter old) =>
      old.inset != inset ||
      old.length != length ||
      old.thickness != thickness ||
      old.radius != radius ||
      old.color != color;
}

/// Zone d'écran avec les marges standard (24 px côtés, 56 px haut).
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.child,
    this.bottom,
    this.scrollable = true,
  });

  final Widget child;

  /// Zone fixe en bas (bouton principal).
  final Widget? bottom;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topPad = top > AppSpacing.screenTop - 12 ? top + 12 : AppSpacing.screenTop;

    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenSide,
        topPad,
        AppSpacing.screenSide,
        0,
      ),
      child: child,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: body,
                  )
                : body,
          ),
          if (bottom != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenSide,
                12,
                AppSpacing.screenSide,
                bottomInset > 0 ? bottomInset : 20,
              ),
              child: bottom,
            ),
        ],
      ),
    );
  }
}
