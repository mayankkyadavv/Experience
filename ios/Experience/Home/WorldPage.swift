import ExperienceCore
import SwiftUI

/// The center page, where the app opens: the name, today, and your world turning slowly. Nothing else.
/// Your city glows; tap it (or the city label) to dive into its map.
struct WorldPage: View {
    /// False while another page is showing: the globe stops rendering.
    let isActive: Bool
    let onOpenCity: (GlobeController) -> Void

    @Environment(AppModel.self) private var model
    @Environment(LifeStore.self) private var life
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var globe = GlobeController()
    @State private var shown = false

    /// A beacon for each place you've lived something, clustered by city at world scale (brief §13), in the
    /// color of the last thing you did there. Your home city comes first: it glows and it's where the dive goes.
    private var beacons: [GlobeBeacon] {
        var out: [GlobeBeacon] = []
        if let city = model.city {
            let here = life.experienced.first { $0.cityId == city.id }
            out.append(GlobeBeacon(id: city.id, lat: city.centerLat, lng: city.centerLng,
                                   color: here?.lifeCategories.first?.group.uiColor ?? UIColor(rgb: 0xFFB300)))
        }
        let elsewhere = life.experienced.filter { $0.placeLat != nil && $0.cityId != model.city?.id }
        let byPlace = Dictionary(grouping: elsewhere) { $0.cityId ?? $0.placeLocality?.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? "" }
        for (key, list) in byPlace where !key.isEmpty {
            let lat = list.compactMap(\.placeLat).reduce(0, +) / Double(list.count)
            let lng = list.compactMap(\.placeLng).reduce(0, +) / Double(list.count)
            let color = list.first?.lifeCategories.first?.group.uiColor ?? UIColor(rgb: 0x12B3C6)
            out.append(GlobeBeacon(id: key, lat: lat, lng: lng, color: color))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Experiences", subtitle: Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))

            GeometryReader { geo in
                // By day the earth sits on the page: no glow of air, a soft shadow beneath it instead.
                // Its silhouette is radius 1 seen from 5.1 through a 30° field: about 0.37 of the height.
                let r = geo.size.height * 0.373
                if scheme == .light {
                    Ellipse()
                        .fill(.black.opacity(0.22))
                        .frame(width: r * 1.5, height: r * 0.16)
                        .blur(radius: 16)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 + r * 1.06)
                        .opacity(shown ? 1 : 0)
                }
                GlobeView(beacons: beacons, controller: globe, reduceMotion: reduceMotion, isActive: isActive, showsAtmosphere: scheme == .dark) { b in
                    if b.id == model.city?.id {
                        onOpenCity(globe)
                    } else {
                        // Elsewhere: turn it to face you for a moment, then let the world spin on.
                        globe.focus(lat: b.lat, lng: b.lng)
                        Task { try? await Task.sleep(for: .seconds(2.5)); globe.release() }
                    }
                }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(shown ? 1 : 0.86)
                    .opacity(shown ? 1 : 0)
                    .accessibilityElement()
                    .accessibilityLabel("Your world. \(model.city.map { "\($0.name) is lit." } ?? "")")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onOpenCity(globe) }
            }

            if let city = model.city {
                Button { onOpenCity(globe) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.circle")
                        Text(city.name)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Color.primary.opacity(0.08), in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10)))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Open your map of \(city.name)")
                .opacity(shown ? 1 : 0)
                .padding(.bottom, Theme.Space.lg)
            }
        }
        .onAppear {
            globe.release()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 1.1, bounce: 0)) { shown = true }
        }
    }
}
