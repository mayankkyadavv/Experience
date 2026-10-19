# MVP: current requirements

This is the scope for the **Philadelphia beta** build. If a feature isn't here, it's out of scope. Precedence is in CLAUDE.md (ADRs > Eng Review ledger > this file > the design doc's Phase 1 section > BUILD_PLAN > EXPERIENCE.md). Ledger IDs (R1-R18, D2-D5) refer to the Eng Review ledger at the end of `docs/designs/experience-mvp.md`.

> **Updated 2026-10-18 for the city-first strategy** (`docs/EXPERIENCE.md`). The previous MVP centered on share-reel → identify → "My Saves" feed → Did it. Capture and identification carry over as the input layer; the center is now **"What should we do?"**. The detailed 30-day plan and the technical architecture for this scope are the next phase. Items marked **[founder]** in "Open decisions" are unresolved.

## The hypothesis

> **When people don't know what to do, will they open Experience?**

Build the smallest product that tests this. Strongest signal: someone in a group says "Check Experience."

## Audience and geography

- **City:** Philadelphia only, for content and dogfooding. The founder uses it for real plans every week.
- **Users:** the founder, then friends and early users in Philadelphia, via TestFlight (R18's "build the loop first" still applies).
- **Architecture stays multi-city:** City is an explicit domain concept/configuration. Nothing Philadelphia-specific is hardcoded. The UI may label it "Philadelphia (beta)".
- **Next market (not now):** New York City, once the core behavior is validated (EXPERIENCE.md).

## The core loop (build this first)

```
Open → "What should we do?" → a few constraints (when, how long, budget, who, optional mood)
→ 3 strong recommendations → Interested / Not interested / Save
→ go → Did it → rate → better recommendations next time
```

The input loop that feeds it:

```
Share a TikTok → "Saved" instantly → identified in the background
→ matched to (or added as) an Experience → saved to your list → shapes your taste and recommendations
```

## In scope

### Account and onboarding
- **Sign in with Apple** via Supabase (ADR-002). Only the main app refreshes tokens (R4).
- **Lightweight preference onboarding** to solve cold start: a short, skippable set of choices (kinds of things you like, typical budget, who you usually go out with). Fast, never a long quiz. Answers seed the taste profile; behavior refines it.

### The Experience catalog (Philadelphia)
- **Seed several hundred high-quality Philadelphia Experiences.** Quality and diversity over coverage.
- Each Experience is an activity (ADR-006), with the data recommendations need: title, category, description, place(s) or area, neighborhood, approximate price per person, typical duration, good-for (solo, date, friends, groups, family), hours or dates, and source/provenance. Exact fields are set in the architecture phase.
- Coverage targets (a mix, not quotas): food, date ideas, friend-group activities, active/adventure, nightlife, creative, culture, seasonal, outdoors, sports, classes, unusual/unique, free/cheap. "Dates" and "friend groups" are **occasions (tags), not categories**.
- **Browse** the catalog (by category, occasion, price, neighborhood).

### "What should we do?" (the center of the app)
- One prominent entry point on the home screen.
- Minimal constraints: **When?** (now, tonight, a day, this weekend) · **How long?** · **Budget?** (free, under $25 / $50 / $100, no preference) · **Who?** (just me, partner, friends, group, family) · optional **mood** (chill, active, food, creative, nightlife, outdoors, something new, surprise me).
- Returns **three** strong recommendations, each with why it fits (stated honestly, provenance shown), price, duration, distance and whether it's open then.
- Filters out what doesn't fit (closed at that time, over budget, too long, too far). Ranks by the taste profile, saves and past feedback. The engine design is set in the architecture phase; no large recommendation infrastructure in the MVP.
- "Who?" is a descriptor in the MVP (it shapes the recommendation). Multi-user groups with merged taste profiles are later.

### Feedback (every recommendation and Experience)
- **Interested · Not interested · Save · Did it · Rating** (after Did it).
- All of it feeds the user's taste profile and future recommendations.

### My Experiences
- Your saved and done Experiences, from the catalog or from shared TikToks. Mark done, rate, remove.
- Saved Experiences are preferred candidates in "What should we do?" ("you saved this three weeks ago").

### Capture (social ingestion stays in the MVP)
- **TikTok first.** Founder decision (2026-10-18): the app supports TikTok links at launch; Instagram (URL-only, ADR-004) and YouTube follow, and their rules below stay in force when they're added. Other links show a friendly "Experience works with TikTok for now" and aren't saved.
- **Share extension** pulls the first URL out of shared text (R12).
- **Outbox first, never lose a save** (R1, ADR-007): write to the App Group outbox with a client-generated `save_id` *before* uploading, show "Saved" immediately, retry until the server confirms. Unique `(user_id, save_id)` on `sources`.
- **Share before sign-in:** queue it and show "Open Experience to finish setup".
- **Main app outbox sync** with a "Syncing N saves" banner while the outbox isn't empty.

### Identify
- **Queued jobs** (R2, R15): the insert trigger calls `identify` immediately, `pg_cron` retries, 3 attempts with backoff, then `needs_review`. Never a silent loss.
- **Pipeline** (ADR-005): resolve short links → legally usable metadata only (ADR-004) → Claude structured extraction → place search (Apple Maps, ADR-003).
- **Extract the activity, not just the place** (ADR-006): title (the activity in words), intent, category, location requirement, place candidates, evidence, confidence; plus, where the post supports it, approximate price, duration and group fit. Don't assume one post = one place.
- **Create or match:** a shared post is matched to an existing catalog Experience when it's the same activity, otherwise it becomes a new Experience for that user (ADR-009, proposed; matching rules set in the architecture phase).
- **One post → several Experiences** when it shows separate things to do ("top 5 bars" → 5, grouped by `source_id`). Alternative places for the same activity are candidates of one Experience.
- **Unsure → one question** in the share extension; unresolved saves go to a short "Needs a place" list. Auto-resolve at confidence ≥ 0.8 with a solid place match (default, tuned by the eval, R7b).
- **Edge cases:** chains (brand + nearest branch at runtime, R5), private or deleted posts ("Post unavailable" + the place question), no fixed venue (`location_requirement: none`), places outside Philadelphia (saved and shown, but not recommended until their city is supported).
- **Retry safety:** writes and job completion happen in one transaction; retries never duplicate and never overwrite `user`-provenance fields.

### Provenance (unchanged)
Every displayed field shows where it came from (`Sourced<T>`, rendered only through `SourcedText`, R8). AI estimates are labelled "(estimated)" and never shown as fact. This includes recommendation reasons: never claim "your friends loved this" or similar without the data.

### Events (from day one)
Capture: `share_started`, `share_saved`, `question_shown` / `question_answered` / `question_skipped` (with duration), `review_resolved`, `correction`.
Recommend: `recommend_opened` (with constraints), `recommendation_shown`, `interested`, `not_interested`, `saved`, `did_it` (with whether it came from a recommendation), `rated`, `onboarding_completed` / `onboarding_skipped`, `experience_viewed`. Final names are set in the architecture phase.

### Privacy and TestFlight
- Server stores: account, preferences and taste signals, saves (URL + extracted fields), feedback and ratings, event logs. Precise location stays on the device unless a feature needs it and says so; recommendations use the location the user is at when they ask.
- In-app account deletion removes everything, logs included, within 30 days. Logs kept at most 12 months (R7d).
- The privacy policy and tester consent name the LLM provider and the places provider as processors.
- Supabase Pro on the day of the first TestFlight build (R16).

### Quality bar (D4 / R10)
- Design pass before building screens; the "What should we do?" flow and recommendation cards come first.
- Empty, loading and error states for every screen. Snapshot tests for every state (loading / empty / error / success × light / dark × default / largest Dynamic Type).
- `/qa` on a real iPhone before each TestFlight build.

## Not in the MVP

Unless separately approved:
- Social feed, friends/followers, comments, messaging, real-time friend location
- Multi-user groups with merged preferences; advanced group optimization
- Plans as a feature (multi-stop itineraries); complete itinerary generation
- Public Plan marketplace, creator monetization, sponsored placements
- City leaderboards, complex achievements, exploration percentages
- Worldwide or multi-city content; travel booking, flights, hotels
- Massive recommendation infrastructure, complex graph databases
- Instagram and YouTube capture (follow after TikTok); Android, web app, bulk import of exports

**Feature filter for anything new:** (1) Does it help someone decide what to do and go do it, or teach Experience what they like? (2) Is it useful in an ordinary week in the city, not just on a trip? (3) Does it avoid locking the core into Philadelphia, travel, restaurants, solo users, or places instead of experiences? A "no" to (1) means not now.

## Metrics

Downloads are not the measure.
- **Activation:** can a new user get a recommendation that feels relevant within their first session?
- **Recommendation quality:** share of recommendations marked Interested or Saved; Not-interested rate.
- **Real-world conversion:** recommended Experiences marked Did it.
- **Repeat:** users who come back the next time they don't know what to do (weeks with a "What should we do?" session per active user).
- **Taste improvement:** acceptance rate rising as users save, rate and complete.
- **Social pull:** users who invite friends.
- **Capture:** TikTok identifications needing no correction ≥ 70%.
- **North star (proposed, [founder]):** recommended Experiences marked done per active user per month.

## Open decisions

1. **[founder] Seed catalog sourcing:** who curates the several hundred Philadelphia Experiences, from which sources, and under which licenses. Place data must follow provider terms (no scraping Google/Yelp). Default proposal: founder-curated with AI-assisted drafting, places resolved via Apple Maps, every field provenance-tagged.
2. **[founder] What happens to the "My Saves" video feed** (vertical swipe with a live mini-map, the old demo screen): keep it as the "My Experiences" view, or defer it. The interrupted design pass was built around it.
3. **[founder] Is a map in the MVP**, and what does it show (want to do / done)?
4. **[founder] North star** (proposal above) and the beta audience size before NYC prep.
5. **[founder] Ratings:** a simple scale, or Beli-style comparisons?
6. Category taxonomy update (architecture phase): the old fixed list (`restaurant, cafe, bar, nightlife, dessert, outdoors, attraction, activity, arts_culture, shopping, event, lodging, other`) lacks classes, sports and entertainment; occasions become tags.
7. Carried over: no-download rule for the shipped app (default: keep, ADR-004/008); minimum iOS version; final name.

**Resolved by this update:** the travel-vs-local wedge (now local, city-first; the `local`/`travel` tag and home-area tracking are no longer needed for that decision); "onboarding interest quizzes" and "recommendations for users with no saves" move from out of scope to in scope (lightweight, as above).
