import Foundation
import Testing
@testable import ExperienceCore

@Suite struct ExperienceTimeTests {
    let ny = "America/New_York"

    func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    @Test func undatedSaysSo() {
        #expect(ExperienceTime.unknown.label() == "Date unknown")
        #expect(ExperienceTime(start: nil, precision: .day).precision == .unknown)
    }

    @Test func aSummerStaysASummer() {
        let t = ExperienceTime(start: date("2021-06-01T04:00:00Z"), end: date("2021-09-01T03:59:00Z"), precision: .season, timezone: ny)
        #expect(t.label() == "Summer 2021")
        #expect(t.label(southern: true) == "Winter 2021")
        #expect(t.year == 2021)
    }

    @Test func monthsAndYearsStayApproximate() {
        #expect(ExperienceTime(start: date("2019-03-01T05:00:00Z"), precision: .month, timezone: ny).label() == "March 2019")
        #expect(ExperienceTime(start: date("2019-01-01T05:00:00Z"), precision: .year, timezone: ny).label() == "2019")
    }

    /// 11:30 PM in New York is the next day in UTC; the label keeps the day it happened there.
    @Test func daysAreShownWhereTheyHappened() {
        let t = ExperienceTime(start: date("2026-10-18T03:30:00Z"), precision: .day, timezone: ny)
        #expect(t.label() == "Oct 17, 2026")
        #expect(t.year == 2026)
    }

    @Test func rangesReadNaturally() {
        let t = ExperienceTime(start: date("2024-06-03T12:00:00Z"), end: date("2024-06-09T12:00:00Z"), precision: .range, timezone: "Europe/Madrid")
        #expect(t.label() == "Jun 3 – 9, 2024")
    }

    @Test func shortLabelsDropOnlyThisYear() {
        let now = date("2026-10-21T12:00:00Z")
        #expect(ExperienceTime(start: date("2026-10-18T16:00:00Z"), precision: .day, timezone: ny).shortLabel(now: now) == "Oct 18")
        #expect(ExperienceTime(start: date("2024-10-18T16:00:00Z"), precision: .day, timezone: ny).shortLabel(now: now) == "Oct 18, 2024")
        #expect(ExperienceTime(start: date("2021-06-01T04:00:00Z"), precision: .season, timezone: ny).shortLabel(now: now) == "Summer 2021")
    }
}

@Suite struct ExperienceModelTests {
    static let json = """
    {"id":"11111111-1111-1111-1111-111111111111","owner_id":"00000000-0000-0000-0000-00000000000a","save_id":null,
     "state":"experienced","is_draft":false,"archived_at":null,"visibility":"private","title":"Tea and a long conversation",
     "description":null,"categories":["everyday","shopping"],"starts_at":"2026-10-18T16:00:00+00:00","ends_at":null,
     "time_precision":"day","timezone":"America/New_York","place_name":null,"place_locality":null,"place_lat":null,
     "place_lng":null,"city_id":null,"listing_id":null,"inspired_by":null,"completed_at":"2026-10-18T22:00:00+00:00",
     "cover_media_id":null,"provenance":{"time":"estimated"},"created_at":"2026-10-18T22:00:00+00:00",
     "updated_at":"2026-10-18T22:00:00+00:00"}
    """

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @Test func decodesARow() throws {
        let e = try Self.decoder().decode(Experience.self, from: Data(Self.json.utf8))
        #expect(e.state == .experienced && e.visibility == .private)
        #expect(e.time.label() == "Oct 18, 2026")
        #expect(e.provenance(of: "time") == .estimated)
        #expect(e.sourcedTitle.provenance == .user)
        // Unknown categories are ignored, not crashed on.
        #expect(e.lifeCategories == [.everyday])
    }

    @Test func onlyConfirmedLivedExperiencesCountOncePerId() throws {
        let base = try Self.decoder().decode(Experience.self, from: Data(Self.json.utf8))
        var want = base; want.id = UUID(); want.state = .want
        var draft = base; draft.id = UUID(); draft.isDraft = true
        var archived = base; archived.id = UUID(); archived.archivedAt = Date()
        var cancelled = base; cancelled.id = UUID(); cancelled.state = .cancelled
        let all = [base, base, want, draft, archived, cancelled]
        #expect(all.experiencedCount == 1)
    }

    @Test func statesAndAudiencesMatchTheDatabase() {
        #expect(ExperienceState.allCases.map(\.rawValue) == ["want", "planned", "in_progress", "experienced", "cancelled"])
        #expect(Audience.allCases.map(\.rawValue) == ["private", "friends", "public"])
        #expect(LifeCategory.allCases.map(\.rawValue) ==
            ["food", "nightlife", "music", "arts_culture", "outdoors", "travel", "sports", "learning", "everyday", "milestones"])
    }
}
