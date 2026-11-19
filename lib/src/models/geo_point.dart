import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Mean Earth radius in meters (WGS-84 / IUGG mean radius).
const double _earthRadiusMeters = 6371008.8;

/// Maximum latitude supported by standard Web Mercator projection.
const double maxMercatorLatitude = 85.05112877980659;

/// An immutable geographic coordinate represented by [latitude] and [longitude]
/// in decimal degrees (WGS-84).
@immutable
class GeoPoint {
  /// Creates a [GeoPoint] at the given [latitude] (`-90` to `90`) and
  /// [longitude] (`-180` to `180`).
  const GeoPoint(this.latitude, this.longitude)
    : assert(
        latitude >= -90.0 && latitude <= 90.0,
        'Latitude must be between -90 and 90 degrees.',
      ),
      assert(
        longitude >= -180.0 && longitude <= 180.0,
        'Longitude must be between -180 and 180 degrees.',
      );

  /// Creates a [GeoPoint] while clamping [latitude] into `[-90, 90]` and
  /// normalizing [longitude] into `[-180, 180]`.
  factory GeoPoint.clamped(double latitude, double longitude) {
    final safeLat = latitude.isFinite ? latitude.clamp(-90.0, 90.0) : 0.0;
    final safeLng = longitude.isFinite ? normalizeLongitude(longitude) : 0.0;
    return GeoPoint(safeLat, safeLng);
  }

  /// Latitude in degrees (`-90.0` South to `+90.0` North).
  final double latitude;

  /// Longitude in degrees (`-180.0` West to `+180.0` East).
  final double longitude;

  /// Normalizes any finite [longitude] angle in degrees into `[-180.0, 180.0]`.
  static double normalizeLongitude(double longitude) {
    if (!longitude.isFinite) {
      return 0.0;
    }
    var normalized = (longitude + 180.0) % 360.0;
    if (normalized < 0.0) {
      normalized += 360.0;
    }
    normalized -= 180.0;
    // Preserve +180 when input is exactly +180.
    if (normalized == -180.0 && longitude > 0.0) {
      return 180.0;
    }
    return normalized;
  }

  /// Returns the great-circle distance in meters between this point and [other]
  /// using the Haversine formula.
  double distanceTo(GeoPoint other) {
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(other.latitude);
    final dLat = _toRadians(other.latitude - latitude);
    final dLng = _toRadians(other.longitude - longitude);

    final sinDLat = math.sin(dLat / 2.0);
    final sinDLng = math.sin(dLng / 2.0);

    final haversine =
        (sinDLat * sinDLat +
                math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng)
            .clamp(0.0, 1.0);
    final centralAngle =
        2.0 * math.atan2(math.sqrt(haversine), math.sqrt(1.0 - haversine));
    return _earthRadiusMeters * centralAngle;
  }

  /// Returns a new [GeoPoint] linearly interpolated between [a] and [b] at [t].
  static GeoPoint lerp(GeoPoint a, GeoPoint b, double t) {
    var dLng = b.longitude - a.longitude;
    if (dLng > 180.0) {
      dLng -= 360.0;
    } else if (dLng < -180.0) {
      dLng += 360.0;
    }
    final lat = (a.latitude + (b.latitude - a.latitude) * t).clamp(-90.0, 90.0);
    final lng = normalizeLongitude(a.longitude + dLng * t);
    return GeoPoint(lat, lng);
  }

  /// Returns a copy of this coordinate with optionally replaced fields.
  GeoPoint copyWith({double? latitude, double? longitude}) {
    return GeoPoint(latitude ?? this.latitude, longitude ?? this.longitude);
  }

  /// Formats this coordinate as a human-readable string with [fractionDigits]
  /// decimal places.
  String format({int fractionDigits = 4}) {
    return '${latitude.toStringAsFixed(fractionDigits)}, '
        '${longitude.toStringAsFixed(fractionDigits)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}

/// An immutable axis-aligned geographic bounding box defined by [southWest]
/// and [northEast] corners.
@immutable
class GeoBounds {
  /// Creates a [GeoBounds] from [southWest] and [northEast] corners.
  const GeoBounds({required this.southWest, required this.northEast});

  /// Creates the smallest [GeoBounds] enclosing all [points].
  ///
  /// Throws an [ArgumentError] if [points] is empty.
  factory GeoBounds.fromPoints(Iterable<GeoPoint> points) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) {
      throw ArgumentError.value(
        points,
        'points',
        'Cannot compute GeoBounds from an empty iterable.',
      );
    }
    var minLat = iterator.current.latitude;
    var maxLat = iterator.current.latitude;
    var minLng = iterator.current.longitude;
    var maxLng = iterator.current.longitude;

    while (iterator.moveNext()) {
      final point = iterator.current;
      if (point.latitude < minLat) {
        minLat = point.latitude;
      }
      if (point.latitude > maxLat) {
        maxLat = point.latitude;
      }
      if (point.longitude < minLng) {
        minLng = point.longitude;
      }
      if (point.longitude > maxLng) {
        maxLng = point.longitude;
      }
    }

    return GeoBounds(
      southWest: GeoPoint(minLat, minLng),
      northEast: GeoPoint(maxLat, maxLng),
    );
  }

  /// The southwestern corner (minimum latitude and longitude).
  final GeoPoint southWest;

  /// The northeastern corner (maximum latitude and longitude).
  final GeoPoint northEast;

  /// The geographic midpoint of this bounding box.
  GeoPoint get center => GeoPoint(
    (southWest.latitude + northEast.latitude) / 2.0,
    (southWest.longitude + northEast.longitude) / 2.0,
  );

  /// The latitude span in degrees.
  double get latitudeSpan => (northEast.latitude - southWest.latitude).abs();

  /// The longitude span in degrees.
  double get longitudeSpan => (northEast.longitude - southWest.longitude).abs();

  /// Whether this bounding box collapses to a single point (zero area).
  bool get isPoint => latitudeSpan < 1e-7 && longitudeSpan < 1e-7;

  /// Returns `true` if [point] lies inside or on the boundary of this box.
  bool contains(GeoPoint point) {
    final inLat =
        point.latitude >= southWest.latitude &&
        point.latitude <= northEast.latitude;
    final inLng = southWest.longitude <= northEast.longitude
        ? point.longitude >= southWest.longitude &&
              point.longitude <= northEast.longitude
        : point.longitude >= southWest.longitude ||
              point.longitude <= northEast.longitude;
    return inLat && inLng;
  }

  /// Returns a new [GeoBounds] expanded to also contain [point].
  GeoBounds extend(GeoPoint point) {
    return GeoBounds(
      southWest: GeoPoint(
        math.min(southWest.latitude, point.latitude),
        math.min(southWest.longitude, point.longitude),
      ),
      northEast: GeoPoint(
        math.max(northEast.latitude, point.latitude),
        math.max(northEast.longitude, point.longitude),
      ),
    );
  }

  /// Returns a new [GeoBounds] expanded symmetrically by [fraction] of its
  /// width and height (e.g., `0.1` adds 10% padding on every side).
  GeoBounds pad(double fraction) {
    final latPad = latitudeSpan * fraction;
    final lngPad = longitudeSpan * fraction;
    return GeoBounds(
      southWest: GeoPoint(
        (southWest.latitude - latPad).clamp(-90.0, 90.0),
        (southWest.longitude - lngPad).clamp(-180.0, 180.0),
      ),
      northEast: GeoPoint(
        (northEast.latitude + latPad).clamp(-90.0, 90.0),
        (northEast.longitude + lngPad).clamp(-180.0, 180.0),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GeoBounds &&
        other.southWest == southWest &&
        other.northEast == northEast;
  }

  @override
  int get hashCode => Object.hash(southWest, northEast);

  @override
  String toString() => 'GeoBounds(sw: $southWest, ne: $northEast)';
}
