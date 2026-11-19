import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster/map_marker_cluster.dart';

Widget _wrapTestApp(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800.0, 600.0)),
      child: Center(child: SizedBox(width: 800.0, height: 600.0, child: child)),
    ),
  );
}

void main() {
  group('ClusterMapOverlay', () {
    testWidgets('renders clusters in declarative mode and handles tap', (
      WidgetTester tester,
    ) async {
      ClusterNode<String>? tappedCluster;
      const markers = <ClusterMarker<String>>[
        ClusterMarker<String>(
          id: 'm1',
          position: GeoPoint(-6.2088, 106.8456),
          label: 'Alpha Hub',
        ),
        ClusterMarker<String>(
          id: 'm2',
          position: GeoPoint(-6.2090, 106.8458),
          label: 'Beta Hub',
        ),
      ];

      await tester.pumpWidget(
        _wrapTestApp(
          ClusterMapOverlay<String>(
            markers: markers,
            viewport: const MapViewport(
              center: GeoPoint(-6.2089, 106.8457),
              zoom: 11.0,
              size: Size(800.0, 600.0),
            ),
            theme: ClusterThemeData.modern(pulseAnimation: false),
            onClusterTap: (cluster) => tappedCluster = cluster,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(tappedCluster, isNotNull);
      expect(tappedCluster!.count, 2);
    });

    testWidgets('spiderfies on tap, selects marker, opens & closes callout', (
      WidgetTester tester,
    ) async {
      final controller = ClusterController<String>(
        initialZoom: 13.0,
        options: const ClusterOptions(tapBehavior: ClusterTapBehavior.spiderfy),
        initialMarkers: const <ClusterMarker<String>>[
          ClusterMarker<String>(
            id: 's1',
            position: GeoPoint(-6.2088, 106.8456),
            label: 'Skyline Coffee',
            subtitle: 'Specialty Roastery',
            category: 'Cafe',
          ),
          ClusterMarker<String>(
            id: 's2',
            position: GeoPoint(-6.2088, 106.8456),
            label: 'Humanize Studio',
            subtitle: 'AI Innovation Hub',
            category: 'Workspace',
          ),
          ClusterMarker<String>(
            id: 's3',
            position: GeoPoint(-6.2088, 106.8456),
            label: 'Central Station',
            subtitle: 'Express Transit',
            category: 'Transit',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapTestApp(
          ClusterMapOverlay<String>(
            controller: controller,
            theme: ClusterThemeData.dark(pulseAnimation: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);

      // Tap cluster badge to trigger spiderfy.
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(controller.isSpiderfied, isTrue);
      expect(find.byType(SpiderfyOverlay<String>), findsOneWidget);

      // Tap a spiderfied marker to display the floating callout.
      await tester.tap(find.bySemanticsLabel('Skyline Coffee'));
      await tester.pumpAndSettle();

      expect(controller.selectedMarker?.id, 's1');
      expect(find.text('Skyline Coffee'), findsOneWidget);
      expect(find.text('Specialty Roastery'), findsOneWidget);
      expect(find.text('Cafe'), findsOneWidget);

      // Close callout via close button.
      await tester.tap(find.bySemanticsLabel('Close marker details'));
      await tester.pumpAndSettle();

      expect(controller.selectedMarker, isNull);
      expect(find.text('Skyline Coffee'), findsNothing);

      // Collapse spiderfy via central anchor button.
      await tester.tap(find.bySemanticsLabel('Collapse expanded cluster'));
      await tester.pumpAndSettle();

      expect(controller.isSpiderfied, isFalse);
      expect(find.text('3'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('supports custom cluster, marker, and callout builders', (
      WidgetTester tester,
    ) async {
      final controller = ClusterController<String>(
        initialZoom: 16.0,
        initialMarkers: const <ClusterMarker<String>>[
          ClusterMarker<String>(
            id: 'solo',
            position: GeoPoint(-6.2088, 106.8456),
            label: 'Solo Spot',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapTestApp(
          ClusterMapOverlay<String>(
            controller: controller,
            theme: ClusterThemeData.minimal(),
            markerBuilder: (context, marker, theme, {required isSelected}) {
              return Container(
                padding: const EdgeInsets.all(6.0),
                color: isSelected
                    ? const Color(0xFFEC4899)
                    : const Color(0xFF4F46E5),
                child: Text('CUSTOM:${marker.id}'),
              );
            },
            calloutBuilder: (context, marker, onClose, theme) {
              return Container(
                color: const Color(0xFFFFFFFF),
                child: Text('CARD:${marker.label}'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CUSTOM:solo'), findsOneWidget);

      await tester.tap(find.text('CUSTOM:solo'));
      await tester.pumpAndSettle();

      expect(find.text('CARD:Solo Spot'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('clamps callout cleanly near top and horizontal edges', (
      WidgetTester tester,
    ) async {
      final controller = ClusterController<void>(
        initialZoom: 16.0,
        initialMarkers: const <ClusterMarker<void>>[
          // Near top-left corner of viewport.
          ClusterMarker<void>(
            id: 'edge',
            position: GeoPoint(-6.2020, 106.8350),
            label: 'North West Edge Marker',
            subtitle: 'Verifies edge clamping and downward flip',
          ),
        ],
      );

      controller.selectMarker(controller.markers.first);

      await tester.pumpWidget(
        _wrapTestApp(
          ClusterMapOverlay<void>(
            controller: controller,
            theme: ClusterThemeData.modern(pulseAnimation: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('North West Edge Marker'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.dispose();
    });
  });

  group('InteractiveClusterMap', () {
    testWidgets(
      'supports controls, pan, mouse-wheel zoom, and custom map layer',
      (WidgetTester tester) async {
        final controller = ClusterController<void>(
          initialMarkers: const <ClusterMarker<void>>[
            ClusterMarker<void>(id: '1', position: GeoPoint(-6.200, 106.840)),
            ClusterMarker<void>(id: '2', position: GeoPoint(-6.202, 106.842)),
            ClusterMarker<void>(id: '3', position: GeoPoint(-6.250, 106.890)),
          ],
        );

        await tester.pumpWidget(
          _wrapTestApp(
            InteractiveClusterMap<void>(
              controller: controller,
              theme: ClusterThemeData.emerald(pulseAnimation: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final initialZoom = controller.zoom;

        // Tap zoom-in control button.
        await tester.tap(find.bySemanticsLabel('Zoom in'));
        await tester.pumpAndSettle();
        expect(controller.zoom, greaterThan(initialZoom));

        // Tap zoom-out control button.
        final zoomedIn = controller.zoom;
        await tester.tap(find.bySemanticsLabel('Zoom out'));
        await tester.pumpAndSettle();
        expect(controller.zoom, lessThan(zoomedIn));

        // Drag to pan viewport.
        final beforePan = controller.center;
        await tester.drag(
          find.byType(InteractiveClusterMap<void>),
          const Offset(120.0, 80.0),
        );
        await tester.pumpAndSettle();
        expect(controller.center, isNot(beforePan));

        // Simulate desktop/web mouse wheel zoom.
        final beforeScrollZoom = controller.zoom;
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.hover(const Offset(400.0, 300.0)),
        );
        await tester.sendEventToBinding(
          pointer.scroll(const Offset(0.0, -160.0)),
        );
        await tester.pumpAndSettle();
        expect(controller.zoom, greaterThan(beforeScrollZoom));

        // Tap fit all markers control.
        await tester.tap(find.bySemanticsLabel('Fit all markers'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Double-tap empty map area zooms in smoothly.
        final beforeDoubleTap = controller.zoom;
        await tester.tapAt(const Offset(100.0, 100.0));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(const Offset(100.0, 100.0));
        await tester.pumpAndSettle();
        expect(controller.zoom, greaterThan(beforeDoubleTap));

        controller.dispose();
      },
    );

    testWidgets('background tap dismisses open callout and spiderfy', (
      WidgetTester tester,
    ) async {
      final controller = ClusterController<String>(
        initialZoom: 13.0,
        options: const ClusterOptions(tapBehavior: ClusterTapBehavior.spiderfy),
        initialMarkers: const <ClusterMarker<String>>[
          ClusterMarker<String>(
            id: 'x1',
            position: GeoPoint(-6.2088, 106.8456),
            label: 'Spot One',
          ),
          ClusterMarker<String>(
            id: 'x2',
            position: GeoPoint(-6.2088, 106.8456),
            label: 'Spot Two',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapTestApp(
          ClusterMapOverlay<String>(
            controller: controller,
            theme: ClusterThemeData.modern(pulseAnimation: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(controller.isSpiderfied, isTrue);

      // Tap far empty corner to dismiss spiderfy overlay.
      await tester.tapAt(const Offset(40.0, 40.0));
      await tester.pumpAndSettle();
      expect(controller.isSpiderfied, isFalse);

      controller.dispose();
    });

    testWidgets('renders pulsing halo animation smoothly without exceptions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapTestApp(
          InteractiveClusterMap<void>(
            theme: ClusterThemeData.modern(),
            markers: const <ClusterMarker<void>>[
              ClusterMarker<void>(
                id: 'a',
                position: GeoPoint(-6.2088, 106.8456),
              ),
              ClusterMarker<void>(
                id: 'b',
                position: GeoPoint(-6.2090, 106.8459),
              ),
            ],
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
