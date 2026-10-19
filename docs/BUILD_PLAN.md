# Build Plan: Experience MVP (friends build)

Last updated 2026-10-18 (realigned after the Rhyme discovery). Check off tasks as you go and add decisions to the log at the bottom. Scope is in `docs/MVP.md`; how things are built is in `docs/ARCHITECTURE.md` and `docs/ADR/`.

**Goal:** a TestFlight build the founder's friends use. The demo loop comes first: share → identify → feed with mini-map → map → Did it. Everything else waits until friends are sharing.

## Prerequisites (the founder does these; agents should not install them)

- [ ] **Install Xcode** from the Mac App Store, then `sudo xcode-select -s /Applications/Xcode.app`. As of 2026-10-18 only the Command Line Tools are installed, so `xcodebuild` fails ("requires Xcode").
- [ ] Apple Developer Program account ($99/yr): needed for the App Group, share extension provisioning, Sign in with Apple, APNs and TestFlight.
- [ ] `brew install xcodegen supabase/tap/supabase deno`
- [ ] A Supabase account (free tier to start) and an Anthropic API key. Keep keys in local, untracked env files.
- [ ] Optional: the `gh` CLI for PRs.

## Milestones

### M0: Phase 0 spikes (1-2 days, throwaway code in `spikes/`)
- [ ] **Share payloads (day 1):** log exactly what Instagram, TikTok and YouTube hand a share extension on a real iPhone (URL vs. text with URL inside, `vm.tiktok.com` short links). → `docs/platforms.md`
- [ ] **Platform metadata matrix:** for 30 of the founder's saves (10 per platform), record what the official endpoints legally return (oEmbed fields, title, caption, author, thumbnail) and whether the place is identifiable from that + place search + at most one question. → `docs/platforms.md`
- [ ] **Terms check:** may oEmbed responses be used as extraction input? Instagram is "no" until confirmed.
- [ ] **Places provider:** Apple Maps vs. Google Places on the 30 reels (match rate, caching terms, cost). Default to Apple Maps.
- [ ] **Embed feed spike:** a SwiftUI vertical pager of 20 real official embeds (WKWebView, max 3 live). Measure first-frame time, smoothness, autoplay and memory. Decide autoplay embed vs. static card + tap-to-play.
- [ ] **Geofence spike:** 1 day on a real device with `CLLocationManager.startMonitoring(for:)` at a 200 m radius.
- [ ] **Rhyme gap hunt (founder):** 15 of your own saves (8+ local or non-travel) through Rhyme and `spikes/identify`; 2 friends do 5 each. Per save, record: place correct (y/n), activity correct (y/n), and what you wished for. Observed gaps go into `docs/COMPETITIVE_RESEARCH.md`. (The spike handles any reel with a caption or title; it doesn't yet output the activity, so judge the activity from Rhyme's result and your own expectation.)

### M1: Skeleton
- [ ] Monorepo layout: `ios/` (XcodeGen `project.yml`: app target + share extension target, shared App Group + keychain group), `ios/Packages/ExperienceCore/` (SPM), `supabase/` (migrations, functions).
- [ ] Supabase project, Sign in with Apple, schema + owner-only RLS per ADR-006: `sources` (unique `(user_id, save_id)`), `experiences` (`source_id`, Sourced `title/intent/category/location_requirement`, `status` in saved/done/dismissed/needs_review, `local_tag`), `experience_places`, `places` (shared cache, client read-only), `jobs`, `events`, `home_cells`, `device_tokens`, `notification_log`. (`identification_candidates` lands in M3.)
- [ ] Test setup: Swift Testing, swift-snapshot-testing, Deno test. CI: GitHub Actions running package tests + Deno tests.
- [ ] **UI gate (D4):** run a design pass on the screens below before building them (`/plan-design-review`, or `/design-consultation` to create a `DESIGN.md`). Keep it short; the founder wants to be building.

### M2: Capture
- [ ] Share extension: pull the first URL out of the payload; reject unsupported links with a friendly message; write to the App Group outbox **before** upload; show "Saved" right away; Instagram gets the "What place is this?" field (MKLocalSearchCompleter, skippable).
- [ ] Outbox sync in the main app: retry in the background and on launch; idempotent `save_id`; "Syncing N saves" banner.
- [ ] Share before sign-in: queue it and show "Open Experience to finish setup."
- [ ] Event logging from day one: `share_started`, `share_saved`, plus the rest of the event list in the design doc (ledger R7c). This measures the expansion gate.

### M3: Identify
- [ ] Insert trigger → `identify` Edge Function (first attempt immediately); cron retries; 3 attempts with backoff, then `needs_review`.
- [ ] Server resolves redirects for short links; metadata (only where legal) → Claude extraction → place search → Experience with confidence; auto-pin at ≥ 0.8 (default, tune later).
- [ ] Extraction returns the activity, not just the place (ADR-006): title, intent, category (fixed list in MVP.md), location requirement, candidates with evidence → `identification_candidates`. Writes happen in one transaction with job completion; retries never duplicate and never overwrite `user` fields.
- [ ] Edge cases: separate things to do → separate Experiences grouped by `source_id`; alternative places for the same thing → candidates of one Experience; no fixed venue (`none`); chains (brand + nearest branch at runtime); private/deleted posts.
- [ ] Local/travel tag at identification (home area per MVP.md; one-time backfill when the home area is established).
- [ ] Identification eval on the 30 Phase 0 reels: place (≥ 70% TikTok/YouTube), activity-correct, Experience count, category, calibration.

### M4: The demo screen ("My Saves" feed)
- [ ] Vertical feed of your own saves with a live mini-map (pans per card; faint pins for nearby saves; dashed pin for done).
- [ ] Overlay: place, neighborhood, distance, category, `SourcedText` fields; actions **Go** and **Did it**.
- [ ] Embed handling per the M0 spike result; 3 live web views max; per-platform fallback card with placeholders.
- [ ] Snapshot tests for every state.

### M5: Map + review queue
- [ ] Map tab: browse, open, edit, delete.
- [ ] "Needs a place" queue with badge: resolve via autocomplete, "Not a place" → idea.

### M6: Push
- [ ] APNs key, device token registration, sending from Edge Functions.
- [ ] Low-confidence question within 5 minutes of a share (later than that → queue only, no push).

### M7: TestFlight to friends
- [ ] Privacy policy URL, tester consent screen, location usage strings, in-app account deletion (deletes everything, including logs; names the LLM and places providers as processors).
- [ ] Upgrade Supabase to Pro. `/qa` on a real iPhone. Ship to the first friend group.

### M8: After friends are sharing
- [ ] Nearby reminders (When In Use first, Always after the 3rd resolved save; 20 nearest regions; re-rank on significant location change).
- [ ] Weekly digest (Thursday 6pm), notification cap (device logs each reminder to `notification_log`; the digest checks it first).
- [ ] Did-it attribution (last touchpoint within 7 days, otherwise organic).

## Open items (decide while building, not before)
- Expansion-gate threshold (how many friends sharing, for how long).
- Minimum iOS version.
- Final product name ("Experience" is hard to trademark or search for).
- Card headline: the activity or the place name; whether the question sheet offers alternative interpretations (D4 design pass).
- No-download rule vs. transcript/video-vision extraction (founder; default: keep the rule).
- Travel vs. local wedge (founder, at the MVP.md review point).

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
