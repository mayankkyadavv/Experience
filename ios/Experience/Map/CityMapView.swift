import ExperienceCore
import MapLibre
import SwiftUI
import UIKit

/// The white 3D city (ADR-010): MapLibre + OpenFreeMap vector tiles, buildings extruded, color only from marks.
/// One instance lives behind every screen (RootView) and follows `MapScene`.
struct CityMapView: UIViewRepresentable {
    let scene: MapScene

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator(scene: scene) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: MapStyle.url(dark: colorScheme == .dark))
        map.delegate = context.coordinator
        map.logoView.isHidden = true
        map.compassView.isHidden = true
        // OpenStreetMap attribution stays visible (license requirement), clear of the bottom panels.
        map.attributionButtonPosition = .topRight
        map.attributionButtonMargins = CGPoint(x: 12, y: 92)
        map.maximumPitch = 75
        map.setCenter(scene.center, zoomLevel: MapCamera.introZoom, direction: 0, animated: false)
        context.coordinator.map = map
        context.coordinator.dark = colorScheme == .dark
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        for g in map.gestureRecognizers ?? [] where (g as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 {
            tap.require(toFail: g) // keep double-tap-to-zoom
        }
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let c = context.coordinator
        c.reduceMotion = reduceMotion
        if c.dark != (colorScheme == .dark) {
            c.dark = colorScheme == .dark
            c.styleReady = false
            map.styleURL = MapStyle.url(dark: c.dark)
        }
        // Reading the scene here makes SwiftUI re-run this when it changes.
        c.sync(shot: scene.shot, center: scene.center, marks: scene.marks, orbit: scene.orbit,
               bottomInset: scene.bottomInset, flight: scene.flight)
        c.syncDots(scene.dots)
        if map.showsUserLocation != scene.showsUser { map.showsUserLocation = scene.showsUser }
    }

    static func dismantleUIView(_ map: MLNMapView, coordinator: Coordinator) {
        coordinator.stop()
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        let scene: MapScene
        weak var map: MLNMapView?
        var dark = false
        var styleReady = false
        var reduceMotion = false

        private var shot: MapScene.Shot?
        private var center = CLLocationCoordinate2D()
        private var marks: [MapMark] = []
        private var orbit = true
        private var flight: TimeInterval = 1.2
        private var heights: [UUID: Double] = [:]
        private var fading: [MapMark] = []
        private var link: CADisplayLink?
        private var userTouchedAt: Date?
        private var flying = false

        init(scene: MapScene) { self.scene = scene }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            MapStyle.apply(to: style, dark: dark)
            let dotSource = MLNShapeSource(identifier: "dots", shape: nil, options: nil)
            style.addSource(dotSource)
            let dotLayer = MLNCircleStyleLayer(identifier: "dots", source: dotSource)
            dotLayer.circleColor = NSExpression(format: "CAST(c, 'UIColor')")
            dotLayer.circleRadius = NSExpression(forConstantValue: 6)
            dotLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            dotLayer.circleStrokeWidth = NSExpression(forConstantValue: 2.5)
            dotLayer.circlePitchAlignment = NSExpression(forConstantValue: "map")
            style.addLayer(dotLayer)

            let source = MLNShapeSource(identifier: "marks", shape: nil, options: nil)
            style.addSource(source)
            let layer = MLNFillExtrusionStyleLayer(identifier: "marks", source: source)
            layer.fillExtrusionColor = NSExpression(format: "CAST(c, 'UIColor')")
            layer.fillExtrusionHeight = NSExpression(forKeyPath: "h")
            layer.fillExtrusionBase = NSExpression(forConstantValue: 0)
            layer.fillExtrusionOpacity = NSExpression(forConstantValue: 0.92)
            style.addLayer(layer)
            styleReady = true
            renderMarks()
            renderDots()
            startLink()
            scene.markReady()
            if let shot, shot != .intro { move(animated: false) }
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            let gestures: MLNCameraChangeReason = [.gesturePan, .gesturePinch, .gestureRotate, .gestureZoomIn, .gestureZoomOut, .gestureOneFingerZoom, .gestureTilt]
            if !reason.isDisjoint(with: gestures) { userTouchedAt = Date() }
        }

        func sync(shot: MapScene.Shot, center: CLLocationCoordinate2D, marks: [MapMark], orbit: Bool, bottomInset: CGFloat, flight: TimeInterval) {
            guard let map else { return }
            self.orbit = orbit
            self.flight = flight
            let insets = UIEdgeInsets(top: 110, left: 0, bottom: bottomInset, right: 0)
            // Applied instantly: animating the inset during a camera flight shifts where the flight lands.
            if map.contentInset != insets { map.setContentInset(insets, animated: false, completionHandler: nil) }

            let marksChanged = marks != self.marks
            if marksChanged {
                // Marks that leave sink back into the ground instead of vanishing.
                let leaving = self.marks.filter { old in !marks.contains { $0.id == old.id } }
                fading.append(contentsOf: leaving.map { var m = $0; m.height = 0; return m })
                fading.removeAll { f in marks.contains { $0.id == f.id } }
                self.marks = marks
                renderMarks()
            }
            let moved = shot != self.shot || center.latitude != self.center.latitude || center.longitude != self.center.longitude
            let refit = marksChanged && shot == .marks
            self.shot = shot
            self.center = center
            if moved || refit, styleReady { move(animated: true) }
            startLink()
        }

        private var dots: [MapMark] = []

        func syncDots(_ dots: [MapMark]) {
            guard dots != self.dots else { return }
            self.dots = dots
            renderDots()
        }

        private func renderDots() {
            guard let map, styleReady, let source = map.style?.source(withIdentifier: "dots") as? MLNShapeSource else { return }
            source.shape = MLNShapeCollectionFeature(shapes: dots.map { dot in
                let f = MLNPointFeature()
                f.coordinate = dot.coordinate
                f.attributes = ["id": dot.id.uuidString, "c": dot.group.uiColor.hexString]
                return f
            })
        }

        func stop() {
            link?.invalidate()
            link = nil
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map, gesture.state == .ended else { return }
            let p = gesture.location(in: map)
            // A little slack around the finger so thin hexes are easy to hit.
            let area = CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)
            let hits = map.visibleFeatures(in: area, styleLayerIdentifiers: ["marks", "dots"])
            let ids = hits.compactMap { ($0.attribute(forKey: "id") as? String).flatMap(UUID.init(uuidString:)) }
            // Prefer the hit closest to the finger.
            let best = ids.min { a, b in distance(a, to: p, in: map) < distance(b, to: p, in: map) }
            if let best { scene.tapped = best }
        }

        private func distance(_ id: UUID, to p: CGPoint, in map: MLNMapView) -> CGFloat {
            guard let mark = (marks + dots).first(where: { $0.id == id }) else { return .greatestFiniteMagnitude }
            let q = map.convert(mark.coordinate, toPointTo: map)
            return hypot(q.x - p.x, q.y - p.y)
        }

        // MARK: Camera

        private func move(animated: Bool) {
            guard let map, let shot else { return }
            let camera: MLNMapCamera
            switch shot {
            case .intro:
                camera = MapCamera.intro(center)
            case .city:
                camera = MapCamera.city(center, heading: map.direction == 0 ? -20 : map.direction)
            case .marks:
                camera = marks.isEmpty ? MapCamera.city(center, heading: map.direction)
                    : MapCamera.overview(marks.map(\.coordinate), heading: map.direction)
            case .focus(let id):
                guard let mark = marks.first(where: { $0.id == id }) else { return }
                camera = MapCamera.focus(mark.coordinate, heading: map.direction + 35)
            }
            if !animated || reduceMotion || flight == 0 {
                map.setCamera(camera, animated: false)
                return
            }
            flying = true
            map.fly(to: camera, withDuration: flight, peakAltitude: -1) { [weak self] in
                Task { @MainActor in self?.flying = false }
            }
        }

        // MARK: Marks + orbit (one display link)

        private func startLink() {
            guard link == nil, styleReady else { return }
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        @objc private func tick() {
            guard let map, styleReady else { return }
            var changed = false
            for mark in marks + fading {
                let h = heights[mark.id] ?? (reduceMotion ? mark.height : 0)
                let next = reduceMotion ? mark.height : h + (mark.height - h) * 0.16
                let settled = abs(mark.height - next) < 0.5 ? mark.height : next
                if settled != h { changed = true }
                heights[mark.id] = settled
            }
            let gone = fading.filter { (heights[$0.id] ?? 0) <= 0.5 }
            if !gone.isEmpty {
                fading.removeAll { f in gone.contains { $0.id == f.id } }
                gone.forEach { heights[$0.id] = nil }
                changed = true
            }
            if changed { renderMarks() }

            let idle = userTouchedAt.map { Date().timeIntervalSince($0) > 6 } ?? true
            if orbit, !reduceMotion, idle, !flying, shot == .city || shot == .marks {
                map.setDirection(map.direction + 0.04, animated: false)
            }
        }

        private func renderMarks() {
            guard let map, styleReady, let source = map.style?.source(withIdentifier: "marks") as? MLNShapeSource else { return }
            let features = (marks + fading).map { mark -> MLNPolygonFeature in
                var ring = Hexagon.ring(around: mark.coordinate, radius: mark.radius)
                let feature = MLNPolygonFeature(coordinates: &ring, count: UInt(ring.count))
                feature.attributes = ["id": mark.id.uuidString, "c": mark.group.uiColor.hexString, "h": heights[mark.id] ?? 0]
                return feature
            }
            source.shape = MLNShapeCollectionFeature(shapes: features)
        }
    }
}

enum MapCamera {
    /// Below the building rise threshold in MapStyle, so the city starts flat.
    static let introZoom = 12.2

    static func intro(_ center: CLLocationCoordinate2D) -> MLNMapCamera {
        MLNMapCamera(lookingAtCenter: center, acrossDistance: 14000, pitch: 0, heading: 0)
    }

    static func city(_ center: CLLocationCoordinate2D, heading: CLLocationDirection = -20) -> MLNMapCamera {
        MLNMapCamera(lookingAtCenter: center, acrossDistance: 3000, pitch: 62, heading: heading)
    }

    static func focus(_ c: CLLocationCoordinate2D, heading: CLLocationDirection) -> MLNMapCamera {
        MLNMapCamera(lookingAtCenter: c, acrossDistance: 3000, pitch: 58, heading: heading)
    }

    static func overview(_ coords: [CLLocationCoordinate2D], heading: CLLocationDirection) -> MLNMapCamera {
        // With many marks, frame the middle 80% so one far-away place doesn't zoom the whole city out.
        func trimmed(_ xs: [Double]) -> [Double] {
            let s = xs.sorted()
            guard s.count > 10 else { return s }
            let cut = s.count / 10
            return Array(s[cut..<(s.count - cut)])
        }
        let lats = trimmed(coords.map(\.latitude)), lngs = trimmed(coords.map(\.longitude))
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lngs.min()! + lngs.max()!) / 2)
        let span = max((lats.max()! - lats.min()!) * 111_000, (lngs.max()! - lngs.min()!) * 85_000)
        // Many marks = a city-wide view: further back and flatter so the whole spread reads.
        let many = coords.count > 10
        return MLNMapCamera(lookingAtCenter: center, acrossDistance: max(3400, span * (many ? 2.4 : 1.7)), pitch: many ? 48 : 55, heading: heading)
    }
}

enum Hexagon {
    /// Six-sided ring (closed) of `radius` meters, flat-topped like the mockup.
    static func ring(around c: CLLocationCoordinate2D, radius: Double) -> [CLLocationCoordinate2D] {
        let dLat = radius / 111_320
        let dLng = radius / (111_320 * cos(c.latitude * .pi / 180))
        return (0...6).map { i in
            let a = Double.pi / 3 * Double(i) + .pi / 6
            return CLLocationCoordinate2D(latitude: c.latitude + dLat * sin(a), longitude: c.longitude + dLng * cos(a))
        }
    }
}
