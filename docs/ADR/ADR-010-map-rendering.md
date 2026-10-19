# ADR-010: Map rendering: MapLibre Native with OpenStreetMap vector tiles

- **Status:** Accepted (2026-10-18) · **Relates to:** ADR-003 (place *search* stays Apple Maps) · **Design:** `DESIGN.md`

## Context
The approved design is a white 3D city: buildings extruded from height data and restyled white, water and parks tinted, labels thinned, and custom 3D shapes (beacons for recommendations, pillars for things done) rising from the map with animated heights. MapKit for SwiftUI renders Apple's own 3D buildings but can't restyle them, can't extrude custom polygons, and only offers a few emphasis styles. The mockup was built with MapLibre GL JS and OpenFreeMap tiles, and it worked.

## Decision
- Render maps with **MapLibre Native for iOS** (open source, BSD-2; Swift Package `maplibre-gl-native-distribution`), wrapped in a small SwiftUI `UIViewRepresentable` inside `ExperienceCore`'s UI layer.
- Tiles: **OpenFreeMap** (OpenMapTiles schema, free, no API key) while building and in the beta. The style is our own JSON (white buildings via `fill-extrusion` on `render_height`, our water/park colors, POIs hidden), shipped in the app bundle.
- Beacons and pillars are GeoJSON sources with `fill-extrusion` layers; heights animate by updating the source.
- **Place search, autocomplete and directions stay Apple** (ADR-003, `MKLocalSearch`, `MKLocalSearchCompleter`, Apple Maps for "Go").
- Attribution: show "© OpenStreetMap contributors" (and OpenFreeMap) in the map's info button, as the licenses require.

## Consequences
- One map stack for every screen (home orbit, results flight, your city, city picker), matching the mockup closely.
- We own the style JSON; dark mode is a second style.
- OpenFreeMap has no SLA. **Fallback:** generate a PMTiles extract per city (Planetiler from OSM) and serve it from Supabase Storage or a CDN; only the style's tile URL changes. Do this before the city has many users.
- Adds one dependency (~a few MB) to the app.

## Revisit when
MapKit gains custom extrusions and building styling, or MapLibre performance on older iPhones fails the D4 bar.
