import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Design system « herbier de nuit » (handoff §7).
class AppColors {
  AppColors._();

  static const background = Color(0xFF0E1712);
  static const surface = Color(0xFF16221B);
  static const surfaceAlt = Color(0xFF121E17);
  static const illustrationBg = Color(0xFF1D2B23);
  static const ivory = Color(0xFFF3EFE6);
  static const textSecondary = Color(0xFFA8B3AA);
  static const textSoft = Color(0xFFD6D0C3);
  static const gold = Color(0xFFC9A96E);
  static const goldLight = Color(0xFFE2C68F);
  static const track = Color(0xFF2A3830);
  static const onGold = Color(0xFF0E1712);

  static const diseaseBadgeBg = Color(0xFF3A2A1A);
  static const diseaseBadgeText = Color(0xFFF0C98A);
  static const healthyBadgeBg = Color(0xFF1B3426);
  static const healthyBadgeText = Color(0xFF9ED3A9);
  static const uncertainBadgeBg = Color(0xFF2A2F36);
  static const uncertainBadgeText = Color(0xFFC3CBD6);

  /// Vert sauge des illustrations de feuille.
  static const leafGreen = Color(0xFF7FA98A);
  static const leafSpot = Color(0xFF7A5A3A);

  static Color get borderSoft => gold.withValues(alpha: 0.18);
  static Color get border => gold.withValues(alpha: 0.30);
}

/// Familles de polices (déclarées dans pubspec.yaml, embarquées : l'app est hors ligne).
const String kSerif = 'CormorantGaramond';
const String kSans = 'Inter';

class AppText {
  AppText._();

  /// Titres d'écran (34–40 px, 500).
  static const title = TextStyle(
    fontFamily: kSerif,
    fontSize: 38,
    fontWeight: FontWeight.w500,
    height: 1.08,
    color: AppColors.ivory,
  );

  /// Nom de plante / de maladie (24–34 px, 600).
  static const name = TextStyle(
    fontFamily: kSerif,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: AppColors.ivory,
  );

  static const diseaseName = TextStyle(
    fontFamily: kSerif,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 1.05,
    color: AppColors.ivory,
  );

  static const body = TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const bodySoft = TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSoft,
  );

  static const bodyStrong = TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.ivory,
  );

  static const caption = TextStyle(
    fontFamily: kSans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Sur-titres (« ÉTAPE 1 SUR 2 ») : 11 px, 500, majuscules, 2,4 px, or.
  static const overline = TextStyle(
    fontFamily: kSans,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.4,
    height: 1.2,
    color: AppColors.gold,
  );

  static const button = TextStyle(
    fontFamily: kSans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.onGold,
  );

  static const buttonOutline = TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.ivory,
  );

  /// Grand pourcentage doré de la carte « Confiance ».
  static const percent = TextStyle(
    fontFamily: kSerif,
    fontSize: 40,
    fontWeight: FontWeight.w500,
    height: 1,
    color: AppColors.gold,
    // Chiffres alignés : les chiffres elzéviriens de Cormorant lisent « 100 » comme « IOO ».
    fontFeatures: [FontFeature.liningFigures()],
  );
}

/// Marges et rayons (handoff §7).
class AppSpacing {
  AppSpacing._();

  static const double screenSide = 24;
  static const double screenTop = 56;
  static const double cardRadius = 22;
  static const double buttonRadius = 18;
  static const double secondaryButtonRadius = 16;
  static const double dropZoneRadius = 24;
}

ThemeData buildAppTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.onGold,
      surface: AppColors.surface,
      onSurface: AppColors.ivory,
      secondary: AppColors.goldLight,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      fontFamily: kSans,
      bodyColor: AppColors.ivory,
      displayColor: AppColors.ivory,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
