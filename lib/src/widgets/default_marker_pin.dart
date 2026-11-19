import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/cluster_marker.dart';
import '../theme/cluster_theme.dart';

/// Default crisp vector map pin rendered via [CustomPaint] with zero icon-font
/// or Material dependencies.
///
/// Supports per-marker [ClusterMarker.accentColor], elevated selected state
/// with translucent halo glow, and hover/press micro-interactions.
class DefaultMarkerPin<T> extends StatefulWidget {
  /// Creates a [DefaultMarkerPin].
  const DefaultMarkerPin({
    required this.marker,
    required this.theme,
    this.isSelected = false,
    this.onTap,
    super.key,
  });

  /// Marker represented by this pin.
  final ClusterMarker<T> marker;

  /// Active cluster theme.
  final ClusterThemeData theme;

  /// Whether this pin is currently selected.
  final bool isSelected;

  /// Optional tap callback.
  final VoidCallback? onTap;

  @override
  State<DefaultMarkerPin<T>> createState() => _DefaultMarkerPinState<T>();
}

class _DefaultMarkerPinState<T> extends State<DefaultMarkerPin<T>> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final pinHeight = widget.marker.size?.height ?? theme.markerSize;
    final pinWidth = widget.marker.size?.width ?? (pinHeight * 0.84);
    final fillColor = widget.isSelected
        ? theme.markerSelectedColor
        : (widget.marker.accentColor ?? theme.markerColor);

    final scale = _pressed
        ? 0.90
        : widget.isSelected
        ? 1.18
        : _hovered
        ? 1.08
        : 1.0;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.marker.label ?? 'Map marker ${widget.marker.id}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: SizedBox(
              width: pinWidth + 14.0,
              height: pinHeight + 12.0,
              child: CustomPaint(
                painter: _MarkerPinPainter(
                  fillColor: fillColor,
                  borderColor: theme.markerBorderColor,
                  innerDotColor: theme.markerInnerDotColor,
                  shadowColor: theme.shadowColor,
                  isSelected: widget.isSelected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerPinPainter extends CustomPainter {
  const _MarkerPinPainter({
    required this.fillColor,
    required this.borderColor,
    required this.innerDotColor,
    required this.shadowColor,
    required this.isSelected,
  });

  final Color fillColor;
  final Color borderColor;
  final Color innerDotColor;
  final Color shadowColor;
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final tipY = size.height - 5.0;
    final headRadius = math.min(size.width * 0.34, size.height * 0.30);
    final headCenter = Offset(cx, headRadius + 5.0);

    // Subtle ground anchor shadow.
    final shadowPaint = Paint()
      ..color = shadowColor.withValues(alpha: isSelected ? 0.30 : 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, tipY + 1.5),
        width: headRadius * (isSelected ? 1.5 : 1.15),
        height: headRadius * 0.42,
      ),
      shadowPaint,
    );

    // Selection glow ring at ground anchor.
    if (isSelected) {
      canvas.drawCircle(
        headCenter,
        headRadius + 6.5,
        Paint()..color = fillColor.withValues(alpha: 0.24),
      );
    }

    // Teardrop vector silhouette.
    final pinPath = _buildTeardropPath(headCenter, headRadius, tipY);

    // Drop shadow behind pin body.
    canvas.drawPath(
      pinPath.shift(const Offset(0.0, 2.5)),
      Paint()
        ..color = shadowColor.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Gradient fill.
    final lighter = Color.lerp(fillColor, const Color(0xFFFFFFFF), 0.22)!;
    final darker = Color.lerp(fillColor, const Color(0xFF000000), 0.14)!;
    final fillPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[lighter, fillColor, darker],
          ).createShader(
            Rect.fromLTRB(
              cx - headRadius,
              headCenter.dy - headRadius,
              cx + headRadius,
              tipY,
            ),
          );
    canvas.drawPath(pinPath, fillPaint);

    // Crisp outer border.
    canvas.drawPath(
      pinPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..color = borderColor,
    );

    // Clean inner white/contrasting center dot.
    canvas.drawCircle(
      headCenter,
      headRadius * 0.38,
      Paint()..color = innerDotColor,
    );
  }

  static Path _buildTeardropPath(
    Offset headCenter,
    double radius,
    double tipY,
  ) {
    final cx = headCenter.dx;
    final cy = headCenter.dy;
    const tangentAngle = 0.56; // radians below horizontal
    final leftTangent = Offset(
      cx - radius * math.cos(tangentAngle),
      cy + radius * math.sin(tangentAngle),
    );
    final rightTangent = Offset(
      cx + radius * math.cos(tangentAngle),
      cy + radius * math.sin(tangentAngle),
    );

    final path = Path()
      ..moveTo(cx, tipY)
      ..quadraticBezierTo(
        cx - radius * 0.42,
        tipY - (tipY - leftTangent.dy) * 0.46,
        leftTangent.dx,
        leftTangent.dy,
      )
      ..arcTo(
        Rect.fromCircle(center: headCenter, radius: radius),
        math.pi - tangentAngle,
        math.pi + 2.0 * tangentAngle,
        false,
      )
      ..quadraticBezierTo(
        cx + radius * 0.42,
        tipY - (tipY - rightTangent.dy) * 0.46,
        cx,
        tipY,
      )
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _MarkerPinPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.innerDotColor != innerDotColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.isSelected != isSelected;
  }
}
