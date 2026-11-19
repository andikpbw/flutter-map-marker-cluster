## 1.0.0

* Initial stable release of `map_marker_cluster`.
* Added `ClusterEngine` and `SpatialHashGrid` with `O(n)` pan-stable world-coordinate clustering, weighted centroids, viewport culling, and antimeridian (`±180°`) support.
* Added `WebMercatorProjection`, extensible `MapProjection`, `GeoPoint`, `GeoBounds`, and `MapViewport` with rotation and `fitZoomLevel` calculation.
* Added `SpiderfyLayoutEngine` and `SpiderfyOverlay` with automatic circle and Archimedean spiral layouts plus animated curved Bezier spider legs.
* Added reactive `ClusterController` supporting CRUD operations, live marker filtering, smooth animated camera transitions, `fitBounds`, `fitMarkers`, selection, and spiderfy control.
* Added provider-agnostic `ClusterMapOverlay` and all-in-one `InteractiveClusterMap` with built-in `VectorMapBackdrop`, pan, focal-point pinch/mouse-wheel zoom, double-tap zoom, and floating controls.
* Added `ClusterThemeData` with 4 modern presets (`modern`, `dark`, `minimal`, `emerald`), `lerp` support, pulsing gradient cluster badges, crisp vector marker pins, and smart edge-clamped floating callout cards.
* Built 100% on `package:flutter/widgets.dart` with zero third-party dependencies and zero deprecated `package:flutter/material.dart` imports for full Flutter 3.47–3.50+ and WebAssembly compatibility.
