import 'package:flutter/widgets.dart';

import 'geo_point.dart';

/// A data-carrying map marker that can be grouped into clusters by
/// `ClusterEngine` and rendered by `ClusterMapOverlay` or
/// `InteractiveClusterMap`.
///
/// The generic type parameter [T] lets you attach any strongly-typed domain
/// model (such as a store, vehicle, property, or event) without sacrificing
/// type safety.
@immutable
class ClusterMarker<T> {
  /// Creates a [ClusterMarker].
  ///
  /// The [id] must uniquely identify the marker within a dataset so animations,
  /// selection state, and spiderfy transitions remain stable across updates.
  const ClusterMarker({
    required this.id,
    required this.position,
    this.data,
    this.label,
    this.subtitle,
    this.category,
    this.accentColor,
    this.weight = 1.0,
    this.zIndex = 0,
    this.size,
  }) : assert(weight > 0.0, 'Marker weight must be greater than zero.');

  /// Unique identifier for this marker.
  final String id;

  /// Geographic position of this marker.
  final GeoPoint position;

  /// Optional strongly-typed payload attached to this marker.
  final T? data;

  /// Optional primary display title shown in callouts or accessibility labels.
  final String? label;

  /// Optional secondary line shown beneath [label] in default callouts.
  final String? subtitle;

  /// Optional category tag (e.g. `'Cafe'`, `'Transit'`, `'Hotel'`) displayed
  /// as a badge in default callouts and usable for filtering.
  final String? category;

  /// Optional accent color overriding the theme default for this marker pin.
  final Color? accentColor;

  /// Positive weight used when computing weighted cluster centroids.
  ///
  /// Defaults to `1.0`.
  final double weight;

  /// Rendering order priority. Higher values render above lower values.
  final int zIndex;

  /// Optional custom hit/layout size for this individual marker.
  final Size? size;

  /// Returns a copy of this marker with the specified fields replaced.
  ClusterMarker<T> copyWith({
    String? id,
    GeoPoint? position,
    T? data,
    String? label,
    String? subtitle,
    String? category,
    Color? accentColor,
    double? weight,
    int? zIndex,
    Size? size,
  }) {
    return ClusterMarker<T>(
      id: id ?? this.id,
      position: position ?? this.position,
      data: data ?? this.data,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      accentColor: accentColor ?? this.accentColor,
      weight: weight ?? this.weight,
      zIndex: zIndex ?? this.zIndex,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ClusterMarker<T> &&
        other.id == id &&
        other.position == position &&
        other.data == data &&
        other.label == label &&
        other.subtitle == subtitle &&
        other.category == category &&
        other.accentColor == accentColor &&
        other.weight == weight &&
        other.zIndex == zIndex &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(
    id,
    position,
    data,
    label,
    subtitle,
    category,
    accentColor,
    weight,
    zIndex,
    size,
  );

  @override
  String toString() =>
      'ClusterMarker<$T>(id: $id, position: $position, label: $label)';
}
