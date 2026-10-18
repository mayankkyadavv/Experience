# Experience — Product Brief

Oct 18, 2026 · @Someone

## How to use this doc

This is the single source of truth for what Experience is, what the MVP includes, and what it deliberately excludes. Humans: read the pitch and thesis, then skim the rest. Coding agents: treat the MVP scope, data model, technical constraints, and "What not to build yet" sections as requirements; when a task conflicts with them, flag it instead of building it.

"Experience" is a working name and may change.

## The pitch

**Experience turns the things people want to do into things they actually do.**

The 30-second version: people discover what they want to do through TikToks, Reels, and Shorts, then save them and forget. With Experience, you tap Share on any video and it figures out what the activity is and where it happened, then pins it on your personal map. Over time you build a backlog of everything you want to experience, from a bar ten minutes away to paragliding in Switzerland. Experience reminds you when you're near something you saved, helps you plan trips around things you already want to do, and eventually helps groups agree on what to do together.

## The problem

Discovery has moved to short-form video, but those platforms are built for consumption, not action. A 20-second clip conveys what an experience actually feels like (the food, the crowd, the view) better than star ratings, written reviews, or professional photos. Traditional platforms like Booking.com and TripAdvisor are reading-heavy and feel staged, which lowers trust with younger users.

The result is a broken loop: **see → save → forget**. A saved Reel doesn't say where it was filmed, what business it shows, what it costs, or how it fits an upcoming trip. Inspiration piles up across saved folders, screenshots, group chats, and Notes, and the sheer volume causes decision paralysis rather than action.

The loop Experience aims to create: **see → share → understand → organize → plan → do**.

## Thesis: a life backlog, not a travel planner

Experience is a backlog of everything a person wants to experience in their life, and travel is only one slice of it. The common thread is a single moment: someone saw something and thought, "I want to do that." That could be a restaurant five minutes away, a concert next month, a hike this weekend, or a trip to Japan someday.

This framing is the core strategic bet. People travel one to three times a year, so trip-focused apps get used in bursts and then forgotten. Local experiences happen every week. A product that covers both is opened weekly, which is what makes retention, preference learning, and nearby reminders work.

Experience starts earlier than booking and review platforms. Those serve people who already know where they're going. Experience owns the step before that: turning scattered inspiration into intent.

## Competitive landscape

The "share a reel, get places on a map" feature is already table stakes: at least four apps ship it today. Experience cannot win on capture alone; capture is the onboarding mechanism, not the product.

| App | What it does | Focus |
| --- | --- | --- |
| [Venturr](https://www.mergeek.com/latest/4QVoNnzBzzjn7vKD) | Extracts places from TikTok, Reels, YouTube, and screenshots using audio, captions, and on-screen content; clusters and routes into day plans | Trip planning |
| [Rhyme (formerly Roamy)](https://apps.apple.com/sa/app/id6748781672) | One-tap import from TikTok/Instagram onto a map; iPhone only | Trip planning |
| [Triply](https://www.producthunt.com/products/triply-3/makers) | Image analysis, transcription, caption parsing, and geotags to pin every place in a video; collections | Trip planning |
| [glide](https://mwm.ai/apps/glide-organize-plan/6755294996) | AI layer over Instagram saves; adds pricing, menu, and vibe details; map view | City exploring |

**Where Experience differs:**

- **Weekly, not yearly.** Competitors are framed around trips. Experience covers local, everyday experiences too, which drives habitual use.
- **Built around doing, not saving.** Competitors stop at an organized map. Experience measures and drives completion through "Did it" tracking and nearby reminders.
- **Aggregate signal.** When many young users save the same spot, that is a more trusted recommendation than any star rating. This network data compounds with every user and is hard to copy.
- **Groups.** Overlapping saves across friends solve group decision paralysis, and each group invite brings in new users.

As of October 2026, based on public listings; this space moves fast, so recheck before pitching.

## Target user and beachhead

The core user is roughly 18–30, discovers things to do primarily through short-form video, and already has hundreds of saved posts they never act on.

"Young people" is too broad to launch with. The beachhead should be one dense group in one area, so that aggregate signal and group features become useful quickly. Candidates include college students in a single city, or recent grads in one metro area such as Philadelphia, New York, or Boston. The first 30–50 users can come from personal networks, ideally friend groups that make plans together.

## Core user flow

The primary interaction should feel as effortless as liking a video:

1. The user watches a Reel, TikTok, or Short in its native app.
2. They tap **Share → Experience** (or text the link to an Experience number).
3. Experience receives the URL and analyzes the content.
4. It identifies the activity and location, with a confidence score.
5. If confidence is low, it asks one quick question ("Is this Café X in Lisbon?").
6. A structured Experience is created and pinned to the user's map.
7. Later, a nearby reminder or trip plan brings it back, and the user marks it **Did it**.

The long-term loop extends this: save → learn preferences → recommend → plan → book → do → remember → discover again. Every stage should reinforce the others.

## MVP scope

The MVP answers one question: **will users keep sending content to Experience and actually go do some of it?** It has six capabilities.

1. **Receive.** Accept shared URLs from Instagram, TikTok, and YouTube through the mobile share sheet. A text-message or WhatsApp bot is an acceptable first ingestion path for validation, since it requires no app install. URL paste on web is a fallback.
2. **Understand.** Determine what the activity is, where it is, which business or place is shown, and its category. Use available signals: URL metadata, captions, hashtags, geotags, transcripts, visible text, and external place search. Always produce a confidence score.
3. **Confirm.** When confidence is low, ask the user one minimal question instead of guessing. Store every correction; it improves extraction over time.
4. **Save.** Convert the result into a structured Experience object (see Data model).
5. **Map.** Show saved experiences geographically. Users can browse by region, open an item, view the original source, edit, delete, and organize.
6. **Act.** Two features close the loop from saving to doing:
   - **Did it:** one tap to mark an experience as done. This is the strongest preference signal and the north-star metric.
   - **Nearby reminders:** geofenced notifications such as "You saved this 8 months ago, it's 0.4 miles away." Respect notification fatigue; cap frequency.

## Data model

Every field must record where its value came from. Values pulled from the source content are trustworthy; values looked up or estimated by AI (price, duration, hours) can be wrong and must be labeled as such in the UI. Showing invented details as fact would destroy the trust advantage over traditional platforms.

Illustrative shape (the real schema will evolve):

```json
{
  "id": "exp_123",
  "user_id": "usr_456",
  "title": "Paragliding in Interlaken",
  "category": "adventure",
  "location": {
    "place_name": null,
    "city": "Interlaken",
    "country": "Switzerland",
    "lat": 46.686,
    "lng": 7.863,
    "place_id": null
  },
  "fields": {
    "price": { "value": "~$150–250", "provenance": "estimated" },
    "duration": { "value": "2–3 hours", "provenance": "estimated" }
  },
  "source": { "platform": "instagram", "url": "https://...", "creator": "@handle" },
  "confidence": 0.91,
  "user_confirmed": false,
  "status": "saved",
  "saved_at": "2026-10-18T12:00:00Z",
  "done_at": null
}
```

Provenance values: `source` (from captions, geotag, transcript, or visuals), `lookup` (from a places database or search), `estimated` (AI inference), `user` (entered or corrected by the user). Status values: `saved`, `done`, `dismissed`.

## Technical constraints

**Never download or re-host platform videos.** Store the URL, the extracted metadata, and the user's notes. Display videos only through each platform's official embed. Re-hosting violates platform terms and creates copyright exposure, especially once content appears to other users in a future feed.

**Do not depend on fragile or prohibited scraping.** Before building ingestion, document per platform (Instagram, TikTok, YouTube) exactly what a shared URL reliably and legally provides: oEmbed data, captions, creator, geotag, thumbnail, transcript access, and rate limits.

**Degrade gracefully.** Ingestion follows a ladder:

1. Rich metadata available (caption, geotag, transcript) → identify automatically.
2. Partial metadata → combine AI extraction with external place search.
3. URL only → ask the user one minimal clarifying question.

**Ingestion paths.** The iOS share extension and Android share intent are the target. An SMS or WhatsApp bot is the fastest validation path; note that iMessage has no business-bot API, so the bot replies with a link to a web view of the map.

**Identification pipeline.** An agent-style pipeline that gathers signals, calls place-search tools, and returns a structured result with confidence works well here. Log every input, output, and user correction for evaluation.

## What not to build yet

None of the following belongs in the MVP unless it is required to validate the core behavior:

- Flight, hotel, or activity booking; restaurant reservations
- Full AI itinerary generation
- An in-app video feed, followers, comments, or messaging
- Group planning (first priority after MVP, but not in it)
- Creator monetization or business dashboards
- Sophisticated recommendation systems or gamification

The architecture should not be shaped around these. A clean Experience object with provenance and status is enough to support all of them later.

## Success metrics

The north star is **experiences marked done per active user per month**. Downloads and total saves are vanity metrics on their own: a user with 400 saves and zero visits got nothing from the product.

| Metric | What it tells us |
| --- | --- |
| Experiences marked done per active user per month | Whether Experience turns intent into action (north star) |
| Saves per active user per week | Whether capture is habitual |
| Week-4 saving retention | Whether saving survives after the novelty wears off |
| Identification accuracy (share of saves the user doesn't correct) | Whether the "magic" works |
| Nearby reminder → visit rate | Whether reminders drive real-world action |

If users save three videos and never return, more features will not fix it.

## Roadmap after MVP

Each phase starts only once the previous one shows real usage.

1. **Validation (weeks).** SMS/WhatsApp bot plus a bare web map, given to 20–30 friends. Gate: people keep sending links after week one and open the map when making plans.
2. **MVP.** Native share extension, full map, Did it, nearby reminders. Gate: healthy week-4 retention and done-rate in the beachhead group.
3. **Groups.** Shared trips or plans where friends' saves overlap: "Your group has 14 experiences in common." This is the main viral loop.
4. **Discovery feed.** A vertical feed of what others nearby are saving, built from official embeds, where the primary action is "I want to experience this." Requires user density in a city.
5. **Trip planning.** "I'm going to Japan March 10–18" produces an itinerary built from the user's own saves, accounting for geography, hours, cost, and travel time. Not a generic AI itinerary.
6. **Marketplace.** Saved experiences represent real purchase intent. Monetize through activity bookings, reservations, affiliate commissions, tickets, promoted experiences, creator partnerships, or premium planning.

## Product principles

- **Get people off their phones and into the world.** Optimize for time spent experiencing life, not time spent in the app.
- **Saving should be as easy as liking.** Every extra tap in capture is a lost save.
- **Honest over impressive.** Show confidence and provenance; ask rather than guess.
- **Learn from behavior, not questionnaires.** A user's saves are their onboarding.
- **Plan around what users already want.** Recommendations and itineraries start from demonstrated intent, not generic lists.
- **Use social platforms as the discovery layer.** Don't try to replace TikTok or Instagram; be where their content turns into action.

## Open questions

- [ ] What does each platform's shared URL reliably provide (oEmbed, captions, geotag, transcript), and what do their terms allow?
- [ ] Which beachhead: one college campus, or recent grads in one metro?
- [ ] Validation path first: SMS bot, WhatsApp bot, or go straight to an iOS share extension?
- [ ] Which places database to use for identification and coordinates, and at what cost per lookup?
- [ ] Final product name ("Experience" is hard to trademark, search, and get a domain for).
- [ ] Notification policy for nearby reminders: how often before it feels like spam?
