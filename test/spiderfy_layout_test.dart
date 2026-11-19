import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

void main() {
  ClusterNode<int> buildCluster(int count) {
    final markers = <ClusterMarker<int>>[
      for (var i = 0; i < count; i++)
        ClusterMarker<int>(
          id: 'm_$i',
          position: const GeoPoint(-6.2088, 106.8456),
          data: i,
        ),
    ];
    return ClusterNode<int>(
      id: 'cluster_test_$count',
      position: const GeoPoint(-6.2088, 106.8456),
      screenPosition: const Offset(400.0, 300.0),
      markers: markers,
      bounds: GeoBounds.fromPoints(markers.map((m) => m.position)),
      expansionZoom: 18.0,
    );
  }

  group('SpiderfyLayoutEngine', () {
    const engine = SpiderfyLayoutEngine();

    test('uses symmetric non-overlapping circle layout for small clusters', () {
      final layout = engine.computeLayout<int>(buildCluster(6));

      expect(layout.usedSpiral, isFalse);
      expect(layout.items, hasLength(6));
      expect(layout.hiddenCount, 0);

      final firstRadius = layout.items.first.offset.distance;
      for (final item in layout.items) {
        expect(item.offset.distance, closeTo(firstRadius, 1e-6));
        expect(item.controlPointOffset.dx.isFinite, isTrue);
        expect(item.controlPointOffset.dy.isFinite, isTrue);
      }

      // Verify minimum separation between adjacent markers.
      for (var i = 0; i < layout.items.length; i++) {
        final next = layout.items[(i + 1) % layout.items.length];
        expect(
          (layout.items[i].offset - next.offset).distance,
          greaterThan(35.0),
        );
      }
    });

    test('switches automatically to spiral layout above threshold', () {
      final layout = engine.computeLayout<int>(buildCluster(14));

      expect(layout.usedSpiral, isTrue);
      expect(layout.items, hasLength(14));
      expect(
        layout.items.last.offset.distance,
        greaterThan(layout.items.first.offset.distance),
      );
      expect(
        layout.outerRadius,
        closeTo(layout.items.last.offset.distance, 1e-6),
      );
    });

    test('caps expanded items to maxSpiderfyCount and reports hiddenCount', () {
      final layout = engine.computeLayout<int>(
        buildCluster(30),
        options: const ClusterOptions(maxSpiderfyCount: 12),
      );

      expect(layout.items, hasLength(12));
      expect(layout.hiddenCount, 18);
    });
  });
}
