import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controller/cluster_controller.dart';
import '../engine/cluster_engine.dart';
import '../models/cluster_marker.dart';
import '../models/cluster_node.dart';
import '../models/cluster_options.dart';
import '../models/map_viewport.dart';
import '../theme/cluster_theme.dart';
import 'cluster_builders.dart';
import 'default_cluster_badge.dart';
import 'default_marker_callout.dart';
import 'default_marker_pin.dart';
import 'spiderfy_overlay.dart';

/// Provider-agnostic marker clustering overlay that can be placed directly
/// above **any** Flutter map widget (`flutter_map`, `google_maps_flutter`,
/// `apple_maps_flutter`, Mapbox, MapLibre, or custom canvas maps) inside a
/// [Stack].
///
/// Works in either:
/// - **Controller mode**: pass a shared [controller] to programmatically
///   control markers, filtering, camera fit, selection, and spiderfy state.
/// - **Declarative mode**: omit [controller] and provide [markers] and
///   [viewport] directly; an internal controller is managed automatically.
///
/// Empty areas never intercept pan/pinch gestures from the underlying map
/// provider.
class ClusterMapOverlay<T> extends StatefulWidget {
  /// Creates a [ClusterMapOverlay].
  ///
  /// Either [controller] must be supplied, or both [markers] and [viewport]
  /// must be supplied.
  ClusterMapOverlay({
    this.controller,
    this.markers,
    this.viewport,
    this.options,
    ClusterThemeData? theme,
    this.clusterBuilder,
    this.markerBuilder,
    this.calloutBuilder,
    this.onClusterTap,
    this.onMarkerTap,
    this.showCalloutOnSelect = true,
    this.dismissOnBackgroundTap = true,
    super.key,
  }) : theme = theme ?? ClusterThemeData.modern(),
       assert(
         controller != null || (markers != null && viewport != null),
         'Provide either a ClusterController or both markers and viewport.',
       );

  /// Optional external reactive controller managing markers and camera state.
  final ClusterController<T>? controller;

  /// Declarative markers used when [controller] is not supplied.
  final List<ClusterMarker<T>>? markers;

  /// Declarative viewport snapshot used when [controller] is not supplied.
  final MapViewport? viewport;

  /// Optional clustering configuration overriding the controller's options.
  final ClusterOptions? options;

  /// Visual theme applied to default badges, pins, spider legs, and callouts.
  final ClusterThemeData theme;

  /// Optional custom builder for multi-marker cluster badges.
  final ClusterWidgetBuilder<T>? clusterBuilder;

  /// Optional custom builder for individual markers.
  final MarkerWidgetBuilder<T>? markerBuilder;

  /// Optional custom builder for the floating marker callout card.
  final CalloutWidgetBuilder<T>? calloutBuilder;

  /// Optional callback fired whenever a cluster badge is tapped.
  ///
  /// Built-in [ClusterOptions.tapBehavior] runs first unless set to
  /// [ClusterTapBehavior.none].
  final ClusterTapCallback<T>? onClusterTap;

  /// Optional callback fired whenever an individual marker is tapped.
  final MarkerTapCallback<T>? onMarkerTap;

  /// Whether selecting a marker automatically displays the floating callout.
  final bool showCalloutOnSelect;

  /// Whether tapping empty space dismisses open callouts and spiderfy overlays
  /// without blocking underlying map pan/pinch gestures.
  final bool dismissOnBackgroundTap;

  @override
  State<ClusterMapOverlay<T>> createState() => _ClusterMapOverlayState<T>();
}

class _ClusterMapOverlayState<T> extends State<ClusterMapOverlay<T>>
    with TickerProviderStateMixin {
  ClusterController<T>? _internalController;
  late AnimationController _transitionController;
  late AnimationController _spiderfyController;

  double? _lastZoomBucket;
  Map<String, Offset> _lastMarkerScreenPos = <String, Offset>{};
  Map<String, Offset> _transitionOrigins = <String, Offset>{};
  bool _wasSpiderfied = false;
  Offset? _pointerDownPosition;

  ClusterController<T> get _activeController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: widget.theme.transitionDuration,
      value: 1.0,
    );
    _spiderfyController = AnimationController(
      vsync: this,
      duration: widget.theme.transitionDuration,
      value: 0.0,
    );

    if (widget.controller == null) {
      final vp = widget.viewport!;
      _internalController = ClusterController<T>(
        initialCenter: vp.center,
        initialZoom: vp.zoom,
        initialRotation: vp.rotation,
        initialViewportSize: vp.size,
        initialMarkers: widget.markers ?? const <Never>[],
        options: widget.options ?? const ClusterOptions(),
        projection: vp.projection,
      );
    } else if (widget.options != null) {
      widget.controller!.setOptions(widget.options!);
    }

    _activeController.addListener(_onControllerChanged);
    _wasSpiderfied = _activeController.isSpiderfied;
    if (_wasSpiderfied) {
      _spiderfyController.value = 1.0;
    }
    _lastZoomBucket = ClusterEngine.quantizeZoom(
      _activeController.zoom,
      _activeController.options,
    );
  }

  @override
  void didUpdateWidget(covariant ClusterMapOverlay<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.theme.transitionDuration != widget.theme.transitionDuration) {
      _transitionController.duration = widget.theme.transitionDuration;
      _spiderfyController.duration = widget.theme.transitionDuration;
    }

    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)?.removeListener(
        _onControllerChanged,
      );

      if (widget.controller == null) {
        final vp = widget.viewport!;
        _internalController ??= ClusterController<T>(
          initialCenter: vp.center,
          initialZoom: vp.zoom,
          initialRotation: vp.rotation,
          initialViewportSize: vp.size,
          initialMarkers: widget.markers ?? const <Never>[],
          options: widget.options ?? const ClusterOptions(),
          projection: vp.projection,
        );
      } else {
        _internalController?.dispose();
        _internalController = null;
      }

      _activeController.addListener(_onControllerChanged);
    }

    if (widget.controller == null && _internalController != null) {
      if (widget.options != null) {
        _internalController!.setOptions(widget.options!);
      }
      if (widget.markers != null &&
          !identical(widget.markers, oldWidget.markers)) {
        _internalController!.setMarkers(widget.markers!);
      }
      if (widget.viewport != null && widget.viewport != oldWidget.viewport) {
        final vp = widget.viewport!;
        _internalController!.updateViewport(
          center: vp.center,
          zoom: vp.zoom,
          size: vp.size,
          rotation: vp.rotation,
          projection: vp.projection,
        );
      }
    } else if (widget.controller != null &&
        widget.options != null &&
        widget.options != oldWidget.options) {
      widget.controller!.setOptions(widget.options!);
    }
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    final controller = _activeController;
    final currentBucket = ClusterEngine.quantizeZoom(
      controller.zoom,
      controller.options,
    );

    // Animate split/merge transitions when crossing zoom bucket boundaries.
    if (controller.options.animateTransitions &&
        _lastZoomBucket != null &&
        _lastZoomBucket != currentBucket &&
        _lastMarkerScreenPos.isNotEmpty) {
      final origins = <String, Offset>{};
      for (final node in controller.visibleNodes) {
        var sumX = 0.0;
        var sumY = 0.0;
        var hits = 0;
        for (final marker in node.markers) {
          final prev = _lastMarkerScreenPos[marker.id];
          if (prev != null) {
            sumX += prev.dx;
            sumY += prev.dy;
            hits++;
          }
        }
        if (hits > 0) {
          origins[node.id] = Offset(sumX / hits, sumY / hits);
        }
      }
      _transitionOrigins = origins;
      _transitionController.forward(from: 0.0);
    } else if (_lastZoomBucket != currentBucket) {
      _transitionOrigins = <String, Offset>{};
      _transitionController.value = 1.0;
    }
    _lastZoomBucket = currentBucket;

    // Drive spiderfy expansion animation cleanly.
    final isSpiderfied = controller.isSpiderfied;
    if (isSpiderfied && !_wasSpiderfied) {
      _spiderfyController.forward(from: 0.0);
    } else if (!isSpiderfied && _wasSpiderfied) {
      _spiderfyController.value = 0.0;
    }
    _wasSpiderfied = isSpiderfied;

    setState(() {});
  }

  void _recordCurrentPositions(
    List<ClusterNode<T>> nodes,
    MapViewport effectiveViewport,
  ) {
    final nextMap = <String, Offset>{};
    for (final node in nodes) {
      final pos = effectiveViewport.latLngToScreen(node.position);
      for (final marker in node.markers) {
        nextMap[marker.id] = pos;
      }
    }
    _lastMarkerScreenPos = nextMap;
  }

  void _handleClusterTap(ClusterNode<T> cluster) {
    _activeController.handleClusterTap(cluster);
    widget.onClusterTap?.call(cluster);
  }

  void _handleMarkerTap(ClusterMarker<T> marker) {
    final controller = _activeController;
    if (controller.selectedMarker?.id == marker.id) {
      controller.clearSelection();
    } else {
      controller.selectMarker(marker);
    }
    widget.onMarkerTap?.call(marker);
  }

  void _scheduleViewportSizeSync(Size measuredSize) {
    if (measuredSize.width <= 0.0 || measuredSize.height <= 0.0) {
      return;
    }
    final controller = _activeController;
    if (controller.viewport.size == measuredSize) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.updateViewportSize(measuredSize);
      }
    });
  }

  @override
  void dispose() {
    _activeController.removeListener(_onControllerChanged);
    _internalController?.dispose();
    _transitionController.dispose();
    _spiderfyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final controller = _activeController;
        final measuredSize =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? constraints.biggest
            : controller.viewport.size;
        _scheduleViewportSizeSync(measuredSize);

        final effectiveViewport = controller.viewport.copyWith(
          size: measuredSize,
        );
        final nodes = controller.visibleNodes;
        _recordCurrentPositions(nodes, effectiveViewport);

        final spiderfyLayout = controller.spiderfyLayout;
        final spiderfiedClusterId = controller.spiderfiedCluster?.id;
        final selectedMarker = controller.selectedMarker;

        return ClipRect(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (PointerDownEvent event) {
              _pointerDownPosition = event.localPosition;
            },
            onPointerUp: (PointerUpEvent event) {
              if (!widget.dismissOnBackgroundTap) {
                return;
              }
              final down = _pointerDownPosition;
              _pointerDownPosition = null;
              if (down == null) {
                return;
              }
              final moved = (event.localPosition - down).distance;
              if (moved < 8.0 &&
                  (controller.selectedMarker != null ||
                      controller.isSpiderfied)) {
                // Only dismiss if pointer was not consumed by a marker/cluster
                // tap that just selected or spiderfied on this same frame.
                _maybeDismissOnTap(event.localPosition, effectiveViewport);
              }
            },
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _transitionController,
                _spiderfyController,
              ]),
              builder: (BuildContext context, Widget? child) {
                final transitionT = widget.theme.transitionCurve.transform(
                  _transitionController.value,
                );

                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // Render clusters and standalone markers.
                    for (final node in nodes)
                      if (spiderfiedClusterId != node.id)
                        _buildNodeWidget(
                          context,
                          node: node,
                          effectiveViewport: effectiveViewport,
                          transitionT: transitionT,
                          selectedMarkerId: selectedMarker?.id,
                        ),
                    // Active spiderfy radial/spiral expansion.
                    if (spiderfyLayout != null)
                      SpiderfyOverlay<T>(
                        layout: spiderfyLayout,
                        centerScreenPosition: effectiveViewport.latLngToScreen(
                          spiderfyLayout.cluster.position,
                        ),
                        progress: _spiderfyController.value,
                        theme: widget.theme,
                        selectedMarkerId: selectedMarker?.id,
                        onMarkerTap: _handleMarkerTap,
                        onCenterTap: controller.unspiderfy,
                        markerBuilder: widget.markerBuilder,
                      ),
                    // Floating callout card for selected marker.
                    if (widget.showCalloutOnSelect && selectedMarker != null)
                      _buildCalloutOverlay(
                        context,
                        marker: selectedMarker,
                        effectiveViewport: effectiveViewport,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _maybeDismissOnTap(Offset tapPos, MapViewport viewport) {
    final controller = _activeController;
    // Check if the tap landed on any rendered cluster/marker or spiderfied item
    // so we don't accidentally cancel a fresh selection.
    const hitRadius = 32.0;
    for (final node in controller.visibleNodes) {
      final pos = viewport.latLngToScreen(node.position);
      if ((pos - tapPos).distance <= hitRadius) {
        return;
      }
    }
    final layout = controller.spiderfyLayout;
    if (layout != null) {
      final center = viewport.latLngToScreen(layout.cluster.position);
      if ((center - tapPos).distance <= 24.0) {
        return;
      }
      for (final item in layout.items) {
        final pos = center + item.offset;
        if ((pos - tapPos).distance <= hitRadius) {
          return;
        }
      }
    }
    // Check callout region if open (accounting for above/below placement).
    if (controller.selectedMarker != null) {
      final selected = controller.selectedMarker!;
      final anchor = _resolveSelectedMarkerScreenPosition(selected, viewport);
      if (anchor != null) {
        final cardWidth = math.min(
          widget.theme.calloutMaxWidth,
          math.max(168.0, viewport.size.width - 24.0),
        );
        const edgePadding = 12.0;
        final maxLeft = math.max(
          edgePadding,
          viewport.size.width - cardWidth - edgePadding,
        );
        final left = (anchor.dx - cardWidth / 2.0).clamp(edgePadding, maxLeft);
        final pinHeight = selected.size?.height ?? widget.theme.markerSize;
        final showBelow = anchor.dy < 156.0;
        final calloutRect = showBelow
            ? Rect.fromLTWH(
                left - 8.0,
                anchor.dy + 4.0,
                cardWidth + 16.0,
                176.0,
              )
            : Rect.fromLTWH(
                left - 8.0,
                anchor.dy - pinHeight - 180.0,
                cardWidth + 16.0,
                180.0,
              );
        if (calloutRect.contains(tapPos)) {
          return;
        }
      }
    }
    controller.dismissOverlays();
  }

  Widget _buildNodeWidget(
    BuildContext context, {
    required ClusterNode<T> node,
    required MapViewport effectiveViewport,
    required double transitionT,
    required String? selectedMarkerId,
  }) {
    final targetPos = effectiveViewport.latLngToScreen(node.position);
    final origin = _transitionOrigins[node.id];
    final animatedPos = (origin != null && transitionT < 0.999)
        ? Offset.lerp(origin, targetPos, transitionT)!
        : targetPos;
    final entryScale = (origin != null && transitionT < 0.999)
        ? (0.76 + 0.24 * transitionT)
        : 1.0;

    if (node.isCluster) {
      final tier = widget.theme.tierForCount(node.count);
      final haloSpread = widget.theme.showHalo ? widget.theme.haloSpread : 0.0;
      final outerSize = tier.diameter + haloSpread * 2.0;

      final Widget badge;
      if (widget.clusterBuilder != null) {
        badge = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleClusterTap(node),
          child: widget.clusterBuilder!(context, node, widget.theme),
        );
      } else {
        badge = DefaultClusterBadge<T>(
          cluster: node,
          theme: widget.theme,
          onTap: () => _handleClusterTap(node),
        );
      }

      return Positioned(
        key: ValueKey<String>(node.id),
        left: animatedPos.dx - outerSize / 2.0,
        top: animatedPos.dy - outerSize / 2.0,
        child: Transform.scale(scale: entryScale, child: badge),
      );
    }

    final marker = node.singleMarker!;
    final isSelected = selectedMarkerId == marker.id;
    final pinHeight = marker.size?.height ?? widget.theme.markerSize;
    final pinWidth = marker.size?.width ?? (pinHeight * 0.84);
    final totalWidth = pinWidth + 14.0;
    final totalHeight = pinHeight + 12.0;

    final Widget pin;
    if (widget.markerBuilder != null) {
      pin = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleMarkerTap(marker),
        child: widget.markerBuilder!(
          context,
          marker,
          widget.theme,
          isSelected: isSelected,
        ),
      );
    } else {
      pin = DefaultMarkerPin<T>(
        marker: marker,
        theme: widget.theme,
        isSelected: isSelected,
        onTap: () => _handleMarkerTap(marker),
      );
    }

    return Positioned(
      key: ValueKey<String>(node.id),
      left: animatedPos.dx - totalWidth / 2.0,
      top: animatedPos.dy - totalHeight + 5.0,
      child: Transform.scale(
        scale: entryScale,
        alignment: Alignment.bottomCenter,
        child: pin,
      ),
    );
  }

  Offset? _resolveSelectedMarkerScreenPosition(
    ClusterMarker<T> marker,
    MapViewport viewport,
  ) {
    final layout = _activeController.spiderfyLayout;
    if (layout != null) {
      final center = viewport.latLngToScreen(layout.cluster.position);
      for (final item in layout.items) {
        if (item.marker.id == marker.id) {
          return center + item.offset;
        }
      }
    }
    return viewport.latLngToScreen(marker.position);
  }

  Widget _buildCalloutOverlay(
    BuildContext context, {
    required ClusterMarker<T> marker,
    required MapViewport effectiveViewport,
  }) {
    final anchor = _resolveSelectedMarkerScreenPosition(
      marker,
      effectiveViewport,
    );
    if (anchor == null) {
      return const SizedBox.shrink();
    }

    final cardWidth = math.min(
      widget.theme.calloutMaxWidth,
      math.max(168.0, effectiveViewport.size.width - 24.0),
    );
    const edgePadding = 12.0;
    const minLeft = edgePadding;
    final maxLeft = math.max(
      edgePadding,
      effectiveViewport.size.width - cardWidth - edgePadding,
    );
    final left = (anchor.dx - cardWidth / 2.0).clamp(minLeft, maxLeft);
    final arrowFraction = ((anchor.dx - left) / cardWidth).clamp(0.12, 0.88);

    final pinHeight = marker.size?.height ?? widget.theme.markerSize;
    final showBelow = anchor.dy < 156.0;

    final Widget calloutContent;
    if (widget.calloutBuilder != null) {
      calloutContent = widget.calloutBuilder!(
        context,
        marker,
        _activeController.clearSelection,
        widget.theme,
      );
    } else {
      calloutContent = DefaultMarkerCallout<T>(
        marker: marker,
        theme: widget.theme,
        onClose: _activeController.clearSelection,
        arrowOffsetFraction: arrowFraction,
        pointUp: showBelow,
      );
    }

    if (showBelow) {
      return Positioned(
        key: ValueKey<String>('callout:${marker.id}'),
        left: left,
        top: anchor.dy + 10.0,
        width: cardWidth,
        child: calloutContent,
      );
    }

    return Positioned(
      key: ValueKey<String>('callout:${marker.id}'),
      left: left,
      bottom: effectiveViewport.size.height - (anchor.dy - pinHeight - 8.0),
      width: cardWidth,
      child: calloutContent,
    );
  }
}
