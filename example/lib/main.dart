import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

void main() {
  runApp(const ClusterShowcaseApp());
}

/// Interactive showcase demonstrating `map_marker_cluster` built purely with
/// `package:flutter/widgets.dart` (zero Material or Cupertino imports).
class ClusterShowcaseApp extends StatelessWidget {
  /// Creates a [ClusterShowcaseApp].
  const ClusterShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Map Marker Cluster Showcase',
      color: const Color(0xFF4F46E5),
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder:
              (BuildContext context, Animation<double> a, Animation<double> b) {
                return builder(context);
              },
        );
      },
      home: const ClusterShowcasePage(),
    );
  }
}

enum _ThemePreset { modern, dark, minimal, emerald }

/// Sample domain payload attached to each [ClusterMarker].
@immutable
class PlaceInfo {
  /// Creates a [PlaceInfo].
  const PlaceInfo({
    required this.name,
    required this.district,
    required this.category,
    required this.rating,
  });

  /// Display name of the place.
  final String name;

  /// Neighborhood or district label.
  final String district;

  /// Place category used for live filtering.
  final String category;

  /// User rating from `1.0` to `5.0`.
  final double rating;
}

/// Main interactive demo screen with theme switcher, category filter chips,
/// live cluster telemetry pill, and spiderfy demo action.
class ClusterShowcasePage extends StatefulWidget {
  /// Creates a [ClusterShowcasePage].
  const ClusterShowcasePage({super.key});

  @override
  State<ClusterShowcasePage> createState() => _ClusterShowcasePageState();
}

class _ClusterShowcasePageState extends State<ClusterShowcasePage> {
  late final ClusterController<PlaceInfo> _controller;
  _ThemePreset _preset = _ThemePreset.modern;
  String? _activeCategory;

  static const List<String> _categories = <String>[
    'All',
    'Cafe',
    'Workspace',
    'Transit',
    'Landmark',
  ];

  @override
  void initState() {
    super.initState();
    _controller = ClusterController<PlaceInfo>(
      initialCenter: const GeoPoint(-6.2088, 106.8456),
      initialZoom: 11.4,
      initialMarkers: _generateSampleMarkers(),
      options: const ClusterOptions(clusterRadius: 68.0, maxClusterZoom: 15.5),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ClusterThemeData get _activeTheme => switch (_preset) {
    _ThemePreset.modern => ClusterThemeData.modern(),
    _ThemePreset.dark => ClusterThemeData.dark(),
    _ThemePreset.minimal => ClusterThemeData.minimal(),
    _ThemePreset.emerald => ClusterThemeData.emerald(),
  };

  VectorMapStyle get _activeMapStyle => switch (_preset) {
    _ThemePreset.modern => const VectorMapStyle.light(),
    _ThemePreset.dark => const VectorMapStyle.dark(),
    _ThemePreset.minimal => const VectorMapStyle.light(),
    _ThemePreset.emerald => const VectorMapStyle.emerald(),
  };

  void _selectCategory(String category) {
    setState(() {
      _activeCategory = category == 'All' ? null : category;
    });
    if (_activeCategory == null) {
      _controller.setMarkerFilter(null);
    } else {
      _controller.setMarkerFilter(
        (ClusterMarker<PlaceInfo> m) => m.category == _activeCategory,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _activeTheme;
    final isDark = _preset == _ThemePreset.dark;

    return ColoredBox(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF3F6FB),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          InteractiveClusterMap<PlaceInfo>(
            controller: _controller,
            theme: theme,
            mapStyle: _activeMapStyle,
            controlsPadding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
          ),
          // Top floating glass header with telemetry & theme presets.
          Positioned(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: theme.calloutBackgroundColor,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: theme.calloutBorderColor),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: theme.shadowColor.withValues(alpha: 0.14),
                              blurRadius: 18.0,
                              offset: const Offset(0.0, 8.0),
                            ),
                          ],
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'map_marker_cluster',
                                    style: TextStyle(
                                      color: theme.calloutTitleColor,
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '${_controller.filteredMarkers.length} markers • '
                                    '${_controller.clusterCount} clusters • '
                                    'z${_controller.zoom.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      color: theme.calloutSubtitleColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 6.0,
                              children: <Widget>[
                                for (final preset in _ThemePreset.values)
                                  _PillButton(
                                    label: _presetLabel(preset),
                                    active: _preset == preset,
                                    theme: theme,
                                    onTap: () =>
                                        setState(() => _preset = preset),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: <Widget>[
                      for (final category in _categories)
                        _PillButton(
                          label: category,
                          active:
                              (category == 'All' && _activeCategory == null) ||
                              _activeCategory == category,
                          theme: theme,
                          onTap: () => _selectCategory(category),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _presetLabel(_ThemePreset preset) => switch (preset) {
    _ThemePreset.modern => 'Modern',
    _ThemePreset.dark => 'Dark',
    _ThemePreset.minimal => 'Minimal',
    _ThemePreset.emerald => 'Emerald',
  };

  static List<ClusterMarker<PlaceInfo>> _generateSampleMarkers() {
    final rng = math.Random(42);
    final hubs = <(String, GeoPoint, int)>[
      ('SCBD District', const GeoPoint(-6.2248, 106.8098), 42),
      ('Thamrin Central', const GeoPoint(-6.1935, 106.8230), 35),
      ('Kemang Creative', const GeoPoint(-6.2607, 106.8135), 24),
      ('Menteng Heritage', const GeoPoint(-6.1960, 106.8390), 18),
      ('Kuningan Hub', const GeoPoint(-6.2297, 106.8326), 28),
      ('Pantai Indah', const GeoPoint(-6.1120, 106.7420), 20),
    ];

    const categoryAccent = <String, Color>{
      'Cafe': Color(0xFFEC4899),
      'Workspace': Color(0xFF4F46E5),
      'Transit': Color(0xFF06B6D4),
      'Landmark': Color(0xFFF59E0B),
    };
    final categoryKeys = categoryAccent.keys.toList();

    final markers = <ClusterMarker<PlaceInfo>>[];
    var idCounter = 1;

    for (final (hubName, center, count) in hubs) {
      for (var i = 0; i < count; i++) {
        // Place a dense co-located pocket at the start of the first hub to
        // demonstrate automatic spiderfy expansion.
        final isCoLocated = hubName == 'SCBD District' && i < 7;
        final spreadLat = isCoLocated ? 0.00004 : 0.018;
        final spreadLng = isCoLocated ? 0.00004 : 0.020;

        final lat = center.latitude + (rng.nextDouble() - 0.5) * spreadLat;
        final lng = center.longitude + (rng.nextDouble() - 0.5) * spreadLng;
        final category = categoryKeys[idCounter % categoryKeys.length];
        final rating = 4.2 + rng.nextDouble() * 0.8;

        markers.add(
          ClusterMarker<PlaceInfo>(
            id: 'place_$idCounter',
            position: GeoPoint(lat, lng),
            label: '$hubName $category #$idCounter',
            subtitle: '$hubName • Rated ${rating.toStringAsFixed(1)} / 5.0',
            category: category,
            accentColor: categoryAccent[category],
            data: PlaceInfo(
              name: '$hubName $category #$idCounter',
              district: hubName,
              category: category,
              rating: rating,
            ),
          ),
        );
        idCounter++;
      }
    }
    return markers;
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.active,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ClusterThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: active ? theme.markerColor : theme.calloutBackgroundColor,
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(
              color: active ? theme.markerColor : theme.calloutBorderColor,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.08),
                blurRadius: 8.0,
                offset: const Offset(0.0, 2.0),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFFFFFFF) : theme.calloutTitleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
