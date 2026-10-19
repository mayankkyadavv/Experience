import Foundation

/// Mirrors the `experience_category` enum in `supabase/migrations` (a test keeps them in sync).
public enum ExperienceCategory: String, Codable, Sendable, CaseIterable {
    case food, cafe, dessert, bar, nightlife, music, comedy
    case artsCulture = "arts_culture"
    case attraction, outdoors, sports, active
    case `class`
    case games, shopping, market, event, wellness, lodging, other

    public var group: CategoryGroup {
        switch self {
        case .food, .cafe, .dessert, .market: .food
        case .bar, .nightlife, .music, .comedy: .nightlife
        case .outdoors, .sports, .active, .wellness: .outdoors
        case .artsCulture, .attraction: .culture
        case .class, .games, .event: .activity
        case .shopping, .lodging, .other: .other
        }
    }
}

/// The six color groups in DESIGN.md: the only saturated colors in the app.
public enum CategoryGroup: String, Sendable, CaseIterable {
    case food, nightlife, outdoors, culture, activity, other

    public var label: String {
        switch self {
        case .food: "Food & drink"
        case .nightlife: "Nightlife"
        case .outdoors: "Outdoors"
        case .culture: "Arts & sights"
        case .activity: "Activities"
        case .other: "Other"
        }
    }

    /// sRGB hex from DESIGN.md (`cat-*` tokens). Identical in light and dark mode.
    public var hex: UInt32 {
        switch self {
        case .food: 0xFF5A36
        case .nightlife: 0xE63E8C
        case .outdoors: 0x1FAF5B
        case .culture: 0x2D6BFF
        case .activity: 0xFFB300
        case .other: 0x12B3C6
        }
    }
}
