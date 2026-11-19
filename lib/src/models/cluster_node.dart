import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'cluster_marker.dart';
import 'geo_point.dart';

/// Represents either a single unclustered [ClusterMarker] or a group of
/// multiple markers merged into one cluster at the current zoom level.
@immutable
class ClusterNode<T> {
  /// Creates a [ClusterNode].
  ClusterNode({
    required this.id,
    required this.position,
    required this.screenPosition,
    required List<ClusterMarker<T>> markers,
    required this.bounds,
    required this.expansionZoom,
  }) : assert(
         markers.isNotEmpty,
         'ClusterNode must contain at least 1 marker.',
       ),
       markers = UnmodifiableListView<ClusterMarker<T>>(
         List<ClusterMarker<T>>.of(markers),
       );

  /// Stable deterministic identifier for this node, used to key widgets and
  /// drive smooth split/merge animations.
  final String id;

  /// Weighted geographic centroid of all [markers] inside this node.
  final GeoPoint position;

  /// Projected screen coordinate of [position] within the current viewport.
  final Offset screenPosition;

  /// Immutable list of markers grouped inside this node.
  final List<ClusterMarker<T>> markers;

  /// Geographic bounding box enclosing all [markers] in this node.
  final GeoBounds bounds;

  /// Estimated minimum zoom level at which this cluster splits into smaller
  /// sub-clusters or individual markers.
  final double expansionZoom;

  /// Number of markers contained in this node.
  int get count => markers.length;

  /// Returns `true` when this node represents two or more grouped markers.
  bool get isCluster => markers.length > 1;

  /// Returns the sole marker when [isCluster] is `false`, or `null` otherwise.
  ClusterMarker<T>? get singleMarker => isCluster ? null : markers.first;

  /// Returns a copy of this node with an updated [screenPosition].
  ClusterNode<T> withScreenPosition(Offset newScreenPosition) {
    return ClusterNode<T>(
      id: id,
      position: position,
      screenPosition: newScreenPosition,
      markers: markers,
      bounds: bounds,
      expansionZoom: expansionZoom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ClusterNode<T> &&
        other.id == id &&
        other.position == position &&
        other.screenPosition == screenPosition &&
        other.count == count &&
        other.bounds == bounds &&
        other.expansionZoom == expansionZoom;
  }

  @override
  int get hashCode =>
      Object.hash(id, position, screenPosition, count, bounds, expansionZoom);

  @override
  String toString() =>
      'ClusterNode<$T>(id: $id, count: $count, position: $position)';
}
