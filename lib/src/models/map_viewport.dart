import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'geo_point.dart';

/// Contract for converting between geographic coordinates ([GeoPoint]),
/// continuous world pixel coordinates at a given zoom level, and screen pixels
/// within a [MapViewport].
///
/// Implement this interface to integrate custom projections (for example,
/// indoor floorplans or non-Mercator maps) while reusing the entire clustering,
/// animation, and spiderfy pipeline.
abstract class MapProjection {
  /// Creates a constant [MapProjection].
  const MapProjection();

  /// Base tile dimension in logical pixels at zoom level `0`.
  double get tileSize;

  /// Total pixel width and height of the projected world at [zoom].
  double worldSize(double zoom) => tileSize * math.pow(2.0, zoom);

  /// Projects a geographic [point] to world pixel coordinates at [zoom].
  Offset latLngToWorld(GeoPoint point, double zoom);

  /// Converts world pixel coordinates [worldPoint] at [zoom] back into a
  /// [GeoPoint].
  GeoPoint worldToLatLng(Offset worldPoint, double zoom);

  /// Projects a geographic [point] to logical screen coordinates inside
  /// [viewport].
  Offset latLngToScreen(GeoPoint point, MapViewport viewport) {
    final worldWidth = worldSize(viewport.zoom);
    final centerWorld = latLngToWorld(viewport.center, viewport.zoom);
    final pointWorld = latLngToWorld(point, viewport.zoom);

    var dx = pointWorld.dx - centerWorld.dx;
    if (dx > worldWidth / 2.0) {
      dx -= worldWidth;
    } else if (dx < -worldWidth / 2.0) {
      dx += worldWidth;
    }
    final dy = pointWorld.dy - centerWorld.dy;

    final double rx;
    final double ry;
    if (viewport.rotation != 0.0) {
      final cosR = math.cos(viewport.rotation);
      final sinR = math.sin(viewport.rotation);
      rx = dx * cosR - dy * sinR;
      ry = dx * sinR + dy * cosR;
    } else {
      rx = dx;
      ry = dy;
    }

    return Offset(
      viewport.size.width / 2.0 + rx,
      viewport.size.height / 2.0 + ry,
    );
  }

  /// Unprojects a logical [screenPoint] inside [viewport] back into a
  /// [GeoPoint].
  GeoPoint screenToLatLng(Offset screenPoint, MapViewport viewport) {
    final sx = screenPoint.dx - viewport.size.width / 2.0;
    final sy = screenPoint.dy - viewport.size.height / 2.0;

    final double dx;
    final double dy;
    if (viewport.rotation != 0.0) {
      final cosR = math.cos(viewport.rotation);
      final sinR = math.sin(viewport.rotation);
      dx = sx * cosR + sy * sinR;
      dy = -sx * sinR + sy * cosR;
    } else {
      dx = sx;
      dy = sy;
    }

    final centerWorld = latLngToWorld(viewport.center, viewport.zoom);
    final targetWorld = Offset(centerWorld.dx + dx, centerWorld.dy + dy);
    return worldToLatLng(targetWorld, viewport.zoom);
  }

  /// Computes the ideal zoom level so that [bounds] fits inside [viewportSize]
  /// with optional [padding], clamped to `[minZoom, maxZoom]`.
  double fitZoomLevel(
    GeoBounds bounds,
    Size viewportSize, {
    EdgeInsets padding = const EdgeInsets.all(48.0),
    double minZoom = 1.0,
    double maxZoom = 18.0,
    double singlePointZoom = 15.0,
  }) {
    if (bounds.isPoint) {
      return singlePointZoom.clamp(minZoom, maxZoom);
    }

    final sw0 = latLngToWorld(bounds.southWest, 0.0);
    final ne0 = latLngToWorld(bounds.northEast, 0.0);

    var spanX = (ne0.dx - sw0.dx).abs();
    if (spanX > tileSize / 2.0 &&
        bounds.southWest.longitude > bounds.northEast.longitude) {
      spanX = tileSize - spanX;
    }
    final spanY = (sw0.dy - ne0.dy).abs();

    final availWidth = math.max(1.0, viewportSize.width - padding.horizontal);
    final availHeight = math.max(1.0, viewportSize.height - padding.vertical);

    final zoomX = spanX > 1e-9
        ? math.log(availWidth / spanX) / math.ln2
        : maxZoom;
    final zoomY = spanY > 1e-9
        ? math.log(availHeight / spanY) / math.ln2
        : maxZoom;

    return math.min(zoomX, zoomY).clamp(minZoom, maxZoom);
  }
}

/// Standard EPSG:3857 Spherical Web Mercator projection compatible with
/// OpenStreetMap, Google Maps, Mapbox, MapLibre, Apple Maps, and `flutter_map`.
@immutable
class WebMercatorProjection extends MapProjection {
  /// Creates a [WebMercatorProjection] with the given base [tileSize]
  /// (defaults to `256.0`).
  const WebMercatorProjection({this.tileSize = 256.0})
    : assert(tileSize > 0.0, 'tileSize must be positive.');

  @override
  final double tileSize;

  @override
  Offset latLngToWorld(GeoPoint point, double zoom) {
    final scale = worldSize(zoom);
    final x = ((point.longitude + 180.0) / 360.0) * scale;
    final clampedLat = point.latitude.clamp(
      -maxMercatorLatitude,
      maxMercatorLatitude,
    );
    final sinLat = math.sin(clampedLat * math.pi / 180.0);
    final y =
        (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
        scale;
    return Offset(x, y);
  }

  @override
  GeoPoint worldToLatLng(Offset worldPoint, double zoom) {
    final scale = worldSize(zoom);
    final normalizedX = worldPoint.dx / scale;
    final clampedY = (worldPoint.dy / scale).clamp(0.0, 1.0);

    final lng = GeoPoint.normalizeLongitude(normalizedX * 360.0 - 180.0);
    final n = math.pi - 2.0 * math.pi * clampedY;
    final sinhN = 0.5 * (math.exp(n) - math.exp(-n));
    final lat = (180.0 / math.pi * math.atan(sinhN)).clamp(-90.0, 90.0);
    return GeoPoint(lat, lng);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WebMercatorProjection && other.tileSize == tileSize;
  }

  @override
  int get hashCode => tileSize.hashCode;
}

/// Snapshot of a map camera and viewport dimensions used to project markers
/// and compute clusters.
@immutable
class MapViewport {
  /// Creates a [MapViewport].
  const MapViewport({
    required this.center,
    required this.zoom,
    required this.size,
    this.rotation = 0.0,
    this.projection = const WebMercatorProjection(),
  });

  /// Geographic coordinate currently centered in the viewport.
  final GeoPoint center;

  /// Current continuous zoom level (e.g. `1.0` world view to `20.0` street).
  final double zoom;

  /// Logical pixel size of the map viewport.
  final Size size;

  /// Clockwise map rotation in radians. Defaults to `0.0`.
  final double rotation;

  /// Projection strategy used to translate coordinates.
  final MapProjection projection;

  /// Whether this viewport has non-zero width and height.
  bool get hasValidSize => size.width > 0.0 && size.height > 0.0;

  /// Projects [point] into logical screen pixels within this viewport.
  Offset latLngToScreen(GeoPoint point) =>
      projection.latLngToScreen(point, this);

  /// Unprojects a [screenPoint] inside this viewport back to a [GeoPoint].
  GeoPoint screenToLatLng(Offset screenPoint) =>
      projection.screenToLatLng(screenPoint, this);

  /// Returns `true` if [screenPoint] falls inside this viewport expanded by
  /// [margin] logical pixels on every side.
  bool containsScreenPoint(Offset screenPoint, {double margin = 0.0}) {
    return screenPoint.dx >= -margin &&
        screenPoint.dx <= size.width + margin &&
        screenPoint.dy >= -margin &&
        screenPoint.dy <= size.height + margin;
  }

  /// Returns a copy of this viewport with optionally updated fields.
  MapViewport copyWith({
    GeoPoint? center,
    double? zoom,
    Size? size,
    double? rotation,
    MapProjection? projection,
  }) {
    return MapViewport(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      projection: projection ?? this.projection,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MapViewport &&
        other.center == center &&
        other.zoom == zoom &&
        other.size == size &&
        other.rotation == rotation &&
        other.projection == projection;
  }

  @override
  int get hashCode => Object.hash(center, zoom, size, rotation, projection);

  @override
  String toString() =>
      'MapViewport(center: $center, zoom: $zoom, size: $size, rotation: $rotation)';
}
