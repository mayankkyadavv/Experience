# ADR-003: Apple Maps by default for place search

- **Status:** Accepted (2026-10-18) · **Ledger:** R13, R14

## Context
Identification needs place search, coordinates and stable ids. Caching terms are a hard requirement.

## Decision
**Apple Maps**: MapKit on the device (including `MKLocalSearchCompleter` for the Instagram hint) and the Maps Server API on the server. Google Places only if the Phase 0 comparison on the 30 reels shows Apple's match rate is clearly worse. Store `place_id` permanently; every other lookup field goes in an expiring cache, with expiry per field set by the provider's terms (zero where caching isn't allowed).

## Consequences
- Low cost, and free on-device autocomplete.
- The Maps Server API needs the Apple Developer account. Until then, `spikes/identify` falls back to OpenStreetMap Nominatim (spike only, not production).

## Revisit when
The Phase 0 or eval match rate for Apple Maps is clearly below Google's.
