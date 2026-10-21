# Build Plan: Experience, Philadelphia beta (30 days)

> **2026-10-20 (ADR-013):** the product is now `EXPERIENCES_PRODUCT.md` (a personal life archive). Scope is the brief's Stages 0-2 as mapped in `docs/MVP.md`. The 30-day plan below was written for the superseded city-first loop; its finished work carries over (see MVP.md "What carries over"), and the unchecked Week 2-4 items are replaced by **Next** below.

## Next (Stages 0-1)
- [ ] Personal Experience schema + one access policy (ARCHITECTURE.md "Changes required by the product brief" 1-2), PGlite RLS tests for owner / friend / non-friend / blocked / logged out.
- [ ] `ExperienceCore` models: Experience with state, time precision, visibility, moments, media, provenance; local draft store.
- [ ] Design pass (`/design-consultation` or `/plan-design-review`): several Life layouts, Experience detail, capture draft.
- [ ] Capture → draft → Save privately (camera, library, text, no media), offline-safe.
- [ ] Life: Overview, Timeline, Map + list; Experience detail; lexical search.
- [ ] Want / Planned on the same object; save a catalog listing or TikTok link as a Want.
- [ ] Media storage (after the founder confirms MVP.md open decision 1) and export.

Last updated 2026-10-18 (city-first). Check off tasks as you go and add decisions to the log at the bottom. Scope: `docs/MVP.md`. How it's built: `docs/ARCHITECTURE.md`, `docs/ADR/` (009 catalog, 010 map). How it looks: `DESIGN.md` (approved mockup linked there).

**Goal:** in 30 days (by ~2026-11-18), a TestFlight build the founder uses every week in Philadelphia to answer "What should we do?", then friends there. Core loop first: onboarding → ask → 3 recommendations → feedback → Did it → rate. TikTok capture feeds it.

## Prerequisites (the founder does these; agents should not install them)

- [x] **Install Xcode** (27.1, selected; iOS 27 Simulator installed 2026-10-19) from the Mac App Store, then `sudo xcode-select -s /Applications/Xcode.app`. As of 2026-10-18 only the Command Line Tools are installed, so `xcodebuild` fails ("requires Xcode").
- [ ] Apple Developer Program account ($99/yr): needed for the App Group, share extension provisioning, Sign in with Apple, APNs and TestFlight.
- [ ] `brew install xcodegen supabase/tap/supabase deno` (the Supabase CLI is only needed to deploy; local dev runs on Docker Desktop, see `README.md`)
- [x] Docker Desktop (installed)
- [ ] A Supabase account (free tier to start) and an Anthropic API key. Keep keys in local, untracked env files.
- [ ] Optional: the `gh` CLI for PRs.

## 30-day plan

### Week 1 (Oct 19-25): backend foundation + catalog (no Xcode needed)
- [x] Supabase schema per ADR-009 (`supabase/migrations/`): `cities`, `places`, `experiences` (catalog + private), `experience_places`, `user_experiences` (saved / interested / not_interested / done, rating, from_recommendation), `profiles` (city, onboarding answers), `sources`, `jobs`, `events`. Owner-only RLS on user tables; catalog readable by signed-in users.
- [x] Recommender v1 (`supabase/functions/recommend/`): hard filters (open in the window, fits duration, within budget, good-for who, reachable) → score (taste weights from onboarding + feedback, saved boost, novelty, distance) → top 3 with reasons built only from real data. Pure TypeScript core with Deno tests.
- [x] Catalog tooling (`tools/catalog/`): a JSON schema for a catalog Experience, a validator, a Claude-assisted drafter that turns a list of names into draft entries (every AI-filled field `estimated`), and a seed loader. Founder reviews drafts before they're `curated`.
- [ ] First 100 Philadelphia Experiences reviewed (founder), across the MVP.md coverage mix. Draft with `deno task catalog:draft` (45 starter ideas in `catalog/philadelphia/_ideas.txt`; needs `ANTHROPIC_WORKSPACE_ID` for the current user-level key), edit each JSON, set `"status": "reviewed"`, then `deno task catalog:seed`.
- [x] `ExperienceCore` Swift package (models incl. `Sourced<T>` with `curated`, API client protocol, recommendation request/response types) with `swift test` on macOS.

### Week 2 (Oct 26-Nov 1): iOS skeleton + the question
- [ ] XcodeGen project: app + share extension, App Group, keychain group. Sign in with Apple via Supabase. **2026-10-19:** app target + UI test target done (`ios/project.yml`); Debug signs in to the local Docker stack; Sign in with Apple code is in Release but needs the Apple Developer team + hosted Supabase. Share extension, App Group, keychain group remain.
- [x] Map component (MapLibre, ADR-010) with the DESIGN.md style: white 3D city, idle orbit, saved dots, beacons. (Saved dots come with the saved list in Week 3.)
- [x] Onboarding: city picker (Philadelphia beta, New York "coming next"), taste chips, budget, usually-with.
- [x] Home ("What should we do?") → ask sheet → recommend → three cards; camera flight + beacons. Interested / Not for us / Save on the cards.

### Week 3 (Nov 2-8): feedback, memory, capture
- [ ] Interested / Not for us / Save / Did it / rating (3-tile placeholder until the founder picks the scale); events logged. **Backend done 2026-10-19:** `record_feedback` RPC + `ExperienceCore.Feedback`; UI remains.
- [ ] Saved list; "Your Philadelphia" with pillars. **2026-10-19:** Explore mode (whole catalog on the map, filters incl. Saved, search, list) and the Experience detail sheet (facts, hours, dates, links, sources, directions, Save/Interested/Not for us/Did it/rating) are in. **Your city:** saved dots on every screen, pillars for done Experiences (height = rating), a done/saved count in the header, and an "Added to your city" toast after rating.
- [ ] Share extension (TikTok only): outbox first, "Saved", identify job (port `spikes/identify` extraction to the Edge Function, metadata only per ADR-004), match-or-create against the catalog.
- [ ] Catalog to 300+ reviewed entries.

### Week 4 (Nov 9-15): quality + TestFlight
- [ ] Every state (loading / empty / error) per DESIGN.md; snapshot tests light/dark × default/largest Dynamic Type.
- [ ] Privacy policy, tester consent, account deletion, location usage strings.
- [ ] Supabase Pro, `/qa` on a real iPhone, TestFlight to the founder, then Philadelphia friends.
- [ ] Founder dogfoods at least one real plan per week and logs what was wrong.

### Carried over from the earlier plan
M0 spikes still worth doing when convenient: TikTok share payloads on a real iPhone, the oEmbed terms check, Apple Maps vs. alternatives for Philadelphia place matching, and the gap hunt (now including the core question on Google Maps Ask Maps, TikTok Local, Beli, Cobble). The old M4-M8 (saves feed, needs-a-place queue, push, reminders, digest) are superseded.

## Open items (decide while building, not before)
- Expansion-gate threshold (how many friends sharing, for how long).
- Minimum iOS version.
- Final product name ("Experience" is hard to trademark or search for).
- Card headline: the activity or the place name; whether the question sheet offers alternative interpretations (D4 design pass).
- No-download rule vs. transcript/video-vision extraction (founder; default: keep the rule).
- ~~Travel vs. local wedge~~: decided 2026-10-18, local / city-first.

## Decisions made during build
<!-- Append: date, decision, why (flexible / reliable / low cost), how to undo. -->
- 2026-10-18 · Identification spike (`spikes/identify/`) is TypeScript run directly by Node (no build step). Why: the real `identify` Edge Function is TypeScript on Deno, so the extraction and place-search code ports almost unchanged (flexible). Undo: rewrite the spike; it's throwaway.
- 2026-10-18 · Extraction uses `claude-opus-5-5` via the Anthropic SDK with structured outputs (Zod schema), effort `medium`, and server-side `fallbacks: "default"` so a policy decline is retried on another model. Why: reliable JSON with no parsing code, and medium effort keeps cost per save low. Undo: change `MODEL` / effort in `extract.ts`.
- 2026-10-18 · Spike place search falls back to OpenStreetMap Nominatim when no Apple Maps token is set. Why: free and needs no key or developer account, so the spike runs before the Apple Developer account exists. Not for production (1 request/second, attribution required). Undo: set `APPLE_MAPS_AUTH_TOKEN`.
- 2026-10-18 · Docs restructured (EXPERIENCE / MVP / ARCHITECTURE / COMPETITIVE_RESEARCH / ADR) and Experience made the root domain object (ADR-006) after the Rhyme discovery. See `docs/designs/experience-direction-after-rhyme.md`. Why: keeps vision out of requirements, and the schema doesn't need a migration when activities and flexible locations matter. Undo: supersede ADR-006.
- 2026-10-18 · Local/travel tagging: home area = the coarse cell seen on the most distinct days in 30 days; 50 km radius; cells kept 30 days. Why: the wedge decision needs this without a new permission prompt (low cost, reliable). Undo: drop `home_cells` and `local_tag`.
- 2026-10-18 · Local decoder service (`spikes/identify`, `npm run serve` on 127.0.0.1:4321): Node + TypeScript, no framework, streaming each stage over Server-Sent Events. Video analysis per ADR-008: yt-dlp (≤ 720p, temp dir deleted every run), whisper.cpp `large-v3-turbo` on Metal for speech, Apple Vision OCR (a small Swift binary compiled on demand) for on-screen text, 8 evenly spaced frames. Why: everything runs on the Mac for free; the same pipeline code feeds the future Edge Function (flexible, low cost). Undo: delete `video.ts`/`server.ts`.
- 2026-10-18 · The "understand" step has two providers: Ollama (local, default `gemma3:12b`, sees frames) and Claude (`claude-opus-5-5`), chosen per run so they can be compared on the same reel. Output follows ADR-006 (Experiences with title, intent, category, location requirement, place candidates, evidence). Why: free local iteration, with Claude as the accuracy reference. Undo: drop a provider in `understand.ts`.
- 2026-10-18 · Decoder Instagram flow: Instagram links get the share extension's "What place is this?" question with autocomplete via `GET /api/suggest`, using Photon (komoot, OSM-based, free, built for search-as-you-type; Nominatim's policy forbids autocomplete) or the Apple Maps `searchAutocomplete` endpoint when a token is set. A picked suggestion = `user` name + coordinates, decision auto-pin, no lookup. A title written from the hint is `estimated`, not `user`. Answer time and outcome are logged for the Instagram < 10 s target. Why: tests the real product flow (ADR-004) for free (low cost, flexible). Undo: delete `suggestPlaces` and the question card.
- 2026-10-18 · **Strategy: city-first** (founder brief). "What should we do?" becomes the central interaction; Philadelphia is the beta/dogfooding city; NYC the likely first expansion; City is a domain concept, never hardcoded. EXPERIENCE, MVP, ARCHITECTURE, COMPETITIVE_RESEARCH and CLAUDE.md updated; ADR-009 (shared city-scoped catalog) proposed, not accepted. Why: a weekly use case instead of a few trips a year, and dogfoodable recommendations. Undo: revert these doc changes; ADR-006 still stands until ADR-009 is accepted.
- 2026-10-18 · **Capture launches TikTok-only** (founder). Instagram (URL-only, ADR-004) and YouTube follow. Why: Instagram needs the place-question flow and more setup; TikTok has the richest legal metadata. Undo: re-enable the other platforms in the share extension's allowlist.
- 2026-10-18 · The design pass (`/design-consultation`) was paused before writing DESIGN.md. Two directions were previewed (dark "Lamplight Atlas", rejected as empty; white "Postcards", not yet reviewed), both built around the old map + saves-feed loop. Restart it around "What should we do?" and recommendation cards. Previews: `~/.gstack/projects/mayankkyadavv-Experience/designs/design-system-20261018/`.
- 2026-10-18 · **ADR-009 accepted, ADR-010 added** (MapLibre Native + OpenFreeMap tiles for the white 3D city; search stays Apple). Why: the approved design needs restyled buildings and custom extrusions MapKit can't do. Undo: supersede ADR-010.
- 2026-10-18 · **Recommender v1 is plain TypeScript** (`supabase/functions/recommend/core.ts`): hard filters (hours in the city's timezone, dates, duration, budget, who/group size, ≤ 40 min travel, dismissed 60 days, done excluded) → transparent score (onboarding likes, feedback by category, saved +2, mood, novelty, ending-soon, distance) → three picks varied across color groups. Reasons come only from held data. Why: explainable, testable, no infra; easy to swap the scorer later (flexible, low cost). Undo: replace `recommend()`.
- 2026-10-18 · **Schema tests run in PGlite** (embedded Postgres in Deno) with a stub `auth` schema, so migrations and RLS are verified without Docker or the Supabase CLI. `deno task test`. Why: reliable checks today (low cost). Undo: switch to `supabase test db` once the CLI is installed.
- 2026-10-18 · **Catalog lives in git** as `catalog/<city>/<slug>.json`, drafted by Claude (`claude-opus-5-5`, web search + a strict `submit_entry` tool, since structured outputs can't be combined with citations), geocoded with Nominatim (dev only), reviewed by the founder, compiled to `supabase/seed.sql` with stable UUIDv5 ids. Why: reviewable diffs, reproducible seeds, no admin UI needed for the beta (flexible, low cost). Undo: move entries into a table + admin tool.
- 2026-10-18 · **ExperienceCore tests run without Xcode** via `ios/Packages/ExperienceCore/test.sh`, which points SwiftPM at the Command Line Tools' Swift Testing framework. Plain `swift test` once Xcode is installed.
- 2026-10-18 · Claude clients send `anthropic-workspace-id` when `ANTHROPIC_WORKSPACE_ID` is set, because the current key is user-level (`sk-ant-usr-…`) and the API rejects it without a workspace.
- 2026-10-19 · **Local backend runs on Docker Compose** (`compose.yaml`, `docker/`): Supabase's own open-source images (Postgres 17, GoTrue, PostgREST, Edge Runtime, Studio) pinned to the versions in their self-hosted compose, behind an nginx gateway on the Supabase CLI ports (54321-54323). A one-shot `migrate` service applies `supabase/migrations` (tracked in `supabase_migrations.schema_migrations`, like the CLI), the seed, and local-only sample data; a `tools` service runs Deno tasks; `deno task smoke` checks sign-up → profile → `recommend` end to end. Why: one command for collaborators, real RLS/auth/functions instead of stubs (reliable), no cloud cost. Production stays hosted Supabase (ADR-002); compose is not a deploy target. Undo: `supabase start` uses the same ports and folders.
- 2026-10-19 · **Feedback is one Postgres function** (`record_feedback`, security invoker so RLS applies), called via PostgREST `/rest/v1/rpc/record_feedback`. It updates `user_experiences` and logs the MVP event in one transaction; interested/not-interested clear each other, rating requires done, undone clears the rating. Why: atomic, no extra Edge Function, testable in PGlite (reliable, low cost). Undo: move the logic to an Edge Function.
- 2026-10-19 · **iOS app foundation:** minimum iOS 17 (Observation, scroll APIs; matches ExperienceCore), app target in Swift 5 language mode (MapLibre delegates; ExperienceCore stays Swift 6). Dependencies: MapLibre 6.31.0 (exact), supabase-swift 2.55+ (auth session/refresh/keychain, PostgREST). Debug builds use `LOCAL_BACKEND` → `http://localhost:54321` with an auto-created email account; Release uses Sign in with Apple. `CoreLoopTests` (XCUITest) walks onboarding → ask → results against Docker and attaches screenshots. Why: fastest path to a working loop with real data (flexible). Undo: swap supabase-swift for our own auth in ExperienceCore.
- 2026-10-19 · **Data model v2 (ADR-011):** links, dated occurrences, `kind`/`subcategory`/`slug` on experiences, `recommendation_items`, profile handles, and `friendships`/`groups`/`group_members` tables with RLS (social stays "not building yet" in the UI). Additive migration; PGlite tests cover the new RLS.
- 2026-10-19 · **Bulk catalog harvest** (`tools/catalog/harvest.ts`): one Claude call per topic in `catalog/<city>/_topics.txt` with web search (≤30 searches), ~15-20 entries per topic, resumable, spend tracked in `_harvest.json` with a `--budget` cap. Model: **Sonnet 5.5** by default (pilot: same quality as Opus 5.5 at ~$1.00 vs $1.65 per topic). Geocoding via Nominatim (`tools/catalog/geocode.ts`, 1 req/s, cached, bounded to the city). Every harvested fact is `estimated`; production publishes only reviewed entries, the local Docker stack publishes drafts (`LOCAL_PUBLISH_DRAFTS`). Undo: delete the drafts; the reviewed flow is unchanged.
- 2026-10-19 · **Location, asked in context:** when-in-use permission is requested on the first "Find 3 things"; the coordinate goes only with recommendation requests (travel time + distance penalty server-side). The app shows the user dot, "~N min (estimated)" on cards and Explore rows, and sorts Explore closest-first. Same rough estimate as the recommender (walk < 1.2 km, else drive/transit). Undo: drop `constraints.location`.
- 2026-10-19 · **Capture-first (ADR-012):** after setup the app opens to the camera (AVFoundation: tap = photo, hold = video ≤ 60 s, pinch / slide-up zoom, lens presets, tap-to-focus, double-tap flip, flash). Review → "Where was this?" (nearest catalog Experiences) → `captures` row + marked done → pillar. Media stays in the app's documents folder; only metadata goes to the server, no coordinates. Mic is requested on first video. Local builds get a "test photo" on the Simulator's no-camera screen. Device runs use `ios/Config/Local.xcconfig` (gitignored) for the Mac's LAN address and signing team.
- 2026-10-20 · **Refounded on `EXPERIENCES_PRODUCT.md` (ADR-013).** Experiences is a personal life archive: one Experience object from Want to Planned to Experienced, private by default, Private/Friends/Public, Stages 0-2 in scope. Supersedes the city-first strategy. CLAUDE.md, MVP.md, ARCHITECTURE.md, ADR index, DESIGN.md (banner), README and EXPERIENCE/COMPETITIVE_RESEARCH (marked historical) updated. Existing code carries over as inputs. Undo: supersede ADR-013.
