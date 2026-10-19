# Experience: product vision

> **This is vision, not requirements.** Nothing here is in scope unless `docs/MVP.md` says so. Agents: never build from this file. Read it for context on *why*, then build from MVP.md, ARCHITECTURE.md and the ADRs.

"Experience" is a working name.

## Thesis

**Experience learns what you want to do from the content that inspires you, then helps you actually do it.**

Internal principle: **close the gap between wanting and doing.**

People discover what they want to do through Reels, TikToks and Shorts, save them, and forget them: **see → save → forget**. Experience exists to turn that into **see → save → understand → do**.

## Where we stand (October 2026)

The category exists and is validated. At least 8 apps turn shared reels into places on a map, and **Rhyme** (formerly Roamy) goes further, into itineraries, group trips and discovery. See `docs/COMPETITIVE_RESEARCH.md`. The founder ran their own saves through Rhyme and it mostly worked.

So:
- **Capture is table stakes, not the product.** Share-reel-to-map is the onboarding mechanism.
- **Our differences are hypotheses until observed.** Everything under "Bets" below is unproven. We don't claim it in positioning until we have evidence.
- Competition is fine. The goal is a product people prefer, or one that grows the category in a direction others don't serve.

## Travel vs. experience

A travel product starts from **"I'm going somewhere. What should I do there?"**

Experience starts from **"I want to do something. Where, when and how can I do it?"**

The flows overlap heavily. The difference only matters if it changes behavior. Renaming "spots" to "experiences" does not make a different product.

Example: a video of someone driving a Formula car at Spa-Francorchamps.
- A place-first system extracts *Circuit de Spa-Francorchamps, Stavelot, Belgium*.
- Experience tries to also understand: *the user wants to drive a Formula-style car on a real circuit. Category: motorsport. Shown at: Spa. Location requirement: probably flexible.*

The user may care more about the activity than the exact place in the video.

**Travel stays important.** It's probably one of the strongest early use cases: travel content performs well, people save lots of it, trips need planning, and intent is strong. Travel may be the initial wedge without being the long-term identity. Which one it is gets decided by what friends actually save and do (MVP.md, "Wedge").

## Experience, not place

The root object is an **Experience** (what the user wants to do), not a point of interest (where something is). One place can hold many experiences. One experience can happen at many places, or none.

```
Place:       Nürburgring, Germany
Experience:  Drive a performance car around the Nürburgring
             category: motorsport / driving · location: Nürburgring · requirement: exact
             status: want to do
```

ADR-006 makes this concrete for the MVP schema.

## Bets (unproven hypotheses)

### 1. Why did they save this?

The first intelligence question is "where was this filmed?" The deeper one is **"why did the user save it?"** A couple eating in a glass igloo under the Northern Lights might mean: this hotel, the Northern Lights, eating in an igloo, Finland, a romantic trip, or a mix. Saves are both a way to collect Experiences and a signal of what someone wants.

### 2. The experience preference graph

Onboarding checkboxes ("adventure, food, nightlife") are a weak cold start. Behavior is richer: "strong: performance driving, unusual restaurants, mountains; weak: museums, shopping; prefers activities to sightseeing; travels far for unique things." Who owns the record of what a person wants to experience in the physical world? Experience could be that system. **We learn from behavior, not questionnaires.**

### 3. Person → destination (the inverse of trip planning)

Rhyme is strong at **destination → places → itinerary**. Experience could explore **person → interests → desired experiences → possible destinations**: "I have four free days next month and $2,000. Where should I go?"

### 4. Local and everyday use

The test for any feature: **would this still be useful if the user weren't traveling?**
- "What should I do tonight?" · "What have I saved nearby?" · "Saturday is free for my partner and me, what should we do?" · "Four of us have six hours, find something we'd all like."

If almost every feature fails this test, Experience is just another travel planner and the claimed difference should be reconsidered.

### 5. Driving the "do", not just the "save"

Competitors stop at an organized map. Experience measures and drives completion: **Did it**, nearby reminders, and a feed of your own saves that brings them back when you could go. North star: experiences marked done per active user per month.

## Long-term lifecycle (not a roadmap)

```
DISCOVER → SAVE → UNDERSTAND → LEARN USER → RECOMMEND → PLAN → BOOK → DO → REMEMBER → DISCOVER AGAIN
```

Each stage starts only after the previous one shows real usage. Rough order of later phases (from the original brief): groups (first priority after the MVP) → a discovery feed of what people nearby save → trip planning from your own saves → marketplace (bookings, tickets, affiliate).

## Two acceptable outcomes

1. **Company:** friends keep sharing reels and marking things done, retention develops, a real difference from Rhyme emerges, and it grows into a company.
2. **Engineering:** even if the company doesn't work, the project shows serious engineering: native iOS, an async backend, structured multimodal extraction with evals, geospatial and search, auth, observability, third-party integrations.

**When they conflict, the company outcome wins.** Example: a richer embedding-based recommendation system would be great engineering, but if friends aren't sharing yet, the time goes to whatever gets them sharing. Engineering quality is how we build, not a reason to build something.

## Product principles

- Get people off their phones and into the world. Optimize for time spent experiencing life, not time in the app.
- Saving should be as easy as liking. Every extra tap in capture is a lost save.
- Honest over impressive. Show confidence and provenance, and ask rather than guess.
- Learn from behavior, not questionnaires.
- Plan around what users already want.
- Use social platforms as the discovery layer. Don't try to replace them.
- Don't add features because a competitor has them.
