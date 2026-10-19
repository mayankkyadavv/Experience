# Competitive research

Living document. Update it whenever someone uses a competitor. Every factual claim needs a source link or the tag **[founder-observed]**. Never write a difference we haven't observed.

## Summary (2026-10-18)

- Share-reel-to-map is a crowded, validated category: at least 8 shipping apps.
- **Rhyme (formerly Roamy) is the closest and strongest competitor.** It covers capture, map, itineraries, group trips and discovery for travel.
- **We have no observed gap yet.** The founder ran their own saves through Rhyme: "it mostly worked" [founder-observed; number and type of reels not recorded]. Closing this is the M0 gap hunt (BUILD_PLAN).

## Rhyme (formerly Roamy)

Site: [rhyme.travel](https://www.rhyme.travel/) · App Store: [Rhyme (formerly Roamy)](https://apps.apple.com/us/app/6748781672)

| Field | What we know | Source |
|---|---|---|
| Core promise | "You save the spots. We'll handle the rest." Turns "saved social media posts into real trips." | [site](https://www.rhyme.travel/) |
| Target user | Travelers who save destinations from social media, solo or in groups. | [site](https://www.rhyme.travel/) |
| Onboarding | Long onboarding that mixes feature demos with personalization quizzes. | [screensdesign teardown](https://screensdesign.com/apps/roamy-save-spot-plan-trips/) |
| Social import | Instagram reels, TikTok, Google Maps links, screenshots, notes, web pages, manual entry. Extracts the location automatically. One teardown: 14 places from one Rome reel. | [site](https://www.rhyme.travel/), [screensdesign](https://screensdesign.com/apps/roamy-save-spot-plan-trips/) |
| Stored data model | Spots (places) organized into lists by city, vibe or trip. Place-centric; no sign of an activity/intent object. | [site](https://www.rhyme.travel/) (inferred from the UI copy) |
| Map experience | Live map of saved spots, filterable by list, category or trip. | [site](https://www.rhyme.travel/) |
| Recommendation quality | "Discover spots from friends and the nearby community." Quality untested by us. Founder brief says it recommends places even with no imports. | [site](https://www.rhyme.travel/); [founder-observed] |
| Planning quality | AI itinerary builder: pick destination, dates and lists, get a day-by-day optimized route. A teardown suggests power users want manual control of travel times and transport modes. | [site](https://www.rhyme.travel/), [App Store](https://apps.apple.com/us/app/6748781672), [screensdesign](https://screensdesign.com/apps/roamy-save-spot-plan-trips/) |
| Group functionality | "Plan together": invite friends; everyone adds must-see spots. | [site](https://www.rhyme.travel/) |
| Social functionality | Shareable lists; discovery from friends. | [site](https://www.rhyme.travel/) |
| Local / non-travel usefulness | Not addressed in its copy; every example is a trip ("travel wishlist"). "Nearby community" is the only local hint. **Not tested by us.** | [site](https://www.rhyme.travel/) |
| Personalization | Personalization quiz in onboarding. | [screensdesign](https://screensdesign.com/apps/roamy-save-spot-plan-trips/) |
| Monetization | In-app purchases with a paywall; price not published on the site. | [screensdesign](https://screensdesign.com/apps/roamy-save-spot-plan-trips/) |
| Platforms | iPhone only; Android waitlist. | [site](https://www.rhyme.travel/) |
| Strengths | Polished; capture works on the founder's saves; full capture → plan loop; group planning. | [founder-observed], [Substack review](https://nikmat.substack.com/p/roamy-your-instagram-saves-actually) |
| Weaknesses | Long onboarding (teardown). Nothing else observed yet. | [screensdesign](https://screensdesign.com/apps/roamy-save-spot-plan-trips/) |
| Missing functionality | Nothing observed yet. See below. | — |

### Things Rhyme cannot do that we genuinely wish it could

*Only observed items go here: a specific save, what Rhyme did, and what we wished for.*

(empty: the founder's test found no failure. Filled by the M0 gap hunt.)

### Hypotheses to test (not observed)

Each needs a real save as evidence before it moves to the list above.
- Local, non-travel saves (a bar in your city, a class) feel second-class in a trip-shaped app.
- It records *where* but not *what you wanted to do* (the activity behind the save, or a flexible location).
- Nothing brings a save back at the moment you could go (no nearby nudge, no "did it").
- Saves without a trip attached have nowhere natural to live.

## Other apps in the category

The list changed from the original brief: Venturr and YK aren't re-verified here, and Korka, Travio and Go There were added from this research. Claims are self-reported by each app.

| App | What it does | Focus | Source |
|---|---|---|---|
| Travio | Share a reel → exact spot, grouped by city → one-tap day-by-day trip | Trip planning | [listing](https://mwm.ai/apps/traviosave-plan-trips/6760474901) |
| Triply | Image analysis, audio transcription, captions, geotags to extract every place; collections | Trip planning | [PeerPush](https://peerpush.com/p/triply-ai-travel-planner) |
| GeoTok | Captions + on-screen text + transcript → venue, verified against TripAdvisor/Foursquare; $14.99/mo | Food | [Peerlist](https://peerlist.io/shalex/project/geotok--save-every-tiktok-worth-eating-at) |
| Korka | Restaurant saves from reels; 5 free imports, one-time purchase | Food | [App Store](https://apps.apple.com/app/id6762612703) |
| glide | AI layer over Instagram saves; pricing, menu, vibe; map | City exploring | [listing](https://mwm.ai/apps/glide-organize-plan/6755294996) |
| Go There | Forwarded DMs/links → Google Places-verified map | Indie, early | [Indie Hackers](https://www.indiehackers.com/post/i-kept-dming-myself-instagram-reels-i-never-visited-so-i-built-an-app-that-turns-them-into-a-map-d4e737ac1d) |
| Venturr | Places from audio, captions, on-screen content; day plans | Trip planning | [Mergeek](https://www.mergeek.com/latest/4QVoNnzBzzjn7vKD) (from the original brief, not re-verified) |

**Pattern:** almost everyone is trip-shaped or food-shaped. None publish visit or done rates.

## Research log

- **2026-10-18:** web research on Rhyme and the category (sources above). The founder reports Rhyme "mostly worked" on their saves.
