# Architecture Decision Records

Each ADR records one decision: context, decision, consequences, and how to revisit it. Precedence: **ADRs > Eng Review ledger** (end of `docs/designs/experience-mvp.md`) **> MVP.md**. An ADR changes the ledger only where it explicitly says "amends".

New decisions get the next number. To change one, add a new ADR that supersedes it; don't rewrite history.

| ADR | Decision | Status |
|---|---|---|
| [001](ADR-001-native-ios.md) | Native iOS (SwiftUI + share extension + `ExperienceCore`) | Accepted |
| [002](ADR-002-supabase-backend.md) | Supabase is the whole backend | Accepted |
| [003](ADR-003-maps-provider.md) | Apple Maps by default for place search | Accepted |
| [004](ADR-004-social-content-ingestion.md) | Ingestion: URL-first, legal metadata only, never download video | Accepted |
| [005](ADR-005-ai-extraction-pipeline.md) | Identification as queued jobs: metadata → Claude → place search | Accepted |
| [006](ADR-006-experience-domain-model.md) | Experience is the root domain object | Accepted (amends the ledger) |
| [007](ADR-007-outbox-idempotent-capture.md) | Outbox capture with idempotent `save_id` | Accepted (amended by 006) |
| [008](ADR-008-local-video-research-exception.md) | Local research exception: video analysis on the founder's Mac only | Accepted (narrows 004 for research) |

## Ledger → ADR map

Every ledger record is either owned by an ADR or stays authoritative in the ledger.

| Ledger | Topic | Lives in |
|---|---|---|
| R1 | Outbox idempotency | ADR-007 (key moved to `sources` by ADR-006) |
| R2 | Identification as queued jobs | ADR-005 |
| R3 | Identify per save, no cross-user cache (reversed) | ADR-005 |
| R4 | Only the main app refreshes tokens | ledger, in force |
| R5 | Region monitoring API, chains | ledger, in force |
| R6 | Notification cap counter | ledger, in force |
| R7 | Spec gaps (a-e) | ledger, in force; (e) also in ADR-004 |
| R8 | `Sourced<T>` + `SourcedText` | ADR-006 |
| R9 | ≤ 3 live web views | ledger, in force |
| R10 / D4 | UI quality gate | ledger, in force |
| R11 | APNs from Edge Functions | ADR-002 |
| R12 | Share-payload handling, redirects | ADR-004 |
| R13 | `MKLocalSearchCompleter` hint | ADR-004 |
| R14 | Places provider, Apple Maps default | ADR-003 |
| R15 | First identify attempt on insert | ADR-005 |
| R16 | Supabase plan (Pro at TestFlight) | ADR-002 |
| R17 | Seed tester backlogs | ledger, in force |
| R18 / D5 | Demo for friends, build the loop first | ledger, in force (MVP.md) |
| D2 | Feed in TestFlight weeks 1-2 | reversed by D5 |
| D3 | Supabase-only backend + shared Swift package | ADR-001, ADR-002 |
