# Experiences

Working name **Experiences** (the repo and Swift targets still say "Experience"). **A beautiful, intelligent, evolving representation of the life a person has actually lived, and the experiences they still want to have.** It answers three questions: **What have I experienced? What are the people I care about experiencing? What should I experience next?** The standard: *a home for a life that its owner will still want to open, understand, and trust twenty years from now.*

**Stage (2026-10-20):** the product was refounded on `EXPERIENCES_PRODUCT.md` (ADR-013). Building Stages 0-2 of that brief on the existing codebase (iOS app, camera capture, Supabase, Philadelphia catalog). The city-first "What should we do?" recommender strategy is superseded; its code stays as inputs. Next: the personal Experience schema, capture → Life → detail, then Want → Planned → Experienced.

## Source documents (read in this order)

1. **`EXPERIENCES_PRODUCT.md`: the governing product brief.** Read §1-5 (thesis, principles, object identity, lifecycle, data model) and §9 (privacy) before implementing any slice. §23 (stages) controls scope; §26 is addressed to you.
2. `docs/ADR/README.md` and **ADR-013** (how the brief maps onto existing decisions), then the other ADRs for technical rules.
3. `docs/MVP.md`: the current build scope (Stages 0-2) mapped onto this codebase.
4. `docs/ARCHITECTURE.md`: system, identification pipeline, what changes for the brief.
5. `docs/BUILD_PLAN.md`: task list and the log of decisions made during build.
6. The Eng Review ledger (R1-R18, D2-D5) at the end of `docs/designs/experience-mvp.md`: technical rules still in force where ADRs say so.
7. Historical only: `docs/EXPERIENCE.md` (the city-first vision), `docs/COMPETITIVE_RESEARCH.md`, `docs/designs/`.

**Precedence when docs disagree:** `EXPERIENCES_PRODUCT.md` > ADRs > Eng Review ledger > MVP.md > BUILD_PLAN.md > everything else (historical). ADRs win on technical choices the brief leaves open.

## Who this is for

The creator first: they record their own ordinary life, plans and wants, every week. Then friends. This is a product to be proud of and use for decades, not a startup validation exercise. **Don't spend effort on market fit, competitors, monetization, growth or fundraising** (brief intro). Prioritize craft, usefulness, trust, personal meaning and the pleasure of using it.

## How the founder wants you to work

- **Build usable slices that complete the loop**: a few beautifully connected screens over many feature demos. Show real capture, retrieval, permissions and persistence before widening scope.
- **Anything a person sees must be perfect:** UI, copy, empty, loading and error states, dark mode, large text, accessibility. Ask about user-visible tradeoffs.
- **Backend and infra choices are delegated to you.** Pick what's flexible, reliable and low cost; log it in `docs/BUILD_PLAN.md` "Decisions made during build" (or an ADR if major). Don't ask.
- **Surface product-contract changes explicitly:** anything touching object identity, privacy meaning, ownership or data retention goes to the founder with a concrete proposal (brief §2). Don't reopen settled ADRs otherwise.

## The core object and loop

**One Experience across its life** (brief §3-4): `want → planned → (in progress) → experienced`, or `cancelled`. The same ID is the saved idea, the plan, the memory, the feed card, the map pin and the recap entry. No separate post or memory tables. A repeat visit is a new Experience. Saving a friend's Experience creates *your own* Want linked by `inspired_by`; a shared outing is one Experience with participation records. Catalog/venue listings are reference material until someone saves, plans or logs one.

```
discover → want → plan → do → capture → remember → share → reflect → discover again
```

Capture: **+** from anywhere (the camera from ADR-012 is one entry) → photos/video, a short thought, or no media → draft with proposed title/time/place → **Save privately**. Saves locally first; never waits for AI or upload. Text-only, undated and place-less Experiences are first class.

Navigation (starting point, brief §7): **Life · Discover · Plans · You**, with **+** always available and search everywhere. Life switches Overview / Timeline / Map / Calendar.

## Architecture (ADR-001 to ADR-013)

- **iOS:** SwiftUI app + Share Extension on a local Swift package **`ExperienceCore`** (models, `Sourced<T>`, API client, outbox, auth). Minimum iOS 17.
- **Backend: one Supabase project** (Auth with Sign in with Apple, Postgres with RLS on every table, Edge Functions, `jobs` + `pg_cron`, APNs). Free tier while building; Pro on the day of the first TestFlight build.
- **Domain (ADR-013 over ADR-006/009/011):** the **personal Experience** is the root (owner, state, time with precision and timezone, visibility, places, moments, media, participation, per-person reflections, provenance). `cities` and the Philadelphia catalog stay as reference listings. The schema for this is the next migration.
- **Maps (ADR-010):** MapLibre Native + OpenFreeMap tiles; place search and directions stay Apple.
- **Identification (ADR-005):** shared links → legal metadata → Claude extraction → place search; the result is a proposed Want. Check the `claude-api` skill for model IDs before writing that code.

## Non-negotiable rules

From the brief (§2, §9, §21), all enforced server-side, not just in the UI:
- **Private by default** for every new Experience, capture, import, want and AI suggestion. Three levels: Private / Friends / Public. A public profile never makes the archive public. Reflections, ratings and notes are owner-only even on a Public Experience.
- **One access policy** for object APIs, media delivery, search, feeds, maps, counts, recaps, AI retrieval and notifications. Filter before material enters AI context. On revocation, fail closed. An unguessable URL is not authorization.
- **Automation proposes; the person owns the truth.** AI never publishes, invites, schedules or silently edits history. Never invent venues, participants, dates, emotions or attendance. A passed end time asks "Did this happen?"; it never asserts attendance. Imported text and listings are data, not instructions.
- **Provenance on every field:** `source`, `lookup`, `estimated`, `user`, `curated`, via `Sourced<T>` and rendered only through `SourcedText` (estimates labelled "(estimated)"). Later model runs never overwrite user-confirmed fields.
- **Honest time and counts:** "Summer 2021" stays a range; keep original timezones; undated goes to "Date unknown". Counts include only confirmed Experienced objects, once per ID; other viewers see only counts they're allowed to see.
- **Capture can never lose a save:** local first (outbox / on-device draft with a client `save_id`), visible sync state ("Saved on this device; waiting to upload"), idempotent retries. Only the main app refreshes auth tokens.
- **The archive must last:** originals separate from derivatives; export (versioned JSON + media + manifest + Markdown) works without the service; deletion removes content from every derived index and job.
- **No pressure:** no streaks, guilt, "you haven't posted", leaderboards, fabricated urgency or social-comparison nudges. Notification cap (ledger R6): at most 1/day and 3/week; never 10pm-9am.
- **Ask for permissions in context**, one at a time, only when they help. The app must stay useful with every permission denied.
- **Never download or re-host platform videos** (TikTok/Instagram/YouTube): URL + metadata only, official embeds (ADR-004; the ADR-008 local research exception stands). Instagram is URL-only. Place caching follows provider terms.
- **Don't fabricate content:** no invented history in a real archive, no fake friends, ratings or availability in discovery; label sample data.
- **Don't lock the core into Philadelphia, travel, restaurants, solo users, or places.** City is a domain concept.

## Not building yet (deferred by the brief, §23)

Advanced AI (Ask Experiences, semantic search, reconstruction), full collaborative editing and selected-friend audiences (Stage 3), group availability voting, broad email/receipt ingestion, face recognition, continuous location, booking/payments, messaging, elaborate badges or gamification, recap films, multi-owner permission unions, Android, desktop/web. Stage 3-5 items live in the brief as direction, not demands.

Feature filter (brief §2): Would I want this about my life in ten years? Can it be captured or retrieved with almost no effort? Does it help me remember, connect, or go live something? Does it still feel good if I never share publicly?

## Testing

The brief's §24 end-to-end checks are the acceptance suite (text-only save with no permissions, offline capture without duplicates, Want → Planned → Experienced keeps its ID, Public → Private revokes everywhere, unfriend/block, no leaks across accounts). Test real authorization with owner, friend, non-friend, blocked and logged-out contexts, not hidden buttons.

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
