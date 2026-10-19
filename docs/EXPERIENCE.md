# Experience: product vision

> **This is vision, not requirements.** Nothing here is in scope unless `docs/MVP.md` says so. Agents: never build from this file. Read it for context on *why*, then build from MVP.md, ARCHITECTURE.md and the ADRs.

"Experience" is a working name.

## Thesis (updated 2026-10-18: city-first)

**Experience helps you and your friends figure out what to do, and actually do it.**

The central product question is: **What should we do?**

It's Friday at 5 PM. Four friends are bored. They have five hours, about $75 each, different tastes and histories, and no idea what they want. Today they search separately across TikTok, Instagram, Google Maps, Reddit, Eventbrite and the group chat. Instead, they open Experience. It knows who's coming, what each person likes and has done, what they've saved, the time and budget, where they are, what's open and what's on, and answers: **here are a few things your group would probably love doing tonight.**

Internal mental model (not marketing copy): **Beli for everything you do outside your house.** Beli organizes around restaurants, rankings, friends and taste. Experience widens the object to everything you can go and do: activities, events, food, classes, entertainment, nightlife, sports, nature, culture, seasonal and unusual things.

Earlier principle, still true: **close the gap between wanting and doing.** Social media creates desire. Experience converts desire into action.

## How the direction changed

**Before (October 2026, after the Rhyme discovery):** social content → identify places → save to map → help you do it, with travel as a likely wedge. Rhyme already does share-reel → map → itinerary well for trips (`docs/COMPETITIVE_RESEARCH.md`).

**Now:** start from ordinary life in a city, not from a trip.

```
Rhyme (travel)                 Experience (city-first)
I AM GOING SOMEWHERE           I HAVE FREE TIME
        ↓                              ↓
WHAT SHOULD I DO THERE?        WHO AM I WITH?
                                       ↓
                               WHAT CAN WE DO?
```

Travel happens a few times a year. "What should we do tonight?" can happen every week: Friday nights, weekends, dates, friend hangouts, after work, rainy days, celebrations, visiting family, seasonal things, spontaneous plans. Travel stays in the long-term vision as one more context the same system works in: if you go to Tokyo, your taste profile comes with you ("given everything I know about you, what should you do in Tokyo?"). It is not the initial product.

The "local vs. travel wedge" question that MVP.md previously left open to data is now decided by the founder: **local, city-first.**

## Experience, not place (unchanged, reinforced)

The root object is an **Experience** (something you can do), not a place.

```
Place:        Central Park
Experiences:  Rent a rowboat in Central Park
              Bike the Central Park loop
              Have a picnic in Sheep Meadow
```

One place holds many experiences; one experience can happen at many places, or none. Recommendations reason about experiences; places are one component. ADR-006 made this the schema; ADR-009 (proposed) extends it to a shared, city-scoped catalog.

## City-first

- **Density beats coverage.** The product gets useful when one city has many experiences, users, ratings, completed plans and friend activity. No worldwide coverage early.
- **Philadelphia is the beta and dogfooding city**, because the founder lives there. Recommendations can be physically tested: if Experience suggests pottery → dinner → comedy for a Saturday for two at $75 each, the founder can go and judge the activity, timing, commute, cost, sequence and whether the social content was accurate.
- **Philadelphia is a beta market, not the product's identity.** The product is "Experience", never "Experience Philadelphia". City is an explicit domain concept and configuration; nothing Philadelphia-specific is hardcoded. Early UI may say "Philadelphia (beta)".
- **New York City is the likely first major expansion market** (density, young professionals, huge supply of things to do, events, creator ecosystem, transit, spontaneous plans). Not populated now. Current sequence, subject to evidence:

```
BUILD → PHILADELPHIA BETA → DOGFOOD → EARLY USERS → VALIDATE CORE BEHAVIOR
      → IMPROVE PRODUCT → PREPARE NYC DATA / USERS → NYC LAUNCH
```

## The behavior to validate first

> **When people don't know what to do, will they open Experience?**

This matters more than catalog size, map pins, AI features, city count, social features or downloads. The strongest signal is someone in a group saying **"Check Experience."**

## Long-term vision (not a roadmap)

Each item starts only after the previous behavior shows up in real usage. MVP.md says what's in scope now.

### Constraint-based recommendations
Time (tonight, 2 hours, all day, this weekend), budget (free, under $25/$50/$100), participants (just me, partner, friend, group, family, specific Experience users), mood or intent (chill, active, creative, nightlife, outdoors, something new, surprise me). Not all required; infer as much as possible from context and history.

### Individual taste profiles
What does this person actually enjoy doing? Signals: onboarding preferences, saves, completions, ratings, completed plans, categories chosen or ignored, imported social content, accepted or rejected recommendations, repeat behavior, price, time and geographic patterns. **Lightweight onboarding solves cold start; behavior improves it over time.** (This replaces the earlier "learn from behavior, not questionnaires" stance.)

### Groups: recommendation + coordination
A group holds several Experience users ("Friday night: Mayank, John, Sarah, Alex"). Experience finds the overlap in what they like and recommends what maximizes expected group satisfaction, eventually weighing budgets, schedules, locations, travel time, group size, past group activity, novelty, availability, weather and ratings from similar groups. Groups are potentially one of the strongest differentiators.

### Plans
A **Plan** is an ordered set of Experiences with timing and transport between them:

```
RAINY SATURDAY
12:00  Ramen · $25 · 60 min      → 9-min walk
 1:15  Interactive art · $42 · 90 min → 14-min subway
 3:15  Coffee · $8 · 45 min       → 6-min walk
 4:15  Comedy show · $25 · 90 min
```

Eventually aware of durations, hours, commute, mode, cost, reservations, ordering and buffers. Plans become a first-class domain object later (not in the MVP; the model shouldn't make them hard).

### Community Plans
Later, Plans may be shared: by users, creators, local experts, Experience editorial, or businesses with clear disclosure. "Perfect first date in Philadelphia", "Philadelphia under $50", "Rainy Saturday", "Parents are visiting". Save, complete, rate, modify, share, follow creators. Not a marketplace in the MVP.

### Social layer
Friends, groups and shared plans that drive discovery rather than a generic feed. It should answer: what have my friends been doing? What does Sarah recommend? What haven't John and I done together? What do all four of us like? What did people like us do last Friday?

### "What did people actually do?"
Most systems answer "what's highly rated" or "what's popular". Experience could answer **what people actually did**: last Friday, couples this weekend, groups of four after 8 PM, tonight, in Fishtown, people like me. This uses behavioral data (completions, plan completion, sequences, group size, actual duration and spend, what came next, repeats, ratings) and may become a strategically important dataset.

### Experience sequences
Learn what naturally follows what (indoor karting → dinner nearby → bar; museum → coffee → park): not just "will this user enjoy X" but "what sequence makes a good evening".

### City exploration
The city as a game board: how much of it you've experienced, neighborhoods visited, new experiences this month, compared with friends; achievements like "new neighborhood explored". **Reward real-world exploration only, never app engagement.** No meaningless points.

### The map
The map stops meaning "places I saved from videos" and becomes **a picture of my real-world life and everything I still want to experience**: want to do, completed, friends completed, trending, recommended, plans, neighborhood exploration. The map visualizes Experience data; it is never the data model.

### Social media stays the input layer
People discover things on TikTok, Reels and Shorts ("Philadelphia just opened an insane indoor mini-golf place"). Sharing it to Experience extracts the experience (indoor mini golf), city, approximate price ($32), duration (90 min), group fit (2-6), category and source. It joins the user's saves and taste profile, and on Friday, for 4 people at $75 each for 5 hours, Experience remembers it. Not every post maps to one place; identify the underlying activity.

### Conceptual data graphs
Taste (what each person enjoys), social (who does things with whom), experience (which experiences relate), geographic (where they can happen), temporal (when), behavioral (what people do, combine, repeat, enjoy). These are concepts, not a mandate for graph databases; storage follows real requirements.

## Product loops

```
DISCOVER → SAVE → DECIDE → PLAN → DO → RATE → LEARN → BETTER RECOMMENDATION → DISCOVER AGAIN
```

For groups:

```
CREATE GROUP → UNDERSTAND EVERYONE → FIND OVERLAP → RECOMMEND → PLAN → DO → RATE → IMPROVE GROUP MODEL
```

(Supersedes the earlier lifecycle DISCOVER → SAVE → UNDERSTAND → LEARN USER → RECOMMEND → PLAN → BOOK → DO → REMEMBER. Booking is no longer on the near-term path.)

## Bets carried over (still unproven)

- **Why did they save this?** A video of a couple eating in a glass igloo under the Northern Lights could mean the hotel, the lights, eating in an igloo, Finland or a romantic trip. Saves are both a way to collect experiences and a taste signal.
- **Activity over venue.** A video of someone driving a Formula car at Spa means "drive a race car on a real circuit" (location: probably flexible) as much as "Circuit de Spa-Francorchamps".
- **Driving the "do".** Competitors stop at an organized list or map. Experience measures completion (Did it) and rating, and uses them to recommend better.
- **Our differences from Rhyme, Beli and others are hypotheses until observed.** Never claim one in UI copy or docs without evidence.

## Two acceptable outcomes

1. **Company:** people in Philadelphia use Experience when they don't know what to do, complete what it recommends, come back next time, and pull friends in; then NYC.
2. **Engineering:** even if the company doesn't work, the project shows serious engineering: native iOS, an async backend, structured multimodal extraction with evals, recommendation and ranking, geospatial search, auth, observability.

**When they conflict, the company outcome wins.** Engineering quality is how we build, not a reason to build something.

## Product principles

- **Open Experience → make a decision → close the phone → go do something.** Success is more time in the real world, not more time in the app.
- Three strong recommendations beat fifty mediocre ones.
- Saving should be as easy as liking. Every extra tap in capture is a lost save.
- Honest over impressive. Show confidence and provenance; ask rather than guess.
- Onboarding solves cold start; behavior does the real learning.
- Density over coverage. One city done well.
- Use social platforms as the discovery layer. Don't try to replace them.
- Don't lock the core into one city, travel, restaurants, solo users or places-instead-of-experiences.
- Don't add features because a competitor has them.
