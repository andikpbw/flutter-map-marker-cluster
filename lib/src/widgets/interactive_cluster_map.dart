import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../controller/cluster_controller.dart';
import '../models/cluster_marker.dart';
import '../models/cluster_options.dart';
import '../models/geo_point.dart';
import '../models/map_viewport.dart';
import '../theme/cluster_theme.dart';
import 'cluster_builders.dart';
import 'cluster_map_overlay.dart';
import 'vector_map_backdrop.dart';

/// All-in-one interactive map widget with built-in smooth pan, focal-point
/// pinch/wheel zoom, double-tap zoom, animated camera transitions, optional
/// floating map controls, and modern marker clustering.
///
/// Supply [mapLayerBuilder] to plug in your own tile/vector/provider map layer
/// beneath the clustering overlay, or omit it to use the lightweight built-in
/// [VectorMapBackdrop].
class InteractiveClusterMap<T> extends StatefulWidget {
  /// Creates an [InteractiveClusterMap].
  InteractiveClusterMap({
    this.controller,
    this.markers,
    this.initialCenter = const GeoPoint(-6.2088, 106.8456),
    this.initialZoom = 11.5,
    this.options = const ClusterOptions(),
    ClusterThemeData? theme,
    this.mapStyle,
    this.mapLayerBuilder,
    this.clusterBuilder,
    this.markerBuilder,
    this.calloutBuilder,
    this.onClusterTap,
    this.onMarkerTap,
    this.showControls = true,
    this.showCalloutOnSelect = true,
    this.enablePan = true,
    this.enableZoom = true,
    this.controlsAlignment = Alignment.bottomRight,
    this.controlsPadding = const EdgeInsets.all(16.0),
    super.key,
  }) : theme = theme ?? ClusterThemeData.modern();

  /// Optional external [ClusterController] for programmatic map and marker
  /// control. If omitted, an internal controller is created automatically.
  final ClusterController<T>? controller;

  /// Markers displayed when [controller] is not provided.
  final List<ClusterMarker<T>>? markers;

  /// Initial map center used when creating an internal controller.
  final GeoPoint initialCenter;

  /// Initial zoom level used when creating an internal controller.
  final double initialZoom;

  /// Clustering options used when creating an internal controller.
  final ClusterOptions options;

  /// Visual theme styling clusters, pins, spiderfy legs, callouts, and
  /// floating controls.
  final ClusterThemeData theme;

  /// Optional cartographic style for the built-in [VectorMapBackdrop].
  ///
  /// When omitted, automatically adapts to dark or light based on
  /// [ClusterThemeData.calloutBackgroundColor] luminance.
  final VectorMapStyle? mapStyle;

  /// Optional custom map layer rendered behind the clustering overlay.
  final MapLayerBuilder? mapLayerBuilder;

  /// Optional custom cluster badge builder.
  final ClusterWidgetBuilder<T>? clusterBuilder;

  /// Optional custom individual marker builder.
  final MarkerWidgetBuilder<T>? markerBuilder;

  /// Optional custom callout card builder.
  final CalloutWidgetBuilder<T>? calloutBuilder;

  /// Callback invoked when a cluster badge is tapped.
  final ClusterTapCallback<T>? onClusterTap;

  /// Callback invoked when an individual marker is tapped.
  final MarkerTapCallback<T>? onMarkerTap;

  /// Whether built-in floating zoom (`+` / `−`) and fit-all buttons are shown.
  final bool showControls;

  /// Whether tapping a marker opens the floating callout card.
  final bool showCalloutOnSelect;

  /// Whether dragging pans the map viewport.
  final bool enablePan;

  /// Whether pinch, double-tap, and mouse-wheel scrolling zoom the viewport.
  final bool enableZoom;

  /// Corner alignment for the floating map controls.
  final Alignment controlsAlignment;

  /// Outer inset for the floating map controls.
  final EdgeInsets controlsPadding;

  @override
  State<InteractiveClusterMap<T>> createState() =>
      _InteractiveClusterMapState<T>();
}

class _InteractiveClusterMapState<T> extends State<InteractiveClusterMap<T>>
    with SingleTickerProviderStateMixin {
  ClusterController<T>? _internalController;
  late final AnimationController _cameraAnimController;

  GeoPoint? _animStartCenter;
  GeoPoint? _animEndCenter;
  double _animStartZoom = 11.0;
  double _animEndZoom = 11.0;
  double _animStartRotation = 0.0;
  double _animEndRotation = 0.0;
  Curve _animCurve = Curves.easeOutCubic;

  // Active scale/pan gesture state.
  GeoPoint? _gestureAnchorGeo;
  double _gestureStartZoom = 11.0;
  Offset? _lastDoubleTapDown;

  ClusterController<T> get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(_onCameraAnimationTick);

    if (widget.controller == null) {
      _internalController = ClusterController<T>(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        initialMarkers: widget.markers ?? const <Never>[],
        options: widget.options,
      );
    }

    _controller.attachCameraAnimationHandler(_startCameraTransition);
  }

  @override
  void didUpdateWidget(covariant InteractiveClusterMap<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)
          ?.attachCameraAnimationHandler(null);

      if (widget.controller == null) {
        _internalController ??= ClusterController<T>(
          initialCenter: widget.initialCenter,
          initialZoom: widget.initialZoom,
          initialMarkers: widget.markers ?? const <Never>[],
          options: widget.options,
        );
      } else {
        _internalController?.dispose();
        _internalController = null;
      }
      _controller.attachCameraAnimationHandler(_startCameraTransition);
    }

    if (widget.controller == null && _internalController != null) {
      if (widget.options != oldWidget.options) {
        _internalController!.setOptions(widget.options);
      }
      if (widget.markers != null &&
          !identical(widget.markers, oldWidget.markers)) {
        _internalController!.setMarkers(widget.markers!);
      }
    }
  }

  void _startCameraTransition(ClusterCameraTransition transition) {
    final vp = _controller.viewport;
    _animStartCenter = vp.center;
    _animEndCenter = transition.targetCenter;
    _animStartZoom = vp.zoom;
    _animEndZoom = transition.targetZoom;
    _animStartRotation = vp.rotation;
    _animEndRotation = transition.targetRotation;
    _animCurve = transition.curve;

    _cameraAnimController.duration = transition.duration;
    _cameraAnimController.forward(from: 0.0);
  }

  void _onCameraAnimationTick() {
    final startCenter = _animStartCenter;
    final endCenter = _animEndCenter;
    if (startCenter == null || endCenter == null) {
      return;
    }
    final t = _animCurve.transform(_cameraAnimController.value);
    final nextCenter = GeoPoint.lerp(startCenter, endCenter, t);
    final nextZoom =
        lerpDouble(_animStartZoom, _animEndZoom, t) ?? _animEndZoom;
    final nextRotation =
        lerpDouble(_animStartRotation, _animEndRotation, t) ?? _animEndRotation;
    _controller.updateViewport(
      center: nextCenter,
      zoom: nextZoom,
      rotation: nextRotation,
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (!widget.enablePan && !widget.enableZoom) {
      return;
    }
    if (_cameraAnimController.isAnimating) {
      _cameraAnimController.stop();
    }
    final vp = _controller.viewport;
    _gestureStartZoom = vp.zoom;
    _gestureAnchorGeo = vp.screenToLatLng(details.localFocalPoint);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enablePan && !widget.enableZoom) {
      return;
    }
    final anchorGeo = _gestureAnchorGeo;
    if (anchorGeo == null) {
      return;
    }

    final vp = _controller.viewport;
    final double nextZoom;
    if (widget.enableZoom && details.scale != 1.0 && details.scale > 0.0) {
      final zoomDelta = math.log(details.scale) / math.ln2;
      nextZoom = (_gestureStartZoom + zoomDelta).clamp(
        _controller.options.minZoom,
        _controller.options.maxZoom,
      );
    } else {
      nextZoom = vp.zoom;
    }

    if (!widget.enablePan) {
      _controller.updateViewport(zoom: nextZoom);
      return;
    }

    final newCenter = _centerKeepingAnchorAtScreenPoint(
      anchorGeo: anchorGeo,
      targetScreenPoint: details.localFocalPoint,
      viewport: vp.copyWith(zoom: nextZoom),
    );
    _controller.updateViewport(center: newCenter, zoom: nextZoom);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _gestureAnchorGeo = null;
  }

  void _handleDoubleTap() {
    if (!widget.enableZoom) {
      return;
    }
    final focal = _lastDoubleTapDown;
    final vp = _controller.viewport;
    final nextZoom = (vp.zoom + 1.25).clamp(
      _controller.options.minZoom,
      _controller.options.maxZoom,
    );
    if (focal == null) {
      _controller.animateTo(vp.center, zoom: nextZoom);
      return;
    }
    final anchorGeo = vp.screenToLatLng(focal);
    final nextCenter = _centerKeepingAnchorAtScreenPoint(
      anchorGeo: anchorGeo,
      targetScreenPoint: focal,
      viewport: vp.copyWith(zoom: nextZoom),
    );
    _controller.animateTo(nextCenter, zoom: nextZoom);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!widget.enableZoom || event is! PointerScrollEvent) {
      return;
    }
    if (_cameraAnimController.isAnimating) {
      _cameraAnimController.stop();
    }
    final vp = _controller.viewport;
    final zoomStep = (-event.scrollDelta.dy / 220.0).clamp(-1.2, 1.2);
    final nextZoom = (vp.zoom + zoomStep).clamp(
      _controller.options.minZoom,
      _controller.options.maxZoom,
    );
    if ((nextZoom - vp.zoom).abs() < 1e-4) {
      return;
    }
    final anchorGeo = vp.screenToLatLng(event.localPosition);
    final nextCenter = _centerKeepingAnchorAtScreenPoint(
      anchorGeo: anchorGeo,
      targetScreenPoint: event.localPosition,
      viewport: vp.copyWith(zoom: nextZoom),
    );
    _controller.updateViewport(center: nextCenter, zoom: nextZoom);
  }

  static GeoPoint _centerKeepingAnchorAtScreenPoint({
    required GeoPoint anchorGeo,
    required Offset targetScreenPoint,
    required MapViewport viewport,
  }) {
    final sx = targetScreenPoint.dx - viewport.size.width / 2.0;
    final sy = targetScreenPoint.dy - viewport.size.height / 2.0;

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

    final anchorWorld = viewport.projection.latLngToWorld(
      anchorGeo,
      viewport.zoom,
    );
    final newCenterWorld = Offset(anchorWorld.dx - dx, anchorWorld.dy - dy);
    return viewport.projection.worldToLatLng(newCenterWorld, viewport.zoom);
  }

  VectorMapStyle _resolveMapStyle() {
    if (widget.mapStyle != null) {
      return widget.mapStyle!;
    }
    final bg = widget.theme.calloutBackgroundColor;
    final luminance = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b;
    return luminance < 0.45
        ? const VectorMapStyle.dark()
        : const VectorMapStyle.light();
  }

  @override
  void dispose() {
    _controller.attachCameraAnimationHandler(null);
    _cameraAnimController.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final measuredSize =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? constraints.biggest
            : _controller.viewport.size;
        if (measuredSize != _controller.viewport.size &&
            measuredSize.width > 0.0 &&
            measuredSize.height > 0.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _controller.updateViewportSize(measuredSize);
            }
          });
        }

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Interactive map viewport (pan, pinch, wheel zoom, and
              // double-tap on empty map surface). Controls sit outside so rapid
              // taps on +/- buttons are instant and never trigger map gestures.
              Listener(
                onPointerSignal: _handlePointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onScaleEnd: _handleScaleEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTapDown: (TapDownDetails details) {
                          _lastDoubleTapDown = details.localPosition;
                        },
                        onDoubleTap: _handleDoubleTap,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (BuildContext context, Widget? child) {
                            final vp = _controller.viewport.copyWith(
                              size: measuredSize,
                            );
                            if (widget.mapLayerBuilder != null) {
                              return widget.mapLayerBuilder!(context, vp);
                            }
                            return VectorMapBackdrop(
                              viewport: vp,
                              style: _resolveMapStyle(),
                            );
                          },
                        ),
                      ),
                      ClusterMapOverlay<T>(
                        controller: _controller,
                        theme: widget.theme,
                        clusterBuilder: widget.clusterBuilder,
                        markerBuilder: widget.markerBuilder,
                        calloutBuilder: widget.calloutBuilder,
                        onClusterTap: widget.onClusterTap,
                        onMarkerTap: widget.onMarkerTap,
                        showCalloutOnSelect: widget.showCalloutOnSelect,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.showControls)
                Align(
                  alignment: widget.controlsAlignment,
                  child: Padding(
                    padding: widget.controlsPadding,
                    child: _MapControlsPanel(
                      theme: widget.theme,
                      onZoomIn: _controller.zoomIn,
                      onZoomOut: _controller.zoomOut,
                      onFitMarkers: _controller.fitMarkers,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MapControlsPanel extends StatelessWidget {
  const _MapControlsPanel({
    required this.theme,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitMarkers,
  });

  final ClusterThemeData theme;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitMarkers;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.calloutBackgroundColor,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: theme.calloutBorderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.14),
            blurRadius: 16.0,
            offset: const Offset(0.0, 6.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ControlIconButton(
            semanticLabel: 'Zoom in',
            icon: _ControlIconType.plus,
            color: theme.calloutTitleColor,
            hoverColor: theme.calloutBadgeBackground,
            onTap: onZoomIn,
          ),
          Container(width: 24.0, height: 1.0, color: theme.calloutBorderColor),
          _ControlIconButton(
            semanticLabel: 'Zoom out',
            icon: _ControlIconType.minus,
            color: theme.calloutTitleColor,
            hoverColor: theme.calloutBadgeBackground,
            onTap: onZoomOut,
          ),
          Container(width: 24.0, height: 1.0, color: theme.calloutBorderColor),
          _ControlIconButton(
            semanticLabel: 'Fit all markers',
            icon: _ControlIconType.fitBounds,
            color: theme.calloutTitleColor,
            hoverColor: theme.calloutBadgeBackground,
            onTap: onFitMarkers,
          ),
        ],
      ),
    );
  }
}

enum _ControlIconType { plus, minus, fitBounds }

class _ControlIconButton extends StatefulWidget {
  const _ControlIconButton({
    required this.semanticLabel,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  final String semanticLabel;
  final _ControlIconType icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  @override
  State<_ControlIconButton> createState() => _ControlIconButtonState();
}

class _ControlIconButtonState extends State<_ControlIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 38.0,
            height: 36.0,
            decoration: BoxDecoration(
              color: _hovered ? widget.hoverColor : const Color(0x00000000),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: CustomPaint(
              painter: _ControlIconPainter(
                icon: widget.icon,
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlIconPainter extends CustomPainter {
  const _ControlIconPainter({required this.icon, required this.color});

  final _ControlIconType icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    switch (icon) {
      case _ControlIconType.plus:
        canvas.drawLine(Offset(cx - 5.5, cy), Offset(cx + 5.5, cy), paint);
        canvas.drawLine(Offset(cx, cy - 5.5), Offset(cx, cy + 5.5), paint);
      case _ControlIconType.minus:
        canvas.drawLine(Offset(cx - 5.5, cy), Offset(cx + 5.5, cy), paint);
      case _ControlIconType.fitBounds:
        const r = 6.0;
        const arm = 3.2;
        // Top-left corner
        canvas.drawLine(
          Offset(cx - r, cy - r + arm),
          Offset(cx - r, cy - r),
          paint,
        );
        canvas.drawLine(
          Offset(cx - r, cy - r),
          Offset(cx - r + arm, cy - r),
          paint,
        );
        // Top-right corner
        canvas.drawLine(
          Offset(cx + r - arm, cy - r),
          Offset(cx + r, cy - r),
          paint,
        );
        canvas.drawLine(
          Offset(cx + r, cy - r),
          Offset(cx + r, cy - r + arm),
          paint,
        );
        // Bottom-right corner
        canvas.drawLine(
          Offset(cx + r, cy + r - arm),
          Offset(cx + r, cy + r),
          paint,
        );
        canvas.drawLine(
          Offset(cx + r, cy + r),
          Offset(cx + r - arm, cy + r),
          paint,
        );
        // Bottom-left corner
        canvas.drawLine(
          Offset(cx - r + arm, cy + r),
          Offset(cx - r, cy + r),
          paint,
        );
        canvas.drawLine(
          Offset(cx - r, cy + r),
          Offset(cx - r, cy + r - arm),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ControlIconPainter oldDelegate) {
    return oldDelegate.icon != icon || oldDelegate.color != color;
  }
}
