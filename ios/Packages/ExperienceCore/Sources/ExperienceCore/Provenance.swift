import Foundation

/// Where a displayed value came from (ledger R8, ADR-009).
public enum Provenance: String, Codable, Sendable, CaseIterable {
    /// Read from the shared post (caption, on-screen text).
    case source
    /// From a places provider.
    case lookup
    /// Written or guessed by AI. Always labelled "(estimated)".
    case estimated
    /// Typed or corrected by the user.
    case user
    /// Editorial catalog data reviewed by the founder.
    case curated
}

/// A value plus its provenance. Render it only through `SourcedText` (app target), which uses `display`.
public struct Sourced<Value: Sendable>: Sendable {
    public var value: Value
    public var provenance: Provenance

    public init(_ value: Value, _ provenance: Provenance) {
        self.value = value
        self.provenance = provenance
    }

    /// Estimates must never be shown as fact.
    public var needsEstimateLabel: Bool { provenance == .estimated }
}

extension Sourced: Equatable where Value: Equatable {}
extension Sourced: Codable where Value: Codable {}

extension Sourced where Value == String {
    /// The exact text to show: estimates get the " (estimated)" suffix, everything else is shown as is.
    public var display: String { needsEstimateLabel ? "\(value) (estimated)" : value }
}
