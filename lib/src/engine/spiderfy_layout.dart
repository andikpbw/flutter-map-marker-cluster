import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/cluster_marker.dart';
import '../models/cluster_node.dart';
import '../models/cluster_options.dart';

/// Positioned marker element inside an active spiderfy expansion.
@immutable
class SpiderfiedItem<T> {
  /// Creates a [SpiderfiedItem].
  const SpiderfiedItem({
    required this.marker,
    required this.index,
    required this.offset,
    required this.angle,
    required this.controlPointOffset,
  });

  /// Underlying marker being displayed on this spider leg.
  final ClusterMarker<T> marker;

  /// Zero-based index of this item inside the spiderfy sequence.
  final int index;

  /// Screen-pixel offset from the cluster's center to this marker's center.
  final Offset offset;

  /// Polar angle in radians from the cluster's center to this marker.
  final double angle;

  /// Quadratic Bezier control point offset relative to the cluster's center,
  /// creating an organic curved spider leg.
  final Offset controlPointOffset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SpiderfiedItem<T> &&
        other.marker == marker &&
        other.index == index &&
        other.offset == offset &&
        other.angle == angle &&
        other.controlPointOffset == controlPointOffset;
  }

  @override
  int get hashCode =>
      Object.hash(marker, index, offset, angle, controlPointOffset);
}

/// Computed radial/spiral geometry for a spiderfied [ClusterNode].
@immutable
class SpiderfyLayout<T> {
  /// Creates a [SpiderfyLayout].
  SpiderfyLayout({
    required this.cluster,
    required List<SpiderfiedItem<T>> items,
    required this.usedSpiral,
    required this.outerRadius,
  }) : items = UnmodifiableListView<SpiderfiedItem<T>>(
         List<SpiderfiedItem<T>>.of(items),
       );

  /// The source cluster currently expanded.
  final ClusterNode<T> cluster;

  /// Ordered list of spiderfied marker items and their target offsets.
  final List<SpiderfiedItem<T>> items;

  /// Whether an Archimedean spiral was used (`true`) or a circle (`false`).
  final bool usedSpiral;

  /// Distance in logical pixels from the cluster center to the farthest item.
  final double outerRadius;

  /// Number of markers omitted because the cluster exceeded
  /// [ClusterOptions.maxSpiderfyCount].
  int get hiddenCount => math.max(0, cluster.count - items.length);
}

/// Computes non-overlapping circular or Archimedean spiral positions for
/// markers fanned out from a cluster center.
class SpiderfyLayoutEngine {
  /// Creates a constant [SpiderfyLayoutEngine].
  const SpiderfyLayoutEngine();

  /// Computes a [SpiderfyLayout] for [cluster] according to [options].
  SpiderfyLayout<T> computeLayout<T>(
    ClusterNode<T> cluster, {
    ClusterOptions options = const ClusterOptions(),
  }) {
    final visibleMarkers = cluster.markers.length > options.maxSpiderfyCount
        ? cluster.markers.sublist(0, options.maxSpiderfyCount)
        : cluster.markers;
    final count = visibleMarkers.length;

    if (count == 0) {
      return SpiderfyLayout<T>(
        cluster: cluster,
        items: const <Never>[],
        usedSpiral: false,
        outerRadius: 0.0,
      );
    }

    final useSpiral = switch (options.spiderfyShape) {
      SpiderfyShape.circle => false,
      SpiderfyShape.spiral => true,
      SpiderfyShape.auto => count > options.spiderfyCircleThreshold,
    };

    if (useSpiral) {
      return _buildSpiralLayout<T>(cluster, visibleMarkers, options);
    }
    return _buildCircleLayout<T>(cluster, visibleMarkers, options);
  }

  SpiderfyLayout<T> _buildCircleLayout<T>(
    ClusterNode<T> cluster,
    List<ClusterMarker<T>> markers,
    ClusterOptions options,
  ) {
    final count = markers.length;
    final circumference = count * options.spiderfyMarkerSpacing;
    final radius = math.max(
      options.spiderfyCircleRadius,
      circumference / (2.0 * math.pi),
    );
    final angleStep = (2.0 * math.pi) / count;
    const startAngle = -math.pi / 2.0;

    final items = <SpiderfiedItem<T>>[];
    for (var i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final offset = Offset(radius * math.cos(angle), radius * math.sin(angle));
      final controlOffset = _curvedControlPoint(offset, curvature: 0.14);
      items.add(
        SpiderfiedItem<T>(
          marker: markers[i],
          index: i,
          offset: offset,
          angle: angle,
          controlPointOffset: controlOffset,
        ),
      );
    }

    return SpiderfyLayout<T>(
      cluster: cluster,
      items: items,
      usedSpiral: false,
      outerRadius: radius,
    );
  }

  SpiderfyLayout<T> _buildSpiralLayout<T>(
    ClusterNode<T> cluster,
    List<ClusterMarker<T>> markers,
    ClusterOptions options,
  ) {
    final startRadius = math.max(38.0, options.spiderfyCircleRadius * 0.72);
    final spacing = options.spiderfyMarkerSpacing;
    final spiralTightness = (spacing * 1.18) / (2.0 * math.pi);

    var angle = -math.pi / 2.0;
    var radius = startRadius;
    var maxRadius = radius;

    final items = <SpiderfiedItem<T>>[];
    for (var i = 0; i < markers.length; i++) {
      if (i > 0) {
        final dTheta = spacing / radius;
        angle += dTheta;
        radius = startRadius + spiralTightness * (angle + math.pi / 2.0);
      }
      if (radius > maxRadius) {
        maxRadius = radius;
      }

      final offset = Offset(radius * math.cos(angle), radius * math.sin(angle));
      final controlOffset = _curvedControlPoint(offset, curvature: 0.18);
      items.add(
        SpiderfiedItem<T>(
          marker: markers[i],
          index: i,
          offset: offset,
          angle: angle,
          controlPointOffset: controlOffset,
        ),
      );
    }

    return SpiderfyLayout<T>(
      cluster: cluster,
      items: items,
      usedSpiral: true,
      outerRadius: maxRadius,
    );
  }

  /// Generates a gentle perpendicular bend midpoint for curved Bezier legs.
  static Offset _curvedControlPoint(
    Offset target, {
    required double curvature,
  }) {
    final mid = target * 0.52;
    final perp = Offset(-target.dy, target.dx) * curvature;
    return mid + perp;
  }
}
