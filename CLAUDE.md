# Experience

Working name. An iOS app that learns what you want to do from the content that inspires you (Reels, TikToks, Shorts), then helps you actually do it. You share a video to the app, it works out the activity and the place, pins it on your map, and brings it back at the moment you could go. Internal principle: **close the gap between wanting and doing.**

**Stage (2026-10-18):** pre-code. Docs realigned after discovering Rhyme (formerly Roamy), a strong competitor that already does share-reel → map → itinerary well. Next: M1 architecture and implementation. Read `docs/MVP.md` first.

## Source documents (read in this order)

1. `docs/MVP.md`: **current requirements**. If a feature isn't here, it's out of scope.
2. `docs/ARCHITECTURE.md`: system, domain model, identification pipeline, eval plan.
3. `docs/ADR/README.md`: the decision records, plus a map of every Eng Review ledger record.
4. The **Eng Review ledger** (R1-R18, D2-D5) at the end of `docs/designs/experience-mvp.md`.
5. `docs/BUILD_PLAN.md`: the ordered task list (M0-M8) and the log of decisions made during build.
6. For context only: `docs/EXPERIENCE.md` (vision, never requirements), `docs/COMPETITIVE_RESEARCH.md`, `docs/designs/experience-direction-after-rhyme.md`.

**Precedence when docs disagree:** ADRs > Eng Review ledger > MVP.md > the design doc's Phase 1 section > BUILD_PLAN.md > EXPERIENCE.md > the rest of `Pitch.md` and the design doc (historical). An ADR changes the ledger only where it says "amends".

## Who this is for right now

The founder's friends (one friend group first). The goal is a working app friends actually use. **Expansion gate:** friends keep sharing reels to it. When they do, it goes out to more people. Share events are logged from day one to measure this. When the company goal and the engineering-portfolio goal conflict, the company goal wins.

## How the founder wants you to work

- **Speed to a usable MVP beats more planning.** Don't reopen settled decisions in the ledger or the ADRs. Ask questions only when they're truly blocking.
- **Anything a tester sees must be perfect:** UI, copy, empty, loading and error states, dark mode, large text. Hold UI to a high bar and ask about tester-visible tradeoffs.
- **Backend and infra choices are delegated to you.** Pick what's flexible to change, reliable, and low cost, then note the choice in `docs/BUILD_PLAN.md` under "Decisions made during build" (or a new ADR if it's a major one). Don't ask about these.

## Core product loop (the demo)

Share reel → "Saved" instantly → identified in the background (activity + place + confidence) → appears in the **"My Saves" feed** (vertical swipe of your own saves, with a live mini-map on top that pans to each place) → **Go** (directions) / **Did it**. If identification is unsure, ask one question; unresolved saves go to the "Needs a place" queue.

North star: experiences marked **done** per active user per month. Expansion signal: friends who keep sharing.

## Architecture (ADR-001 to ADR-007)

- **iOS:** SwiftUI app + Share Extension, both depending on a local Swift package **`ExperienceCore`** (models, `Sourced<T>`, API client, outbox, auth). Minimum iOS version: the lowest that keeps the code simple (decide in M1).
- **Backend: one Supabase project.** No separate server. It holds Auth (Sign in with Apple), Postgres with row-level security on every table, Edge Functions (`identify`, later `digest`), a `jobs` table for queueing, `pg_cron` for retries and schedules, and APNs push from Edge Functions. Free tier while building; upgrade to **Pro (~$25/mo) on the day of the first TestFlight build**.
- **Domain model (ADR-006):** the root object is an **Experience** (activity + intent, 0..n places, `location_requirement` exact/flexible/none), not a place. Tables: `sources` (one per shared post, holds `save_id`), `experiences`, `experience_places`, `places` (shared provider cache), `identification_candidates`.
- **Identification (ADR-005):** legally usable platform metadata → LLM extraction (Claude API; check the `claude-api` skill for current model IDs before writing that code) → place search. **Apple Maps by default** (ADR-003). Prototype: `spikes/identify/`.

## Non-negotiable rules

- **Never download or re-host platform videos.** Store the URL + extracted metadata only. Display videos only through official embeds. Only exception: local research in `spikes/identify` on the founder's Mac (ADR-008: TikTok/YouTube, temp files deleted every run, never shipped).
- **Provenance on every field:** `source` (from the post), `lookup` (places provider), `estimated` (AI), `user` (typed or corrected). Use the `Sourced<T>` type and render fields only through `SourcedText`, which labels estimates "(estimated)" automatically. Never show an estimate as fact. This includes the AI-written activity title, category and location requirement.
- **Instagram links are URL-only.** Don't scrape or work around Meta's terms. The share extension asks "What place is this?" (skippable) using on-device `MKLocalSearchCompleter`. Any platform without legally usable metadata uses this same flow.
- **Place data caching follows the provider's terms** (e.g. Google lat/lng ≤ 30 days). Store `place_id` permanently; set cache expiry per field.
- **Capture can never lose a save:** the share extension writes to the App Group **outbox before uploading**, shows "Saved," and retries until the server confirms. Every save carries a client-generated `save_id` UUID with a unique index `(user_id, save_id)` on `sources`, so retries never create duplicates.
- **Only the main app refreshes auth tokens.** The extension uses a valid token or just queues.
- **The feed keeps at most 3 live web views** (previous / current / next).
- Notification cap: at most 1/day and 3/week across all push types (except the low-confidence question sent within 5 minutes of a share). Never notify 10pm-9am.
- **Don't reduce Experiences to pins, and don't add features because a competitor has them.** Our differences from Rhyme are unproven hypotheses; never claim one in UI copy or docs without evidence.

## Not building yet

Itineraries or trip planning, booking or reservations, friends / followers / social feed / comments / shared lists, group planning (first priority after MVP), onboarding interest quizzes, recommendations or discovery for users with no saves, creator or business features, gamification, Android, a web app, bulk import of Instagram/TikTok exports. Vision items (preference graph, person → destination) live only in `docs/EXPERIENCE.md`.

Feature filter for anything new: does it serve the demo loop or the expansion gate, and would it still be useful if the user weren't traveling?

## Testing

No test setup exists yet; set it up in M1.
- **Swift Testing** for ExperienceCore logic: outbox replay idempotency, attribution, notification cap, URL extraction, provenance rendering rules.
- **Snapshot tests (swift-snapshot-testing)** for every screen state: loading, empty, error, success × light/dark × default/largest Dynamic Type (ledger D4).
- **Deno tests** for Edge Functions. An **identification eval** on the 30 reels from Phase 0: place ≥70% correct for TikTok/YouTube; activity-correct, Experience count, category and confidence calibration are scored too (ARCHITECTURE.md).
- Before each TestFlight build: run `/qa` (or `/ios-qa`) on a real iPhone.
- Full test plan: `~/.gstack/projects/mayankkyadavv-Experience/mayankkyadavv-main-eng-review-test-plan-20261018-180000.md`.

## Useful skills

`/plan-design-review` or `/design-consultation` (UI before building screens, D4), `/ios-qa` and `/ios-design-review` (on-device checks), `/investigate` (bugs), `/ship` (when a milestone is done).
