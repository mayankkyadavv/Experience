# MVP: current requirements

This is the scope for the friends TestFlight build. If a feature isn't here, it's out of scope. Precedence is in CLAUDE.md (ADRs > Eng Review ledger > this file > the design doc's Phase 1 section > BUILD_PLAN > EXPERIENCE.md). Ledger IDs (R1-R18, D2-D5) refer to the Eng Review ledger at the end of `docs/designs/experience-mvp.md`.

## Audience and gates

- **Who:** the founder's friends, one friend group first, via TestFlight (D5 / R18).
- **Expansion gate:** friends keep sharing reels to the app. The threshold isn't set yet. Share events are logged from day one to measure it.
- **Before any wider rollout:** the Gate 2 metrics from the design doc (done-rate per active user, with at least 20 active users) still apply.

## The demo loop (build this first)

```
Share reel → "Saved" instantly → identified in the background (place + activity + confidence)
→ "My Saves" feed (vertical swipe, live mini-map on top) → Go (directions) / Did it
Unsure → one question. Unresolved → "Needs a place" queue.
```

## In scope

### Capture
- **Share extension** accepts Instagram, TikTok and YouTube links. It pulls the first URL out of shared text (R12). Any other link shows "Experience works with Instagram, TikTok and YouTube for now" and isn't saved.
- **Outbox first, never lose a save** (R1, ADR-007): write to the App Group outbox with a client-generated `save_id` *before* uploading, show "Saved" immediately, retry until the server confirms. Unique `(user_id, save_id)` on `sources`, so retries never duplicate.
- **Instagram is URL-only** (ADR-004). The extension shows one skippable "What place is this?" field using on-device `MKLocalSearchCompleter` (R13). The chosen name and coordinates are stored as a `user` hint. Any platform without legally usable metadata uses the same flow (R7e).
- **Share before sign-in:** queue it and show "Open Experience to finish setup". Queued saves are processed right after sign-in.
- **Main app outbox sync:** retries in the background and on launch, with a "Syncing N saves" banner while the outbox isn't empty.
- **Auth:** Sign in with Apple via Supabase. Only the main app refreshes tokens; the extension uses a valid access token or just queues (R4).

### Identify
- **Queued jobs** (R2, R15): the insert trigger calls `identify` immediately, `pg_cron` retries, 3 attempts with backoff, then `needs_review`. Never a silent loss.
- **Pipeline** (ADR-005): the server resolves short links → legally usable metadata only (ADR-004) → Claude structured extraction → place search (Apple Maps, ADR-003) → Experiences with confidence and evidence.
- **Extraction returns the activity, not just the place** (ADR-006): title (the activity in words), intent, category, location requirement, place candidates, evidence quotes, confidence. Candidates are stored (`identification_candidates`).
- **One post → how many Experiences:** things you'd do separately become separate Experiences ("top 5 bars" → 5, grouped as "5 places from this reel" by `source_id`). Alternative places for the same activity become one Experience with candidate places.
- **Auto-pin** at confidence ≥ 0.8 with a solid place match (a default, tuned from the eval, R7b). Below that, ask one question.
- **Identify per save** (R3 reversed): no cross-user cache.
- **Edge cases:** chains (brand + "multiple locations"; the nearest branch is resolved at runtime, R5), private or deleted posts ("Post unavailable" + the place question), no fixed venue (`location_requirement: none`).
- **Retry safety:** `identify` writes a source's Experiences and marks its job done in one transaction. If the source already has Experiences, a retry doesn't create more. Retries never overwrite `user`-provenance fields.

### Experience behavior by location requirement (ADR-006)

| | exact | flexible | none (an "idea") |
|---|---|---|---|
| Feed card / mini-map | Pans to the primary place. With no place resolved yet: card says "Location not confirmed yet", no pin | With a primary place: pans to it, card adds "or similar". With no primary place (candidates or not): card shows the activity, map shows your area, no pin | Card shows the activity, no pin |
| Go | Directions to the primary place (hidden until resolved) | Directions to the primary place if one exists, otherwise hidden | Hidden |
| Map tab | Yes, once resolved | Only with a primary place | No |
| "Needs a place" | Yes, if no place resolved or confidence is low | Never | Never |
| Reminders (M8) | Eligible | Not in MVP | Never |

The location requirement is itself an estimate. If its confidence is low, the one-question sheet asks before routing ("Is this a specific place?"). The user can always change it later. The look of both goes to the D4 design pass.

### Show
- **"My Saves" feed:** vertical swipe of your own saves with a live mini-map that pans per card (faint pins for nearby saves, dashed pin for done). At most 3 live web views (previous / current / next, R9). Embed vs. static card + tap-to-play per the M0 spike, with per-platform fallback placeholders. Videos only via official embeds.
- **Overlay:** title, place, neighborhood, distance, category and other fields, **all rendered through `SourcedText`** (R8). Estimates are labelled "(estimated)", never shown as fact.
- **Actions:** **Go** and **Did it**.
- **Map tab:** browse, open, edit, delete.
- **"Needs a place" queue** with a badge. Resolve via autocomplete. "Not a place" turns it into an idea (`none`). The question is pushed at most once.
- **Empty, loading and error states** for every screen.

### Push (M6)
- APNs from Edge Functions, device tokens table (R11).
- The low-confidence question is sent only within 5 minutes of the user's own share. Later than that → queue only, no push (R7a).

### Location and local/travel tagging
- Ask for **When In Use** on first launch. "Always" only later, for M8 reminders.
- **Home area** (for the wedge decision): one coarse (~1 km) cell per user per day, kept 30 days, deleted by `pg_cron` and with the account. The home area is the cell seen on the most distinct days (ties → most recent), established after 3 distinct days.
- At identification, each Experience is tagged `local` (primary place ≤ 50 km from the home cell's centre), `travel` (> 50 km), or `unknown`. When the home area is first established, `unknown` tags are backfilled once. Set tags are never recomputed.

### Events (from day one)
`share_started`, `share_saved`, `question_shown` / `question_answered` / `question_skipped` (with duration), `review_resolved`, `correction`, `feed_card_viewed` (≥ 2 s), `go_tapped`, `did_it` (R7c). Later with M8: `reminder_sent/opened`, `digest_sent/opened`.

### Privacy and TestFlight (M7)
- Server stores: account, saves (URL + extracted fields), corrections, event logs, and the coarse home-area cells above. Precise location and geofences stay on the device.
- In-app account deletion removes everything, logs included, within 30 days. Logs kept at most 12 months (R7d).
- The privacy policy and one-screen tester consent name the LLM provider and the places provider as processors, and state the coarse-location rule exactly.
- Location usage strings for When In Use (and Always, later).
- Supabase Pro on the day of the first TestFlight build (R16).

### Quality bar (D4 / R10)
- Design pass before building screens.
- Snapshot tests for every state (loading / empty / error / success × light / dark × default / largest Dynamic Type).
- `/qa` on a real iPhone before each TestFlight build.

## After friends are sharing (M8, not before)

Nearby reminders (geofences, R5), the weekly digest, the shared notification cap (≤ 1/day, ≤ 3/week, never 10pm-9am, R6), Did-it attribution (last touchpoint within 7 days, otherwise organic).

## Not in the MVP

Even though competitors have them:
- Itinerary or trip generation, day planning
- Friends, followers, social feed, comments, shared lists
- Group planning (first priority *after* the MVP)
- Onboarding interest quizzes; recommendations or "discover" for users with no saves
- Booking, reservations, hotels, flights
- Creator or business features, gamification
- Android, web app, bulk import of Instagram/TikTok exports
- The preference graph, person → destination (vision only, see EXPERIENCE.md)

**Feature filter for anything new:** (1) Does it serve the demo loop or the expansion gate? (2) Would it still be useful if the user weren't traveling? A "no" to (1) means not now. A "no" to (2) needs an explicit reason.

## Metrics

- **North star:** experiences marked done per active user per month.
- **Expansion signal:** friends who keep sharing (share events per friend per week).
- **Identification:** TikTok/YouTube ≥ 70% need no correction; Instagram ≥ 80% resolved by the inline question in < 10 s.
- **Habit:** saves per active user per week through week 4.

## Wedge: travel or local

The app accepts everything and builds nothing travel-only. Every Experience stores a category from this fixed list:

`restaurant, cafe, bar, nightlife, dessert, outdoors, attraction, activity, arts_culture, shopping, event, lodging, other`

It also stores the `local` / `travel` / `unknown` tag. **Review point:** after 4 weeks of friend use, or 30 dones (whichever comes first), compare the share of saves and dones that are local vs. travel, and by category. The founder makes the call from that data.

## Open decisions (founder)

1. **No-download rule vs. richer extraction:** for **local research only**, allowed by ADR-008 (TikTok/YouTube, temp files deleted every run). For the shipped app it is still open; default: keep the rule.
2. **Card headline:** the activity ("Drive a race car on a real circuit") or the place name? (D4 design pass.)
3. **Alternative interpretations:** does the question sheet offer interpretations or only places? (D4 design pass.)
4. Expansion-gate threshold, minimum iOS version, final name.
