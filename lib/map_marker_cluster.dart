/// Modern, lightweight, customizable, and provider-agnostic map marker
/// clustering library for Flutter.
///
/// Built purely on top of `package:flutter/widgets.dart` with zero third-party
/// dependencies, `map_marker_cluster` provides:
///
/// - **High-performance `O(n)` spatial hash clustering** ([ClusterEngine]) with
///   pan-stable world-coordinate caching and antimeridian-safe centroids.
/// - **Provider-agnostic overlay** ([ClusterMapOverlay]) that layers cleanly on
///   top of `flutter_map`, `google_maps_flutter`, Mapbox, MapLibre, or custom
///   map canvases.
/// - **All-in-one interactive map widget** ([InteractiveClusterMap]) with pan,
///   pinch/wheel focal zoom, animated camera transitions, and a procedural
///   [VectorMapBackdrop].
/// - **Spiderfy radial & Archimedean spiral layouts** ([SpiderfyLayoutEngine],
///   [SpiderfyOverlay]) for co-located or dense clusters.
/// - **Modern, customizable theming** ([ClusterThemeData]) with 4 curated
///   presets (`modern`, `dark`, `minimal`, `emerald`), animated pulsing halos,
///   vector pins, and floating callout cards.
library;

export 'src/controller/cluster_controller.dart';
export 'src/engine/cluster_engine.dart';
export 'src/engine/spiderfy_layout.dart';
export 'src/models/cluster_marker.dart';
export 'src/models/cluster_node.dart';
export 'src/models/cluster_options.dart';
export 'src/models/geo_point.dart';
export 'src/models/map_viewport.dart';
export 'src/theme/cluster_theme.dart';
export 'src/widgets/cluster_builders.dart';
export 'src/widgets/cluster_map_overlay.dart';
export 'src/widgets/default_cluster_badge.dart';
export 'src/widgets/default_marker_callout.dart';
export 'src/widgets/default_marker_pin.dart';
export 'src/widgets/interactive_cluster_map.dart';
export 'src/widgets/spiderfy_overlay.dart';
export 'src/widgets/vector_map_backdrop.dart';
