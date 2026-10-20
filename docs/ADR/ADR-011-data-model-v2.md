# ADR-011: Data model v2: links, occurrences, recommendation items, social graph

- **Status:** Accepted (2026-10-19) · **Extends:** ADR-009 · **Migration:** `supabase/migrations/20261021000000_data_model_v2.sql`

## Context
The founder asked for a large, AI-researched Philadelphia catalog (hundreds of places and dated events) and a schema that stays organized as the product grows: user information, event tracking, recommendation items, links, Experiences, friends and groups. ADR-009's schema holds Experiences, places, per-user state and the request log, but has no home for an Experience's URLs, for dated event instances, for per-pick recommendation analytics, or for a social graph.

## Decision
Additive tables and columns, grouped by domain. Nothing in v1 changes meaning.

| Domain | Tables | Notes |
|---|---|---|
| Geography | `cities`, `places` | Unchanged. |
| Catalog | `experiences` (+ `kind`, `subcategory`, `slug`), `experience_places`, **`experience_links`**, **`experience_occurrences`** | `kind`: place / activity / event / route. Links carry a `link_kind` (website, tickets, menu, socials, source) and provenance. Occurrences are concrete dates for events; weekly `hours` stay for places. |
| People | `profiles` (+ `username`, `avatar_url`) | Handles exist for friends later; no UI in the MVP. |
| Per-user state | `user_experiences` | Unchanged; `from_recommendation` now references `recommendation_requests`. |
| Recommendation | `recommendation_requests` (+ `group_id`), **`recommendation_items`** | One row per pick shown (position, score, reasons) so feedback joins to what was recommended. |
| Capture | `sources`, `identification_candidates`, `jobs` | Unchanged. |
| Social (vision) | **`friendships`**, **`groups`**, **`group_members`** | Tables and RLS only. CLAUDE.md still lists friends and groups as "not building yet"; this keeps them from needing a reshape. |
| Analytics | `events` (+ index on `name, at`) | The MVP event list. |

RLS: links and occurrences follow their Experience's visibility; recommendation items are visible to the requester; friendships to either side (requester creates, addressee answers); groups and members to members, via a `security definer` membership check to avoid recursive policies.

Catalog content stays in git (`catalog/<city>/*.json`, BUILD_PLAN decision) and is compiled to `supabase/seed.sql`. `tools/catalog/harvest.ts` bulk-researches topics with Claude + web search; every harvested fact is `estimated` and drafts are unpublished in production. The local Docker stack publishes drafts (`LOCAL_PUBLISH_DRAFTS`) so they show in the app, still labelled "(estimated)".

## Consequences
- The recommender writes `recommendation_items` alongside the request log.
- Events can be recommended by occurrence date once the recommender reads `experience_occurrences` (today it reads `dates`).
- Plans (ordered Experiences) attach later as `plans` + `plan_items` referencing `experiences`, `groups` and `recommendation_requests`.

## Revisit when
The catalog outgrows git review (move curation to an admin tool), or social features start and need feeds or graph queries beyond simple joins.
