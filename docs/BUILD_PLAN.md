# Build Plan: Experience MVP (friends build)

Last updated 2026-10-18, at the end of planning (office hours + eng review). Check off tasks as you go and add decisions to the log at the bottom.

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

### M1: Skeleton
- [ ] Monorepo layout: `ios/` (XcodeGen `project.yml`: app target + share extension target, shared App Group + keychain group), `ios/Packages/ExperienceCore/` (SPM), `supabase/` (migrations, functions).
- [ ] Supabase project, Sign in with Apple, schema + RLS: `experiences` (with `save_id` unique per user, `status` in saved/done/dismissed/needs_review, `source_group_id`), per-field provenance, `jobs`, `events`, `device_tokens`, `notification_log`.
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
- [ ] Edge cases: several places in one post (one Experience each, grouped), no fixed venue (location-less "idea"), chains (brand + nearest branch), private/deleted posts.
- [ ] Identification eval on the 30 Phase 0 reels.

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

## Decisions made during build
<!-- Append: date, decision, why (flexible / reliable / low cost), how to undo. -->
- 2026-10-18 · Identification spike (`spikes/identify/`) is TypeScript run directly by Node (no build step). Why: the real `identify` Edge Function is TypeScript on Deno, so the extraction and place-search code ports almost unchanged (flexible). Undo: rewrite the spike; it's throwaway.
- 2026-10-18 · Extraction uses `claude-opus-5-5` via the Anthropic SDK with structured outputs (Zod schema), effort `medium`, and server-side `fallbacks: "default"` so a policy decline is retried on another model. Why: reliable JSON with no parsing code, and medium effort keeps cost per save low. Undo: change `MODEL` / effort in `extract.ts`.
- 2026-10-18 · Spike place search falls back to OpenStreetMap Nominatim when no Apple Maps token is set. Why: free and needs no key or developer account, so the spike runs before the Apple Developer account exists. Not for production (1 request/second, attribution required). Undo: set `APPLE_MAPS_AUTH_TOKEN`.
