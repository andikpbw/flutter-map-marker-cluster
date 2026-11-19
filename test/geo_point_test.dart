import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

void main() {
  group('GeoPoint', () {
    test('clamps invalid latitudes and normalizes longitudes', () {
      final p1 = GeoPoint.clamped(120.0, 200.0);
      expect(p1.latitude, 90.0);
      expect(p1.longitude, closeTo(-160.0, 1e-9));

      final p2 = GeoPoint.clamped(-95.0, -540.0);
      expect(p2.latitude, -90.0);
      expect(p2.longitude, closeTo(-180.0, 1e-9));

      final p3 = GeoPoint.clamped(double.nan, double.infinity);
      expect(p3.latitude, 0.0);
      expect(p3.longitude, 0.0);

      expect(GeoPoint.normalizeLongitude(180.0), 180.0);
      expect(GeoPoint.normalizeLongitude(-180.0), -180.0);
    });

    test('computes accurate Haversine distances', () {
      const jakarta = GeoPoint(-6.2088, 106.8456);
      const bandung = GeoPoint(-6.9175, 107.6191);

      expect(jakarta.distanceTo(jakarta), 0.0);

      final distanceKm = jakarta.distanceTo(bandung) / 1000.0;
      expect(distanceKm, inInclusiveRange(110.0, 125.0));

      const northPole = GeoPoint(90.0, 0.0);
      const southPole = GeoPoint(-90.0, 0.0);
      expect(northPole.distanceTo(southPole) / 1000.0, closeTo(20015.1, 1.0));
    });

    test('lerps across the antimeridian via shortest path', () {
      const east = GeoPoint(10.0, 179.0);
      const west = GeoPoint(10.0, -179.0);

      final mid = GeoPoint.lerp(east, west, 0.5);
      expect(mid.latitude, closeTo(10.0, 1e-9));
      expect(mid.longitude.abs(), closeTo(180.0, 1e-9));
    });

    test('supports value equality, copyWith, and formatting', () {
      const point = GeoPoint(-6.2088, 106.8456);
      expect(point, const GeoPoint(-6.2088, 106.8456));
      expect(point.hashCode, const GeoPoint(-6.2088, 106.8456).hashCode);
      expect(point.copyWith(latitude: -6.5), const GeoPoint(-6.5, 106.8456));
      expect(point.format(fractionDigits: 2), '-6.21, 106.85');
    });
  });

  group('GeoBounds', () {
    test('computes bounding box, center, containment, and padding', () {
      final bounds = GeoBounds.fromPoints(const <GeoPoint>[
        GeoPoint(-6.3, 106.7),
        GeoPoint(-6.1, 106.9),
        GeoPoint(-6.2, 106.8),
      ]);

      expect(bounds.southWest, const GeoPoint(-6.3, 106.7));
      expect(bounds.northEast, const GeoPoint(-6.1, 106.9));
      expect(bounds.center.latitude, closeTo(-6.2, 1e-9));
      expect(bounds.center.longitude, closeTo(106.8, 1e-9));
      expect(bounds.isPoint, isFalse);
      expect(bounds.contains(const GeoPoint(-6.2, 106.8)), isTrue);
      expect(bounds.contains(const GeoPoint(-6.5, 106.8)), isFalse);

      final extended = bounds.extend(const GeoPoint(-6.5, 107.1));
      expect(extended.southWest, const GeoPoint(-6.5, 106.7));
      expect(extended.northEast, const GeoPoint(-6.1, 107.1));

      final padded = bounds.pad(0.5);
      expect(padded.latitudeSpan, closeTo(bounds.latitudeSpan * 2.0, 1e-9));
      expect(padded.longitudeSpan, closeTo(bounds.longitudeSpan * 2.0, 1e-9));
    });

    test('identifies single-point bounds and rejects empty iterables', () {
      final single = GeoBounds.fromPoints(const <GeoPoint>[
        GeoPoint(-6.2, 106.8),
      ]);
      expect(single.isPoint, isTrue);

      expect(
        () => GeoBounds.fromPoints(const <GeoPoint>[]),
        throwsArgumentError,
      );
    });
  });
}
