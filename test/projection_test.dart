import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

void main() {
  group('WebMercatorProjection', () {
    const projection = WebMercatorProjection();

    test('round-trips world projection accurately across global cities', () {
      const points = <GeoPoint>[
        GeoPoint(0.0, 0.0),
        GeoPoint(-6.2088, 106.8456),
        GeoPoint(35.6762, 139.6503),
        GeoPoint(40.7128, -74.0060),
        GeoPoint(51.5074, -0.1278),
        GeoPoint(-33.8688, 151.2093),
        GeoPoint(85.0, 179.5),
        GeoPoint(-85.0, -179.5),
      ];

      for (final zoom in <double>[1.0, 6.5, 12.0, 18.0]) {
        for (final point in points) {
          final world = projection.latLngToWorld(point, zoom);
          expect(world.dx.isFinite, isTrue);
          expect(world.dy.isFinite, isTrue);

          final restored = projection.worldToLatLng(world, zoom);
          expect(restored.latitude, closeTo(point.latitude, 1e-5));
          expect(restored.longitude, closeTo(point.longitude, 1e-5));
        }
      }
    });

    test(
      'clamps extreme polar latitudes without producing NaN or Infinity',
      () {
        final north = projection.latLngToWorld(const GeoPoint(90.0, 0.0), 10.0);
        final south = projection.latLngToWorld(
          const GeoPoint(-90.0, 0.0),
          10.0,
        );

        expect(north.dx.isFinite && north.dy.isFinite, isTrue);
        expect(south.dx.isFinite && south.dy.isFinite, isTrue);
        expect(north.dy, lessThan(south.dy));
      },
    );

    test('round-trips screen coordinates under rotation', () {
      const target = GeoPoint(-6.1950, 106.8610);
      for (final rotation in <double>[
        0.0,
        math.pi / 4.0,
        -math.pi / 2.0,
        math.pi,
      ]) {
        final viewport = MapViewport(
          center: const GeoPoint(-6.2088, 106.8456),
          zoom: 13.0,
          size: const Size(800.0, 600.0),
          rotation: rotation,
        );

        final screen = viewport.latLngToScreen(target);
        final unprojected = viewport.screenToLatLng(screen);
        expect(unprojected.latitude, closeTo(target.latitude, 1e-5));
        expect(unprojected.longitude, closeTo(target.longitude, 1e-5));
      }
    });

    test('wraps shortest horizontal distance across antimeridian', () {
      const viewport = MapViewport(
        center: GeoPoint(0.0, 179.5),
        zoom: 5.0,
        size: Size(800.0, 600.0),
      );

      final screenPoint = viewport.latLngToScreen(const GeoPoint(0.0, -179.5));
      // -179.5° is 1° east of 179.5°, so it must appear just to the right of center.
      expect(screenPoint.dx, greaterThan(400.0));
      expect(screenPoint.dx, lessThan(450.0));
    });

    test(
      'computes fitZoomLevel cleanly for normal and single-point bounds',
      () {
        final cityBounds = GeoBounds.fromPoints(const <GeoPoint>[
          GeoPoint(-6.30, 106.75),
          GeoPoint(-6.12, 106.95),
        ]);
        final zoom = projection.fitZoomLevel(
          cityBounds,
          const Size(800.0, 600.0),
        );
        expect(zoom, inInclusiveRange(9.0, 14.0));

        final pointBounds = GeoBounds.fromPoints(const <GeoPoint>[
          GeoPoint(-6.20, 106.84),
        ]);
        final pointZoom = projection.fitZoomLevel(
          pointBounds,
          const Size(800.0, 600.0),
          singlePointZoom: 15.5,
        );
        expect(pointZoom, 15.5);
      },
    );
  });
}
