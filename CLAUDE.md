# Experience

Working name. An iOS app that turns short-form videos people save (Reels, TikToks, Shorts) into things they actually go do. You share a video to the app, it works out the place, pins it on your map, and brings it back at the moment you could go.

**Stage (2026-10-18):** pre-code. Planning is done; the next session starts building. Read `docs/BUILD_PLAN.md` first. It's the ordered task list.

## Source documents (read in this order)

1. `docs/BUILD_PLAN.md`: what to build next, milestone by milestone, with prerequisites.
2. `docs/designs/experience-mvp.md`: approved design doc. It covers the problem, premises, the full product spec (Phase 1 section), success metrics, and at the end the **Eng Review decision ledger (R1-R18, D2-D5)**. When this file and the ledger disagree, the ledger wins.
3. `Pitch.md`: the founder's original brief: vision, competitive landscape, data model sketch, long-term roadmap.

## Who this is for right now

The founder's friends (one friend group first). The goal is a working app friends actually use. **Expansion gate:** friends keep sharing reels to it. When they do, it goes out to more people. Share events are logged from day one to measure this.

## How the founder wants you to work

- **Speed to a usable MVP beats more planning.** Don't reopen settled decisions in the ledger. Ask questions only when they're truly blocking.
- **Anything a tester sees must be perfect:** UI, copy, empty, loading and error states, dark mode, large text. Hold UI to a high bar and ask about tester-visible tradeoffs.
- **Backend and infra choices are delegated to you.** Pick what's flexible to change, reliable, and low cost, then note the choice in `docs/BUILD_PLAN.md` under "Decisions made during build". Don't ask about these.

## Core product loop (the demo)

Share reel → "Saved" instantly → identified in the background (place + confidence) → appears in the **"My Saves" feed** (vertical swipe of your own saves, with a live mini-map on top that pans to each place) → **Go** (directions) / **Did it**. If identification is unsure, ask one question; unresolved saves go to the "Needs a place" queue.

North star: experiences marked **done** per active user per month. Expansion signal: friends who keep sharing.

## Architecture (decided: ledger D3, R1-R18)

- **iOS:** SwiftUI app + Share Extension, both depending on a local Swift package **`ExperienceCore`** (models, API client, outbox, auth, provenance types). Minimum iOS version: pick the lowest that keeps the code simple (decide in M1).
- **Backend: one Supabase project.** No separate server. It holds Auth (Sign in with Apple), Postgres with row-level security on every table, Edge Functions (`identify`, later `digest`), a `jobs` table for queueing, `pg_cron` for retries and schedules, and APNs push sent from Edge Functions. Free tier while building; upgrade to **Pro (~$25/mo) on the day of the first TestFlight build** (the free tier pauses after 7 idle days).
- **Identification:** legally usable platform metadata → LLM extraction (Claude API; check the `claude-api` skill for current model IDs before writing that code) → place search. **Places provider: Apple Maps by default** (MapKit on device, Maps Server API on the server); Google Places only if Phase 0 shows Apple's match rate is clearly worse.

## Non-negotiable rules

- **Never download or re-host platform videos.** Store the URL + extracted metadata only. Display videos only through official embeds.
- **Provenance on every field:** `source` (from the post), `lookup` (places provider), `estimated` (AI), `user` (typed or corrected). Use the `Sourced<T>` type and render fields only through `SourcedText`, which labels estimates "(estimated)" automatically. Never show an estimate as fact.
- **Instagram links are URL-only.** Don't scrape or work around Meta's terms. The share extension asks "What place is this?" (skippable) using on-device `MKLocalSearchCompleter`. Any platform without legally usable metadata uses this same flow.
- **Place data caching follows the provider's terms** (e.g. Google lat/lng ≤ 30 days). Store `place_id` permanently; set cache expiry per field.
- **Capture can never lose a save:** the share extension writes to the App Group **outbox before uploading**, shows "Saved," and retries until the server confirms. Every save carries a client-generated `save_id` UUID with a unique index `(user_id, save_id)`, so retries never create duplicates.
- **Only the main app refreshes auth tokens.** The extension uses a valid token or just queues.
- **The feed keeps at most 3 live web views** (previous / current / next).
- Notification cap: at most 1/day and 3/week across all push types (except the low-confidence question sent within 5 minutes of a share). Never notify 10pm-9am.

## Not building yet

Booking or reservations, AI itineraries, social feed / followers / comments, group planning (first priority after MVP), creator or business features, a recommendation engine, gamification, Android, bulk import of Instagram/TikTok exports.

## Testing

No test setup exists yet; set it up in M1.
- **Swift Testing** for ExperienceCore logic: outbox replay idempotency, attribution, notification cap, URL extraction, provenance rendering rules.
- **Snapshot tests (swift-snapshot-testing)** for every screen state: loading, empty, error, success × light/dark × default/largest Dynamic Type (ledger D4).
- **Deno tests** for Edge Functions. An **identification eval** on the 30 reels from Phase 0 (target ≥70% correct for TikTok/YouTube).
- Before each TestFlight build: run `/qa` (or `/ios-qa`) on a real iPhone.
- Full test plan: `~/.gstack/projects/mayankkyadavv-Experience/mayankkyadavv-main-eng-review-test-plan-20261018-180000.md`.

## Useful skills

`/plan-design-review` or `/design-consultation` (UI before building screens, D4), `/ios-qa` and `/ios-design-review` (on-device checks), `/investigate` (bugs), `/ship` (when a milestone is done).
