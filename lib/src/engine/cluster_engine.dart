import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/cluster_marker.dart';
import '../models/cluster_node.dart';
import '../models/cluster_options.dart';
import '../models/geo_point.dart';
import '../models/map_viewport.dart';

/// A lightweight 2D spatial hash grid that accelerates nearest-neighbor
/// lookups from `O(n^2)` to amortized `O(n)`.
///
/// Uses Dart 3 record keys `(int, int)` so cell indexing is collision-free and
/// safe across native 64-bit, JavaScript 53-bit, and WebAssembly targets.
class SpatialHashGrid<T> {
  /// Creates a [SpatialHashGrid] with the specified positive [cellSize].
  SpatialHashGrid(this.cellSize)
    : assert(cellSize > 0.0, 'cellSize must be positive.');

  /// Width and height of each grid cell in projected pixel space.
  final double cellSize;

  final Map<(int, int), List<T>> _cells = <(int, int), List<T>>{};

  /// Inserts [item] at projected pixel coordinate [position].
  void insert(Offset position, T item) {
    final key = _cellKey(position);
    (_cells[key] ??= <T>[]).add(item);
  }

  /// Returns all items residing in the 3x3 neighborhood surrounding [position].
  ///
  /// When [worldWidth] is provided, queries near the horizontal world seam
  /// automatically include wrapped cells across the antimeridian.
  List<T> queryNeighborhood(Offset position, {double? worldWidth}) {
    final cx = (position.dx / cellSize).floor();
    final cy = (position.dy / cellSize).floor();
    final results = <T>[];
    final maxCellX = worldWidth != null ? (worldWidth / cellSize).ceil() : null;

    for (var dx = -1; dx <= 1; dx++) {
      var nx = cx + dx;
      if (maxCellX != null && maxCellX > 2) {
        if (nx < 0) {
          nx += maxCellX;
        } else if (nx >= maxCellX) {
          nx -= maxCellX;
        }
      }
      for (var dy = -1; dy <= 1; dy++) {
        final bucket = _cells[(nx, cy + dy)];
        if (bucket != null) {
          results.addAll(bucket);
        }
      }
    }
    return results;
  }

  /// Removes all entries from this grid.
  void clear() => _cells.clear();

  (int, int) _cellKey(Offset position) =>
      ((position.dx / cellSize).floor(), (position.dy / cellSize).floor());
}

class _ProjectedEntry<T> {
  const _ProjectedEntry({
    required this.index,
    required this.marker,
    required this.worldPosition,
  });

  final int index;
  final ClusterMarker<T> marker;
  final Offset worldPosition;
}

class _WorldCluster<T> {
  const _WorldCluster({
    required this.id,
    required this.position,
    required this.markers,
    required this.bounds,
    required this.expansionZoom,
  });

  final String id;
  final GeoPoint position;
  final List<ClusterMarker<T>> markers;
  final GeoBounds bounds;
  final double expansionZoom;
}

/// High-performance, pan-stable spatial marker clustering engine.
///
/// Clustering is evaluated in absolute projected world pixel coordinates at a
/// quantized zoom bucket ([ClusterOptions.zoomBucketStep]). Because world
/// coordinates never drift as the user pans, clusters remain 100% stable with
/// zero flicker during panning, and panning reuses the cached cluster set in
/// `O(k)` time (where `k` is the number of clusters).
class ClusterEngine<T> {
  /// Creates a [ClusterEngine].
  ClusterEngine();

  /// Co-located grouping threshold in pixels above [ClusterOptions.maxClusterZoom]
  /// so markers sharing identical coordinates remain cleanly spiderfiable.
  static const double _coLocatedRadiusPx = 6.0;

  List<ClusterMarker<T>>? _lastMarkersRef;
  int _lastMarkersLength = -1;
  int _lastMarkersSignature = 0;
  double? _lastZoomBucket;
  ClusterOptions? _lastOptions;
  MapProjection? _lastProjection;
  List<_WorldCluster<T>>? _cachedWorldClusters;

  /// Quantizes a continuous [zoom] level to the nearest lower bucket defined
  /// by [options].
  static double quantizeZoom(double zoom, ClusterOptions options) {
    final clamped = zoom.clamp(options.minZoom, options.maxZoom);
    final step = options.zoomBucketStep;
    final bucket = (clamped / step).floorToDouble() * step;
    return bucket.clamp(options.minZoom, options.maxZoom);
  }

  /// Computes clusters for [markers] visible inside [viewport] using [options].
  ///
  /// When [ClusterOptions.cullToViewport] is `true`, nodes outside the
  /// viewport expanded by [ClusterOptions.cullMargin] are filtered out while
  /// preserving accurate cluster membership and counts.
  List<ClusterNode<T>> cluster(
    List<ClusterMarker<T>> markers, {
    required MapViewport viewport,
    ClusterOptions options = const ClusterOptions(),
  }) {
    if (markers.isEmpty) {
      return const <Never>[];
    }

    final worldClusters = _getOrComputeWorldClusters(
      markers,
      zoom: viewport.zoom,
      projection: viewport.projection,
      options: options,
    );

    final result = <ClusterNode<T>>[];
    final shouldCull = options.cullToViewport && viewport.hasValidSize;

    for (final wc in worldClusters) {
      final screenPos = viewport.latLngToScreen(wc.position);
      if (shouldCull &&
          !viewport.containsScreenPoint(
            screenPos,
            margin: options.cullMargin,
          )) {
        continue;
      }
      result.add(
        ClusterNode<T>(
          id: wc.id,
          position: wc.position,
          screenPosition: screenPos,
          markers: wc.markers,
          bounds: wc.bounds,
          expansionZoom: wc.expansionZoom,
        ),
      );
    }

    return result;
  }

  /// Computes all clusters for [markers] at [viewport] without viewport
  /// culling, regardless of [ClusterOptions.cullToViewport].
  List<ClusterNode<T>> clusterAll(
    List<ClusterMarker<T>> markers, {
    required MapViewport viewport,
    ClusterOptions options = const ClusterOptions(),
  }) {
    return cluster(
      markers,
      viewport: viewport,
      options: options.copyWith(cullToViewport: false),
    );
  }

  /// Clears any memoized cluster results.
  void invalidateCache() {
    _lastMarkersRef = null;
    _lastMarkersLength = -1;
    _lastMarkersSignature = 0;
    _lastZoomBucket = null;
    _lastOptions = null;
    _lastProjection = null;
    _cachedWorldClusters = null;
  }

  List<_WorldCluster<T>> _getOrComputeWorldClusters(
    List<ClusterMarker<T>> markers, {
    required double zoom,
    required MapProjection projection,
    required ClusterOptions options,
  }) {
    final zoomBucket = quantizeZoom(zoom, options);
    final signature = _computeMarkerSignature(markers);

    final cacheHit =
        _cachedWorldClusters != null &&
        identical(_lastMarkersRef, markers) &&
        _lastMarkersLength == markers.length &&
        _lastMarkersSignature == signature &&
        _lastZoomBucket == zoomBucket &&
        _lastOptions == options &&
        _lastProjection == projection;

    if (cacheHit) {
      return _cachedWorldClusters!;
    }

    final computed = _computeWorldClusters(
      markers,
      zoomBucket: zoomBucket,
      projection: projection,
      options: options,
    );

    _lastMarkersRef = markers;
    _lastMarkersLength = markers.length;
    _lastMarkersSignature = signature;
    _lastZoomBucket = zoomBucket;
    _lastOptions = options;
    _lastProjection = projection;
    _cachedWorldClusters = computed;

    return computed;
  }

  List<_WorldCluster<T>> _computeWorldClusters(
    List<ClusterMarker<T>> markers, {
    required double zoomBucket,
    required MapProjection projection,
    required ClusterOptions options,
  }) {
    // Deterministic ordering guarantees stable cluster seeding regardless of
    // input permutation.
    final sorted = List<ClusterMarker<T>>.of(markers)
      ..sort((a, b) {
        final zCmp = b.zIndex.compareTo(a.zIndex);
        if (zCmp != 0) {
          return zCmp;
        }
        return a.id.compareTo(b.id);
      });

    final aboveMaxClusterZoom = zoomBucket >= options.maxClusterZoom;
    final effectiveRadius = aboveMaxClusterZoom
        ? _coLocatedRadiusPx
        : options.clusterRadius;
    final radiusSq = effectiveRadius * effectiveRadius;
    final worldWidth = projection.worldSize(zoomBucket);

    final grid = SpatialHashGrid<_ProjectedEntry<T>>(effectiveRadius);
    final entries = <_ProjectedEntry<T>>[];

    for (var i = 0; i < sorted.length; i++) {
      final marker = sorted[i];
      final worldPos = projection.latLngToWorld(marker.position, zoomBucket);
      final entry = _ProjectedEntry<T>(
        index: i,
        marker: marker,
        worldPosition: worldPos,
      );
      entries.add(entry);
      grid.insert(worldPos, entry);
    }

    final visited = List<bool>.filled(entries.length, false);
    final clusters = <_WorldCluster<T>>[];

    for (var i = 0; i < entries.length; i++) {
      if (visited[i]) {
        continue;
      }
      final seed = entries[i];
      final candidates = grid.queryNeighborhood(
        seed.worldPosition,
        worldWidth: worldWidth,
      );

      final group = <_ProjectedEntry<T>>[seed];
      for (final candidate in candidates) {
        if (candidate.index == seed.index || visited[candidate.index]) {
          continue;
        }
        final dx = _wrappedDeltaX(
          candidate.worldPosition.dx - seed.worldPosition.dx,
          worldWidth,
        );
        final dy = candidate.worldPosition.dy - seed.worldPosition.dy;
        if (dx * dx + dy * dy <= radiusSq) {
          group.add(candidate);
        }
      }

      if (group.length >= options.minClusterSize) {
        for (final item in group) {
          visited[item.index] = true;
        }
        clusters.add(
          _buildWorldCluster(
            seed: seed,
            group: group,
            zoomBucket: zoomBucket,
            worldWidth: worldWidth,
            effectiveRadius: effectiveRadius,
            projection: projection,
            options: options,
          ),
        );
      } else {
        visited[i] = true;
        clusters.add(
          _WorldCluster<T>(
            id: 'marker:${seed.marker.id}',
            position: seed.marker.position,
            markers: UnmodifiableListView<ClusterMarker<T>>(<ClusterMarker<T>>[
              seed.marker,
            ]),
            bounds: GeoBounds(
              southWest: seed.marker.position,
              northEast: seed.marker.position,
            ),
            expansionZoom: zoomBucket,
          ),
        );
      }
    }

    return clusters;
  }

  _WorldCluster<T> _buildWorldCluster({
    required _ProjectedEntry<T> seed,
    required List<_ProjectedEntry<T>> group,
    required double zoomBucket,
    required double worldWidth,
    required double effectiveRadius,
    required MapProjection projection,
    required ClusterOptions options,
  }) {
    // Compute weighted centroid in unwrapped world coordinates relative to the
    // seed so clusters crossing the ±180° antimeridian stay geometrically exact.
    var sumDx = 0.0;
    var sumDy = 0.0;
    var totalWeight = 0.0;
    var maxDistFromSeed = 0.0;

    final groupMarkers = <ClusterMarker<T>>[];
    var minLat = seed.marker.position.latitude;
    var maxLat = seed.marker.position.latitude;
    var minLng = seed.marker.position.longitude;
    var maxLng = seed.marker.position.longitude;

    for (final entry in group) {
      final marker = entry.marker;
      groupMarkers.add(marker);

      final dx = _wrappedDeltaX(
        entry.worldPosition.dx - seed.worldPosition.dx,
        worldWidth,
      );
      final dy = entry.worldPosition.dy - seed.worldPosition.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > maxDistFromSeed) {
        maxDistFromSeed = dist;
      }

      final w = marker.weight;
      sumDx += dx * w;
      sumDy += dy * w;
      totalWeight += w;

      final pos = marker.position;
      if (pos.latitude < minLat) {
        minLat = pos.latitude;
      }
      if (pos.latitude > maxLat) {
        maxLat = pos.latitude;
      }
      if (pos.longitude < minLng) {
        minLng = pos.longitude;
      }
      if (pos.longitude > maxLng) {
        maxLng = pos.longitude;
      }
    }

    var centroidWorldX = seed.worldPosition.dx + (sumDx / totalWeight);
    centroidWorldX = ((centroidWorldX % worldWidth) + worldWidth) % worldWidth;
    final centroidWorldY = seed.worldPosition.dy + (sumDy / totalWeight);

    final centroid = projection.worldToLatLng(
      Offset(centroidWorldX, centroidWorldY),
      zoomBucket,
    );

    final double expansionZoom;
    if (maxDistFromSeed < 1e-4) {
      expansionZoom = options.maxZoom;
    } else {
      final zoomDelta =
          math.log((effectiveRadius * 1.15) / maxDistFromSeed) / math.ln2;
      expansionZoom = (zoomBucket + math.max(options.zoomBucketStep, zoomDelta))
          .clamp(zoomBucket, options.maxZoom);
    }

    return _WorldCluster<T>(
      id: 'cluster:${seed.marker.id}:${groupMarkers.length}',
      position: centroid,
      markers: UnmodifiableListView<ClusterMarker<T>>(groupMarkers),
      bounds: GeoBounds(
        southWest: GeoPoint(minLat, minLng),
        northEast: GeoPoint(maxLat, maxLng),
      ),
      expansionZoom: expansionZoom,
    );
  }

  static double _wrappedDeltaX(double dx, double worldWidth) {
    if (dx > worldWidth / 2.0) {
      return dx - worldWidth;
    }
    if (dx < -worldWidth / 2.0) {
      return dx + worldWidth;
    }
    return dx;
  }

  static int _computeMarkerSignature<T>(List<ClusterMarker<T>> markers) {
    var hash = markers.length;
    if (markers.isEmpty) {
      return hash;
    }
    // Sample evenly across the list plus boundary elements for fast mutation
    // detection even if callers mutate a list in place.
    final step = math.max(1, markers.length ~/ 16);
    for (var i = 0; i < markers.length; i += step) {
      final m = markers[i];
      hash = Object.hash(hash, m.id, m.position, m.weight, m.zIndex);
    }
    final last = markers.last;
    return Object.hash(hash, last.id, last.position, last.weight, last.zIndex);
  }
}
