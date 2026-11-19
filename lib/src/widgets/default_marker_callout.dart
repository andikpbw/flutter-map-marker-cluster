import 'package:flutter/widgets.dart';

import '../models/cluster_marker.dart';
import '../theme/cluster_theme.dart';

/// Default floating modern callout card displayed above (or below when near
/// the top edge) a selected [ClusterMarker].
class DefaultMarkerCallout<T> extends StatelessWidget {
  /// Creates a [DefaultMarkerCallout].
  const DefaultMarkerCallout({
    required this.marker,
    required this.theme,
    required this.onClose,
    this.arrowOffsetFraction = 0.5,
    this.pointUp = false,
    super.key,
  });

  /// Selected marker to display.
  final ClusterMarker<T> marker;

  /// Active visual theme.
  final ClusterThemeData theme;

  /// Callback invoked when the user taps the close button.
  final VoidCallback onClose;

  /// Horizontal fractional position (`0.1` to `0.9`) of the pointer arrow
  /// along the card's width so the arrow stays anchored to the marker even
  /// when the card is clamped against viewport edges.
  final double arrowOffsetFraction;

  /// Whether the pointer arrow points upward (when rendered beneath the
  /// marker) instead of downward (default, rendered above the marker).
  final bool pointUp;

  @override
  Widget build(BuildContext context) {
    final accent = marker.accentColor ?? theme.markerColor;
    final title = marker.label ?? marker.id;
    final arrow = _CalloutPointer(
      color: theme.calloutBackgroundColor,
      borderColor: theme.calloutBorderColor,
      pointUp: pointUp,
      alignmentFraction: arrowOffsetFraction,
    );

    final card = Container(
      constraints: BoxConstraints(
        minWidth: 168.0,
        maxWidth: theme.calloutMaxWidth,
      ),
      padding: const EdgeInsets.fromLTRB(14.0, 12.0, 12.0, 12.0),
      decoration: BoxDecoration(
        color: theme.calloutBackgroundColor,
        borderRadius: BorderRadius.circular(theme.calloutBorderRadius),
        border: Border.all(color: theme.calloutBorderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.16),
            blurRadius: 22.0,
            offset: const Offset(0.0, 10.0),
          ),
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.06),
            blurRadius: 6.0,
            offset: const Offset(0.0, 2.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (marker.category != null &&
                        marker.category!.trim().isNotEmpty) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 3.0,
                        ),
                        decoration: BoxDecoration(
                          color: theme.calloutBadgeBackground,
                          borderRadius: BorderRadius.circular(999.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 6.0,
                              height: 6.0,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5.0),
                            Text(
                              marker.category!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.calloutBadgeTextColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                fontFamily: theme.fontFamily,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6.0),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.calloutTitleColor,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: -0.2,
                        fontFamily: theme.fontFamily,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              _CalloutCloseButton(
                color: theme.calloutSubtitleColor,
                hoverColor: theme.calloutBadgeBackground,
                onTap: onClose,
              ),
            ],
          ),
          if (marker.subtitle != null &&
              marker.subtitle!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4.0),
            Text(
              marker.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.calloutSubtitleColor,
                fontSize: 12.0,
                height: 1.35,
                fontFamily: theme.fontFamily,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 8.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                marker.position.format(),
                style: TextStyle(
                  color: theme.calloutSubtitleColor.withValues(alpha: 0.85),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: theme.fontFamily,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pointUp ? <Widget>[arrow, card] : <Widget>[card, arrow],
    );
  }
}

class _CalloutCloseButton extends StatefulWidget {
  const _CalloutCloseButton({
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  @override
  State<_CalloutCloseButton> createState() => _CalloutCloseButtonState();
}

class _CalloutCloseButtonState extends State<_CalloutCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close marker details',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24.0,
            height: 24.0,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.hoverColor
                  : widget.color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: CustomPaint(painter: _CloseIconPainter(color: widget.color)),
          ),
        ),
      ),
    );
  }
}

class _CloseIconPainter extends CustomPainter {
  const _CloseIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const inset = 7.5;
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CloseIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CalloutPointer extends StatelessWidget {
  const _CalloutPointer({
    required this.color,
    required this.borderColor,
    required this.pointUp,
    required this.alignmentFraction,
  });

  final Color color;
  final Color borderColor;
  final bool pointUp;
  final double alignmentFraction;

  @override
  Widget build(BuildContext context) {
    final aligned = (alignmentFraction.clamp(0.12, 0.88) * 2.0) - 1.0;
    return Align(
      alignment: Alignment(aligned, 0.0),
      child: SizedBox(
        width: 16.0,
        height: 8.0,
        child: CustomPaint(
          painter: _PointerTrianglePainter(
            color: color,
            borderColor: borderColor,
            pointUp: pointUp,
          ),
        ),
      ),
    );
  }
}

class _PointerTrianglePainter extends CustomPainter {
  const _PointerTrianglePainter({
    required this.color,
    required this.borderColor,
    required this.pointUp,
  });

  final Color color;
  final Color borderColor;
  final bool pointUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointUp) {
      path
        ..moveTo(0.0, size.height)
        ..lineTo(size.width / 2.0, 0.0)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      path
        ..moveTo(0.0, 0.0)
        ..lineTo(size.width / 2.0, size.height)
        ..lineTo(size.width, 0.0)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);

    final edgePath = Path();
    if (pointUp) {
      edgePath
        ..moveTo(0.0, size.height)
        ..lineTo(size.width / 2.0, 0.0)
        ..lineTo(size.width, size.height);
    } else {
      edgePath
        ..moveTo(0.0, 0.0)
        ..lineTo(size.width / 2.0, size.height)
        ..lineTo(size.width, 0.0);
    }
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerTrianglePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.pointUp != pointUp;
  }
}
