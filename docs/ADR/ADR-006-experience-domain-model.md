# ADR-006: Experience is the root domain object

- **Status:** Accepted (2026-10-18) · **Amends:** the Phase 1 Experience object and the location of R1's unique key · **Ledger:** R8 · **Design:** `docs/designs/experience-direction-after-rhyme.md`

## Context
Competitors (Rhyme and others) are place-centric: a saved post becomes a spot. Experience's thesis is about what the user *wants to do*. One place holds many possible experiences, and one experience (drive a race car on a real circuit) may not need the exact place in the video. The Phase 1 object had the location inline, which made a pin the root.

## Decision
- **Experience** = activity + intent, linked to **0..n places**, with a `location_requirement` of `exact | flexible | none` (`none` = the ledger's location-less "idea").
- Tables: `sources` (one per shared post, holds `save_id`), `experiences` (`source_id` replaces `source_group_id`), `experience_places` (`primary | candidate`), `places` (a shared provider cache, read-only to clients), `identification_candidates`. Every user table has `user_id` with owner-only RLS. See ARCHITECTURE.md.
- `title`, `intent`, `category`, `location_requirement` are all **`Sourced<T>`**: `estimated` by default, `source` when read literally from the post, `user` when corrected. They're rendered only via `SourcedText` (R8).
- **One post → Experiences:** separate things to do become separate Experiences (grouped by `source_id`). Alternative places for the same thing become candidates of one Experience.
- R1's idempotency key lives on `sources`. ADR-007 owns that rule.
- Feed, Go, Map and queue behavior per `location_requirement` is defined in MVP.md.

## Consequences
- The M1 schema is a few more tables than the inline object, but no migration later when intent or flexible locations matter.
- The eval can score activity and Experience counts, not just place.
- The UI headline (activity or place name) is a design decision (D4 pass).

## Revisit when
Real usage shows nearly every save is a single exact venue. Then the extra structure is cost without benefit.
