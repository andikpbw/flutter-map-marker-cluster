import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../engine/spiderfy_layout.dart';
import '../theme/cluster_theme.dart';
import 'cluster_builders.dart';
import 'default_marker_pin.dart';

/// Animated overlay that renders curved or straight spider legs connecting a
/// cluster's anchor to its radially fanned-out markers.
class SpiderfyOverlay<T> extends StatelessWidget {
  /// Creates a [SpiderfyOverlay].
  const SpiderfyOverlay({
    required this.layout,
    required this.centerScreenPosition,
    required this.progress,
    required this.theme,
    required this.selectedMarkerId,
    required this.onMarkerTap,
    required this.onCenterTap,
    this.markerBuilder,
    super.key,
  });

  /// Computed spiderfy item geometry.
  final SpiderfyLayout<T> layout;

  /// Current screen position of the cluster's geographic center.
  final Offset centerScreenPosition;

  /// Animation progress from `0.0` (collapsed) to `1.0` (fully expanded).
  final double progress;

  /// Visual theme styling legs, anchor, and default pins.
  final ClusterThemeData theme;

  /// Identifier of the currently selected marker, if any.
  final String? selectedMarkerId;

  /// Callback invoked when any spiderfied marker is tapped.
  final MarkerTapCallback<T> onMarkerTap;

  /// Callback invoked when the central spider anchor is tapped (typically to
  /// collapse the spiderfy).
  final VoidCallback onCenterTap;

  /// Optional custom builder for each spiderfied marker.
  final MarkerWidgetBuilder<T>? markerBuilder;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final markerEase = Curves.easeOutBack
        .transform(progress.clamp(0.0, 1.0))
        .clamp(0.0, 1.08);
    const anchorSize = 26.0;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Spider legs painted smoothly behind markers.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SpiderLegsPainter<T>(
                layout: layout,
                center: centerScreenPosition,
                progress: eased,
                legColor: theme.spiderLegColor,
                legWidth: theme.spiderLegWidth,
                curved: theme.curvedSpiderLegs,
              ),
            ),
          ),
        ),
        // Central clickable anchor hub to collapse spiderfy.
        Positioned(
          left: centerScreenPosition.dx - anchorSize / 2.0,
          top: centerScreenPosition.dy - anchorSize / 2.0,
          child: Opacity(
            opacity: eased.clamp(0.0, 1.0),
            child: Semantics(
              button: true,
              label: 'Collapse expanded cluster',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCenterTap,
                  child: Container(
                    width: anchorSize,
                    height: anchorSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.spiderCenterColor.withValues(alpha: 0.16),
                      border: Border.all(
                        color: theme.spiderCenterColor,
                        width: 2.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: layout.hiddenCount > 0
                        ? Text(
                            '+${layout.hiddenCount}',
                            style: TextStyle(
                              color: theme.spiderCenterColor,
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                              fontFamily: theme.fontFamily,
                              decoration: TextDecoration.none,
                            ),
                          )
                        : Container(
                            width: 8.0,
                            height: 8.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.spiderCenterColor,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Fanned-out markers.
        for (final item in layout.items)
          _buildSpiderfiedMarker(
            context,
            item: item,
            positionProgress: markerEase,
            opacityProgress: eased,
          ),
      ],
    );
  }

  Widget _buildSpiderfiedMarker(
    BuildContext context, {
    required SpiderfiedItem<T> item,
    required double positionProgress,
    required double opacityProgress,
  }) {
    final marker = item.marker;
    final isSelected = selectedMarkerId == marker.id;
    final pinHeight = marker.size?.height ?? theme.markerSize;
    final pinWidth = marker.size?.width ?? (pinHeight * 0.84);
    final totalWidth = pinWidth + 14.0;
    final totalHeight = pinHeight + 12.0;

    final currentPos = centerScreenPosition + item.offset * positionProgress;

    final Widget child;
    if (markerBuilder != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onMarkerTap(marker),
        child: markerBuilder!(context, marker, theme, isSelected: isSelected),
      );
    } else {
      child = DefaultMarkerPin<T>(
        marker: marker,
        theme: theme,
        isSelected: isSelected,
        onTap: () => onMarkerTap(marker),
      );
    }

    return Positioned(
      key: ValueKey<String>('spiderfy:${marker.id}'),
      left: currentPos.dx - totalWidth / 2.0,
      top: currentPos.dy - totalHeight + 5.0,
      child: Opacity(
        opacity: opacityProgress.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: (0.45 + 0.55 * positionProgress).clamp(0.45, 1.05),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }
}

class _SpiderLegsPainter<T> extends CustomPainter {
  const _SpiderLegsPainter({
    required this.layout,
    required this.center,
    required this.progress,
    required this.legColor,
    required this.legWidth,
    required this.curved,
  });

  final SpiderfyLayout<T> layout;
  final Offset center;
  final double progress;
  final Color legColor;
  final double legWidth;
  final bool curved;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || layout.items.isEmpty) {
      return;
    }

    // Soft radial backdrop halo highlighting the spiderfy zone.
    final haloRadius = math.max(24.0, (layout.outerRadius + 24.0) * progress);
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            legColor.withValues(alpha: 0.12 * progress),
            legColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    final legPaint = Paint()
      ..color = legColor.withValues(alpha: 0.72 * progress)
      ..strokeWidth = legWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = legColor.withValues(alpha: 0.85 * progress);

    for (final item in layout.items) {
      final end = center + item.offset * progress;
      if (curved) {
        final control = center + item.controlPointOffset * progress;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        canvas.drawPath(path, legPaint);
      } else {
        canvas.drawLine(center, end, legPaint);
      }
      canvas.drawCircle(end, 3.0 * progress, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpiderLegsPainter<T> oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.center != center ||
        oldDelegate.progress != progress ||
        oldDelegate.legColor != legColor ||
        oldDelegate.legWidth != legWidth ||
        oldDelegate.curved != curved;
  }
}
