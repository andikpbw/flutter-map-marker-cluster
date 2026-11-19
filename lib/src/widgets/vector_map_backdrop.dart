import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/map_viewport.dart';

/// Color palette configuring the built-in lightweight procedural
/// [VectorMapBackdrop].
@immutable
class VectorMapStyle {
  /// Creates a [VectorMapStyle].
  const VectorMapStyle({
    required this.landColor,
    required this.waterColor,
    required this.parkColor,
    required this.buildingColor,
    required this.minorRoadColor,
    required this.majorRoadColor,
    required this.highwayColor,
    required this.gridLineColor,
  });

  /// Crisp editorial light-mode cartographic palette.
  const VectorMapStyle.light()
    : landColor = const Color(0xFFF3F6FB),
      waterColor = const Color(0xFFDBEAFE),
      parkColor = const Color(0xFFD9F3E5),
      buildingColor = const Color(0xFFE6ECF5),
      minorRoadColor = const Color(0xFFFFFFFF),
      majorRoadColor = const Color(0xFFE2E8F0),
      highwayColor = const Color(0xFFCBD5E1),
      gridLineColor = const Color(0x1464748B);

  /// Deep obsidian dark-mode cartographic palette tailored for neon clusters.
  const VectorMapStyle.dark()
    : landColor = const Color(0xFF0B1120),
      waterColor = const Color(0xFF0F2540),
      parkColor = const Color(0xFF0D2B2A),
      buildingColor = const Color(0xFF131D33),
      minorRoadColor = const Color(0xFF1A2742),
      majorRoadColor = const Color(0xFF233554),
      highwayColor = const Color(0xFF334E7A),
      gridLineColor = const Color(0x1694A3B8);

  /// Soft sage & mint cartographic palette suited for emerald themes.
  const VectorMapStyle.emerald()
    : landColor = const Color(0xFFF0F9F6),
      waterColor = const Color(0xFFCFFAFE),
      parkColor = const Color(0xFFC6F6D5),
      buildingColor = const Color(0xFFE1F0EB),
      minorRoadColor = const Color(0xFFFFFFFF),
      majorRoadColor = const Color(0xFFD1E7DF),
      highwayColor = const Color(0xFFA7D7C5),
      gridLineColor = const Color(0x14065F46);

  /// Base land background color.
  final Color landColor;

  /// Waterways and coastline tint.
  final Color waterColor;

  /// Parks and green belt polygon fill.
  final Color parkColor;

  /// Subtle urban block fill visible at higher zoom levels.
  final Color buildingColor;

  /// Local street grid stroke color.
  final Color minorRoadColor;

  /// Arterial boulevard stroke color.
  final Color majorRoadColor;

  /// Primary highway stroke color.
  final Color highwayColor;

  /// Subtle cartographic graticule line color.
  final Color gridLineColor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VectorMapStyle &&
        other.landColor == landColor &&
        other.waterColor == waterColor &&
        other.parkColor == parkColor &&
        other.buildingColor == buildingColor &&
        other.minorRoadColor == minorRoadColor &&
        other.majorRoadColor == majorRoadColor &&
        other.highwayColor == highwayColor &&
        other.gridLineColor == gridLineColor;
  }

  @override
  int get hashCode => Object.hash(
    landColor,
    waterColor,
    parkColor,
    buildingColor,
    minorRoadColor,
    majorRoadColor,
    highwayColor,
    gridLineColor,
  );
}

/// Lightweight, zero-dependency procedural vector map background synchronized
/// 1:1 with [MapViewport] world coordinates (pan, zoom, and rotation).
///
/// Used as the default visual backdrop inside `InteractiveClusterMap` when no
/// external tile or map provider is supplied via `mapLayerBuilder`.
class VectorMapBackdrop extends StatelessWidget {
  /// Creates a [VectorMapBackdrop].
  const VectorMapBackdrop({
    required this.viewport,
    this.style = const VectorMapStyle.light(),
    super.key,
  });

  /// Active map camera viewport.
  final MapViewport viewport;

  /// Cartographic color palette.
  final VectorMapStyle style;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _VectorMapPainter(viewport: viewport, style: style),
        size: Size.infinite,
      ),
    );
  }
}

class _VectorMapPainter extends CustomPainter {
  const _VectorMapPainter({required this.viewport, required this.style});

  final MapViewport viewport;
  final VectorMapStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = style.landColor);
    if (size.width <= 0.0 || size.height <= 0.0) {
      return;
    }

    final centerWorld = viewport.projection.latLngToWorld(
      viewport.center,
      viewport.zoom,
    );
    final zoomScale = math.pow(2.0, viewport.zoom - 11.0).toDouble();

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    if (viewport.rotation != 0.0) {
      canvas.rotate(viewport.rotation);
    }

    // Half-diagonal guarantees full coverage even under arbitrary map rotation.
    final halfDiag =
        math.sqrt(size.width * size.width + size.height * size.height) * 0.55;
    final viewRect = Rect.fromLTRB(
      centerWorld.dx - halfDiag,
      centerWorld.dy - halfDiag,
      centerWorld.dx + halfDiag,
      centerWorld.dy + halfDiag,
    );

    canvas.translate(-centerWorld.dx, -centerWorld.dy);

    // 1. Waterways / gentle river channels anchored in world space.
    _paintWaterways(canvas, viewRect, zoomScale);

    // 2. Deterministic city parks and urban blocks.
    _paintBlocksAndParks(canvas, viewRect, zoomScale);

    // 3. Multi-tier road hierarchy (Level of Detail scales cleanly with zoom).
    _paintRoadNetwork(canvas, viewRect, zoomScale);

    // 4. Subtle cartographic graticule.
    _paintGraticule(canvas, viewRect, zoomScale);

    canvas.restore();
  }

  void _paintWaterways(Canvas canvas, Rect viewRect, double zoomScale) {
    final blockUnit = 220.0 * zoomScale.clamp(0.35, 6.0);
    final startRow = (viewRect.top / blockUnit).floor() - 1;
    final endRow = (viewRect.bottom / blockUnit).ceil() + 1;

    final riverPaint = Paint()
      ..color = style.waterColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (26.0 * math.sqrt(zoomScale)).clamp(8.0, 64.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var row = startRow; row <= endRow; row++) {
      if ((row.abs() % 3) != 1) {
        continue;
      }
      final baseY = row * blockUnit;
      final path = Path();
      final step = math.max(36.0, blockUnit * 0.25);
      final startX = (viewRect.left / step).floor() * step - step;
      final endX = viewRect.right + step;
      var first = true;
      for (var x = startX; x <= endX; x += step) {
        final wave =
            math.sin(x / (blockUnit * 0.65) + row * 1.7) * (blockUnit * 0.16) +
            math.cos(x / (blockUnit * 1.35)) * (blockUnit * 0.08);
        final y = baseY + wave;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, riverPaint);
    }
  }

  void _paintBlocksAndParks(Canvas canvas, Rect viewRect, double zoomScale) {
    final tileUnit = (92.0 * zoomScale).clamp(48.0, 220.0);
    final startCol = (viewRect.left / tileUnit).floor() - 1;
    final endCol = (viewRect.right / tileUnit).ceil() + 1;
    final startRow = (viewRect.top / tileUnit).floor() - 1;
    final endRow = (viewRect.bottom / tileUnit).ceil() + 1;

    final parkPaint = Paint()..color = style.parkColor;
    final buildingPaint = Paint()..color = style.buildingColor;

    final showBuildings = viewport.zoom >= 11.2;

    for (var cx = startCol; cx <= endCol; cx++) {
      for (var cy = startRow; cy <= endRow; cy++) {
        final h = _cellHash(cx, cy);
        final cellX = cx * tileUnit;
        final cellY = cy * tileUnit;
        final inset = tileUnit * 0.12;

        if (h % 9 == 0) {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cellX + inset,
              cellY + inset,
              tileUnit - inset * 2.0,
              tileUnit - inset * 2.0,
            ),
            Radius.circular(tileUnit * 0.18),
          );
          canvas.drawRRect(rect, parkPaint);
        } else if (showBuildings && h % 2 == 0) {
          final bWidth = tileUnit * (0.32 + (h % 4) * 0.09);
          final bHeight = tileUnit * (0.28 + ((h >> 3) % 4) * 0.10);
          final offsetX = tileUnit * (0.14 + ((h >> 5) % 3) * 0.08);
          final offsetY = tileUnit * (0.14 + ((h >> 7) % 3) * 0.08);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(cellX + offsetX, cellY + offsetY, bWidth, bHeight),
              const Radius.circular(3.0),
            ),
            buildingPaint,
          );
        }
      }
    }
  }

  void _paintRoadNetwork(Canvas canvas, Rect viewRect, double zoomScale) {
    // Minor urban streets appear smoothly when zoomed in.
    if (viewport.zoom >= 10.5) {
      final minorStep = (46.0 * zoomScale).clamp(28.0, 140.0);
      final alpha = ((viewport.zoom - 10.5) / 2.0).clamp(0.0, 1.0);
      _drawGridLines(
        canvas,
        viewRect,
        step: minorStep,
        paint: Paint()
          ..color = style.minorRoadColor.withValues(alpha: alpha * 0.85)
          ..strokeWidth = (1.6 * math.sqrt(zoomScale)).clamp(1.0, 4.0),
      );
    }

    // Major arterial avenues.
    final majorStep = (138.0 * zoomScale).clamp(64.0, 280.0);
    _drawGridLines(
      canvas,
      viewRect,
      step: majorStep,
      paint: Paint()
        ..color = style.majorRoadColor
        ..strokeWidth = (3.2 * math.sqrt(zoomScale)).clamp(1.8, 7.0),
    );

    // Primary diagonal/expressway corridors.
    final highwayStep = (320.0 * zoomScale).clamp(150.0, 560.0);
    final highwayPaint = Paint()
      ..color = style.highwayColor
      ..strokeWidth = (4.6 * math.sqrt(zoomScale)).clamp(2.4, 9.0)
      ..strokeCap = StrokeCap.round;

    final startCol = (viewRect.left / highwayStep).floor() - 1;
    final endCol = (viewRect.right / highwayStep).ceil() + 1;
    for (var col = startCol; col <= endCol; col++) {
      final x = col * highwayStep;
      canvas.drawLine(
        Offset(x, viewRect.top),
        Offset(x + highwayStep * 0.35, viewRect.bottom),
        highwayPaint,
      );
    }
  }

  void _paintGraticule(Canvas canvas, Rect viewRect, double zoomScale) {
    final step = (240.0 * zoomScale).clamp(120.0, 420.0);
    _drawGridLines(
      canvas,
      viewRect,
      step: step,
      paint: Paint()
        ..color = style.gridLineColor
        ..strokeWidth = 1.0,
    );
  }

  void _drawGridLines(
    Canvas canvas,
    Rect viewRect, {
    required double step,
    required Paint paint,
  }) {
    final startX = (viewRect.left / step).floor() * step;
    for (var x = startX; x <= viewRect.right; x += step) {
      canvas.drawLine(
        Offset(x, viewRect.top),
        Offset(x, viewRect.bottom),
        paint,
      );
    }
    final startY = (viewRect.top / step).floor() * step;
    for (var y = startY; y <= viewRect.bottom; y += step) {
      canvas.drawLine(
        Offset(viewRect.left, y),
        Offset(viewRect.right, y),
        paint,
      );
    }
  }

  static int _cellHash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)).abs();
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) {
    return oldDelegate.viewport != viewport || oldDelegate.style != style;
  }
}
