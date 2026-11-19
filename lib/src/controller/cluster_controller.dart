import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../engine/cluster_engine.dart';
import '../engine/spiderfy_layout.dart';
import '../models/cluster_marker.dart';
import '../models/cluster_node.dart';
import '../models/cluster_options.dart';
import '../models/geo_point.dart';
import '../models/map_viewport.dart';

/// Describes an animated camera transition requested via
/// [ClusterController.animateTo].
@immutable
class ClusterCameraTransition {
  /// Creates a [ClusterCameraTransition].
  const ClusterCameraTransition({
    required this.targetCenter,
    required this.targetZoom,
    required this.targetRotation,
    this.duration = const Duration(milliseconds: 380),
    this.curve = Curves.easeOutCubic,
  });

  /// Destination map center coordinate.
  final GeoPoint targetCenter;

  /// Destination zoom level.
  final double targetZoom;

  /// Destination clockwise rotation in radians.
  final double targetRotation;

  /// Duration of the transition animation.
  final Duration duration;

  /// Easing curve applied to the camera interpolation.
  final Curve curve;
}

/// Callback used by an attached interactive map widget to execute smooth
/// camera animations requested through [ClusterController].
typedef CameraAnimationHandler =
    void Function(ClusterCameraTransition transition);

/// Predicate used to filter which [ClusterMarker] entries are active.
typedef MarkerFilter<T> = bool Function(ClusterMarker<T> marker);

/// Reactive controller managing markers, viewport state, clustering output,
/// selection, filtering, and spiderfy interactions.
///
/// Can be shared across `ClusterMapOverlay`, `InteractiveClusterMap`, search
/// bars, filter chips, or external map providers such as `flutter_map` and
/// `google_maps_flutter`.
class ClusterController<T> extends ChangeNotifier {
  /// Creates a [ClusterController].
  ClusterController({
    GeoPoint initialCenter = const GeoPoint(-6.2088, 106.8456),
    double initialZoom = 11.0,
    double initialRotation = 0.0,
    Size initialViewportSize = const Size(800.0, 600.0),
    List<ClusterMarker<T>> initialMarkers = const <Never>[],
    ClusterOptions options = const ClusterOptions(),
    MapProjection projection = const WebMercatorProjection(),
    MarkerFilter<T>? markerFilter,
    ClusterEngine<T>? engine,
    SpiderfyLayoutEngine spiderfyEngine = const SpiderfyLayoutEngine(),
  }) : _options = options,
       _engine = engine ?? ClusterEngine<T>(),
       _spiderfyEngine = spiderfyEngine,
       _markerFilter = markerFilter,
       _markers = List<ClusterMarker<T>>.of(initialMarkers),
       _viewport = MapViewport(
         center: initialCenter,
         zoom: initialZoom.clamp(options.minZoom, options.maxZoom),
         size: initialViewportSize,
         rotation: initialRotation,
         projection: projection,
       ) {
    _recomputeFilteredMarkers();
    _recomputeNodes();
  }

  final ClusterEngine<T> _engine;
  final SpiderfyLayoutEngine _spiderfyEngine;

  List<ClusterMarker<T>> _markers;
  List<ClusterMarker<T>> _filteredMarkers = const <Never>[];
  List<ClusterNode<T>> _visibleNodes = const <Never>[];

  ClusterOptions _options;
  MapViewport _viewport;
  MarkerFilter<T>? _markerFilter;

  ClusterMarker<T>? _selectedMarker;
  ClusterNode<T>? _spiderfiedCluster;
  SpiderfyLayout<T>? _spiderfyLayout;
  double? _spiderfyZoom;
  bool _disposed = false;

  CameraAnimationHandler? _cameraAnimationHandler;

  /// Current immutable viewport state.
  MapViewport get viewport => _viewport;

  /// Current geographic center of the viewport.
  GeoPoint get center => _viewport.center;

  /// Current continuous zoom level.
  double get zoom => _viewport.zoom;

  /// Current clockwise rotation in radians.
  double get rotation => _viewport.rotation;

  /// Current clustering configuration.
  ClusterOptions get options => _options;

  /// Active marker filter predicate, or `null` when unfiltered.
  MarkerFilter<T>? get markerFilter => _markerFilter;

  /// All registered markers (before filtering).
  List<ClusterMarker<T>> get markers =>
      UnmodifiableListView<ClusterMarker<T>>(_markers);

  /// Active markers after applying [markerFilter].
  List<ClusterMarker<T>> get filteredMarkers =>
      UnmodifiableListView<ClusterMarker<T>>(_filteredMarkers);

  /// Clustered nodes currently visible in [viewport].
  List<ClusterNode<T>> get visibleNodes =>
      UnmodifiableListView<ClusterNode<T>>(_visibleNodes);

  /// Currently selected individual marker, if any.
  ClusterMarker<T>? get selectedMarker => _selectedMarker;

  /// Currently spiderfied cluster node, if any.
  ClusterNode<T>? get spiderfiedCluster => _spiderfiedCluster;

  /// Computed geometry for the active spiderfy expansion, or `null`.
  SpiderfyLayout<T>? get spiderfyLayout => _spiderfyLayout;

  /// Whether a cluster is currently expanded via spiderfy.
  bool get isSpiderfied => _spiderfyLayout != null;

  /// Number of multi-marker cluster nodes currently visible.
  int get clusterCount => _visibleNodes.where((n) => n.isCluster).length;

  /// Total number of individual markers represented by [visibleNodes].
  int get visibleMarkerCount {
    var total = 0;
    for (final node in _visibleNodes) {
      total += node.count;
    }
    return total;
  }

  /// Attaches an animated camera handler (used internally by
  /// `InteractiveClusterMap` or custom external map bridges).
  void attachCameraAnimationHandler(CameraAnimationHandler? handler) {
    _cameraAnimationHandler = handler;
  }

  /// Replaces the full marker dataset.
  void setMarkers(List<ClusterMarker<T>> markers) {
    _markers = List<ClusterMarker<T>>.of(markers);
    _recomputeFilteredMarkers();
    _syncSelectionAndSpiderfyAfterDataChange();
    _recomputeNodes();
    _notifySafe();
  }

  /// Adds a single [marker] to the dataset.
  void addMarker(ClusterMarker<T> marker) {
    _markers = <ClusterMarker<T>>[..._markers, marker];
    _recomputeFilteredMarkers();
    _recomputeNodes();
    _notifySafe();
  }

  /// Appends multiple [markers] to the dataset.
  void addMarkers(Iterable<ClusterMarker<T>> markers) {
    _markers = <ClusterMarker<T>>[..._markers, ...markers];
    _recomputeFilteredMarkers();
    _recomputeNodes();
    _notifySafe();
  }

  /// Updates an existing marker matching `marker.id`, or appends it if not
  /// present.
  void updateMarker(ClusterMarker<T> marker) {
    final next = List<ClusterMarker<T>>.of(_markers);
    final index = next.indexWhere((m) => m.id == marker.id);
    if (index >= 0) {
      next[index] = marker;
    } else {
      next.add(marker);
    }
    _markers = next;
    if (_selectedMarker?.id == marker.id) {
      _selectedMarker = marker;
    }
    _recomputeFilteredMarkers();
    _syncSelectionAndSpiderfyAfterDataChange();
    _recomputeNodes();
    _notifySafe();
  }

  /// Removes the marker with the matching [id]. Returns `true` if removed.
  bool removeMarkerById(String id) {
    final next = _markers.where((m) => m.id != id).toList(growable: false);
    if (next.length == _markers.length) {
      return false;
    }
    _markers = next;
    _recomputeFilteredMarkers();
    _syncSelectionAndSpiderfyAfterDataChange();
    _recomputeNodes();
    _notifySafe();
    return true;
  }

  /// Removes all markers and clears selection and spiderfy state.
  void clearMarkers() {
    if (_markers.isEmpty &&
        _selectedMarker == null &&
        _spiderfyLayout == null) {
      return;
    }
    _markers = const <Never>[];
    _filteredMarkers = const <Never>[];
    _selectedMarker = null;
    _spiderfiedCluster = null;
    _spiderfyLayout = null;
    _spiderfyZoom = null;
    _visibleNodes = const <Never>[];
    _engine.invalidateCache();
    _notifySafe();
  }

  /// Applies or clears a live [filter] over [markers] without mutating the
  /// underlying marker collection.
  void setMarkerFilter(MarkerFilter<T>? filter) {
    _markerFilter = filter;
    _recomputeFilteredMarkers();
    _syncSelectionAndSpiderfyAfterDataChange();
    _recomputeNodes();
    _notifySafe();
  }

  /// Replaces the active [ClusterOptions] and recomputes clusters.
  void setOptions(ClusterOptions options) {
    if (_options == options) {
      return;
    }
    _options = options;
    final clampedZoom = _viewport.zoom.clamp(options.minZoom, options.maxZoom);
    if (clampedZoom != _viewport.zoom) {
      _viewport = _viewport.copyWith(zoom: clampedZoom);
    }
    if (_spiderfiedCluster != null) {
      _spiderfyLayout = _spiderfyEngine.computeLayout<T>(
        _spiderfiedCluster!,
        options: _options,
      );
    }
    _recomputeNodes();
    _notifySafe();
  }

  /// Updates the viewport state immediately without triggering a camera
  /// transition animation.
  void updateViewport({
    GeoPoint? center,
    double? zoom,
    Size? size,
    double? rotation,
    MapProjection? projection,
  }) {
    final nextZoom = (zoom ?? _viewport.zoom).clamp(
      _options.minZoom,
      _options.maxZoom,
    );
    final nextViewport = _viewport.copyWith(
      center: center,
      zoom: nextZoom,
      size: size,
      rotation: rotation,
      projection: projection,
    );

    if (nextViewport == _viewport) {
      return;
    }

    _viewport = nextViewport;

    // Auto-collapse spiderfy if zoom changed meaningfully.
    if (_spiderfyZoom != null &&
        (_viewport.zoom - _spiderfyZoom!).abs() > 0.35) {
      _clearSpiderfyInternal();
    } else if (_spiderfiedCluster != null) {
      // Keep spiderfied cluster screen position synced while panning.
      _spiderfiedCluster = _spiderfiedCluster!.withScreenPosition(
        _viewport.latLngToScreen(_spiderfiedCluster!.position),
      );
    }

    _recomputeNodes();
    _notifySafe();
  }

  /// Updates only the viewport dimensions (for example, on layout resize).
  void updateViewportSize(Size size) {
    if (size == _viewport.size || size.width <= 0.0 || size.height <= 0.0) {
      return;
    }
    updateViewport(size: size);
  }

  /// Moves the camera immediately to [center] with optional [zoom] and
  /// [rotation].
  void moveTo(GeoPoint center, {double? zoom, double? rotation}) {
    updateViewport(center: center, zoom: zoom, rotation: rotation);
  }

  /// Smoothly animates the camera to [center] (and optional [zoom] /
  /// [rotation]) when an animated map host is attached; otherwise jumps
  /// directly.
  void animateTo(
    GeoPoint center, {
    double? zoom,
    double? rotation,
    Duration duration = const Duration(milliseconds: 380),
    Curve curve = Curves.easeOutCubic,
  }) {
    final targetZoom = (zoom ?? _viewport.zoom).clamp(
      _options.minZoom,
      _options.maxZoom,
    );
    final targetRotation = rotation ?? _viewport.rotation;

    final handler = _cameraAnimationHandler;
    if (handler != null) {
      handler(
        ClusterCameraTransition(
          targetCenter: center,
          targetZoom: targetZoom,
          targetRotation: targetRotation,
          duration: duration,
          curve: curve,
        ),
      );
    } else {
      updateViewport(
        center: center,
        zoom: targetZoom,
        rotation: targetRotation,
      );
    }
  }

  /// Increases the zoom level by [delta] (defaults to `1.0`).
  void zoomIn({double delta = 1.0, bool animate = true}) {
    final targetZoom = (_viewport.zoom + delta).clamp(
      _options.minZoom,
      _options.maxZoom,
    );
    if (animate) {
      animateTo(_viewport.center, zoom: targetZoom);
    } else {
      updateViewport(zoom: targetZoom);
    }
  }

  /// Decreases the zoom level by [delta] (defaults to `1.0`).
  void zoomOut({double delta = 1.0, bool animate = true}) {
    final targetZoom = (_viewport.zoom - delta).clamp(
      _options.minZoom,
      _options.maxZoom,
    );
    if (animate) {
      animateTo(_viewport.center, zoom: targetZoom);
    } else {
      updateViewport(zoom: targetZoom);
    }
  }

  /// Centers and zooms the viewport so [bounds] fits comfortably within the
  /// current viewport size.
  void fitBounds(
    GeoBounds bounds, {
    EdgeInsets? padding,
    bool animate = true,
    double? maxZoom,
  }) {
    final effectivePadding = padding ?? _options.clusterFitPadding;
    final targetZoom = _viewport.projection.fitZoomLevel(
      bounds,
      _viewport.hasValidSize ? _viewport.size : const Size(800.0, 600.0),
      padding: effectivePadding,
      minZoom: _options.minZoom,
      maxZoom: maxZoom ?? _options.maxZoom,
    );
    if (animate) {
      animateTo(bounds.center, zoom: targetZoom);
    } else {
      moveTo(bounds.center, zoom: targetZoom);
    }
  }

  /// Fits all currently active ([filteredMarkers]) markers inside the viewport.
  void fitMarkers({EdgeInsets? padding, bool animate = true, double? maxZoom}) {
    if (_filteredMarkers.isEmpty) {
      return;
    }
    final bounds = GeoBounds.fromPoints(
      _filteredMarkers.map((m) => m.position),
    );
    fitBounds(bounds, padding: padding, animate: animate, maxZoom: maxZoom);
  }

  /// Zooms into [cluster]'s bounding box or expansion zoom level.
  void focusCluster(ClusterNode<T> cluster, {bool animate = true}) {
    final fitZoom = _viewport.projection.fitZoomLevel(
      cluster.bounds,
      _viewport.hasValidSize ? _viewport.size : const Size(800.0, 600.0),
      padding: _options.clusterFitPadding,
      minZoom: _options.minZoom,
      maxZoom: _options.maxZoom,
    );
    final targetZoom =
        (fitZoom > _viewport.zoom + 0.35
                ? fitZoom
                : cluster.expansionZoom.clamp(
                    _viewport.zoom + 1.0,
                    _options.maxZoom,
                  ))
            .clamp(_options.minZoom, _options.maxZoom);

    if (animate) {
      animateTo(cluster.bounds.center, zoom: targetZoom);
    } else {
      moveTo(cluster.bounds.center, zoom: targetZoom);
    }
  }

  /// Executes the configured [ClusterOptions.tapBehavior] for a tapped
  /// [cluster].
  void handleClusterTap(ClusterNode<T> cluster) {
    if (!cluster.isCluster) {
      selectMarker(cluster.singleMarker);
      return;
    }

    switch (_options.tapBehavior) {
      case ClusterTapBehavior.none:
        return;
      case ClusterTapBehavior.spiderfy:
        spiderfyCluster(cluster);
      case ClusterTapBehavior.zoomToBounds:
        unspiderfy();
        focusCluster(cluster);
      case ClusterTapBehavior.zoomThenSpiderfy:
        final atMaxClusteringZoom =
            _viewport.zoom >= _options.maxClusterZoom - 0.1 ||
            _viewport.zoom >= _options.maxZoom - 0.25;
        final cannotSplitByZoom = cluster.bounds.isPoint || atMaxClusteringZoom;
        if (cannotSplitByZoom) {
          spiderfyCluster(cluster);
        } else {
          unspiderfy();
          focusCluster(cluster);
        }
    }
  }

  /// Selects [marker] (or clears selection when `null`).
  void selectMarker(ClusterMarker<T>? marker) {
    if (_selectedMarker == marker) {
      return;
    }
    _selectedMarker = marker;
    _notifySafe();
  }

  /// Clears the currently selected marker.
  void clearSelection() => selectMarker(null);

  /// Fans out [cluster] using the configured spiderfy layout.
  void spiderfyCluster(ClusterNode<T> cluster) {
    if (!cluster.isCluster) {
      return;
    }
    final syncedCluster = cluster.withScreenPosition(
      _viewport.latLngToScreen(cluster.position),
    );
    _spiderfiedCluster = syncedCluster;
    _spiderfyZoom = _viewport.zoom;
    _spiderfyLayout = _spiderfyEngine.computeLayout<T>(
      syncedCluster,
      options: _options,
    );
    _selectedMarker = null;
    _notifySafe();
  }

  /// Collapses any active spiderfy expansion.
  void unspiderfy() {
    if (_spiderfyLayout == null) {
      return;
    }
    _clearSpiderfyInternal();
    _notifySafe();
  }

  /// Closes both the active marker callout and any spiderfy expansion.
  void dismissOverlays() {
    if (_selectedMarker == null && _spiderfyLayout == null) {
      return;
    }
    _selectedMarker = null;
    _clearSpiderfyInternal();
    _notifySafe();
  }

  void _clearSpiderfyInternal() {
    _spiderfiedCluster = null;
    _spiderfyLayout = null;
    _spiderfyZoom = null;
  }

  void _recomputeFilteredMarkers() {
    final filter = _markerFilter;
    if (filter == null) {
      _filteredMarkers = _markers;
    } else {
      _filteredMarkers = _markers.where(filter).toList(growable: false);
    }
  }

  void _syncSelectionAndSpiderfyAfterDataChange() {
    final activeIds = <String>{
      for (final marker in _filteredMarkers) marker.id,
    };
    if (_selectedMarker != null && !activeIds.contains(_selectedMarker!.id)) {
      _selectedMarker = null;
    }
    if (_spiderfiedCluster != null) {
      final stillPresent = _spiderfiedCluster!.markers.any(
        (m) => activeIds.contains(m.id),
      );
      if (!stillPresent) {
        _clearSpiderfyInternal();
      }
    }
  }

  void _recomputeNodes() {
    _visibleNodes = _engine.cluster(
      _filteredMarkers,
      viewport: _viewport,
      options: _options,
    );
  }

  void _notifySafe() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cameraAnimationHandler = null;
    super.dispose();
  }
}
