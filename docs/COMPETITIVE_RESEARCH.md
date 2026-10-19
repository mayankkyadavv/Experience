# Competitive research

Living document. Update it whenever someone uses a competitor. Every factual claim needs a source link or the tag **[founder-observed]**. Never write a difference we haven't observed.

## Summary (updated 2026-10-18, city-first)

- **The strategy moved** from social travel discovery to **"What should we do?"** for people living in a city (Philadelphia beta). So the competitive set widened: anyone who answers "what should I/we do around here?" (Google Maps, Beli, TikTok's Local feed, Fever, Eventbrite, group planners) now matters as much as reel-to-map apps.
- **Rhyme still owns social content → trip.** Experience's initial job is person/group + time + budget + taste + city → what to do. That difference is a positioning choice, not yet an observed advantage.
- **Strong incumbents now overlap the core question:** Google Maps' Gemini-powered Ask Maps (March 2026) answers conversational local questions personalized by your saves and searches; TikTok's Local feed (US, February 2026) surfaces nearby restaurants and events; Beli has taste profiles, friend scores and match scores for restaurants.
- **Group "decide what to do" apps exist but are small:** Cobble, Converge AI, TheChecklist, down?, Howbout (calendars). None verified as large.
- **We have no observed gap yet** for any of them. The founder ran their own saves through Rhyme: "it mostly worked" [founder-observed]. The M0 gap hunt should now also test the core question ("Friday, 4 people, $75 each, 5 hours in Philadelphia") on Google Maps Ask Maps, TikTok and Beli.

## The questions to answer for each competitor

What object do they organize around (places, restaurants, events, trips, activities, people)? What user problem do they own? How often can someone reasonably open it? What social functionality exists? How is taste modeled? How are groups handled? How are recommendations generated? What behavioral data do they collect? What happens after the user actually does something? What would make someone choose Experience instead? **Document what they do better than us.** "Not researched yet" is an honest answer; a guess is not.

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

## City-first competitive set (added 2026-10-18)

Claims are from each product's own listing or press coverage unless marked; none tested by us yet.

### Beli: social restaurant tracking and taste

| Question | What we know | Source |
|---|---|---|
| Object | Restaurants | [App Store](https://apps.apple.com/us/app/-/id1478375386) |
| Problem owned | Where should I eat, given my taste and my friends' | [Stanford Daily, Jan 2026](https://stanforddaily.com/2026/01/20/from-one-beli-to-another-bringing-the-social-aspect-back-to-eating-out/) |
| Frequency | Every meal out, plus logging afterwards | inferred |
| Social | Follow friends, compare rankings, a "friend score" averaging friends' ratings; university competitions | [Stanford Daily](https://stanforddaily.com/2026/01/20/from-one-beli-to-another-bringing-the-social-aspect-back-to-eating-out/), [Daily Dropout](https://dailydropout.substack.com/p/beli-your-favorite-restaurants-ranked) |
| Taste model | Ranking by pairwise comparison against places you've been; "Rec Score" (predicted liking), "Taste Profile", "Match Score" with friends; personalized recs after about 15 ranked places | [Daily Dropout](https://dailydropout.substack.com/p/beli-your-favorite-restaurants-ranked), [App Store](https://apps.apple.com/us/app/-/id1478375386) |
| Groups | Not researched yet | — |
| After you go | You rank it; that ranking is the core loop and the data | as above |
| Better than us | A proven loop where doing the thing (eating) creates the data; strong social pull among students and young professionals | as above |
| Why choose Experience | Hypothesis: things to do beyond restaurants, and group + time + budget constraints. Unproven. | — |

### Google Maps (Ask Maps, Gemini)

| Question | What we know | Source |
|---|---|---|
| Object | Places (300M+), reviews | [TechCrunch, Mar 2026](https://www.techcrunch.com/2026/03/12/google-maps-is-getting-an-ai-ask-maps-feature-and-upgraded-immersive-navigation/) |
| Problem owned | Finding and getting to any place; now conversational local questions | [TechCrunch](https://www.techcrunch.com/2026/03/12/google-maps-is-getting-an-ai-ask-maps-feature-and-upgraded-immersive-navigation/) |
| Taste / recs | Ask Maps answers are personalized by places you've searched for or saved; drawn from Maps place and review data | [AP via KFYR](https://www.kfyrtv.com/2026/03/12/google-unveils-major-changes-its-maps-app) |
| Actions | Directions, restaurant reservations, save to a list, share with friends | [AP via KFYR](https://www.kfyrtv.com/2026/03/12/google-unveils-major-changes-its-maps-app) |
| Availability | Mobile, US and India first (March 2026) | [GSMArena](https://www.gsmarena.com/google_maps_gets_geminipowered_ask_maps_and_immersive_navigation-news-71935.php) |
| Groups | Not researched yet | — |
| Better than us | Coverage, hours, reviews, transit times, booking, distribution on every phone. It can already answer "what should we do tonight near me" conversationally. | as above |
| Why choose Experience | Hypothesis: knows what you and your friends actually like and have done, and covers activities as experiences rather than places. Must be tested against Ask Maps directly. | — |

### TikTok (Local feed) and Instagram

| Question | What we know | Source |
|---|---|---|
| Object | Short videos, ranked by location, topic and recency in the Local feed | [TikTok Newsroom, Feb 2026](https://newsroom.tiktok.com/introducing-the-local-feed) |
| Problem owned | Desire and discovery: what's happening nearby, restaurants, events, shopping, small businesses | [TikTok Newsroom](https://newsroom.tiktok.com/introducing-the-local-feed) |
| Status | US launch February 2026 after a "Nearby" feed in the UK, France, Italy and Germany (Dec 2025); off by default, needs precise location | [TikTok Newsroom](https://newsroom.tiktok.com/introducing-the-local-feed), [eMarketer](https://www.emarketer.com/content/tiktok-introduces-nearby-feed-boosting-local-discovery-organic-reach) |
| After you go | Nothing: no plan, no completion, no rating | inferred |
| Better than us | Where desire is created; infinite fresh local content | — |
| Relationship | Our input layer (share to Experience), not something to replace (EXPERIENCE.md) | — |

Instagram: not re-researched for local discovery; capture rules in ADR-004.

### Event discovery: Fever, Eventbrite

| | Fever | Eventbrite |
|---|---|---|
| Object | Curated events and experiences, many exclusive ("Fever Originals", e.g. Candlelight concerts) | Events and tickets |
| Recs | Personalized by your likes; categories, dates, area, map | Discover tab with personalized recommendations and "It-Lists" curated by local tastemakers (60+ lists, 12 markets at launch); personalized by purchases, interests, location |
| Social | Send tickets to friends | Share events, plan with friends |
| After you go | Ticket in-app; rewards on purchases | Not researched yet |
| Better than us | Inventory and ticketing; a reason to open it (what's on this weekend) | Scale of events and organizer supply |
| Sources | [App Store](https://apps.apple.com/us/app/-/id497702817), [Pilot Plans review](https://www.pilotplans.com/blog/fever-review) | [Silicon UK press release](https://www.silicon.co.uk/press-release/get-into-it-eventbrites-reimagined-app-makes-discovering-your-next-favorite-live-experience-as-enjoyable-as-being-there), [Eventbrite blog](https://www.eventbrite.com/blog/?p=237471) |

Whether Fever is active in Philadelphia: not researched yet.

### Group planning: "what should we do" for friends

| App | What it does | Source |
|---|---|---|
| Cobble: AI Group Planner | Suggests restaurants, bars and events nearby; friends vote yes/no/maybe via a link, no app needed. 4.2★ (123 ratings). A reviewer asked to add their own venues. | [App Store](https://apps.apple.com/us/app/cobble-ai-group-planner/id1472811526) |
| Converge AI | Group sets mood, budget and distance, then votes on AI options; $6.99/mo | [App Store](https://apps.apple.com/cd/app/id6761791060) |
| TheChecklist | Group members swipe on places; shows matches when everyone swipes right | [App Store](https://apps.apple.com/us/app/thechecklist/id6754468571) |
| down? | Hangout threads, one-tap RSVP by text link, in-chat polls | [listing](https://mwm.ai/apps/down-group-hangout-planner/6789345455) |
| Howbout | Shared social calendar: availability and polls | [Howbout blog](https://howbout.app/blog/making-plans/the-app-to-get-friends-together) (self-published) |

**Better than us:** they already ship group voting and no-install invite links. **Gap (hypothesis):** none of them appear to hold a taste profile built from what each person saved and did. Unverified.

### Yelp, TripAdvisor

Not researched yet in this pass (a Yelp AI search returned nothing current). Both organize around places and reviews; TripAdvisor is travel-first. Research before the architecture phase if the recommender leans on review data.

### City exploration and gamification

| App | What it does | Source |
|---|---|---|
| Been To | Fog that clears as you visit; precise percentage of a city or district uncovered | [App Store](https://apps.apple.com/app/id6642704199) |
| Fog of World | Worldwide fog-of-war travel game since 2012; levels and visit percentages per continent | [App Store](https://apps.apple.com/us/app/%EC%84%B8%EA%B3%84%EC%9D%98-%EC%95%88%EA%B0%9C-fog-of-world/id505367096?l=ko) |
| YEG Unfogged | Which of Edmonton's 407 neighbourhoods you've set foot in, % explored, on-device only | [App Store](https://apps.apple.com/ch/app/id6785997646) |
| CityStrides | Running app: every street completed in a city (OpenStreetMap) | [citystrides.com](https://www.citystrides.com) |

**Lesson:** they reward *being somewhere*. Experience's version (vision only) should reward *doing something* there, and never app engagement.

### Positioning summary

```
Rhyme:          SOCIAL TRAVEL CONTENT → DESTINATION → TRIP
Beli:           RESTAURANTS → RANK → FRIENDS' TASTE → WHERE TO EAT
Google Maps:    ANY PLACE → ASK → GO
TikTok Local:   NEARBY VIDEOS → DESIRE
Fever:          CURATED EVENTS → TICKET
Group planners: OPTIONS → VOTE
Experience:     PERSON / GROUP → TIME → BUDGET → TASTE → CITY → WHAT SHOULD WE DO? → DID IT → LEARN
```

## Research log

- **2026-10-18:** web research on Rhyme and the category (sources above). The founder reports Rhyme "mostly worked" on their saves.
- **2026-10-18 (city-first):** added Beli, Google Maps Ask Maps, TikTok Local feed, Fever, Eventbrite, group planners and city-exploration apps from web research (sources inline). Yelp and TripAdvisor not yet researched. Nothing tested hands-on.
