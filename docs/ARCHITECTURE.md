# Architecture

How the MVP is built. Decisions and their reasons live in `docs/ADR/` (the index maps every Eng Review ledger record). The scope is in `docs/MVP.md`.

> **Built (2026-10-21):** the personal Experience schema, one access rule, private media storage and local-first saves are in (BUILD_PLAN decisions of 2026-10-21; migrations `20261024000000_life_archive.sql`, `20261025000000_media_storage.sql`; `ios/Experience/Life/`). The catalog tables are now `listings`. Items 1-4 of "Changes required by the product brief" are done; 5-8 remain.
>
> **Life-archive update (2026-10-20, ADR-013):** the product is now `EXPERIENCES_PRODUCT.md`. The system (iOS + share extension + Supabase + identification) still holds. The domain model below is out of date: the root is now the **personal Experience** (owner, lifecycle state, time precision/timezone, visibility, moments, media, participation, reflections), and the catalog becomes reference listings. See "Changes required by the product brief" at the end.

> **City-first update (2026-10-18):** the strategy moved to "What should we do?" in Philadelphia (`docs/EXPERIENCE.md`, `docs/MVP.md`). The system below (iOS + share extension + Supabase + the identification pipeline) still holds. The city-first schema is now in `supabase/migrations/20261019000000_init.sql` (ADR-009) and supersedes the domain model table below where they differ; maps follow ADR-010. Items 1-3, 6 and 7 of "Changes required by the city-first strategy" are done; 4, 5 and 8 remain.

## System

```
iPhone                                         Supabase (one project, ADR-002)
┌──────────────────────────────┐               ┌───────────────────────────────────────────┐
│ Share Extension              │  upload       │ Auth (Sign in with Apple)                 │
│  first URL → outbox → "Saved"├──────────────►│ Postgres + RLS on every table             │
│  IG: MKLocalSearchCompleter  │  (save_id)    │  sources ─insert trigger─► jobs           │
├──────────────────────────────┤               │                    │                      │
│ App (SwiftUI)                │               │  Edge Function: identify ◄── pg_cron retry│
│  outbox sync, feed+mini-map, │◄──────────────┤   metadata → Claude → Apple Maps          │
│  map, Needs a place, Did it  │  realtime/    │   → experiences, experience_places,       │
├──────────────────────────────┤  poll         │     identification_candidates             │
│ ExperienceCore (Swift pkg)   │               │  APNs push (low-confidence question)      │
│  models, Sourced<T>, API,    │◄──── push ────┤                                           │
│  outbox, auth, provenance    │               └───────────────────────────────────────────┘
└──────────────────────────────┘                        │            │
                                                Claude API   Apple Maps Server API
```

- **iOS** (ADR-001): a SwiftUI app and a share extension, both depending on the local Swift package `ExperienceCore`. The App Group holds the outbox. The refresh token lives in a shared keychain group, and the access token in an App Group file with complete protection. Only the app refreshes (R4).
- **Backend** (ADR-002): Supabase is the only backend. Edge Functions are TypeScript on Deno. The `jobs` table plus `pg_cron` do queueing and retries.
- **Repo layout:** `ios/` (XcodeGen `project.yml`), `ios/Packages/ExperienceCore/`, `supabase/` (migrations, functions), `catalog/` + `tools/`, `spikes/` (throwaway). `compose.yaml` + `docker/` run the same Supabase services locally (`README.md`); production is the hosted project.

## Domain model (ADR-006)

The root object is the **Experience** (what the user wants to do). Places are separate. Every user-data table has `user_id` with an owner-only RLS policy.

| Table | Key fields | Notes |
|---|---|---|
| `sources` | `id, user_id, save_id, url, platform, creator, user_hint (Sourced/user), saved_at` | One row per shared post. **Unique `(user_id, save_id)`** (ADR-007). Never stores video. |
| `experiences` | `id, user_id, source_id, title, intent, category, location_requirement` (all `Sourced`), `status (saved/done/dismissed/needs_review), confidence, user_confirmed, local_tag (local/travel/unknown), timestamps` | A post can yield several. |
| `experience_places` | `user_id, experience_id, place_ref, role (primary/candidate), confidence` | Chain branches are resolved at runtime, not stored (R5). |
| `places` | `provider, place_id, cached lookup fields + per-field expiry` | **Shared provider cache**, not user data. Clients read only; only `identify` (service role) writes. `place_id` is kept permanently; other fields expire per provider terms. User hints never go here. |
| `identification_candidates` | `user_id, source_id, candidates jsonb (interpretation, evidence, confidence, model), created_at` | Lands in M3. 12-month retention, deleted with the account. |
| `jobs` | `source_id, status, attempts, last_error, run_after` | One identification per source (R2). |
| `events` | `user_id, name, props, at` | MVP event list. |
| `home_cells` | `user_id, day, cell` | Coarse ~1 km. One row per user/day/cell, 30-day retention. |
| `device_tokens`, `notification_log` | | Push (R11) and the cap (R6, M8). |

**Provenance** (R8): every displayed field is `Sourced<T> { value, provenance: source | lookup | estimated | user }`. The only view that renders one is `SourcedText`, which labels estimates "(estimated)". `lookup` fields come from the places cache and are refetched by `place_id` when expired.

## Identification pipeline (ADR-005)

```
source row inserted
 → job (trigger fires identify immediately; pg_cron retries; 3 attempts → needs_review)
 → 1. resolve short links (server side; Instagram is never fetched)
 → 2. gather legal signals (ADR-004): TikTok/YouTube oEmbed caption/title/author, YouTube Data API
       description/tags/recording location, the user's hint
 → 3. Claude structured extraction → candidate interpretations:
       { title, intent, category, location_requirement, place candidates, evidence quotes, confidence }
 → 4. place resolution: Apple Maps search per candidate, name-match check, adjust confidence
 → 5. write in one transaction: experiences + experience_places + identification_candidates; job done
 → 6. ≥ 0.8 and a solid match → auto-pin; otherwise question (push only within 5 min) or "Needs a place"
```

- The model is `claude-opus-5-5` with structured outputs (Zod schema) and server-side fallback on refusal. Check the `claude-api` skill for current IDs before changing it.
- Metadata is untrusted input. The prompt tells the model to ignore instructions inside captions.
- The pipeline never hides uncertainty: confidence and evidence are stored per candidate.
- `spikes/identify/` is the working prototype of steps 1-4. It doesn't yet return intent, title-as-activity or location requirement; M3 adds those.

## Evaluation

The identification system is measured, not trusted.

**Dataset:** 30 of the founder's saves from Phase 0 (10 per platform), hand-labelled per reel with the correct place, the correct activity, the expected number of Experiences, category, and location requirement. It grows with corrections from friends (`correction` events).

**Metrics:**
- Location / business accuracy (MVP target: ≥ 70% correct for TikTok/YouTube)
- Activity correct (founder-labelled yes/no), the Experience count matching, category accuracy: **scored, no MVP target yet**
- Confidence calibration: do 0.8+ predictions turn out right ≥ 80% of the time?

**Signal ladder experiments (allowed signals only):**

| Arm | Signals | Status |
|---|---|---|
| 1 | Metadata only (title, author) | allowed |
| 2 | Caption + metadata | allowed |
| 3 | Caption + web search | allowed |
| 4 | Caption + thumbnail vision | **blocked until the terms check confirms oEmbed thumbnails may be used**. If allowed, the thumbnail is fetched transiently, sent to the model, and never stored or re-served. |
| 5 | + transcript / frames / on-screen text | **local research only** (ADR-008, `spikes/identify`). Blocked for production by ADR-004. |

## Constraints that shape the code

- Never download or re-host platform video. Embeds only (ADR-004).
- Place caching follows the provider's terms; `place_id` is the only lookup field kept permanently.
- The outbox is written before upload. `save_id` is idempotent (ADR-007).
- Only the main app refreshes auth tokens (R4).
- At most 3 live web views in the feed (R9).
- Notification cap and quiet hours (R6, M8).

## Changes required by the city-first strategy (settle in the architecture phase)

Kept small on purpose: only what the MVP needs, plus not blocking what comes later.

1. **Shared catalog + City** (ADR-009, proposed): `cities`; catalog `experiences` with recommendation attributes (price range, duration, good-for occasions, hours/dates, tags); a per-user relationship table (saved / interested / not interested / done, rating). Today's per-user `experiences` rows from shared posts become "match or create".
2. **Taste profile:** onboarding answers + feedback events → per-user preference weights. Start as plain Postgres tables or a derived view; no separate infrastructure.
3. **Recommendation:** constraints (time window, duration, budget, who, mood, location) → hard filters (open, affordable, fits the time, reachable) → rank by taste and saves → top 3 with reasons. Whether an LLM ranks or explains is decided with cost and latency numbers. Must work for the few hundred Philadelphia Experiences without new infrastructure.
4. **Hours and travel time:** a source for opening hours and event dates, and an estimate of travel time from the user's location (provider terms apply to caching).
5. **Identification matching:** extracted Experiences match existing catalog entries; the eval adds "matched correctly".
6. **Provenance for curated data:** add a provenance value for editorial/catalog data, or map it to an existing one.
7. **No longer needed for the wedge decision:** `home_cells` and `local_tag` (the travel-vs-local question is decided). Drop them unless another feature needs them.
8. **Not now, but don't block:** Plans (ordered Experiences + transport), groups of users, many-user ratings, "what did people do" aggregates, sequences. Plain relational tables are fine; no graph database.

## Changes required by the product brief (2026-10-20, ADR-013)

1. **Personal Experience schema:** a new migration for owner-scoped `experiences` (or rename the catalog to `listings` and give personal Experiences the name): `state`, draft/archived flags, `visibility`, time start/end + precision + timezone, `inspired_by`, `source_listing_id`, revision. Related: `moments`, `media_assets` (original vs derivative, processing status, contributor), `participation` (invitation, attendance, display consent), `reflections` (per person, private by default), `collections`. Migrate `user_experiences` and `captures` into it.
2. **One access policy:** a Postgres function (`can_view(experience, viewer)`) used by every RLS policy, media signing, search and counts, so all surfaces agree. Friends visibility = the owner's accepted friends (`friendships`), not participants' friends.
3. **Media storage:** private Supabase Storage buckets, signed short-lived URLs checked against the access policy, location stripped from served derivatives, idempotent uploads keyed by a client id (founder confirms, MVP.md open decision 1).
4. **Local-first capture:** an on-device draft store (extends the outbox, ADR-007) so saves work offline and sync visibly.
5. **Search:** Postgres full-text search over permitted fields first; semantic search later and rebuildable.
6. **Export:** an Edge Function (or on-device builder) producing versioned JSON + media + manifest + Markdown; round-trip test.
7. **Deletion:** remove from serving paths, search, derived summaries, queued jobs and recaps; documented retention windows.
8. **Recommender and identification** stay; their output is a proposed Want, never an asserted fact.
