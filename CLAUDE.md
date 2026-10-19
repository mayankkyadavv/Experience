# Experience

Working name. An iOS app that **helps you and your friends figure out what to do, and actually do it.** The central question: **"What should we do?"** It knows what you like, what you've saved (including TikToks you share to it), your time, budget and who you're with, and recommends a few things worth doing in your city. City-first, not travel-first. Internal principle: **close the gap between wanting and doing.**

**Stage (2026-10-18):** building. City-first strategy (Philadelphia beta, NYC likely next; `docs/EXPERIENCE.md`), design approved (`DESIGN.md`), 30-day plan in `docs/BUILD_PLAN.md` (week 1: Supabase schema, recommender, catalog tooling, `ExperienceCore`). Read `docs/MVP.md` first.

## Source documents (read in this order)

1. `docs/MVP.md`: **current requirements**. If a feature isn't here, it's out of scope.
2. `docs/ARCHITECTURE.md`: system, domain model, identification pipeline, eval plan.
3. `docs/ADR/README.md`: the decision records, plus a map of every Eng Review ledger record.
4. The **Eng Review ledger** (R1-R18, D2-D5) at the end of `docs/designs/experience-mvp.md`.
5. `docs/BUILD_PLAN.md`: the ordered task list (M0-M8) and the log of decisions made during build.
6. For context only: `docs/EXPERIENCE.md` (vision, never requirements), `docs/COMPETITIVE_RESEARCH.md`, `docs/designs/experience-direction-after-rhyme.md`.

**Precedence when docs disagree:** ADRs > Eng Review ledger > MVP.md > the design doc's Phase 1 section > BUILD_PLAN.md > EXPERIENCE.md > the rest of `Pitch.md` and the design doc (historical). An ADR changes the ledger only where it says "amends".

## Who this is for right now

The founder (dogfooding real plans in **Philadelphia**), then friends and early users there. The question being tested: **when people don't know what to do, will they open Experience?** The strongest signal is someone saying "Check Experience." If the Philadelphia beta shows that behavior, NYC is the likely first expansion. Philadelphia is a beta market, not the product's identity: City is a domain concept, never hardcoded. When the company goal and the engineering-portfolio goal conflict, the company goal wins.

## How the founder wants you to work

- **Speed to a usable MVP beats more planning.** Don't reopen settled decisions in the ledger or the ADRs. Ask questions only when they're truly blocking.
- **Anything a tester sees must be perfect:** UI, copy, empty, loading and error states, dark mode, large text. Hold UI to a high bar and ask about tester-visible tradeoffs.
- **Backend and infra choices are delegated to you.** Pick what's flexible to change, reliable, and low cost, then note the choice in `docs/BUILD_PLAN.md` under "Decisions made during build" (or a new ADR if it's a major one). Don't ask about these.

## Core product loop

**"What should we do?"** → a few constraints (when, how long, budget, who, optional mood) → **three** strong recommendations from a seeded Philadelphia catalog plus your saves → Interested / Not interested / Save → go → **Did it** → rate → better recommendations.

Input loop: share a TikTok → "Saved" instantly → identified in the background (activity + place + confidence) → matched to or added as an Experience → shapes your taste. If identification is unsure, ask one question.

North star (proposed, founder to confirm): recommended Experiences marked **done** per active user per month. Philosophy: open Experience → decide → close the phone → go do something. Never optimize for time in the app.

## Architecture (ADR-001 to ADR-010)

- **iOS:** SwiftUI app + Share Extension, both depending on a local Swift package **`ExperienceCore`** (models, `Sourced<T>`, API client, outbox, auth). Minimum iOS version: the lowest that keeps the code simple (decide in M1).
- **Backend: one Supabase project.** No separate server. It holds Auth (Sign in with Apple), Postgres with row-level security on every table, Edge Functions (`identify`, later `digest`), a `jobs` table for queueing, `pg_cron` for retries and schedules, and APNs push from Edge Functions. Free tier while building; upgrade to **Pro (~$25/mo) on the day of the first TestFlight build**.
- **Domain model (ADR-006):** the root object is an **Experience** (activity + intent, 0..n places, `location_requirement` exact/flexible/none), not a place. Tables: `sources` (one per shared post, holds `save_id`), `experiences`, `experience_places`, `places` (shared provider cache), `identification_candidates`. **ADR-009** adds `cities` and makes Experiences a shared, city-scoped catalog (`curated` provenance) with per-user `user_experiences` (saved / interested / not interested / done, rating); shared posts match or create private Experiences.
- **Maps (ADR-010):** render with **MapLibre Native** + OpenStreetMap vector tiles (OpenFreeMap) and our own white 3D style; place search, autocomplete and directions stay Apple.
- **Identification (ADR-005):** legally usable platform metadata → LLM extraction (Claude API; check the `claude-api` skill for current model IDs before writing that code) → place search. **Apple Maps by default** (ADR-003). Prototype: `spikes/identify/`.

## Non-negotiable rules

- **Never download or re-host platform videos.** Store the URL + extracted metadata only. Display videos only through official embeds. Only exception: local research in `spikes/identify` on the founder's Mac (ADR-008: TikTok/YouTube, temp files deleted every run, never shipped).
- **Provenance on every field:** `source` (from the post), `lookup` (places provider), `estimated` (AI), `user` (typed or corrected). Use the `Sourced<T>` type and render fields only through `SourcedText`, which labels estimates "(estimated)" automatically. Never show an estimate as fact. This includes the AI-written activity title, category and location requirement.
- **TikTok first** for capture in the app (founder, 2026-10-18); Instagram and YouTube follow under the same rules.
- **Instagram links are URL-only.** Don't scrape or work around Meta's terms. The share extension asks "What place is this?" (skippable) using on-device `MKLocalSearchCompleter`. Any platform without legally usable metadata uses this same flow.
- **Place data caching follows the provider's terms** (e.g. Google lat/lng ≤ 30 days). Store `place_id` permanently; set cache expiry per field.
- **Capture can never lose a save:** the share extension writes to the App Group **outbox before uploading**, shows "Saved," and retries until the server confirms. Every save carries a client-generated `save_id` UUID with a unique index `(user_id, save_id)` on `sources`, so retries never create duplicates.
- **Only the main app refreshes auth tokens.** The extension uses a valid token or just queues.
- **The feed keeps at most 3 live web views** (previous / current / next).
- Notification cap: at most 1/day and 3/week across all push types (except the low-confidence question sent within 5 minutes of a share). Never notify 10pm-9am.
- **Don't reduce Experiences to pins, and don't add features because a competitor has them.** Our differences from Rhyme, Beli, Google Maps and others are unproven hypotheses; never claim one in UI copy or docs without evidence. Recommendation reasons follow the provenance rule too.
- **Don't lock the core into Philadelphia, travel, restaurants, solo users, or places instead of experiences.**

## Not building yet

Social feed, friends/followers, comments, messaging, multi-user groups and group optimization, Plans (multi-stop itineraries), a public Plan marketplace, creator monetization, sponsored placements, leaderboards and achievements, multi-city or worldwide content, travel booking/flights/hotels, large recommendation infrastructure, graph databases, Instagram/YouTube capture (after TikTok), Android, a web app, bulk import of exports. Vision items (groups, Plans, "what did people do", sequences, city exploration, travel mode) live only in `docs/EXPERIENCE.md`.

Feature filter for anything new: (1) does it help someone decide what to do and go do it, or teach Experience what they like? (2) is it useful in an ordinary week in the city? (3) does it avoid locking the core into one city, travel, restaurants, solo users or places? A "no" to (1) means not now.

## Testing

Local backend: `docker compose up -d`, then `docker compose run --rm tools deno task smoke` (see `README.md`). `deno task test` runs the recommender and schema/RLS tests.
- **Swift Testing** for ExperienceCore logic: outbox replay idempotency, attribution, notification cap, URL extraction, provenance rendering rules.
- **Snapshot tests (swift-snapshot-testing)** for every screen state: loading, empty, error, success × light/dark × default/largest Dynamic Type (ledger D4).
- **Deno tests** for Edge Functions. An **identification eval** on the 30 reels from Phase 0: place ≥70% correct for TikTok (YouTube once supported); catalog-match accuracy once ADR-009 lands; activity-correct, Experience count, category and confidence calibration are scored too (ARCHITECTURE.md).
- Before each TestFlight build: run `/qa` (or `/ios-qa`) on a real iPhone.
- Full test plan: `~/.gstack/projects/mayankkyadavv-Experience/mayankkyadavv-main-eng-review-test-plan-20261018-180000.md`.

## Useful skills

`/plan-design-review` or `/design-consultation` (UI before building screens, D4), `/ios-qa` and `/ios-design-review` (on-device checks), `/investigate` (bugs), `/ship` (when a milestone is done).

## Design System
Read DESIGN.md before visual or UI work: it defines the fonts, colors, spacing, and
aesthetic direction. Ask the user before departing from it. When reviewing or QA-ing
UI, flag code that doesn't match DESIGN.md.

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. Route only to skills in the session's available-skills list; answer directly for quick questions or small scoped edits.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
