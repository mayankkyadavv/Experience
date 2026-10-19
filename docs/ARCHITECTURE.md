# Architecture

How the MVP is built. Decisions and their reasons live in `docs/ADR/` (the index maps every Eng Review ledger record). The scope is in `docs/MVP.md`.

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
- **Repo layout:** `ios/` (XcodeGen `project.yml`), `ios/Packages/ExperienceCore/`, `supabase/` (migrations, functions), `spikes/` (throwaway).

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
