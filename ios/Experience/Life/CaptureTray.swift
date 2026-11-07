import CoreLocation
import ExperienceCore
import Foundation
import MapKit
import Observation
import SwiftUI

/// A draft's place: suggested from Apple Maps near where its photos were taken, found in a search, or just typed.
struct DraftPlace: Codable, Equatable, Hashable {
    var name: String
    var locality: String?
    /// Nil for a place typed by hand ("Grandma's house").
    var lat: Double?
    var lng: Double?
    /// Apple's point-of-interest category, when it has one.
    var category: String?
}

/// A photo or video waiting in the tray. Its file is already in the originals; its id becomes the media's client id.
struct TrayShot: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: MediaAsset.Kind
    var fileName: String
    var takenAt: Date
    var duration: Double?
    var width: Int?
    var height: Int?
    var contentType: String
    var lat: Double?
    var lng: Double?
    var fromPhotos = false
    /// Linked from the Photos library: no file of ours (`fileName` is empty), nothing copied or uploaded.
    var libraryRef: String?

    init(id: UUID, kind: MediaAsset.Kind, fileName: String, takenAt: Date, duration: Double? = nil, width: Int? = nil, height: Int? = nil,
         contentType: String, lat: Double? = nil, lng: Double? = nil, fromPhotos: Bool = false, libraryRef: String? = nil) {
        self.id = id; self.kind = kind; self.fileName = fileName; self.takenAt = takenAt; self.duration = duration
        self.width = width; self.height = height; self.contentType = contentType; self.lat = lat; self.lng = lng; self.fromPhotos = fromPhotos
        self.libraryRef = libraryRef
    }

    /// Deletes this shot's own file. A linked photo has none: the library keeps it, and nothing here touches it.
    func discardFile() {
        guard libraryRef == nil, !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: LifeFiles.original(fileName))
    }

    /// A photo or video picked from the library, already copied into the originals.
    init(picked m: PendingMedia, takenAt fallback: Date) {
        self.init(id: m.clientId, kind: m.kind, fileName: m.fileName, takenAt: m.takenAt ?? fallback, duration: m.duration, width: m.width,
                  height: m.height, contentType: m.contentType, lat: m.lat, lng: m.lng, fromPhotos: true)
    }

    var asset: MediaAsset {
        MediaAsset(id: id, experienceId: id, clientId: id, kind: kind, position: 0, caption: nil, altText: nil, takenAt: takenAt,
                   durationSeconds: duration, width: width, height: height, originalPath: nil, thumbPath: nil,
                   deviceFile: libraryRef == nil ? fileName : nil, status: libraryRef == nil ? .onDevice : .linked, libraryRef: libraryRef)
    }

    var pending: PendingMedia {
        PendingMedia(clientId: id, kind: kind, fileName: fileName, takenAt: takenAt, duration: duration, width: width, height: height,
                     contentType: contentType, lat: lat, lng: lng, libraryRef: libraryRef)
    }
}

/// When the person says it was, overriding the photos' own time. Approximate stays approximate.
struct ChosenTime: Codable, Equatable {
    var start: Date?
    var end: Date?
    var precision: TimePrecision

    static let unknown = ChosenTime(start: nil, end: nil, precision: .unknown)

    static func day(_ date: Date) -> ChosenTime {
        ChosenTime(start: Calendar.current.startOfDay(for: date), end: nil, precision: .day)
    }

    static func month(_ year: Int, _ month: Int) -> ChosenTime {
        let start = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        return ChosenTime(start: start, end: Calendar.current.date(byAdding: DateComponents(month: 1, second: -1), to: start), precision: .month)
    }

    /// "Summer 2021" is June 1 to August 31; winter starts the December before.
    static func season(_ name: String, _ year: Int) -> ChosenTime {
        let first = ["Winter": 12, "Spring": 3, "Summer": 6, "Fall": 9][name] ?? 6
        let start = Calendar.current.date(from: DateComponents(year: first == 12 ? year - 1 : year, month: first, day: 1))!
        return ChosenTime(start: start, end: Calendar.current.date(byAdding: DateComponents(month: 3, second: -1), to: start), precision: .season)
    }

    static func year(_ year: Int) -> ChosenTime {
        let start = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
        return ChosenTime(start: start, end: Calendar.current.date(byAdding: DateComponents(year: 1, second: -1), to: start), precision: .year)
    }
}

/// One Experience on its way to being kept: shots from one stretch of time in one place (the camera's tray, picked
/// photos), or just words. Every way in edits this same draft on the same screen. Everything it proposes (title,
/// place, kind) was worked out on this phone from the shots' time and location, and is labelled estimated.
struct TrayDraft: Codable, Identifiable, Equatable {
    var id: UUID
    var shots: [TrayShot]
    var timezone: String
    /// What the person typed; nil while the suggestion stands.
    var title: String?
    var words = ""
    var collection: CollectionChoice?
    var place: DraftPlace?
    /// The person picked the place (or said there isn't one); suggestions leave it alone from then on.
    var placeChosen = false
    /// Other places close by, offered in "How we guessed".
    var nearby: [DraftPlace] = []
    /// The neighborhood, when there's no place to name.
    var area: String?
    var coverId: UUID?
    /// When the person set the time; nil means the shots' own time (or unknown with no shots).
    var chosenTime: ChosenTime?
    /// Kinds the person picked; nil while the suggestion stands.
    var chosenCategories: [LifeCategory]?
    /// Stored only for a want, so older drafts read back as lived.
    private var want: Bool?

    init(id: UUID = UUID(), shots: [TrayShot] = [], timezone: String = TimeZone.current.identifier, lived: Bool = true) {
        self.id = id
        self.shots = shots
        self.timezone = timezone
        self.want = lived ? nil : true
    }

    /// I lived it, or I want to.
    var lived: Bool {
        get { want != true }
        set { want = newValue ? nil : true }
    }

    var start: Date { shots.map(\.takenAt).min() ?? Date() }
    var end: Date { shots.map(\.takenAt).max() ?? Date() }
    var cover: TrayShot? { shots.first { $0.id == coverId } ?? shots.first }
    var photos: Int { shots.filter { $0.kind == .photo }.count }
    var videos: Int { shots.filter { $0.kind == .video }.count }

    var center: CLLocation? {
        let located = shots.compactMap { s in s.lat.flatMap { lat in s.lng.map { CLLocation(latitude: lat, longitude: $0) } } }
        guard !located.isEmpty else { return nil }
        let n = Double(located.count)
        return CLLocation(latitude: located.map(\.coordinate.latitude).reduce(0, +) / n,
                          longitude: located.map(\.coordinate.longitude).reduce(0, +) / n)
    }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: timezone) ?? .current
        return c
    }

    private var hour: Int { calendar.component(.hour, from: start) }

    var partOfDay: String {
        switch hour {
        case 5..<12: "Morning"
        case 12..<17: "Afternoon"
        case 17..<22: "Evening"
        default: "Night"
        }
    }

    private var meal: String? {
        switch hour {
        case 6..<11: "Breakfast"
        case 11..<15: "Lunch"
        case 17..<23: "Dinner"
        default: nil
        }
    }

    /// Named from the place and the time of day. With nothing to go on, just the day ("Thursday evening").
    /// Words alone get no suggestion: the person names it.
    var suggestedTitle: String {
        guard !shots.isEmpty, lived else { return "" }
        if let place {
            switch place.category.map(MKPointOfInterestCategory.init(rawValue:)) {
            case .restaurant?: return "\(meal ?? partOfDay) at \(place.name)"
            case .cafe?, .bakery?: return "Coffee at \(place.name)"
            case .nightlife?, .brewery?, .winery?: return "Drinks at \(place.name)"
            case .museum?, .theater?, .movieTheater?, .stadium?, .amusementPark?, .aquarium?, .zoo?, .nationalPark?: return place.name
            default: return "\(partOfDay) at \(place.name)"
            }
        }
        if let area { return "\(partOfDay) in \(area)" }
        var f = Date.FormatStyle.dateTime.weekday(.wide)
        f.timeZone = calendar.timeZone
        return "\(start.formatted(f)) \(partOfDay.lowercased())"
    }

    var sourcedTitle: Sourced<String> {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Sourced(title.trimmingCharacters(in: .whitespacesAndNewlines), .user)
        }
        // A title from the day alone is read straight off the photos; one naming a place is a guess.
        return Sourced(suggestedTitle, place != nil || area != nil ? .estimated : .source)
    }

    var sourcedPlace: Sourced<String>? {
        if let place { return Sourced(place.name, placeChosen ? .user : .estimated) }
        return placeChosen ? nil : area.map { Sourced($0, .estimated) }
    }

    var canSave: Bool { !shots.isEmpty || !sourcedTitle.value.isEmpty }

    /// The kinds it'll be saved with: the person's, else the suggestion.
    var categories: [LifeCategory] { chosenCategories ?? suggestedCategories }

    /// The kind of thing, from the place's category. A suggestion like the rest.
    var suggestedCategories: [LifeCategory] {
        switch place?.category.map(MKPointOfInterestCategory.init(rawValue:)) {
        case .restaurant?, .cafe?, .bakery?, .foodMarket?: [.food]
        case .nightlife?, .brewery?, .winery?: [.nightlife]
        case .museum?, .theater?, .movieTheater?, .library?: [.artsCulture]
        case .park?, .beach?, .nationalPark?, .campground?, .marina?: [.outdoors]
        case .stadium?, .fitnessCenter?: [.sports]
        default: []
        }
    }

    /// When it was, and where that came from: the person's choice, else the shots' own time.
    var time: (start: Date?, end: Date?, precision: TimePrecision, provenance: Provenance) {
        if !lived { return (nil, nil, .unknown, .user) }
        if let c = chosenTime { return (c.start, c.end, c.start == nil ? .unknown : c.precision, .user) }
        if shots.isEmpty { return (nil, nil, .unknown, .user) }
        return (start, end.timeIntervalSince(start) >= 60 ? end : nil, .exact, .source)
    }

    /// "7:40 – 9:15 PM", "7:40 PM – now" while it's still going, with the day in front when it isn't today.
    /// A time the person chose reads the way it was chosen ("Summer 2021", "Date unknown").
    func timeLabel(now: Date = Date()) -> String {
        if let c = chosenTime {
            if c.precision == .day, let s = c.start {
                if calendar.isDate(s, inSameDayAs: now) { return "Today" }
                if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(s, inSameDayAs: y) { return "Yesterday" }
            }
            return ExperienceTime(start: c.start, end: c.end, precision: c.precision, timezone: timezone).label()
        }
        if shots.isEmpty { return "Date unknown" }
        var t = Date.FormatStyle.dateTime.hour().minute()
        t.timeZone = calendar.timeZone
        var day = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        day.timeZone = calendar.timeZone
        let prefix = calendar.isDate(start, inSameDayAs: now) ? "" : "\(start.formatted(day)) · "
        if now.timeIntervalSince(end) < 15 * 60, calendar.isDate(end, inSameDayAs: now) { return prefix + "\(start.formatted(t)) – now" }
        if end.timeIntervalSince(start) < 60 { return prefix + start.formatted(t) }
        let range = start ..< end
        var r = Date.IntervalFormatStyle(time: .shortened)
        r.timeZone = calendar.timeZone
        return prefix + range.formatted(r)
    }

    /// "5 photos and a video".
    var countLabel: String { Self.countLabel(photos: photos, videos: videos) }

    static func countLabel(photos: Int, videos: Int) -> String {
        let p = photos == 0 ? nil : photos == 1 ? "a photo" : "\(photos) photos"
        let v = videos == 0 ? nil : videos == 1 ? "a video" : "\(videos) videos"
        let s = [p, v].compactMap { $0 }.joined(separator: " and ")
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// What gets saved: the Experience, its media (cover first) and its collection. Nil until there's something to keep.
    func saving() -> (draft: ExperienceDraft, media: [PendingMedia], collection: CollectionChoice?)? {
        guard canSave else { return nil }
        let title = sourcedTitle
        let t = time
        var provenance: [String: Provenance] = ["title": title.provenance]
        if t.start != nil { provenance["time"] = t.provenance }
        let place = sourcedPlace
        if let place { provenance["place"] = place.provenance }
        if !categories.isEmpty { provenance["categories"] = chosenCategories == nil ? .estimated : .user }
        let words = self.words.trimmingCharacters(in: .whitespacesAndNewlines)
        let spot: CLLocation? = if let p = self.place {
            p.lat.flatMap { lat in p.lng.map { CLLocation(latitude: lat, longitude: $0) } }
        } else {
            placeChosen ? nil : center
        }
        let draft = ExperienceDraft(title: title.value, description: words.isEmpty ? nil : words, state: lived ? .experienced : .want,
                                    startsAt: t.start, endsAt: t.end, precision: t.precision,
                                    timezone: t.start == nil ? nil : timezone, placeName: self.place?.name,
                                    placeLocality: self.place?.locality ?? (placeChosen ? nil : area),
                                    placeLat: spot?.coordinate.latitude, placeLng: spot?.coordinate.longitude,
                                    categories: categories.map(\.rawValue), provenance: provenance)
        // The cover goes first: the first photo is the card's picture.
        let ordered = (cover.map { [$0] } ?? []) + shots.filter { $0.id != cover?.id }.sorted { $0.takenAt < $1.takenAt }
        return (draft, ordered.map(\.pending), collection)
    }
}

/// Names for a spot, from Apple Maps: the nearest named place within a short walk, a few others close by, and the
/// neighborhood. The only thing that leaves the phone is the coordinate, to Apple, as with any map.
enum PlaceLookup {
    static func around(_ center: CLLocation) async -> (closest: DraftPlace?, nearby: [DraftPlace], area: String?) {
        let request = MKLocalPointsOfInterestRequest(center: center.coordinate, radius: 120)
        let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        let area = await neighborhood(center)
        let places: [DraftPlace] = items
            .compactMap { item -> (DraftPlace, CLLocationDistance)? in
                guard let name = item.name, let loc = item.placemark.location else { return nil }
                return (DraftPlace(name: name, locality: area, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude,
                                   category: item.pointOfInterestCategory?.rawValue), loc.distance(from: center))
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        // Only a place right where the photos were gets named; otherwise just the neighborhood.
        let closest = places.first.flatMap { p in
            CLLocation(latitude: p.lat ?? 0, longitude: p.lng ?? 0).distance(from: center) < 60 ? p : nil
        }
        return (closest, Array(places.prefix(4)), area)
    }

    static func neighborhood(_ location: CLLocation) async -> String? {
        let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return mark?.subLocality ?? mark?.locality
    }

    /// A search for a place by name, near a spot when there is one.
    static func search(_ query: String, near center: CLLocation?) async -> [DraftPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let center { request.region = MKCoordinateRegion(center: center.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000) }
        let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        return items.prefix(8).compactMap { item in
            guard let name = item.name, let loc = item.placemark.location else { return nil }
            let mark = item.placemark
            return DraftPlace(name: name, locality: mark.subLocality ?? mark.locality, lat: loc.coordinate.latitude,
                              lng: loc.coordinate.longitude, category: item.pointOfInterestCategory?.rawValue)
        }
    }
}

/// The draft tray (A + C): shots from the camera collect here, grouped by time and place, instead of each
/// asking a question. The person gathers them into Experiences at the camera or later from the globe.
/// Kept on this phone as one JSON file; the shots' files are already in the originals, so nothing is lost.
@MainActor @Observable
final class CaptureTray {
    private(set) var drafts: [TrayDraft] = []
    /// "Later" on the globe card: hidden until something new comes in.
    private(set) var snoozed = false

    /// A new draft starts after this long without a shot, or this far from the last one.
    static let gap: TimeInterval = 2 * 3600
    static let apart: CLLocationDistance = 500

    private static let file = LifeFiles.root.appending(path: "Tray.json")
    private var looking: Set<UUID> = []

    init() {
        LifeFiles.prepare()
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: Self.file), let saved = try? dec.decode(Saved.self, from: data) {
            drafts = saved.drafts
            snoozed = saved.snoozed
        }
    }

    var latest: TrayDraft? { drafts.max { $0.end < $1.end } }
    var shotCount: Int { drafts.reduce(0) { $0 + $1.shots.count } }
    func draft(_ id: UUID) -> TrayDraft? { drafts.first { $0.id == id } }

    /// "Tonight" after five, otherwise "Today".
    static func dayWord(_ now: Date = Date()) -> String { Calendar.current.component(.hour, from: now) >= 17 ? "Tonight" : "Today" }

    // MARK: Adding

    /// Moves a capture into the originals and files it with the draft it belongs to. Returns whether it started a new one.
    @discardableResult
    func add(_ captured: CapturedMedia, at location: CLLocation?) async -> Bool {
        let id = UUID()
        let ext = captured.url.pathExtension.isEmpty ? (captured.kind == .video ? "mov" : "jpg") : captured.url.pathExtension
        let name = "\(id.uuidString.lowercased()).\(ext)"
        let dest = LifeFiles.original(name)
        do { try FileManager.default.moveItem(at: captured.url, to: dest) } catch {
            guard (try? FileManager.default.copyItem(at: captured.url, to: dest)) != nil else { return false }
        }
        let kind: MediaAsset.Kind = captured.kind == .video ? .video : .photo
        let facts = await LifeMedia.facts(of: dest, kind: kind)
        let shot = TrayShot(id: id, kind: kind, fileName: name, takenAt: captured.takenAt, duration: captured.duration ?? facts.duration,
                            width: facts.width, height: facts.height, contentType: facts.contentType,
                            lat: location?.coordinate.latitude, lng: location?.coordinate.longitude)
        let started = file(shot)
        snoozed = false
        persist()
        return started
    }

    /// Photos or videos picked from the library, added to a draft as they are.
    func add(_ media: [PendingMedia], to draftId: UUID) {
        guard let i = drafts.firstIndex(where: { $0.id == draftId }) else { return }
        let fallback = drafts[i].end
        drafts[i].shots += media.map { TrayShot(picked: $0, takenAt: fallback) }
        persist()
    }

    /// The location arrived after the shot (the first fix, or the permission answer). Suggest again with it.
    func locate(_ shotId: UUID, _ location: CLLocation) {
        guard let d = drafts.firstIndex(where: { $0.shots.contains { $0.id == shotId } }),
              let s = drafts[d].shots.firstIndex(where: { $0.id == shotId }), drafts[d].shots[s].lat == nil else { return }
        drafts[d].shots[s].lat = location.coordinate.latitude
        drafts[d].shots[s].lng = location.coordinate.longitude
        persist()
        Task { await suggest(drafts[d].id, force: true) }
    }

    private func file(_ shot: TrayShot) -> Bool {
        let here = shot.lat.flatMap { lat in shot.lng.map { CLLocation(latitude: lat, longitude: $0) } }
        if let i = drafts.indices.max(by: { drafts[$0].end < drafts[$1].end }),
           abs(shot.takenAt.timeIntervalSince(drafts[i].end)) < Self.gap,
           here == nil || drafts[i].center == nil || here!.distance(from: drafts[i].center!) < Self.apart {
            drafts[i].shots.append(shot)
            let id = drafts[i].id
            if drafts[i].nearby.isEmpty { Task { await suggest(id) } }
            return false
        }
        drafts.append(TrayDraft(shots: [shot]))
        let id = drafts[drafts.count - 1].id
        Task { await suggest(id) }
        return drafts.count > 1
    }

    // MARK: Suggesting (on this phone, plus Apple Maps for the names of places)

    /// Looks up what's at the draft's location. Leaves anything the person chose alone.
    func suggest(_ id: UUID, force: Bool = false) async {
        guard let draft = draft(id), !draft.placeChosen, let center = draft.center, !looking.contains(id),
              force || draft.nearby.isEmpty else { return }
        looking.insert(id)
        defer { looking.remove(id) }

        let found = await PlaceLookup.around(center)
        guard let i = drafts.firstIndex(where: { $0.id == id }), !drafts[i].placeChosen else { return }
        drafts[i].place = found.closest
        drafts[i].nearby = found.nearby
        drafts[i].area = found.area
        persist()
    }

    // MARK: Editing

    func update(_ id: UUID, _ change: (inout TrayDraft) -> Void) {
        guard let i = drafts.firstIndex(where: { $0.id == id }) else { return }
        change(&drafts[i])
        // A tray draft is its shots; with the last one removed there's nothing left to keep.
        if drafts[i].shots.isEmpty { drafts.remove(at: i) }
        persist()
    }

    /// The draft screen edits a tray draft in place: every change is saved as it's made.
    func binding(_ id: UUID) -> Binding<TrayDraft> {
        var last = draft(id) ?? TrayDraft(id: id)
        return Binding(get: { [self] in
            if let d = draft(id) { last = d }
            return last
        }, set: { [self] new in update(id) { $0 = new } })
    }

    /// The person's choice of place; nil means "there isn't one".
    func choosePlace(_ id: UUID, _ place: DraftPlace?) {
        update(id) { $0.place = place; $0.placeChosen = true }
    }

    /// Takes a shot out of the tray and off the phone.
    func remove(_ shotId: UUID) {
        guard let d = drafts.firstIndex(where: { $0.shots.contains { $0.id == shotId } }),
              let shot = drafts[d].shots.first(where: { $0.id == shotId }) else { return }
        drafts[d].shots.removeAll { $0.id == shotId }
        if drafts[d].shots.isEmpty { drafts.remove(at: d) }
        shot.discardFile()
        persist()
    }

    /// Moves a shot into a draft of its own. Returns the new draft's id.
    @discardableResult
    func split(_ shotId: UUID) -> UUID? {
        guard let d = drafts.firstIndex(where: { $0.shots.contains { $0.id == shotId } }), drafts[d].shots.count > 1,
              let shot = drafts[d].shots.first(where: { $0.id == shotId }) else { return nil }
        drafts[d].shots.removeAll { $0.id == shotId }
        var new = TrayDraft(id: UUID(), shots: [shot], timezone: drafts[d].timezone)
        new.area = drafts[d].area
        drafts.append(new)
        persist()
        Task { await suggest(new.id) }
        return new.id
    }

    func snooze() {
        snoozed = true
        persist()
    }

    // MARK: Keeping

    /// Saves a draft as a private Experience (phone first, like every save) and takes it out of the tray.
    @discardableResult
    func keep(_ id: UUID, in store: LifeStore) -> UUID? {
        guard let saving = draft(id)?.saving() else { return nil }
        let saved = store.save(saving.draft, media: saving.media, collection: saving.collection)
        drafts.removeAll { $0.id == id }
        persist()
        return saved
    }

    // MARK: File

    private struct Saved: Codable {
        var drafts: [TrayDraft]
        var snoozed: Bool
    }

    private func persist() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(Saved(drafts: drafts, snoozed: snoozed)) else { return }
        try? data.write(to: Self.file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
