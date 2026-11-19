import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

void main() {
  group('ClusterEngine', () {
    const baseViewport = MapViewport(
      center: GeoPoint(-6.2088, 106.8456),
      zoom: 11.0,
      size: Size(800.0, 600.0),
    );

    test(
      'returns empty list for empty markers and single node for one marker',
      () {
        final engine = ClusterEngine<String>();
        expect(
          engine.cluster(
            const <ClusterMarker<String>>[],
            viewport: baseViewport,
          ),
          isEmpty,
        );

        const single = ClusterMarker<String>(
          id: 'm1',
          position: GeoPoint(-6.2088, 106.8456),
        );
        final nodes = engine.cluster(const <ClusterMarker<String>>[
          single,
        ], viewport: baseViewport);
        expect(nodes, hasLength(1));
        expect(nodes.first.isCluster, isFalse);
        expect(nodes.first.singleMarker, single);
      },
    );

    test('groups nearby markers and respects minClusterSize', () {
      final engine = ClusterEngine<void>();
      final markers = <ClusterMarker<void>>[
        const ClusterMarker<void>(
          id: 'a',
          position: GeoPoint(-6.2088, 106.8456),
        ),
        const ClusterMarker<void>(
          id: 'b',
          position: GeoPoint(-6.2095, 106.8462),
        ),
        const ClusterMarker<void>(
          id: 'far',
          position: GeoPoint(-6.3500, 106.9900),
        ),
      ];

      final clustered = engine.cluster(
        markers,
        viewport: baseViewport,
        options: const ClusterOptions(),
      );
      expect(clustered.where((n) => n.isCluster).length, 1);
      expect(clustered.where((n) => n.isCluster).first.count, 2);

      // Requiring minClusterSize = 3 leaves all 3 markers unclustered.
      final unclustered = engine.cluster(
        markers,
        viewport: baseViewport,
        options: const ClusterOptions(minClusterSize: 3),
      );
      expect(unclustered.every((n) => !n.isCluster), isTrue);
    });

    test(
      'produces deterministic clusters independent of input permutation',
      () {
        final engineA = ClusterEngine<void>();
        final engineB = ClusterEngine<void>();

        final markers = <ClusterMarker<void>>[
          for (var i = 0; i < 40; i++)
            ClusterMarker<void>(
              id: 'm_${i.toString().padLeft(2, '0')}',
              position: GeoPoint(
                -6.20 + (i % 5) * 0.008,
                106.82 + (i ~/ 5) * 0.008,
              ),
            ),
        ];
        final reversed = markers.reversed.toList();

        final nodesA = engineA.clusterAll(markers, viewport: baseViewport);
        final nodesB = engineB.clusterAll(reversed, viewport: baseViewport);

        expect(nodesA.length, nodesB.length);
        expect(
          nodesA.map((n) => n.id).toList(),
          nodesB.map((n) => n.id).toList(),
        );
      },
    );

    test('computes weighted centroid accurately', () {
      final engine = ClusterEngine<void>();
      final markers = <ClusterMarker<void>>[
        const ClusterMarker<void>(
          id: 'heavy',
          position: GeoPoint(-6.2000, 106.8400),
          weight: 9.0,
        ),
        const ClusterMarker<void>(
          id: 'light',
          position: GeoPoint(-6.2100, 106.8500),
        ),
      ];

      final nodes = engine.clusterAll(
        markers,
        viewport: baseViewport,
        options: const ClusterOptions(clusterRadius: 120.0),
      );
      expect(nodes, hasLength(1));
      // Weighted centroid should be 90% of the way toward 'heavy'.
      expect(nodes.first.position.latitude, closeTo(-6.2010, 0.001));
      expect(nodes.first.position.longitude, closeTo(106.8410, 0.001));
    });

    test('clusters seamlessly across the ±180° antimeridian', () {
      final engine = ClusterEngine<void>();
      const markers = <ClusterMarker<void>>[
        ClusterMarker<void>(id: 'e', position: GeoPoint(0.0, 179.9)),
        ClusterMarker<void>(id: 'w', position: GeoPoint(0.0, -179.9)),
      ];
      const viewport = MapViewport(
        center: GeoPoint(0.0, 179.95),
        zoom: 6.0,
        size: Size(800.0, 600.0),
      );

      final nodes = engine.clusterAll(
        markers,
        viewport: viewport,
        options: const ClusterOptions(clusterRadius: 80.0),
      );
      expect(nodes, hasLength(1));
      expect(nodes.first.count, 2);
      expect(nodes.first.position.longitude.abs(), greaterThan(179.5));
    });

    test('keeps clusters 100% pan-stable with zero membership flicker', () {
      final engine = ClusterEngine<void>();
      final rng = math.Random(7);
      final markers = <ClusterMarker<void>>[
        for (var i = 0; i < 120; i++)
          ClusterMarker<void>(
            id: 'p_$i',
            position: GeoPoint(
              -6.25 + rng.nextDouble() * 0.12,
              106.78 + rng.nextDouble() * 0.14,
            ),
          ),
      ];

      final baseline = engine.clusterAll(markers, viewport: baseViewport);
      final baselineIds = baseline.map((n) => n.id).toList();

      // Pan the viewport across several fractional pixel shifts.
      for (var step = 1; step <= 10; step++) {
        final panned = baseViewport.copyWith(
          center: GeoPoint(
            baseViewport.center.latitude + step * 0.003,
            baseViewport.center.longitude - step * 0.004,
          ),
        );
        final next = engine.clusterAll(markers, viewport: panned);
        expect(next.map((n) => n.id).toList(), baselineIds);
      }
    });

    test('culls off-screen markers when cullToViewport is enabled', () {
      final engine = ClusterEngine<void>();
      const markers = <ClusterMarker<void>>[
        ClusterMarker<void>(id: 'in', position: GeoPoint(-6.2088, 106.8456)),
        ClusterMarker<void>(id: 'out', position: GeoPoint(48.8566, 2.3522)),
      ];

      final culled = engine.cluster(
        markers,
        viewport: baseViewport,
        options: const ClusterOptions(cullMargin: 40.0),
      );
      expect(culled, hasLength(1));
      expect(culled.first.singleMarker?.id, 'in');

      final unculled = engine.clusterAll(markers, viewport: baseViewport);
      expect(unculled, hasLength(2));
    });

    test(
      'keeps co-located markers grouped above maxClusterZoom for spiderfy',
      () {
        final engine = ClusterEngine<void>();
        const markers = <ClusterMarker<void>>[
          ClusterMarker<void>(id: 'c1', position: GeoPoint(-6.2088, 106.8456)),
          ClusterMarker<void>(id: 'c2', position: GeoPoint(-6.2088, 106.8456)),
          ClusterMarker<void>(id: 'sep', position: GeoPoint(-6.2070, 106.8475)),
        ];

        final zoomedIn = baseViewport.copyWith(zoom: 17.0);
        final nodes = engine.clusterAll(
          markers,
          viewport: zoomedIn,
          options: const ClusterOptions(),
        );
        expect(nodes, hasLength(2));
        expect(nodes.where((n) => n.isCluster).single.count, 2);
        expect(nodes.where((n) => !n.isCluster).single.singleMarker?.id, 'sep');
      },
    );

    test('clusters 5,000 markers rapidly while conserving every marker', () {
      final engine = ClusterEngine<int>();
      final rng = math.Random(100);
      final markers = <ClusterMarker<int>>[
        for (var i = 0; i < 5000; i++)
          ClusterMarker<int>(
            id: 'm_$i',
            position: GeoPoint(
              -6.5 + rng.nextDouble() * 0.6,
              106.5 + rng.nextDouble() * 0.6,
            ),
            data: i,
          ),
      ];

      final sw = Stopwatch()..start();
      final nodes = engine.clusterAll(markers, viewport: baseViewport);
      sw.stop();

      final totalCount = nodes.fold<int>(0, (sum, n) => sum + n.count);
      expect(totalCount, 5000);
      expect(nodes.length, lessThan(1500));
      expect(sw.elapsedMilliseconds, lessThan(1500));
    });
  });
}
