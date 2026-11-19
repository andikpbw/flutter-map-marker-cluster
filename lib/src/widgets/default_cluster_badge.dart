import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/cluster_node.dart';
import '../theme/cluster_theme.dart';

/// Default modern multi-layered cluster badge featuring diagonal gradients,
/// translucent pulsing halos, specular edge lighting, and tactile hover/press
/// micro-interactions.
class DefaultClusterBadge<T> extends StatefulWidget {
  /// Creates a [DefaultClusterBadge].
  const DefaultClusterBadge({
    required this.cluster,
    required this.theme,
    this.onTap,
    super.key,
  });

  /// The cluster represented by this badge.
  final ClusterNode<T> cluster;

  /// Active visual theme.
  final ClusterThemeData theme;

  /// Optional tap callback.
  final VoidCallback? onTap;

  @override
  State<DefaultClusterBadge<T>> createState() => _DefaultClusterBadgeState<T>();
}

class _DefaultClusterBadgeState<T> extends State<DefaultClusterBadge<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _hovered = false;
  bool _pressed = false;
  bool _pulseRunning = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: widget.theme.pulseDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseAnimation();
  }

  @override
  void didUpdateWidget(covariant DefaultClusterBadge<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme.pulseDuration != widget.theme.pulseDuration) {
      _pulseController.duration = widget.theme.pulseDuration;
    }
    _syncPulseAnimation();
  }

  void _syncPulseAnimation() {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldPulse =
        widget.theme.showHalo &&
        widget.theme.pulseAnimation &&
        !disableAnimations;

    if (shouldPulse && !_pulseRunning) {
      _pulseRunning = true;
      _pulseController.repeat();
    } else if (!shouldPulse && _pulseRunning) {
      _pulseRunning = false;
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tier = theme.tierForCount(widget.cluster.count);
    final gradientColors = tier.resolvedGradientColors;
    final label = theme.countFormatter(widget.cluster.count);
    final haloSpread = theme.showHalo ? theme.haloSpread : 0.0;
    final outerSize = tier.diameter + haloSpread * 2.0;

    final interactionScale = _pressed
        ? 0.92
        : _hovered
        ? 1.08
        : 1.0;

    return Semantics(
      button: true,
      label: '${widget.cluster.count} clustered markers',
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
            scale: interactionScale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: outerSize,
              height: outerSize,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  if (theme.showHalo)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (BuildContext context, Widget? child) {
                        final t = _pulseRunning ? _pulseController.value : 0.35;
                        final wave = 0.5 - 0.5 * math.cos(t * 2.0 * math.pi);
                        final pulseScale = 0.90 + 0.18 * wave;
                        final pulseOpacity =
                            (theme.haloOpacity * (1.0 - 0.55 * wave)).clamp(
                              0.0,
                              1.0,
                            );
                        return Transform.scale(
                          scale: pulseScale,
                          child: Container(
                            width: outerSize,
                            height: outerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tier.haloColor.withValues(
                                alpha: pulseOpacity,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  // Secondary crisp translucent inner ring.
                  if (theme.showHalo)
                    Container(
                      width: tier.diameter + haloSpread * 0.85,
                      height: tier.diameter + haloSpread * 0.85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tier.haloColor.withValues(
                          alpha: theme.haloOpacity * 0.72,
                        ),
                      ),
                    ),
                  // Gradient core badge with crisp border & luminous specular rim.
                  Container(
                    width: tier.diameter,
                    height: tier.diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      border: Border.all(
                        color: theme.badgeBorderColor,
                        width: theme.badgeBorderWidth,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: gradientColors.first.withValues(alpha: 0.36),
                          blurRadius: 14.0,
                          offset: const Offset(0.0, 6.0),
                        ),
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.16),
                          blurRadius: 6.0,
                          offset: const Offset(0.0, 2.0),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Subtle top-left glass specular sheen.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.center,
                                colors: <Color>[
                                  const Color(
                                    0xFFFFFFFF,
                                  ).withValues(alpha: 0.28),
                                  const Color(
                                    0xFFFFFFFF,
                                  ).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              color: tier.textColor,
                              fontSize: tier.fontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              height: 1.0,
                              fontFamily: theme.fontFamily,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
