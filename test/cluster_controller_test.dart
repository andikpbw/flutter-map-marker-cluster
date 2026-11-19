import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

void main() {
  group('ClusterController', () {
    test('supports full marker CRUD and live filtering', () {
      final controller = ClusterController<String>(
        initialMarkers: const <ClusterMarker<String>>[
          ClusterMarker<String>(
            id: '1',
            position: GeoPoint(-6.20, 106.84),
            category: 'Cafe',
            label: 'Kopi Satu',
          ),
          ClusterMarker<String>(
            id: '2',
            position: GeoPoint(-6.21, 106.85),
            category: 'Transit',
            label: 'MRT Bundaran',
          ),
        ],
      );

      expect(controller.markers, hasLength(2));
      expect(controller.filteredMarkers, hasLength(2));

      controller.addMarker(
        const ClusterMarker<String>(
          id: '3',
          position: GeoPoint(-6.22, 106.86),
          category: 'Cafe',
        ),
      );
      expect(controller.markers, hasLength(3));

      controller.selectMarker(controller.markers[1]);
      expect(controller.selectedMarker?.id, '2');

      // Filtering out the selected marker automatically clears selection.
      controller.setMarkerFilter((m) => m.category == 'Cafe');
      expect(controller.filteredMarkers, hasLength(2));
      expect(controller.selectedMarker, isNull);

      // Clearing filter restores full dataset without data loss.
      controller.setMarkerFilter(null);
      expect(controller.filteredMarkers, hasLength(3));

      controller.updateMarker(
        const ClusterMarker<String>(
          id: '1',
          position: GeoPoint(-6.20, 106.84),
          label: 'Updated Cafe',
        ),
      );
      expect(
        controller.markers.firstWhere((m) => m.id == '1').label,
        'Updated Cafe',
      );

      expect(controller.removeMarkerById('3'), isTrue);
      expect(controller.removeMarkerById('missing'), isFalse);
      expect(controller.markers, hasLength(2));

      controller.clearMarkers();
      expect(controller.markers, isEmpty);
      expect(controller.visibleNodes, isEmpty);

      controller.dispose();
    });

    test('handles zoomThenSpiderfy including co-located markers', () {
      final controller = ClusterController<void>(
        initialMarkers: const <ClusterMarker<void>>[
          ClusterMarker<void>(id: 'a', position: GeoPoint(-6.2088, 106.8456)),
          ClusterMarker<void>(id: 'b', position: GeoPoint(-6.2088, 106.8456)),
          ClusterMarker<void>(id: 'c', position: GeoPoint(-6.2088, 106.8456)),
        ],
      );

      final cluster = controller.visibleNodes.single;
      expect(cluster.isCluster, isTrue);

      // Co-located markers cannot be separated by zooming, so tap spiderfies immediately.
      controller.handleClusterTap(cluster);
      expect(controller.isSpiderfied, isTrue);
      expect(controller.spiderfyLayout?.items, hasLength(3));

      // Panning preserves spiderfy and updates screen position.
      controller.moveTo(const GeoPoint(-6.2100, 106.8470));
      expect(controller.isSpiderfied, isTrue);

      // Significant zoom change collapses spiderfy automatically.
      controller.updateViewport(zoom: 13.0);
      expect(controller.isSpiderfied, isFalse);

      controller.dispose();
    });

    test('delegates animateTo when camera animation handler is attached', () {
      final controller = ClusterController<void>(
        initialCenter: const GeoPoint(-6.20, 106.84),
        initialZoom: 10.0,
      );

      ClusterCameraTransition? received;
      controller.attachCameraAnimationHandler((transition) {
        received = transition;
      });

      controller.zoomIn(delta: 2.0);
      expect(received, isNotNull);
      expect(received!.targetZoom, 12.0);

      controller.attachCameraAnimationHandler(null);
      controller.zoomOut(delta: 1.5);
      expect(controller.zoom, 8.5);

      controller.dispose();
    });

    test('fits markers and dismisses overlays cleanly', () {
      final controller = ClusterController<void>(
        initialViewportSize: const Size(600.0, 400.0),
        initialMarkers: const <ClusterMarker<void>>[
          ClusterMarker<void>(id: '1', position: GeoPoint(-6.10, 106.70)),
          ClusterMarker<void>(id: '2', position: GeoPoint(-6.30, 106.95)),
        ],
      );

      controller.fitMarkers(animate: false);
      expect(controller.center.latitude, closeTo(-6.20, 1e-6));
      expect(controller.center.longitude, closeTo(106.825, 1e-6));

      controller.selectMarker(controller.markers.first);
      expect(controller.selectedMarker, isNotNull);
      controller.dismissOverlays();
      expect(controller.selectedMarker, isNull);

      controller.dispose();
    });
  });
}
