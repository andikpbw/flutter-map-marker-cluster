import 'package:flutter/widgets.dart';

/// Determines how [ClusterMapOverlay] and [InteractiveClusterMap] respond when
/// the user taps a cluster badge.
enum ClusterTapBehavior {
  /// Zooms smoothly into the cluster's bounding box when it can still expand,
  /// and automatically falls back to spiderfy when the markers are co-located
  /// or the map has reached [ClusterOptions.maxClusterZoom].
  zoomThenSpiderfy,

  /// Always expands the cluster radially via spiderfy on tap.
  spiderfy,

  /// Always zooms into the cluster's bounding box on tap without spiderfying.
  zoomToBounds,

  /// Disables built-in tap handling so callers can handle `onClusterTap`
  /// exclusively.
  none,
}

/// Geometry used when fanning out spiderfied markers around a cluster center.
enum SpiderfyShape {
  /// Uses a symmetric [circle] for small clusters (`<= circleThreshold`) and
  /// transitions smoothly to an Archimedean [spiral] for larger clusters.
  auto,

  /// Places all spiderfied markers evenly around a circle.
  circle,

  /// Places spiderfied markers along an expanding Archimedean spiral.
  spiral,
}

/// Configuration options controlling clustering geometry, viewport culling,
/// zoom limits, and spiderfy behavior.
@immutable
class ClusterOptions {
  /// Creates a [ClusterOptions] configuration.
  const ClusterOptions({
    this.clusterRadius = 64.0,
    this.minClusterSize = 2,
    this.minZoom = 1.0,
    this.maxZoom = 19.0,
    this.maxClusterZoom = 16.0,
    this.zoomBucketStep = 1.0,
    this.cullToViewport = true,
    this.cullMargin = 120.0,
    this.tapBehavior = ClusterTapBehavior.zoomThenSpiderfy,
    this.spiderfyShape = SpiderfyShape.auto,
    this.spiderfyCircleThreshold = 8,
    this.spiderfyCircleRadius = 56.0,
    this.spiderfyMarkerSpacing = 44.0,
    this.maxSpiderfyCount = 24,
    this.clusterFitPadding = const EdgeInsets.all(64.0),
    this.animateTransitions = true,
  }) : assert(clusterRadius > 0.0, 'clusterRadius must be positive.'),
       assert(minClusterSize >= 2, 'minClusterSize must be at least 2.'),
       assert(minZoom <= maxZoom, 'minZoom must be <= maxZoom.'),
       assert(zoomBucketStep > 0.0, 'zoomBucketStep must be positive.'),
       assert(cullMargin >= 0.0, 'cullMargin cannot be negative.'),
       assert(maxSpiderfyCount >= 2, 'maxSpiderfyCount must be at least 2.');

  /// Pixel distance threshold within which neighboring markers merge into a
  /// cluster at the current zoom bucket.
  final double clusterRadius;

  /// Minimum number of markers required to form a cluster. Defaults to `2`.
  final int minClusterSize;

  /// Minimum allowed camera zoom level.
  final double minZoom;

  /// Maximum allowed camera zoom level.
  final double maxZoom;

  /// Zoom level at or above which spatial clustering is disabled so individual
  /// markers appear directly (co-located markers can still spiderfy).
  final double maxClusterZoom;

  /// Quantization step used to stabilize clusters while smoothly zooming or
  /// panning.
  ///
  /// A value of `1.0` recomputes clusters at each integer zoom boundary
  /// (similar to Supercluster), guaranteeing zero flicker during panning.
  final double zoomBucketStep;

  /// Whether to cull nodes outside the visible viewport expanded by
  /// [cullMargin]. Improves performance dramatically for large datasets.
  final bool cullToViewport;

  /// Extra margin in logical pixels around the viewport retained during
  /// viewport culling so markers enter and exit smoothly.
  final double cullMargin;

  /// Default interaction performed when tapping a cluster badge.
  final ClusterTapBehavior tapBehavior;

  /// Layout geometry used when spiderfying a cluster.
  final SpiderfyShape spiderfyShape;

  /// Maximum marker count that uses a circle layout when [spiderfyShape] is
  /// [SpiderfyShape.auto]. Clusters with more markers switch to a spiral.
  final int spiderfyCircleThreshold;

  /// Base radius in logical pixels for circular spiderfy layouts.
  final double spiderfyCircleRadius;

  /// Minimum arc spacing in logical pixels between consecutive spiderfied
  /// markers to prevent overlap.
  final double spiderfyMarkerSpacing;

  /// Maximum number of markers fanned out during a single spiderfy expansion.
  final int maxSpiderfyCount;

  /// Padding applied when fitting a tapped cluster's bounds into the viewport.
  final EdgeInsets clusterFitPadding;

  /// Whether split/merge position transitions are animated when zoom buckets
  /// change.
  final bool animateTransitions;

  /// Returns a copy of this configuration with selected fields overridden.
  ClusterOptions copyWith({
    double? clusterRadius,
    int? minClusterSize,
    double? minZoom,
    double? maxZoom,
    double? maxClusterZoom,
    double? zoomBucketStep,
    bool? cullToViewport,
    double? cullMargin,
    ClusterTapBehavior? tapBehavior,
    SpiderfyShape? spiderfyShape,
    int? spiderfyCircleThreshold,
    double? spiderfyCircleRadius,
    double? spiderfyMarkerSpacing,
    int? maxSpiderfyCount,
    EdgeInsets? clusterFitPadding,
    bool? animateTransitions,
  }) {
    return ClusterOptions(
      clusterRadius: clusterRadius ?? this.clusterRadius,
      minClusterSize: minClusterSize ?? this.minClusterSize,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      maxClusterZoom: maxClusterZoom ?? this.maxClusterZoom,
      zoomBucketStep: zoomBucketStep ?? this.zoomBucketStep,
      cullToViewport: cullToViewport ?? this.cullToViewport,
      cullMargin: cullMargin ?? this.cullMargin,
      tapBehavior: tapBehavior ?? this.tapBehavior,
      spiderfyShape: spiderfyShape ?? this.spiderfyShape,
      spiderfyCircleThreshold:
          spiderfyCircleThreshold ?? this.spiderfyCircleThreshold,
      spiderfyCircleRadius: spiderfyCircleRadius ?? this.spiderfyCircleRadius,
      spiderfyMarkerSpacing:
          spiderfyMarkerSpacing ?? this.spiderfyMarkerSpacing,
      maxSpiderfyCount: maxSpiderfyCount ?? this.maxSpiderfyCount,
      clusterFitPadding: clusterFitPadding ?? this.clusterFitPadding,
      animateTransitions: animateTransitions ?? this.animateTransitions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ClusterOptions &&
        other.clusterRadius == clusterRadius &&
        other.minClusterSize == minClusterSize &&
        other.minZoom == minZoom &&
        other.maxZoom == maxZoom &&
        other.maxClusterZoom == maxClusterZoom &&
        other.zoomBucketStep == zoomBucketStep &&
        other.cullToViewport == cullToViewport &&
        other.cullMargin == cullMargin &&
        other.tapBehavior == tapBehavior &&
        other.spiderfyShape == spiderfyShape &&
        other.spiderfyCircleThreshold == spiderfyCircleThreshold &&
        other.spiderfyCircleRadius == spiderfyCircleRadius &&
        other.spiderfyMarkerSpacing == spiderfyMarkerSpacing &&
        other.maxSpiderfyCount == maxSpiderfyCount &&
        other.clusterFitPadding == clusterFitPadding &&
        other.animateTransitions == animateTransitions;
  }

  @override
  int get hashCode => Object.hash(
    clusterRadius,
    minClusterSize,
    minZoom,
    maxZoom,
    maxClusterZoom,
    zoomBucketStep,
    cullToViewport,
    cullMargin,
    tapBehavior,
    spiderfyShape,
    spiderfyCircleThreshold,
    spiderfyCircleRadius,
    spiderfyMarkerSpacing,
    maxSpiderfyCount,
    clusterFitPadding,
    animateTransitions,
  );
}
