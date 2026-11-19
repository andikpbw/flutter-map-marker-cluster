import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

void main() {
  group('ClusterThemeData', () {
    test('formats compact cluster counts cleanly', () {
      expect(defaultClusterCountFormatter(7), '7');
      expect(defaultClusterCountFormatter(999), '999');
      expect(defaultClusterCountFormatter(1000), '1k');
      expect(defaultClusterCountFormatter(1250), '1.3k');
      expect(defaultClusterCountFormatter(15400), '15k');
      expect(defaultClusterCountFormatter(1000000), '1M');
      expect(defaultClusterCountFormatter(2450000), '2.5M');
    });

    test('resolves matching tiers across all 4 built-in presets', () {
      final presets = <ClusterThemeData>[
        ClusterThemeData.modern(),
        ClusterThemeData.dark(),
        ClusterThemeData.minimal(),
        ClusterThemeData.emerald(),
      ];

      for (final theme in presets) {
        final small = theme.tierForCount(4);
        final medium = theme.tierForCount(25);
        final large = theme.tierForCount(120);
        expect(medium.diameter, greaterThanOrEqualTo(small.diameter));
        expect(large.diameter, greaterThanOrEqualTo(medium.diameter));
        expect(small.resolvedGradientColors.length, greaterThanOrEqualTo(2));
      }
    });

    test('handles empty tier list and single-color gradients gracefully', () {
      final emptyTierTheme = ClusterThemeData.modern().copyWith(
        tiers: const <ClusterTier>[],
      );
      final fallback = emptyTierTheme.tierForCount(5);
      expect(fallback.resolvedGradientColors, hasLength(2));

      const singleColorTier = ClusterTier(
        minCount: 2,
        diameter: 40.0,
        gradientColors: <Color>[Color(0xFF4F46E5)],
        haloColor: Color(0xFF4F46E5),
      );
      expect(singleColorTier.resolvedGradientColors, hasLength(2));
    });

    test('interpolates smoothly via ClusterThemeData.lerp', () {
      final light = ClusterThemeData.modern();
      final dark = ClusterThemeData.dark();
      final mid = ClusterThemeData.lerp(light, dark, 0.5);

      expect(mid.tiers.length, light.tiers.length);
      expect(
        mid.haloOpacity,
        closeTo((light.haloOpacity + dark.haloOpacity) / 2.0, 1e-6),
      );
    });
  });
}
