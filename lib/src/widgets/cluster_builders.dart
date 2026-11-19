import 'package:flutter/widgets.dart';

import '../models/cluster_marker.dart';
import '../models/cluster_node.dart';
import '../models/map_viewport.dart';
import '../theme/cluster_theme.dart';

/// Builder callback for rendering a custom cluster badge widget.
typedef ClusterWidgetBuilder<T> =
    Widget Function(
      BuildContext context,
      ClusterNode<T> cluster,
      ClusterThemeData theme,
    );

/// Builder callback for rendering a custom individual marker widget.
typedef MarkerWidgetBuilder<T> =
    Widget Function(
      BuildContext context,
      ClusterMarker<T> marker,
      ClusterThemeData theme, {
      required bool isSelected,
    });

/// Builder callback for rendering a custom floating callout card above a
/// selected [marker].
typedef CalloutWidgetBuilder<T> =
    Widget Function(
      BuildContext context,
      ClusterMarker<T> marker,
      VoidCallback onClose,
      ClusterThemeData theme,
    );

/// Builder callback for providing a custom background map layer (such as
/// `flutter_map`, `google_maps_flutter`, custom tiles, or vector canvas)
/// synchronized with [viewport].
typedef MapLayerBuilder =
    Widget Function(BuildContext context, MapViewport viewport);

/// Callback invoked when a user taps a cluster badge.
typedef ClusterTapCallback<T> = void Function(ClusterNode<T> cluster);

/// Callback invoked when a user taps an individual marker (either standalone
/// or inside a spiderfied expansion).
typedef MarkerTapCallback<T> = void Function(ClusterMarker<T> marker);
