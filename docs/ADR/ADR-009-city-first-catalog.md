# ADR-009: City-first: a shared Experience catalog with City as a domain concept

- **Status:** Accepted (2026-10-18) · **Amends:** ADR-006 (Experiences become shared catalog entries instead of only per-user rows) · **Strategy:** `docs/EXPERIENCE.md`, `docs/MVP.md`

## Context
ADR-006 made the Experience the root object, but every Experience is a per-user row created from a shared post (`experiences.user_id`, `source_id`). The city-first MVP adds a seeded catalog of several hundred Philadelphia Experiences that every user browses, saves, completes and rates, and a recommender that ranks them. A shared post should match an existing catalog Experience when it's the same activity. The product must also expand to other cities (NYC next) without schema changes.

## Decision
- **City** is an explicit entity (id, name, region, timezone, status such as `beta`). Experiences and places belong to a city. No city-specific logic in code.
- **Experience** becomes a shared catalog entity (activity + intent, 0..n places, `location_requirement`, plus recommendation attributes: price range, duration, good-for occasions, hours or dates, category, tags). It keeps ADR-006's shape and `Sourced<T>` provenance.
- **User ↔ Experience** relationships live in a per-user table (saved / interested / not interested / done, rating, from-recommendation flag), with owner-only RLS.
- A **shared post** (`sources`) yields extracted candidates. Each is matched to a catalog Experience or creates a new one: private to the user (`visibility = private`, `created_by` = the user). Promotion to the shared catalog is manual (founder review) in the beta.
- Leave room, without building them, for **Plan** (an ordered list of Experiences with times and transport), **groups** and **ratings by many users**.

## Consequences
- The M1 schema in BUILD_PLAN/ARCHITECTURE changes before any migration is written (nothing is built yet, so no data migration).
- Provenance gains a fifth value, `curated` (editorial catalog data), rendered without a label like `source`.
- Identification gains a matching step, and the eval gains a "matched the right catalog Experience" metric.

## Revisit when
Shared posts rarely match catalog entries, or the catalog's curation cost outweighs its value; then per-user Experiences (ADR-006 alone) may be enough.
