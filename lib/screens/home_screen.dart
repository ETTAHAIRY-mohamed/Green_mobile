import 'package:flutter/material.dart';

import '../data/plants.dart';
import '../theme/app_theme.dart';
import '../theme/illustrations.dart' show LeafLogo;
import '../theme/plant_image.dart';
import '../theme/widgets.dart';
import 'history_screen.dart';
import 'upload_screen.dart';

/// Écran 1 — Accueil : choix de la plante.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const plants = Plant.all;
    return ScreenScaffold(
      bottom: const _PrivacyNote(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LeafLogo(size: 34),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PlantCare',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ivory,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RoundIconButton(
                icon: Icons.history,
                semanticLabel: 'Historique',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => HistoryScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _Reveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Overline('Diagnostic hors ligne'),
                SizedBox(height: 12),
                Text('Quelle plante\nexaminons-nous ?', style: AppText.title),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Reveal(
            delay: 120,
            child: Text(
              'Choisissez la plante, ajoutez une photo de feuille et obtenez un '
              'diagnostic en quelques secondes.',
              style: AppText.body.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          for (var row = 0; row < plants.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _PlantCard(plant: plants[row], index: row)),
                  const SizedBox(width: 14),
                  Expanded(child: _PlantCard(plant: plants[row + 1], index: row + 1)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Apparition douce (fondu + léger glissement) du bloc de titre.
/// Sans effet si l'utilisateur a réduit les animations.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child, this.delay = 0});

  final Widget child;

  /// Retard en millisecondes (le fondu démarre après ce délai).
  final int delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    const base = 600;
    final total = base + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final p = Curves.easeOutCubic.transform(
          ((t * total - delay) / base).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 14 * (1 - p)), child: child),
        );
      },
      child: child,
    );
  }
}

/// Carte d'une plante, avec photo détourée et animations :
/// - entrée en cascade (la carte monte en fondu, puis le fruit « tombe » avec
///   un léger rebond) ;
/// - flottement continu du fruit (translation + légère rotation) avec ombre au
///   sol qui s'adapte à la hauteur ;
/// - réaction au toucher (la carte s'enfonce, le fruit grossit).
///
/// Toutes les animations sont coupées si le système demande de réduire les mouvements.
class _PlantCard extends StatefulWidget {
  const _PlantCard({required this.plant, required this.index});

  final Plant plant;
  final int index;

  @override
  State<_PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<_PlantCard> with TickerProviderStateMixin {
  static const int _staggerMs = 110;
  static const int _entranceMs = 950;

  late final AnimationController _enter;
  late final AnimationController _float;
  late final Animation<double> _cardProgress;
  late final Animation<double> _fruitScale;
  late final Animation<double> _fruitFade;

  bool _started = false;
  bool _pressed = false;

  int get _delayMs => widget.index * _staggerMs;
  double get _totalMs => (_entranceMs + _delayMs).toDouble();

  /// Segment de la timeline d'entrée [from, to] (ms, après le retard de la carte).
  Animation<double> _slice(double from, double to, Curve curve) {
    return CurvedAnimation(
      parent: _enter,
      curve: Interval((_delayMs + from) / _totalMs, (_delayMs + to) / _totalMs, curve: curve),
    );
  }

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs.round()),
    );
    // Chaque fruit flotte à son rythme et à son propre moment du cycle.
    _float = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3200 + widget.index * 420),
      value: (widget.index * 0.29) % 1,
    );
    _cardProgress = _slice(0, 560, Curves.easeOutCubic);
    _fruitFade = _slice(260, 620, Curves.easeOut);
    _fruitScale = _slice(260, 950, Curves.easeOutBack);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _enter.value = 1;
      _float.stop();
    } else if (!_started) {
      _started = true;
      _enter.forward();
      _float.repeat(reverse: true);
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
    super.dispose();
  }

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => UploadScreen(plant: widget.plant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final card = AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Semantics(
        button: true,
        label: plant.nameFr,
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            side: BorderSide(
              color: _pressed ? AppColors.border : AppColors.borderSoft,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            onTap: _open,
            onHighlightChanged: (down) => setState(() => _pressed = down),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FruitStage(
                    plant: plant,
                    float: _float,
                    fruitScale: _fruitScale,
                    fruitFade: _fruitFade,
                    pressed: _pressed,
                    animate: !reduce,
                  ),
                  const SizedBox(height: 14),
                  Text(plant.nameFr, style: AppText.name.copyWith(fontSize: 26)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (reduce) return card;
    return FadeTransition(
      opacity: _cardProgress,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(_cardProgress),
        child: card,
      ),
    );
  }
}

/// Zone illustrée de la carte : fond doux, ombre au sol, fruit flottant.
class _FruitStage extends StatelessWidget {
  const _FruitStage({
    required this.plant,
    required this.float,
    required this.fruitScale,
    required this.fruitFade,
    required this.pressed,
    required this.animate,
  });

  final Plant plant;
  final Animation<double> float;
  final Animation<double> fruitScale;
  final Animation<double> fruitFade;
  final bool pressed;
  final bool animate;

  static const double _height = 94;

  @override
  Widget build(BuildContext context) {
    Widget fruit = Hero(
      tag: plantHeroTag(plant),
      child: PlantImage(plant, width: 102, height: 70),
    );
    fruit = AnimatedScale(
      scale: pressed ? 1.12 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: fruit,
    );

    return Container(
      height: _height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Léger halo central : le fruit se détache du fond.
        gradient: const RadialGradient(
          center: Alignment(0, 0.15),
          radius: 0.95,
          colors: [Color(0xFF273A30), AppColors.illustrationBg],
        ),
      ),
      child: AnimatedBuilder(
        animation: float,
        builder: (context, child) {
          // t : 0 = fruit en bas, 1 = fruit en haut du flottement.
          final t = animate ? Curves.easeInOut.transform(float.value) : 0.5;
          final dy = 2.5 - 5.5 * t;
          final angle = (t - 0.5) * 0.06;
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Ombre au sol : plus petite et plus pâle quand le fruit monte.
              Positioned(
                bottom: 9,
                child: Opacity(
                  opacity: fruitFade.value,
                  child: Transform.scale(
                    scaleX: 1.0 - 0.18 * t,
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.elliptical(23, 2.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.40 - 0.16 * t),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                child: Opacity(
                  opacity: fruitFade.value,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(
                      angle: angle,
                      child: Transform.scale(
                        scale: animate ? fruitScale.value.clamp(0.0, 1.2) : 1,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: fruit,
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 22, color: AppColors.gold),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Vos photos restent sur votre téléphone. L\'analyse fonctionne '
              'sans connexion.',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
