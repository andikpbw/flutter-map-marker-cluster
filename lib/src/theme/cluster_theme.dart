import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// Formats a cluster's marker [count] into a compact human-readable label
/// (for example: `42`, `1.2k`, `18k`, `2.4M`).
String defaultClusterCountFormatter(int count) {
  if (count < 1000) {
    return '$count';
  }
  if (count < 10000) {
    final value = count / 1000.0;
    final formatted = value.toStringAsFixed(1);
    return formatted.endsWith('.0')
        ? '${formatted.substring(0, formatted.length - 2)}k'
        : '${formatted}k';
  }
  if (count < 1000000) {
    return '${(count / 1000).round()}k';
  }
  final millions = count / 1000000.0;
  final formatted = millions.toStringAsFixed(1);
  return formatted.endsWith('.0')
      ? '${formatted.substring(0, formatted.length - 2)}M'
      : '${formatted}M';
}

/// Visual styling for a single size/density bucket of cluster badges.
@immutable
class ClusterTier {
  /// Creates a [ClusterTier].
  const ClusterTier({
    required this.minCount,
    required this.diameter,
    required this.gradientColors,
    required this.haloColor,
    this.textColor = const Color(0xFFFFFFFF),
    this.fontSize = 13.0,
  }) : assert(minCount >= 2, 'minCount must be at least 2.'),
       assert(diameter > 0.0, 'diameter must be positive.');

  /// Minimum marker count required to activate this tier.
  final int minCount;

  /// Core badge diameter in logical pixels (excluding outer halo).
  final double diameter;

  /// Diagonal linear gradient colors filling the cluster core.
  final List<Color> gradientColors;

  /// Translucent outer halo ring color.
  final Color haloColor;

  /// Foreground count label color.
  final Color textColor;

  /// Font size for the count label inside the badge.
  final double fontSize;

  /// Guaranteed list of at least two gradient colors suitable for
  /// [LinearGradient].
  List<Color> get resolvedGradientColors {
    if (gradientColors.length >= 2) {
      return gradientColors;
    }
    if (gradientColors.length == 1) {
      return <Color>[gradientColors.first, gradientColors.first];
    }
    return <Color>[haloColor, haloColor];
  }

  /// Linearly interpolates between two [ClusterTier] instances.
  static ClusterTier lerp(ClusterTier a, ClusterTier b, double t) {
    final gradA = a.resolvedGradientColors;
    final gradB = b.resolvedGradientColors;
    final primaryA = gradA.first;
    final secondaryA = gradA.last;
    final primaryB = gradB.first;
    final secondaryB = gradB.last;
    return ClusterTier(
      minCount: t < 0.5 ? a.minCount : b.minCount,
      diameter: lerpDouble(a.diameter, b.diameter, t) ?? b.diameter,
      gradientColors: <Color>[
        Color.lerp(primaryA, primaryB, t) ?? primaryB,
        Color.lerp(secondaryA, secondaryB, t) ?? secondaryB,
      ],
      haloColor: Color.lerp(a.haloColor, b.haloColor, t) ?? b.haloColor,
      textColor: Color.lerp(a.textColor, b.textColor, t) ?? b.textColor,
      fontSize: lerpDouble(a.fontSize, b.fontSize, t) ?? b.fontSize,
    );
  }

  /// Returns a copy of this tier with overridden fields.
  ClusterTier copyWith({
    int? minCount,
    double? diameter,
    List<Color>? gradientColors,
    Color? haloColor,
    Color? textColor,
    double? fontSize,
  }) {
    return ClusterTier(
      minCount: minCount ?? this.minCount,
      diameter: diameter ?? this.diameter,
      gradientColors: gradientColors ?? this.gradientColors,
      haloColor: haloColor ?? this.haloColor,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ClusterTier &&
        other.minCount == minCount &&
        other.diameter == diameter &&
        other.haloColor == haloColor &&
        other.textColor == textColor &&
        other.fontSize == fontSize &&
        _colorListsEqual(other.gradientColors, gradientColors);
  }

  @override
  int get hashCode => Object.hash(
    minCount,
    diameter,
    Object.hashAll(gradientColors),
    haloColor,
    textColor,
    fontSize,
  );

  static bool _colorListsEqual(List<Color> a, List<Color> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Complete visual theme governing default cluster badges, individual marker
/// pins, spiderfy legs, floating callout cards, and motion curves.
///
/// Built entirely on top of `package:flutter/widgets.dart` with zero Material
/// or Cupertino dependencies, making it lightweight and forward-compatible
/// across all Flutter SDK versions.
@immutable
class ClusterThemeData {
  /// Creates a custom [ClusterThemeData].
  const ClusterThemeData({
    required this.tiers,
    required this.markerColor,
    required this.markerSelectedColor,
    required this.markerBorderColor,
    required this.markerInnerDotColor,
    required this.badgeBorderColor,
    required this.shadowColor,
    required this.spiderLegColor,
    required this.spiderCenterColor,
    required this.calloutBackgroundColor,
    required this.calloutBorderColor,
    required this.calloutTitleColor,
    required this.calloutSubtitleColor,
    required this.calloutBadgeBackground,
    required this.calloutBadgeTextColor,
    this.badgeBorderWidth = 2.5,
    this.showHalo = true,
    this.haloSpread = 10.0,
    this.haloOpacity = 0.28,
    this.pulseAnimation = true,
    this.pulseDuration = const Duration(milliseconds: 2200),
    this.markerSize = 36.0,
    this.spiderLegWidth = 2.0,
    this.curvedSpiderLegs = true,
    this.calloutBorderRadius = 16.0,
    this.calloutMaxWidth = 252.0,
    this.transitionDuration = const Duration(milliseconds: 340),
    this.transitionCurve = Curves.easeOutCubic,
    this.fontFamily,
    this.countFormatter = defaultClusterCountFormatter,
  });

  /// Vibrant contemporary light-mode theme featuring indigo, violet, rose, and
  /// sunset-amber tiers with soft glowing halos and frosted callout cards.
  factory ClusterThemeData.modern({
    bool pulseAnimation = true,
    String? fontFamily,
  }) {
    return ClusterThemeData(
      tiers: const <ClusterTier>[
        ClusterTier(
          minCount: 2,
          diameter: 42.0,
          gradientColors: <Color>[Color(0xFF4F46E5), Color(0xFF06B6D4)],
          haloColor: Color(0xFF4F46E5),
        ),
        ClusterTier(
          minCount: 10,
          diameter: 50.0,
          gradientColors: <Color>[Color(0xFF7C3AED), Color(0xFFEC4899)],
          haloColor: Color(0xFF8B5CF6),
          fontSize: 14.0,
        ),
        ClusterTier(
          minCount: 40,
          diameter: 58.0,
          gradientColors: <Color>[Color(0xFFE11D48), Color(0xFFF97316)],
          haloColor: Color(0xFFF43F5E),
          fontSize: 15.0,
        ),
        ClusterTier(
          minCount: 150,
          diameter: 66.0,
          gradientColors: <Color>[Color(0xFFD97706), Color(0xFFEF4444)],
          haloColor: Color(0xFFF59E0B),
          fontSize: 16.0,
        ),
      ],
      markerColor: const Color(0xFF4F46E5),
      markerSelectedColor: const Color(0xFFEC4899),
      markerBorderColor: const Color(0xFFFFFFFF),
      markerInnerDotColor: const Color(0xFFFFFFFF),
      badgeBorderColor: const Color(0xFFFFFFFF),
      shadowColor: const Color(0xFF0F172A),
      spiderLegColor: const Color(0xFF6366F1),
      spiderCenterColor: const Color(0xFF4F46E5),
      calloutBackgroundColor: const Color(0xF7FFFFFF),
      calloutBorderColor: const Color(0xFFE2E8F0),
      calloutTitleColor: const Color(0xFF0F172A),
      calloutSubtitleColor: const Color(0xFF475569),
      calloutBadgeBackground: const Color(0xFFEEF2FF),
      calloutBadgeTextColor: const Color(0xFF4338CA),
      pulseAnimation: pulseAnimation,
      fontFamily: fontFamily,
    );
  }

  /// High-contrast midnight neon theme crafted for dark maps and dashboards.
  factory ClusterThemeData.dark({
    bool pulseAnimation = true,
    String? fontFamily,
  }) {
    return ClusterThemeData(
      tiers: const <ClusterTier>[
        ClusterTier(
          minCount: 2,
          diameter: 42.0,
          gradientColors: <Color>[Color(0xFF06B6D4), Color(0xFF3B82F6)],
          haloColor: Color(0xFF22D3EE),
        ),
        ClusterTier(
          minCount: 10,
          diameter: 50.0,
          gradientColors: <Color>[Color(0xFF8B5CF6), Color(0xFFD946EF)],
          haloColor: Color(0xFFC084FC),
          fontSize: 14.0,
        ),
        ClusterTier(
          minCount: 40,
          diameter: 58.0,
          gradientColors: <Color>[Color(0xFFEC4899), Color(0xFFF43F5E)],
          haloColor: Color(0xFFFB7185),
          fontSize: 15.0,
        ),
        ClusterTier(
          minCount: 150,
          diameter: 66.0,
          gradientColors: <Color>[Color(0xFFF59E0B), Color(0xFFFB923C)],
          haloColor: Color(0xFFFBBF24),
          fontSize: 16.0,
        ),
      ],
      markerColor: const Color(0xFF22D3EE),
      markerSelectedColor: const Color(0xFFF472B6),
      markerBorderColor: const Color(0xFF0F172A),
      markerInnerDotColor: const Color(0xFF0F172A),
      badgeBorderColor: const Color(0xFF0F172A),
      shadowColor: const Color(0xFF020617),
      spiderLegColor: const Color(0xFF38BDF8),
      spiderCenterColor: const Color(0xFF22D3EE),
      calloutBackgroundColor: const Color(0xF20F172A),
      calloutBorderColor: const Color(0xFF334155),
      calloutTitleColor: const Color(0xFFF8FAFC),
      calloutSubtitleColor: const Color(0xFF94A3B8),
      calloutBadgeBackground: const Color(0xFF1E293B),
      calloutBadgeTextColor: const Color(0xFF38BDF8),
      haloOpacity: 0.34,
      haloSpread: 12.0,
      pulseAnimation: pulseAnimation,
      fontFamily: fontFamily,
    );
  }

  /// Sleek monochrome obsidian theme inspired by minimalist editorial maps.
  factory ClusterThemeData.minimal({
    bool pulseAnimation = false,
    String? fontFamily,
  }) {
    return ClusterThemeData(
      tiers: const <ClusterTier>[
        ClusterTier(
          minCount: 2,
          diameter: 40.0,
          gradientColors: <Color>[Color(0xFF334155), Color(0xFF1E293B)],
          haloColor: Color(0xFF64748B),
        ),
        ClusterTier(
          minCount: 10,
          diameter: 48.0,
          gradientColors: <Color>[Color(0xFF1E293B), Color(0xFF0F172A)],
          haloColor: Color(0xFF475569),
          fontSize: 14.0,
        ),
        ClusterTier(
          minCount: 40,
          diameter: 56.0,
          gradientColors: <Color>[Color(0xFF0F172A), Color(0xFF020617)],
          haloColor: Color(0xFF334155),
          fontSize: 15.0,
        ),
      ],
      markerColor: const Color(0xFF0F172A),
      markerSelectedColor: const Color(0xFF2563EB),
      markerBorderColor: const Color(0xFFFFFFFF),
      markerInnerDotColor: const Color(0xFFFFFFFF),
      badgeBorderColor: const Color(0xFFFFFFFF),
      shadowColor: const Color(0xFF020617),
      spiderLegColor: const Color(0xFF475569),
      spiderCenterColor: const Color(0xFF0F172A),
      calloutBackgroundColor: const Color(0xFAFFFFFF),
      calloutBorderColor: const Color(0xFFCBD5E1),
      calloutTitleColor: const Color(0xFF0F172A),
      calloutSubtitleColor: const Color(0xFF475569),
      calloutBadgeBackground: const Color(0xFFF1F5F9),
      calloutBadgeTextColor: const Color(0xFF0F172A),
      haloOpacity: 0.18,
      haloSpread: 8.0,
      pulseAnimation: pulseAnimation,
      fontFamily: fontFamily,
    );
  }

  /// Fresh emerald-to-teal theme suited for mobility, real estate, and travel
  /// applications.
  factory ClusterThemeData.emerald({
    bool pulseAnimation = true,
    String? fontFamily,
  }) {
    return ClusterThemeData(
      tiers: const <ClusterTier>[
        ClusterTier(
          minCount: 2,
          diameter: 42.0,
          gradientColors: <Color>[Color(0xFF10B981), Color(0xFF06B6D4)],
          haloColor: Color(0xFF10B981),
        ),
        ClusterTier(
          minCount: 10,
          diameter: 50.0,
          gradientColors: <Color>[Color(0xFF059669), Color(0xFF0284C7)],
          haloColor: Color(0xFF14B8A6),
          fontSize: 14.0,
        ),
        ClusterTier(
          minCount: 40,
          diameter: 58.0,
          gradientColors: <Color>[Color(0xFF0D9488), Color(0xFFF59E0B)],
          haloColor: Color(0xFFF59E0B),
          fontSize: 15.0,
        ),
      ],
      markerColor: const Color(0xFF059669),
      markerSelectedColor: const Color(0xFFD97706),
      markerBorderColor: const Color(0xFFFFFFFF),
      markerInnerDotColor: const Color(0xFFFFFFFF),
      badgeBorderColor: const Color(0xFFFFFFFF),
      shadowColor: const Color(0xFF064E3B),
      spiderLegColor: const Color(0xFF10B981),
      spiderCenterColor: const Color(0xFF059669),
      calloutBackgroundColor: const Color(0xF8FFFFFF),
      calloutBorderColor: const Color(0xFFD1FAE5),
      calloutTitleColor: const Color(0xFF064E3B),
      calloutSubtitleColor: const Color(0xFF047857),
      calloutBadgeBackground: const Color(0xFFECFDF5),
      calloutBadgeTextColor: const Color(0xFF047857),
      pulseAnimation: pulseAnimation,
      fontFamily: fontFamily,
    );
  }

  /// Density tiers ordered by [ClusterTier.minCount] ascending.
  final List<ClusterTier> tiers;

  /// Default fill color for individual marker pins.
  final Color markerColor;

  /// Fill color applied when an individual marker pin is selected.
  final Color markerSelectedColor;

  /// Outer stroke color around individual marker pins.
  final Color markerBorderColor;

  /// Inner center dot color inside individual marker pins.
  final Color markerInnerDotColor;

  /// Crisp border stroke color around cluster badges.
  final Color badgeBorderColor;

  /// Width of the border stroke around cluster badges.
  final double badgeBorderWidth;

  /// Base elevation drop-shadow color.
  final Color shadowColor;

  /// Whether cluster badges display a translucent outer halo ring.
  final bool showHalo;

  /// Extra radial spread of the translucent outer halo in logical pixels.
  final double haloSpread;

  /// Peak alpha opacity of the outer halo ring (`0.0` to `1.0`).
  final double haloOpacity;

  /// Whether cluster badges play a subtle breathing radar pulse animation.
  final bool pulseAnimation;

  /// Cycle duration for the cluster halo pulse animation.
  final Duration pulseDuration;

  /// Default logical pixel height for individual marker pins.
  final double markerSize;

  /// Color of lines connecting spiderfied markers back to the cluster anchor.
  final Color spiderLegColor;

  /// Stroke width of spiderfy leg connectors.
  final double spiderLegWidth;

  /// Color of the central anchor node visible while a cluster is spiderfied.
  final Color spiderCenterColor;

  /// Whether spiderfy legs render as smooth quadratic Bezier curves (`true`)
  /// or straight lines (`false`).
  final bool curvedSpiderLegs;

  /// Surface background color of the default floating marker callout card.
  final Color calloutBackgroundColor;

  /// Border color of the default floating marker callout card.
  final Color calloutBorderColor;

  /// Primary title text color inside the default callout card.
  final Color calloutTitleColor;

  /// Secondary subtitle text color inside the default callout card.
  final Color calloutSubtitleColor;

  /// Background pill color for the category badge inside default callouts.
  final Color calloutBadgeBackground;

  /// Text color for the category badge inside default callouts.
  final Color calloutBadgeTextColor;

  /// Corner radius of the default floating callout card.
  final double calloutBorderRadius;

  /// Maximum width of the default floating callout card in logical pixels.
  final double calloutMaxWidth;

  /// Duration used for cluster split/merge and spiderfy animations.
  final Duration transitionDuration;

  /// Easing curve used for cluster split/merge and spiderfy animations.
  final Curve transitionCurve;

  /// Optional font family applied to default cluster count badges and callouts.
  final String? fontFamily;

  /// Formatter converting a cluster's integer count into a compact label.
  final String Function(int count) countFormatter;

  /// Resolves the highest matching [ClusterTier] for a cluster containing
  /// [count] markers.
  ClusterTier tierForCount(int count) {
    if (tiers.isEmpty) {
      return ClusterTier(
        minCount: 2,
        diameter: 44.0,
        gradientColors: <Color>[markerColor, markerSelectedColor],
        haloColor: markerColor,
      );
    }
    var selected = tiers.first;
    for (final tier in tiers) {
      if (count >= tier.minCount && tier.minCount >= selected.minCount) {
        selected = tier;
      }
    }
    return selected;
  }

  /// Linearly interpolates between two [ClusterThemeData] themes at [t].
  static ClusterThemeData lerp(
    ClusterThemeData a,
    ClusterThemeData b,
    double t,
  ) {
    final tiersA = a.tiers.isEmpty ? <ClusterTier>[a.tierForCount(2)] : a.tiers;
    final tiersB = b.tiers.isEmpty ? <ClusterTier>[b.tierForCount(2)] : b.tiers;
    final maxTierCount = tiersA.length >= tiersB.length
        ? tiersA.length
        : tiersB.length;
    final blendedTiers = <ClusterTier>[
      for (var i = 0; i < maxTierCount; i++)
        ClusterTier.lerp(
          tiersA[i < tiersA.length ? i : tiersA.length - 1],
          tiersB[i < tiersB.length ? i : tiersB.length - 1],
          t,
        ),
    ];

    return ClusterThemeData(
      tiers: blendedTiers,
      markerColor: Color.lerp(a.markerColor, b.markerColor, t) ?? b.markerColor,
      markerSelectedColor:
          Color.lerp(a.markerSelectedColor, b.markerSelectedColor, t) ??
          b.markerSelectedColor,
      markerBorderColor:
          Color.lerp(a.markerBorderColor, b.markerBorderColor, t) ??
          b.markerBorderColor,
      markerInnerDotColor:
          Color.lerp(a.markerInnerDotColor, b.markerInnerDotColor, t) ??
          b.markerInnerDotColor,
      badgeBorderColor:
          Color.lerp(a.badgeBorderColor, b.badgeBorderColor, t) ??
          b.badgeBorderColor,
      badgeBorderWidth:
          lerpDouble(a.badgeBorderWidth, b.badgeBorderWidth, t) ??
          b.badgeBorderWidth,
      shadowColor: Color.lerp(a.shadowColor, b.shadowColor, t) ?? b.shadowColor,
      showHalo: t < 0.5 ? a.showHalo : b.showHalo,
      haloSpread: lerpDouble(a.haloSpread, b.haloSpread, t) ?? b.haloSpread,
      haloOpacity: lerpDouble(a.haloOpacity, b.haloOpacity, t) ?? b.haloOpacity,
      pulseAnimation: t < 0.5 ? a.pulseAnimation : b.pulseAnimation,
      pulseDuration: t < 0.5 ? a.pulseDuration : b.pulseDuration,
      markerSize: lerpDouble(a.markerSize, b.markerSize, t) ?? b.markerSize,
      spiderLegColor:
          Color.lerp(a.spiderLegColor, b.spiderLegColor, t) ?? b.spiderLegColor,
      spiderLegWidth:
          lerpDouble(a.spiderLegWidth, b.spiderLegWidth, t) ?? b.spiderLegWidth,
      spiderCenterColor:
          Color.lerp(a.spiderCenterColor, b.spiderCenterColor, t) ??
          b.spiderCenterColor,
      curvedSpiderLegs: t < 0.5 ? a.curvedSpiderLegs : b.curvedSpiderLegs,
      calloutBackgroundColor:
          Color.lerp(a.calloutBackgroundColor, b.calloutBackgroundColor, t) ??
          b.calloutBackgroundColor,
      calloutBorderColor:
          Color.lerp(a.calloutBorderColor, b.calloutBorderColor, t) ??
          b.calloutBorderColor,
      calloutTitleColor:
          Color.lerp(a.calloutTitleColor, b.calloutTitleColor, t) ??
          b.calloutTitleColor,
      calloutSubtitleColor:
          Color.lerp(a.calloutSubtitleColor, b.calloutSubtitleColor, t) ??
          b.calloutSubtitleColor,
      calloutBadgeBackground:
          Color.lerp(a.calloutBadgeBackground, b.calloutBadgeBackground, t) ??
          b.calloutBadgeBackground,
      calloutBadgeTextColor:
          Color.lerp(a.calloutBadgeTextColor, b.calloutBadgeTextColor, t) ??
          b.calloutBadgeTextColor,
      calloutBorderRadius:
          lerpDouble(a.calloutBorderRadius, b.calloutBorderRadius, t) ??
          b.calloutBorderRadius,
      calloutMaxWidth:
          lerpDouble(a.calloutMaxWidth, b.calloutMaxWidth, t) ??
          b.calloutMaxWidth,
      transitionDuration: t < 0.5 ? a.transitionDuration : b.transitionDuration,
      transitionCurve: t < 0.5 ? a.transitionCurve : b.transitionCurve,
      fontFamily: t < 0.5 ? a.fontFamily : b.fontFamily,
      countFormatter: t < 0.5 ? a.countFormatter : b.countFormatter,
    );
  }

  /// Returns a copy of this theme with selected fields overridden.
  ClusterThemeData copyWith({
    List<ClusterTier>? tiers,
    Color? markerColor,
    Color? markerSelectedColor,
    Color? markerBorderColor,
    Color? markerInnerDotColor,
    Color? badgeBorderColor,
    double? badgeBorderWidth,
    Color? shadowColor,
    bool? showHalo,
    double? haloSpread,
    double? haloOpacity,
    bool? pulseAnimation,
    Duration? pulseDuration,
    double? markerSize,
    Color? spiderLegColor,
    double? spiderLegWidth,
    Color? spiderCenterColor,
    bool? curvedSpiderLegs,
    Color? calloutBackgroundColor,
    Color? calloutBorderColor,
    Color? calloutTitleColor,
    Color? calloutSubtitleColor,
    Color? calloutBadgeBackground,
    Color? calloutBadgeTextColor,
    double? calloutBorderRadius,
    double? calloutMaxWidth,
    Duration? transitionDuration,
    Curve? transitionCurve,
    String? fontFamily,
    String Function(int count)? countFormatter,
  }) {
    return ClusterThemeData(
      tiers: tiers ?? this.tiers,
      markerColor: markerColor ?? this.markerColor,
      markerSelectedColor: markerSelectedColor ?? this.markerSelectedColor,
      markerBorderColor: markerBorderColor ?? this.markerBorderColor,
      markerInnerDotColor: markerInnerDotColor ?? this.markerInnerDotColor,
      badgeBorderColor: badgeBorderColor ?? this.badgeBorderColor,
      badgeBorderWidth: badgeBorderWidth ?? this.badgeBorderWidth,
      shadowColor: shadowColor ?? this.shadowColor,
      showHalo: showHalo ?? this.showHalo,
      haloSpread: haloSpread ?? this.haloSpread,
      haloOpacity: haloOpacity ?? this.haloOpacity,
      pulseAnimation: pulseAnimation ?? this.pulseAnimation,
      pulseDuration: pulseDuration ?? this.pulseDuration,
      markerSize: markerSize ?? this.markerSize,
      spiderLegColor: spiderLegColor ?? this.spiderLegColor,
      spiderLegWidth: spiderLegWidth ?? this.spiderLegWidth,
      spiderCenterColor: spiderCenterColor ?? this.spiderCenterColor,
      curvedSpiderLegs: curvedSpiderLegs ?? this.curvedSpiderLegs,
      calloutBackgroundColor:
          calloutBackgroundColor ?? this.calloutBackgroundColor,
      calloutBorderColor: calloutBorderColor ?? this.calloutBorderColor,
      calloutTitleColor: calloutTitleColor ?? this.calloutTitleColor,
      calloutSubtitleColor: calloutSubtitleColor ?? this.calloutSubtitleColor,
      calloutBadgeBackground:
          calloutBadgeBackground ?? this.calloutBadgeBackground,
      calloutBadgeTextColor:
          calloutBadgeTextColor ?? this.calloutBadgeTextColor,
      calloutBorderRadius: calloutBorderRadius ?? this.calloutBorderRadius,
      calloutMaxWidth: calloutMaxWidth ?? this.calloutMaxWidth,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      transitionCurve: transitionCurve ?? this.transitionCurve,
      fontFamily: fontFamily ?? this.fontFamily,
      countFormatter: countFormatter ?? this.countFormatter,
    );
  }
}
