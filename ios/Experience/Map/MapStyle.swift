import MapLibre
import UIKit

/// The DESIGN.md map: OpenFreeMap's Positron (light) or Dark base, restyled, with extruded buildings.
enum MapStyle {
    static func url(dark: Bool) -> URL {
        URL(string: dark ? "https://tiles.openfreemap.org/styles/dark" : "https://tiles.openfreemap.org/styles/positron")!
    }

    static func apply(to style: MLNStyle, dark: Bool) {
        let ground = UIColor(rgb: dark ? 0x0B0B0C : 0xF3F3F0)
        let water = UIColor(rgb: dark ? 0x14202A : 0xCFE2EC)
        let park = UIColor(rgb: dark ? 0x132019 : 0xDCEBD8)

        for layer in style.layers {
            let id = layer.identifier
            switch layer {
            case let l as MLNBackgroundStyleLayer:
                l.backgroundColor = NSExpression(forConstantValue: ground)
            case let l as MLNFillStyleLayer where id.contains("water"):
                l.fillColor = NSExpression(forConstantValue: water)
            case let l as MLNFillStyleLayer where ["park", "grass", "wood", "landcover"].contains(where: id.contains):
                l.fillColor = NSExpression(forConstantValue: park)
            case let l as MLNFillStyleLayer where id == "building":
                l.isVisible = false
            case let l as MLNSymbolStyleLayer where id.contains("poi") || id.contains("housenumber") || id.contains("shield"):
                l.isVisible = false
            default:
                break
            }
        }

        guard let source = style.source(withIdentifier: "openmaptiles") else { return }
        let buildings = MLNFillExtrusionStyleLayer(identifier: "b3d", source: source)
        buildings.sourceLayerIdentifier = "building"
        buildings.minimumZoomLevel = 12.6
        let stops: [NSNumber: UIColor] = dark
            ? [0: UIColor(rgb: 0x1A1B1E), 60: UIColor(rgb: 0x202125), 200: UIColor(rgb: 0x2A2C31)]
            : [0: UIColor(rgb: 0xFFFFFF), 60: UIColor(rgb: 0xF4F4F1), 200: UIColor(rgb: 0xE7E9EE)]
        buildings.fillExtrusionColor = NSExpression(
            format: "mgl_interpolate:withCurveType:parameters:stops:(mgl_coalesce({render_height, 8}), 'linear', nil, %@)", stops)
        // Buildings grow out of the ground between zoom 12.8 and 14: flying in from the flat intro raises the city.
        buildings.fillExtrusionHeight = NSExpression(mglJSONObject: [
            "interpolate", ["linear"], ["zoom"], 12.8, 0, 14.0, ["coalesce", ["get", "render_height"], 8],
        ])
        buildings.fillExtrusionBase = NSExpression(mglJSONObject: [
            "interpolate", ["linear"], ["zoom"], 12.8, 0, 14.0, ["coalesce", ["get", "render_min_height"], 0],
        ])
        buildings.fillExtrusionOpacity = NSExpression(forConstantValue: 0.95)
        // Under the labels, so street and neighborhood names stay readable.
        if let firstLabel = style.layers.first(where: { $0 is MLNSymbolStyleLayer }) {
            style.insertLayer(buildings, below: firstLabel)
        } else {
            style.addLayer(buildings)
        }

        // Soft light from the viewport keeps the buildings white instead of shading them gray (mockup values).
        let light = MLNLight()
        light.anchor = NSExpression(forConstantValue: "viewport")
        light.color = NSExpression(forConstantValue: UIColor.white)
        // Lower intensity = less contrast between faces, so walls stay near white.
        light.intensity = NSExpression(forConstantValue: dark ? 0.3 : 0.25)
        light.position = NSExpression(forConstantValue: NSValue(mlnSphericalPosition: MLNSphericalPositionMake(1.3, 210, 40)))
        style.light = light
    }
}
