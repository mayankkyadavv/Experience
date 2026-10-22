# Satellite earth (parked 2026-10-21)

The second globe style, built alongside Dots and parked when the founder chose Dots. It may come back as a
toggle on the home globe.

One-pass shading of 8K NASA Blue Marble (public domain): low sun and soft terminator, night city lights,
ocean-only sun glint, terrain relief, clouds with shadows, thin limb atmosphere. Sources ship as HEIC and are
compressed to ASTC 4×4 on a background thread at first show (~65 MB GPU, ~1 s fade-in).

| File | Was |
|---|---|
| `SatelliteEarth.swift` | `ios/Experience/Globe/` |
| `SatelliteTextures.swift` | `ios/Experience/Globe/` |
| `Resources/satellite_*.heic` (10.7 MB) | `ios/Experience/Resources/Globe/` |
| `satellite-tool.swift` | `tools/globe/satellite.swift`, builds the HEIC sources from NASA imagery |

## Restore

1. Move the two Swift files back to `ios/Experience/Globe/` and the HEICs back to `ios/Experience/Resources/Globe/`.
2. `SatelliteEarth` conforms to `EarthLook` (`Globe/EarthLook.swift`), which still exists. It uses
   `EarthShaders.halo` from the same file.
3. In `GlobeView.swift`, make the look selectable again: a `GlobeStyle` enum (`dots`, `satellite`), a `style`
   property on `GlobeView`, and `GlobeCoordinator.apply(style:)` swapping `DotsEarth(layers:)` for
   `SatelliteEarth(layers:)`. Commit `57ef4bb` has the exact code, including the home-screen picker.
4. `cd ios && xcodegen`.
