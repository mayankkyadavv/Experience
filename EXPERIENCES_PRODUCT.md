# Experiences

## Primary product and build brief

**Version:** 1.0 · October 20, 2026  
**Audience:** The creator and the implementation/design agent building the app  
**Working product name:** Experiences  
**Product object:** An Experience  
**Purpose:** Build an app the creator is proud of and wants to use for decades.

This document is the primary product brief. It consolidates the direction in “Organize Experience Idea” and the creator’s expanded requirements. It replaces earlier business-oriented framing. Examples, screen layouts, sample data, and implementation defaults below are proposed product decisions, not claims about an existing app or actual personal history.

Do not spend the build on market fit, competitors, monetization, fundraising, growth strategy, or predictions of startup success. Those are explicitly de-emphasized and outside this brief’s scope. Prioritize craft, usefulness, trust, personal meaning, and the pleasure of using the finished product. The staged plan is a way to build the app well, not an investor-validation exercise.

### Reading guide

| Start here for… | Sections |
| --- | --- |
| Product intent and constraints | [Thesis](#1-the-product-in-one-thought), [principles](#2-product-philosophy) |
| Core implementation model | [Object identity](#3-what-an-experience-is), [lifecycle](#4-lifecycle-past-present-and-future), [data model](#5-experience-data-model) |
| The everyday product | [Capture](#6-capture-should-feel-almost-effortless), [navigation](#7-a-coherent-home-and-navigation), [life views](#13-ways-to-explore-a-life) |
| Social and future experiences | [Profiles](#8-profile-and-relationship-graph), [privacy](#9-visibility-and-privacy-contract), [discovery](#10-social-feeds-and-public-discovery), [planning](#11-want-to-experience-and-planning), [collaboration](#12-collaborative-and-shared-experiences) |
| Meaning over time | [Reflection](#14-ratings-reflections-and-favorite-moments), [AI](#15-ask-experiences-and-intelligence-over-a-life), [recaps](#16-memories-recaps-and-resurfacing), [exploration](#17-exploration-and-gentle-gamification) |
| Experience quality and trust | [Notifications](#18-notifications-that-earn-their-place), [onboarding](#19-onboarding-and-the-first-month), [design](#20-aesthetic-and-interaction-goals), [ownership](#21-security-ownership-and-portability) |
| Building and reviewing | [Examples](#22-concrete-experience-objects), [stages/MVP](#23-staged-build-plan), [quality checks](#24-engineering-and-quality-expectations), [success standard](#25-definition-of-a-product-worth-keeping), [agent instructions](#26-instructions-to-the-implementationdesign-agent) |

Read the principles, identity, and privacy sections before implementing any slice. Use the staged plan to control scope; the later possibilities describe a direction, not a demand to implement everything immediately.

## 1. The product in one thought

**Experiences is a beautiful, intelligent, evolving representation of the life a person has actually lived—and the experiences they still want to have.**

Build the app you wish had existed for the last ten years of your life.

It should answer three questions beautifully:

1. **What have I experienced?** A visual, searchable, contextual history of life.
2. **What are the people I care about experiencing?** A social world grounded in shared and lived experiences.
3. **What should I experience next?** Possibilities that connect naturally to desire, planning, and action.

The fundamental object is an **Experience**. Social, discovery, activities, events, planning, maps, AI, memories, media, ratings, and gamification orbit it. None should become a competing center of the product.

The conceptual loop is:

```text
Life
  → Experiences captures and structures it
  → AI understands the person better, with permission
  → Experiences helps them discover or plan something
  → They live it
  → It becomes part of their life
  → Repeat
```

The purpose of that understanding is to help someone remember and live. Opening the app more often is not inherently a desirable outcome.

### Why “Experiences”

The plural suggests a collection: my experiences, our experiences, experiences in Philadelphia. This is a design intuition, not a proven psychological claim. Use the name consistently. Interface language includes **Your Life**, **128 Experiences**, **Want to Experience**, **Experiences with Nithin**, and **Add an Experience**.

## 2. Product philosophy

### Non-negotiable principles

1. **One object across its life.** The thing a person plans, lives, captures, shares, remembers, and reflects on is the same Experience. Do not build separate post and memory systems.
2. **Seconds to capture; depth when wanted.** A title or a few photos can be enough. Description, ratings, attendees, location, and reflections are optional enrichment.
3. **Ordinary life belongs here.** A quiet walk, cooking with a friend, or an evening at home is as legitimate as an overseas trip. Money spent, distance traveled, and spectacular imagery do not determine meaning.
4. **Your Life is the center.** An account is valuable without friends, public sharing, external connections, or an elaborate AI setup.
5. **Privacy belongs to each Experience.** Private, Friends, and Public are explicit, inspectable choices. A public profile never makes its owner’s entire archive public.
6. **Automation proposes; the person owns the truth.** AI must distinguish evidence, guesses, and authored recollection. It never silently converts a suggestion into a public fact.
7. **Social should enrich lived experience.** Relationships support sharing, planning, context, and discovery. Follower counts are not the status system.
8. **The archive must last.** Preserve originals, dates, context, provenance, and editable structure. Build export and recovery into the foundation.
9. **No punishment for living offline.** No compulsory logging, streak loss, guilt, or pressure to document every moment.
10. **Beauty must coexist with clarity and accessibility.** Media, motion, and maps serve comprehension. Core actions must work without animation, precise gestures, or perfect vision.
11. **Permission applies everywhere.** Feeds, maps, counts, search, AI answers, recaps, cached thumbnails, and notifications all respect the same access rules.
12. **More data is not automatically better.** Ask for access when it provides a clear benefit; support a satisfying experience with minimal permissions.

When a feature competes for attention, ask:

- Would I want this information about my life ten years from now?
- Can we capture or retrieve it with almost no effort?
- Does this help me remember, connect, or go live something?
- Does this still feel good if I choose never to share publicly?

Counts can be expressive without becoming scores of personal worth. Do not turn “128 Experiences” into a contest or quota.

### Where the agent should explore

Explore typography, color, editorial layout, card treatments, motion, transitions between time and geography, recap composition, contextual shortcuts, and ways to make capture feel effortless. Prototype several interpretations of a living archive. Propose delightful details that serve the principles.

Suggested navigation and screen sketches in this brief are starting points. Improve them if the same capabilities become easier to understand. Choose a practical technical stack based on the actual project environment. Do not treat a speculative feature as a requirement to build an entire platform before the first usable Experience.

Changes to object identity, privacy meaning, ownership, or data retention are product-contract changes and should be surfaced explicitly. Routine layout and engineering decisions should not require the creator to micromanage the work.

## 3. What an Experience is

An Experience is a meaningful unit of lived or intended life, defined by the person rather than by a rigid event taxonomy.

Examples include a concert, trying a restaurant, a spontaneous night out, a museum visit, a weekend trip, a run, a birthday, learning pottery, a difficult milestone, or making dinner with someone you love. An Experience can have no media, no precise time, no location, and no other participants.

An Experience can contain **moments or stops**: dinner → bowling → drinks. A trip can contain child Experiences when its parts deserve their own identities. Avoid making the person decide on a complex hierarchy during capture; support organizing later.

### Identity rules

- A saved intention that becomes a plan and is later completed retains its Experience ID.
- Sharing an Experience creates an audience-visible presentation of that object, not a new post.
- A memory card, recap slide, map pin, calendar item, and feed card point back to the same ID.
- An edit to title, location, or audience is reflected wherever that object appears.
- Feed activity records may describe “shared” or “updated,” but contain references rather than an independently editable copy of the Experience.
- A repeat visit is a new occurrence with a new ID. “Ramen at the same restaurant again” is not an edit to last month’s dinner.
- Saving a friend’s completed Experience as something you want to do creates **your own future Experience**, linked by `inspired_by`. It does not copy their memory, media, attendance, or reflections.
- Joining the same real-world group outing uses the shared Experience ID and a participation record. Do not create one disconnected memory per participant.
- A venue or provider listing is reference material. It becomes part of a personal Experience when someone saves, plans, or logs it.

This distinction is essential: different people doing the same activity on different dates is different Experiences; several people living the same outing can share one Experience.

## 4. Lifecycle: past, present, and future

The conceptual lifecycle is **discover → want → plan → do → capture → remember → share → reflect → discover again**. People can enter anywhere, skip steps, return later, and keep everything private.

Use a small set of stored intention/occurrence states rather than a state for every interface action:

| State | Meaning | Typical actions |
| --- | --- | --- |
| Want | A possibility worth keeping; no commitment required | Save, add a note, group into a collection, start a plan |
| Planned | There is a concrete intention, often a date or participants | Edit details, invite, reschedule, add stops |
| In progress | Optional, explicitly entered present-tense state | Open directions, see plan, add a moment |
| Experienced | The person confirms it happened or creates a past Experience | Capture, organize, reflect, share, revisit |
| Cancelled | A plan did not happen | Keep context, archive, or return to Want |

Draft status, archived status, visibility, and time precision are separate dimensions. “Memory” is a way of viewing an Experienced object, not a second database entity or terminal state. Sharing does not imply completion, and completion does not imply sharing.

Time provides another perspective:

- **Past:** Primarily Experienced records, including retrospectively added memories with approximate dates.
- **Present:** Today’s plans, optional in-progress activities, and recent capture suggestions. Never require continuous tracking.
- **Future:** Want and Planned records, with or without a date.

A scheduled end time passing may trigger a gentle “Did this happen?” suggestion. It must not automatically claim attendance. A person who declines an invitation is not recorded as having experienced it. A cancelled show stays distinguishable from a show someone attended.

Allow one-tap undo after state changes. Preserve a lightweight history for consequential changes, including permissions and collaborative edits.

## 5. Experience data model

The following is a conceptual contract, not a required database schema. Start with a compact implementation that can evolve without splitting the object.

### Core entities and fields

| Area | Fields or related records | Product behavior |
| --- | --- | --- |
| Identity | Stable ID, owner ID, created/updated timestamps, revision, schema version | IDs survive edits, state changes, sharing, and reorganization |
| Meaning | Title, optional description, categories, tags | AI suggestions remain editable; no mandatory essay |
| Lifecycle | State, draft flag, archived flag, completion confirmation | Distinguish planned from actually lived |
| Time | Start/end, original timezone, precision, date range, recorded-at time | Support exact time, day, month, year, or unknown; recording time is not occurrence time |
| Geography | Ordered place references, optional coordinates, locality, geographic precision, private/public location representations | Multi-stop outings and location-free memories both work |
| People | Participation records, invitation state, role, attendance confirmation, consent to display identity | Being tagged does not establish attendance or grant access |
| Narrative | Moments/stops, favorite moments, optional child Experience references | Rich stories without separate post records |
| Media | Asset references, original capture metadata, contributor, ordering, caption, processing status, audience approval | Originals and derivatives remain distinguishable |
| Personal layer | Per-person rating, reflection, private notes, favorites, personal tags | A participant’s private reflection never inherits the shared object’s audience |
| Social | Visibility, optional selected-friend audience, comments, reactions, publish/update events | Social interaction attaches to the Experience |
| Planning | Candidate dates, final date, meeting place, notes, simple checklist, participant responses | Add only the coordination needed for the outing |
| Relationships | Parent ID, related occurrence IDs, inspired-by ID, source listing references | Trips, repeated visits, and inspiration remain navigable |
| Provenance | Source type/reference, field-level evidence, confidence or uncertainty, user-confirmed flag | Explain what came from a person, metadata, import, or AI |
| Ownership/control | Contributor rights, display approvals, deletion state, relevant audit entries | Make removal, access changes, and export predictable |

Supporting entities include **Person/Account, Friendship, Participation, Place, MediaAsset, Moment, Reflection, ActivityListing, Collection, and Recap**. These support the Experience rather than compete with it. A recap references Experiences; a collection groups them; neither duplicates their authoritative contents.

### Minimum viable record

Require an owner, stable ID, lifecycle state, privacy setting, and something recognizable: a title, selected media, or a saved activity reference. Provide a neutral editable title if needed. A date is helpful but may be unknown. Never force someone to invent a date or a place to save a memory.

Technical timestamps can be precise even when autobiographical time is not. “Summer 2021” should remain a range, not become an invented June 1 event. Preserve original timezones for travel and events crossing midnight.

### Personal meaning inside a shared object

Shared factual context and individual feelings are different. One canonical Experience can have several confirmed participants, common media, and separate personal reflections. Those per-person records are part of the object’s relationships, not standalone memories or social posts.

The shared Experience might say “Dinner in Fishtown.” One participant can privately write “The first time I felt at home in this city.” Another can privately rate the food. Neither reflection becomes shared merely because the Experience is Public.

### Counting Experiences

- The headline counts confirmed Experienced objects the person owns or participated in, once per ID.
- Wants, drafts, cancelled plans, imported suggestions, and unconfirmed attendance do not count.
- By default, moments are not separately counted. When a trip contains counted child Experiences, mark the trip as a container and exclude it from the aggregate. A standalone trip with no counted children can count once.
- Repeated visits count as separate occurrences. A single shared outing counts once for each confirmed participant’s own archive.
- Categories may overlap; their totals need not sum to the headline. Make that clear where necessary.
- City/place counts use confirmed places and a consistent locality definition, not every GPS sample.
- Public-facing aggregates follow the visibility rules in Section 9; they must not reveal private activity through inference by default.

## 6. Capture should feel almost effortless

### The default capture flow

1. Tap **+** from anywhere.
2. Choose photos/videos, type a short thought, or select **Add without media**.
3. See a draft with a proposed title, time, place, media grouping, and any explicitly chosen people.
4. Correct only what matters. The primary action is **Save privately**.
5. Optionally add friends, a favorite moment, or change visibility afterward.

A draft might read:

> **Saturday Night in Fishtown**  
> Saturday, 7:14 PM–Sunday, 1:42 AM · Philadelphia  
> Dinner → Bowling → Drinks  
> 24 photos · 6 videos  
> People: Add people  
> Private · **Save privately**

Date/place suggestions should visibly distinguish confirmed metadata from inferred context. Do not invent venue names, participants, emotions, or conversations. The title can remain simple if evidence is thin.

The person should be able to save before AI or uploads finish. Show local save, upload, and processing states clearly; retry without losing the draft or duplicating it. A plain text-only memory must remain excellent.

### AI-assisted capture

With the appropriate permissions, assistance can use:

- Photo/video timestamps, location metadata, and nearby capture clusters.
- Selected visual content for a suggested category or short neutral title.
- The person’s text, voice note, or later corrections.
- An explicitly selected plan, calendar entry, event ticket, or place listing.
- Confirmed collaborators’ contributions and accepted relationship context.

Suggestions should be reviewable in a small, understandable capture inbox: **“These 12 photos may belong together.”** Offer **Save**, **Edit**, **Split**, **Merge**, and **Dismiss**. A batch import must not silently flood the archive with thousands of asserted experiences.

Use bounded time/location clustering; provide split/merge because a wedding weekend or evening out can fit several reasonable boundaries. Detect likely duplicate media and likely duplicate Experiences, but ask before merging meaningful records. Preserve source IDs and merge lineage so an import retry does not duplicate the archive.

People suggestions must come from explicit tags, accepted invitations, or another authorized source. Face recognition, if ever explored, is separately opt-in and is not a dependency of capture. Do not label someone as present solely because a calendar invite or a photo resemblance suggests it.

### Optional authorized sources

Later connectors may include a selected photo library, calendars, selected ticket/receipt messages, shared albums, or deliberately connected activity/travel sources. Explain which data is read, whether it stays on-device or goes to a service, and what the person receives in return.

Use granular scopes, preview before import, and clear disconnect controls. Revoking a connector stops future reads and removes credentials; separately explain how to remove already imported material. Broad access to messages, continuous location, and full-library uploads must never be prerequisites.

### Capture acceptance targets

Treat these as initial design targets to validate on real devices:

- A basic text or photo Experience can be saved in roughly 10–20 seconds once content is selected.
- No required rating, caption, category, location, friend tag, or public-sharing decision.
- Permissions denied, AI unavailable, and interrupted uploads all have useful paths.
- Capture works without a network connection; synchronization is visible and recoverable.
- Review and correction take less work than entering all details manually.

## 7. A coherent home and navigation

Use a mobile-first interaction model, with a responsive desktop experience suited to browsing, importing, searching, and revisiting many years. Native capabilities may be added where the chosen platform supports them; do not pretend unsupported photo or background access exists.

Suggested primary navigation:

| Destination | Job |
| --- | --- |
| **Life** | Your archive and living overview; timeline, map, calendar, people, categories, and media |
| **Discover** | Friends’ experiences, public inspiration, and nearby possibilities |
| **Plans** | Want to Experience, scheduled Experiences, and group coordination |
| **You** | Profile, personal summaries, audience preview, account and privacy controls |

Keep **+** available as a prominent action, not a fifth content universe. Search is available throughout. **Ask Experiences** is reached from search and contextual prompts; it does not need to monopolize a tab.

Within Life, use **Overview / Timeline / Map / Calendar** as primary view switches. People, places/cities, categories, and media are browsable lenses and filters. Preserve the selected date range and relevant filters when switching views. Avoid crowding every feature into a bottom navigation bar.

### Life overview: example screen

```text
Tuesday, October 20                         Search   +
Your Life                                  Philadelphia

Recently
  Haunted house with Nithin
  A new ramen place
  Concert on Friday

From your life
  One year ago this week [memory preview]

Coming up
  Saturday · Museum afternoon with friends

Worth a look
  An evening activity nearby [one useful suggestion]

Overview   Timeline   Map   Calendar
Life       Discover       Plans       You
```

This is a finite, calm page. Sections can disappear when irrelevant. Do not fabricate content or replace the archive with an endless recommendation feed. A capture suggestion may appear when useful, but should not make every visit feel like clearing an inbox.

### Experience detail: example screen

Show a strong cover or a beautiful text-first treatment, title, time/place, people, and a plainly visible audience indicator. Follow with ordered moments/media, personal reflection, shared context, and social interaction if enabled.

For an Experienced object, primary actions are **Add a moment**, **Reflect**, and **Share**. For Want, they are **Plan this** and **Edit**. For Planned, show the date, location, participant responses, and **Add photos** or **Mark experienced** at the right time. Do not make the person navigate to a separate posting composer to share it.

An audience preview should answer **“What would a friend or public visitor see?”**, including the location precision and visible media.

## 8. Profile and relationship graph

The profile is a window into someone’s life, shaped by what they choose to share.

```text
Mayank
Philadelphia

128 Experiences
14 Cities · 37 Want to Experience

[Selected Experiences] [Map] [Categories]
```

This example is the owner’s view or an explicitly configured public summary. Public visitors do not automatically receive private totals, private wants, or the full map.

Let a person choose a display name, avatar, short biography, and optional broad home city. Basic profile information can be public while individual Experiences remain private. Provide a minimal or undiscoverable profile option. Do not expose email addresses, precise home location, birthday, or contact information as basic public identity.

Use **Add friend**, **Request sent**, and **Friends** as relationship actions. Start with mutual friendship and accepted requests. The graph supports Friends visibility, invitations, people views, and feed relevance. It need not display connection totals. If one-way following is ever added, it subscribes only to public content and does not confer friendship or access to Friends Experiences.

Requests can be accepted, declined, cancelled, or blocked. Unfriending removes friend-derived access. Blocking prevents direct interaction and removes relationship-derived access; do not promise that blocking can prevent a person from seeing genuinely public material outside their account. Muting affects feed/notification presentation without changing friendship or access.

Mentioning a friend is not inviting them, proving attendance, or sharing their identity publicly. Let people approve participant display and remove a tag from their own profile. Private local people labels such as “Grandma” should work without creating an account or exposing that label to others.

### Count disclosure

The default owner view shows the full count, such as **128 Experiences**. Other viewers see counts of Experiences available to them, clearly labeled where needed: **31 public Experiences** or **93 Experiences shared with you**.

Offer a separate, optional **Show my total Experience count** setting for someone who wants a public “128 Experiences” headline despite only sharing 31 objects. Explain that this reveals the existence of additional private activity. Never enable that disclosure through a general Public profile toggle. Apply the same rule to cities, categories, wants, map density, and other summaries.

No leaderboards for archive size, friend count, travel distance, or spending. The profile should feel like a person’s life, not their influence dashboard.

## 9. Visibility and privacy contract

### The three levels

| Level | Who can view the Experience | Default behavior |
| --- | --- | --- |
| **Private** | Its owner only | Default for new capture, imports, and AI suggestions |
| **Friends** | The owner’s accepted friends, or an explicitly selected subset of those friends | No public discovery or public search indexing |
| **Public** | Anyone | Eligible for public profile and discovery, after explicit publication |

For MVP, Friends may mean all accepted friends. Selected-friend audiences are introduced before collaborative editing so a group can share an outing without exposing it to everyone. This refines the Friends level; it does not introduce an ambiguous fourth visibility label.

Audience does not follow lifecycle: Wants and plans are private by default, too. Publishing a future plan requires a clear preview of date, place, and people disclosed. Never publish live location automatically.

### Concrete rules

- Owner-only drafts stay off feeds, public maps, share previews, and other people’s search results.
- A tag, comment, reaction, group invitation, or shared link does not expand the audience.
- Friends visibility is based on the owner’s friend audience, not the union of every participant’s friends.
- Access to an Experience does not grant access to its participants’ other Experiences.
- Personal reflections and notes are owner-only unless individually and explicitly shared.
- Public location can be a venue or broad area; omit sensitive coordinates and strip location metadata from externally served derivatives.
- Private home-like locations are hidden from external viewers by default. Do not infer or publicly label someone’s home from their history.
- Changing an Experience from Public to Friends or Private revokes future access through app surfaces and asset delivery. Explain that screenshots or copies already obtained cannot be recalled.
- Exports, shared recap files, and downloaded media are explicit disclosures. Preview their audience/content before creation.
- Short-lived media access and server-side permission checks protect originals and thumbnails. An unguessable URL is not an authorization model.

Build one access policy used by object APIs, media delivery, search, feeds, map aggregation, recap generation, and AI retrieval. Perform permission filtering before material enters AI context, then check again when returning results. Invalidate affected caches and indexes on audience changes or relationship revocation. If a cached result is stale, fail closed rather than briefly display formerly accessible content.

Privacy settings should be intelligible from the interface. **“Friends · Alex, Sarah, Nithin”** is clearer than a generic lock symbol when a selected audience is active.

## 10. Social, feeds, and public discovery

### Friends’ experiences

Discover contains a distinct **Friends** view showing newly shared Experiences from accepted friends. Use a recent-first default with optional thoughtful grouping by a weekend or shared outing. A group outing should appear once, with participants, rather than as six duplicate cards.

A card presents the Experience: title, imagery or narrative, date, general place, approved participants, and a useful personal comment if the author chose to share one. Actions include **Open Experience**, **Want to Experience**, a lightweight reaction, and comment. Reactions and comments belong to the Experience and obey its audience. Their counts are secondary.

Editing a typo should not repeatedly bump an old Experience to the top. A meaningful addition can appear as an update without becoming a second authoritative object. A newly shared memory from 2019 should say it was experienced in 2019 and shared recently.

Provide **You’re caught up** and a finite recent-history boundary. There should be no requirement to watch engagement-optimized videos to reach friends’ lives. Ranking experiments, if any, should favor relationship relevance and declared interests rather than outrage, vanity, or screen time.

### Public discovery

Offer two clearly distinguished types of material:

- **Lived inspiration:** Public Experiences from people, describing something that actually happened.
- **Things you could do:** Places, activities, and scheduled listings that can become future Experiences.

Show the distinction on cards. A public memory about last year’s concert must not look like a ticket available tonight. Do not fabricate attendance, ratings, friends, or availability to make discovery feel populated.

Filters can include city, neighborhood, date, category, indoors/outdoors, price range, distance, and accessibility information when supported by the source. Unknown accessibility, availability, or price is shown as unknown, not guessed.

### Nearby events and activities

Allow one-time approximate location permission or a manually chosen city. Default to useful groupings such as **Tonight**, **This weekend**, **Anytime nearby**, and **From your Want list**.

Each listing includes source, source link, relevant time and timezone, freshness indicator, place, and known availability or cost. Handle cancellations, sold-out notices, changed hours, duplicates across providers, and stale data. If verification is unavailable, say **Check current details** and link to the source. A cancelled saved event does not disappear from a person’s plan without explanation.

External listings are reference objects. **Want to Experience** creates a private personal Experience linked to the listing, retaining enough source context to understand it later. Keep canonical event updates separate from the person’s own plan and recollection. Provider changes must not rewrite a past memory.

A listing becoming unavailable should leave the person with an understandable saved intention, not a broken card. Link-based or manually curated discovery is a valid first release; label sample content in prototypes and never present it as live inventory.

## 11. Want to Experience and planning

Want is a living collection of future possibilities. It is useful even without a date, a group, or a detailed plan.

Save from a friend’s Experience, public discovery, a nearby listing, a link, a place, or a typed idea. Provide simple collections such as **Philadelphia weekends**, **With Nithin**, **Someday**, or **Rainy day**. Collections should be optional; avoid requiring organization at save time.

Useful views include **All wants**, **Near me**, **With someone**, **Seasonal**, and **Planned**. Show a short reason when resurfacing something: **“You saved this museum; it’s near Saturday’s lunch.”** Do not assume someone still wants an old interest; support dismissing or updating it.

### A plan grows from the Experience

**Plan this** adds a date or date options, meeting place, invited friends, notes, and optional stops. Preserve the Experience ID. Start with lightweight coordination rather than building a complete booking, payment, ticketing, or messaging service.

Group planning can later add availability voting, a small checklist, attendance responses, reminders, and contextual discussion. A participant accepts or declines; an invitation does not mark attendance. Keep tentative dates separate from a confirmed date. Confirm timezone and handle travel across timezones.

After the outing, show **“Did you go?”** or let the person add media and mark it Experienced. Confirmed participants can independently confirm their own attendance. An owner finishing an event must not force “Experienced” into every invitee’s archive.

### Example: inspiration becomes life

1. Mayank sees a friend’s publicly shared museum afternoon.
2. He taps **Want to Experience**. A new private Experience is created for his future visit, with an inspiration link to the friend’s object.
3. In Plans, he chooses Saturday and invites Nithin. This same future Experience becomes Planned.
4. They go. He adds four photos and confirms completion; Nithin confirms attendance.
5. Mayank chooses a Friends audience. The feed card opens the same Experience now visible in his Life timeline and map.
6. A year later, a recap references that object. A correction to the museum name is reflected everywhere.

## 12. Collaborative and shared Experiences

Collaboration means several people can contribute to one outing’s shared record while retaining control of their own contributions and personal meaning.

### Initial collaboration contract

- One owner manages common metadata and the object’s audience. Accepted contributors can add approved media, moments, captions, and proposed factual corrections.
- Begin with accepted friends as contributors. An owner can choose a selected-friend audience containing just the participants. That still uses the Friends visibility level.
- A Private Experience is owner-only. Inviting contributors requires the owner to explicitly switch it to an appropriate Friends audience; the UI must show this change before sending invitations.
- Contributor and viewer are different roles. A friend who can view an object cannot automatically edit it.
- All participation records point to the same Experience ID. Each participant controls attendance confirmation, profile association, personal reflection, and their own contributed media.
- Contribution consent includes the current audience. Expanding the audience, particularly to Public, requires renewed approval for other people’s contributions and participant identity. Until approved, exclude those contributions/identities from the expanded view.
- A contributor can withdraw their media and remove their visible participation. The owner can remove material from the shared presentation but cannot reassign authorship.
- Participants cannot independently republish the shared object to a broader audience. They can request a broader audience or share an access-controlled link.

This is a deliberate first contract, not a claim that group permissions are simple. Non-friend contributors, multiple co-owners, and more granular audience unions can be explored later only with a clear access model.

### Resolving edits and disagreements

Keep attribution on contributions. Protect media from duplicate uploads and handle simultaneous edits with revisions and recoverable history. For conflicting common fields, show the latest accepted change and let the owner resolve proposed corrections; do not silently discard a person’s reflection or caption.

People need not agree on a rating, favorite moment, or interpretation. Keep those individual. Shared factual context should not force a shared emotional narrative.

### Leaving, revocation, and deletion

Explain the consequences before removing participants or making a collaborative Experience Private: other participants lose access to the shared object. Their own notes and original contributions remain exportable to them; they do not retain access to withdrawn material from others. A detached participation record can show **Shared Experience unavailable** without leaking removed metadata or continuing to count it as a visible shared memory.

Before deleting a shared record, offer ownership transfer to an accepted participant, subject to confirmation. If deletion proceeds, revoke shared access and remove shared derivatives according to the declared deletion policy. Preserve only the individual’s own retained contributions/notes where the retention policy and their choice allow it, with clear provenance. Do not silently clone the whole shared Experience into everyone’s archive as a workaround.

Build and test these controls before enabling collaboration. Shared history is valuable precisely because its ownership deserves care.

## 13. Ways to explore a life

All of these are projections of the same authorized Experience collection. They should share search, filters, navigation back to an Experience, and consistent counts.

### Timeline and Life view

Zoom between years, months, days, and individual Experiences. Support a rich month with many entries, a quiet month with one meaningful entry, and years with incomplete history. Show approximate dates honestly. Place undated memories in an accessible **Date unknown** area rather than inventing chronology.

Use narrative density intelligently: a year might show a few chosen highlights and category rhythms, while a day shows specific moments. Preserve scroll position when returning from an Experience. Let people select their own highlights instead of equating most media or most reactions with most meaningful.

### Map and geographic life view

Show Experiences, not raw location trails. Cluster at world/country scale; reveal cities, neighborhoods, places, and individual visits as the person zooms. A place detail can combine **Your visits**, **Want to Experience here**, and permitted friend inspiration.

Allow Past / Future / Both and date/category/people filters. A repeated venue has several visits. A route appears only when the Experience contains known ordered stops and the person wants that view; do not infer travel paths from isolated points.

Offer a synchronized list so map use is optional and accessible. Experiences without locations stay discoverable elsewhere. Public map previews use disclosed location precision and exclude private density or travel patterns.

### Calendar and time view

Use month/week/day views for lived history and future plans. Visually distinguish Experienced, Planned, and tentative Want items with text or symbols as well as color. Keep all-day, multi-day, and timezone-aware events accurate. Approximate memories belong in an appropriate summary, not in an arbitrary day cell.

Calendar integration is optional. A calendar invitation suggests a possible plan; it is not evidence that the person attended.

### People view

Open **Experiences with Nithin** to see confirmed shared history, private owner-authored recollections involving him, upcoming plans, and wants the owner has associated with him. When Nithin views a shared profile, he sees only material he is authorized to see—not the owner’s private people view.

Offer relationship-specific recaps only when requested or enabled. Let someone mute a person from resurfacing, remove a mistaken association, or keep difficult memories without recurring reminders. Avoid ranking relationships by quantity or announcing that someone is a “best friend” based on interaction volume.

### Categories

Begin with a manageable set such as Food, Music, Art & Culture, Outdoors, Travel, Sports, Learning, Everyday Life, and Milestones. Permit multiple categories and user-created tags. Categories guide retrieval and discovery; they should not force every life event into an activity catalog.

### Media

Provide a media browser where every asset leads to its Experience context. Preserve original quality when retained, and provide efficient derivatives for browsing. Support text-only Experiences, captions, alt text, video playback controls, optional transcription, and graceful handling of unsupported formats.

An asset may be referenced by several related moments without storing redundant originals. Removing it from one presentation is different from deleting the original; label those actions clearly. Imports should explain storage state and whether originals are stored, linked, or unavailable.

### Cities and places

A city page brings together lived Experiences, favorite places, future wants, and approved friend inspiration. Distinguish a real visit from an airport transfer or a guessed geotag. Allow correcting city assignment. A place rename should preserve the historical name/context while linking to the current place when known.

### Search

Search titles, dates, places, people, categories, captions, notes, and optionally authorized transcripts. Support ordinary queries such as **“concerts with Alex in 2024”**, **“ramen I loved”**, and **“that rainy weekend in New York.”**

Combine deterministic filters with semantic retrieval as the archive grows. Show why a result matches. Separate **Your Life**, **Shared with you**, and **Discover** scopes so a search for a private memory does not unexpectedly become a public search. Provide useful lexical search even if AI is unavailable.

## 14. Ratings, reflections, and favorite moments

Make reflection an invitation, not a completion requirement. After capture, offer one small prompt such as **“What do you want to remember?”** Let the person ignore it indefinitely.

Optional fields can include:

- A personal 1–5 rating, with no default value; unrated is different from zero.
- **Would do again**, with room for uncertainty.
- A favorite moment, photo, quote, song reference, or small detail.
- A freeform reflection, voice note, or short emotional description chosen by the person.
- Practical notes such as cost, useful booking information, or what to do differently next time.

Private is the default for ratings and reflections, even on a Public Experience. Offer a separate explicit action to share selected words. A personal “5/5 night” does not automatically become a public review of the venue. If venue reviews are ever added, distinguish them clearly from the meaning of the whole Experience.

A later reflection can coexist with the original: **“What I wrote that night”** and **“How I remember it now.”** Preserve authorship and dates. The ability to reconsider one’s life should not erase the earlier record.

## 15. Ask Experiences and intelligence over a life

AI should make the archive more accessible and future possibilities more personal. It is an assistant to recollection, not an authority on who the person is.

### Questions the product should eventually answer

- “What did I do last summer?”
- “When was the first time I went to New York with Alex?”
- “Show me my favorite nights with the college group.”
- “What were my favorite things when I was 25?”
- “Which restaurants did I want to revisit?”
- “What did we do on that rainy weekend?”
- “Make me a movie of 2028.”
- “What could I do this Saturday that feels different from my usual routine?”

Answers should cite the Experiences and moments supporting them, with tappable links. Use dates and small media previews where helpful. A question about age requires an explicitly provided birth date or age anchor; do not infer it from appearance. A “first time” answer should say **“The earliest visit in your archive…”** unless the person has confirmed a stronger claim.

### Grounded behavior

Distinguish **recorded facts**, **the person’s own words**, **reasonable inference**, and **unknown**. The archive is incomplete. Missing photos do not prove that something did not happen. An unlogged month is not an empty month of life.

For subjective terms such as “best,” explain the basis: explicitly favorited Experiences, personal ratings, or the person’s own reflections. If there is no basis, ask a lightweight clarification or show a few candidate memories. Never use engagement statistics as a substitute for personal meaning without consent.

Example answer:

> The earliest New York visit with Alex recorded here is June 8, 2024. You saved a museum visit and dinner that evening. There may have been earlier trips that are not in your archive. [Open the two Experiences]

AI cannot quietly modify history, publish an Experience, invite friends, or schedule a plan. It can prepare a proposal and present the appropriate user action. Imported text, messages, captions, and provider listings are data, not instructions to the assistant. Permission boundaries must hold even when those sources contain misleading requests.

### Personalization that the person can inspect

Use declared interests, saved wants, explicitly favorable reflections, practical constraints, and optionally patterns in authorized history. Explain recommendations: **“You saved two pottery ideas and have Saturday afternoon free.”** Only mention calendar availability if calendar access was granted and the evidence supports it.

Provide **Less like this**, **More like this**, **Not interested anymore**, and controls to exclude categories or periods from personalization. Do not equate lack of history with lack of interest, infer sensitive identity traits, or freeze someone into their past preferences. Leave room for novelty and growth.

### Long-term possibilities

| Capability | Desired experience | Boundary |
| --- | --- | --- |
| Memory reconstruction | Reassemble a weekend from surviving photos, timestamps, notes, and confirmed participants | Show an evidence-based draft; gaps and guesses remain visible |
| Autobiographical questions | Trace places, relationships, interests, and life chapters across years | Answer only from authorized material; cite records and uncertainty |
| Recaps and movies | Compose a month, trip, friendship, or year into an editable narrative | Preview media, participants, captions, and soundtrack rights before export |
| Forgotten interests | Resurface something the person enjoyed and may want to revisit | Suggest gently; support dismissal and sensitive-memory exclusions |
| Future recommendations | Connect wants, season, location, time, companions, and personal tastes | Explain relevance and verify external event details where possible |
| Conversational recall | Help someone add missing context by asking one useful question | Never pressure them or present invented detail as recovered memory |

Reconstruction must not generate fictional documentary evidence. If creative imagery or dramatized scenes are ever explored, keep them clearly labeled and separate from original media; never imply a generated scene proves what happened. Voice/person likeness generation is outside the initial scope.

### Build intelligence in layers

Start with deterministic metadata extraction and good search. Then add optional title/category suggestions. Add retrieval-grounded Ask Experiences after access control and source linking are reliable. Rich multimodal reconstruction, long-form films, and proactive recommendations come later. The core archive must remain useful when a model is unavailable, expensive, slow, or replaced.

## 16. Memories, recaps, and resurfacing

Support month, season, year, trip, city, person, and custom-period recaps, plus **One year ago**, **On this day**, and **Around this time**. Approximate source dates should produce approximate resurfacing, not false anniversaries.

A recap should favor chosen highlights, variety, narrative, and personal reflections rather than simply selecting the highest-rated or most-photographed moments. Let someone rearrange, remove, rename, and replace selections before saving or sharing. Use calm typography and media pacing; a quiet year can have a beautiful recap.

Recaps are generated views or authored compositions referencing original Experiences. Store selection/order/edit decisions, but do not create an independent memory database. Recheck permissions when rendering or sharing. If a referenced contribution is withdrawn, remove it from future renders; explain the limits for files already exported.

Private source material stays private. A private recap can contain private Experiences; a public recap must either exclude them or ask for a deliberate content disclosure without silently changing source visibility. For the first sharing implementation, use the simpler rule: only publicly share recap content already approved for Public visibility.

Provide **Hide this memory**, **Don’t resurface this person**, **Exclude this date range**, and **Turn off anniversaries**. Do not infer grief, relationship status, or trauma in order to offer these controls. Someone can keep an important difficult memory without wanting it unexpectedly displayed on a lock screen.

## 17. Exploration and gentle gamification

Reward participation in real life, curiosity, and personal discovery. The feature should be optional and private by default.

Examples:

- **A new corner of your city:** Visit a neighborhood you wanted to explore.
- **Your first pottery class:** Acknowledge a self-confirmed first experience.
- **A small local collection:** Three parks, bookstores, or food spots chosen by the person.
- **Return to something you love:** Revisit an old interest rather than always rewarding novelty.
- **A city chapter:** A personal retrospective of places that became meaningful over a year.

City/neighborhood exploration can show areas visited and saved possibilities, with adjustable precision. Avoid surveillance-style completeness maps. Do not require GPS proof, encourage trespassing, imply safety where unknown, or reward travel/spending over accessible nearby experiences.

No daily-login streaks, penalties for inactivity, public living scores, or mandatory completion percentages for a city. People with different mobility, time, energy, and budgets should be able to find meaning without being told they are behind.

Unlocks or badges, if used, should be small acknowledgments inside the archive. The actual reward is a richer life and a richer memory of it.

## 18. Notifications that earn their place

Notifications should deliver something timely, wanted, or actionable. Controls should be simple by category, support quiet hours, and have a clear master off switch.

| Category | Good example | Default posture |
| --- | --- | --- |
| Plans | “Your meeting place changed for Saturday.” | Enabled for accepted plans; sensitive detail hidden on lock screens |
| Invitations | “Nithin invited you to a museum afternoon.” | Enabled with rate limits and request controls |
| Contributions | “Alex added photos to your shared Experience.” | Group updates; avoid one alert per asset |
| Capture suggestions | “Would you like to save Saturday’s photos?” | Opt-in digest; dismissible |
| Memories | “Your October recap is ready.” | Opt-in cadence; respect exclusions |
| Discovery | “An activity you saved has a date this weekend.” | Opt-in, specific, and fresh |
| Integrity/security | “Your export is ready” or “Your upload needs attention” | Clear and actionable; avoid sensitive previews |

Do not send “You haven’t posted,” social-comparison nudges, or fabricated urgency. No daily obligation to engage. Deduplicate notifications and stop reminders after someone cancels, dismisses, or completes the relevant action.

## 19. Onboarding and the first month

The first session should demonstrate the product through the person’s own material, with little setup.

### Proposed onboarding flow

1. Introduce the promise in one sentence: **“A home for the life you’ve lived and what you want to do next.”**
2. Create a minimal account. Explain that new Experiences are Private by default.
3. Offer **Add a recent Experience**, **Save something I want to do**, or **Explore first**.
4. If they choose capture, ask only for the selected photos or text needed now. Save the first Experience and immediately show it in Life.
5. Offer a city for discovery, using manual entry or approximate location. Make it skippable.
6. Invite optional profile personalization and friend discovery after the person has seen value. Do not demand contact access.

Never request photo library, contacts, precise location, calendar, microphone, and notifications in a single opening permission wall. Explain each permission at the moment it helps.

### Empty states

- **Life:** “Start with something you want to remember.” Actions: add photos, write a memory, add an older Experience.
- **Map:** “Your places will appear here.” Explain how to add a place; keep a useful list fallback.
- **Plans:** “Keep a place for someday.” Offer a typed idea or honest nearby suggestions.
- **Friends:** “Experiences can be personal or shared.” Offer an invitation action without implying the account is incomplete.
- **Ask Experiences:** Show sample questions as examples, not fake answers. With one entry, answer only what that entry supports.

Do not seed the real archive with invented personal history. A demo gallery must be clearly labeled and removable. Import is optional; someone should be able to start today without reconstructing their whole life first.

### Growing value over time

| Horizon | What should become valuable |
| --- | --- |
| **First session** | One real Experience feels worth keeping; adding it is easy; one future idea has a home |
| **1 month** | Recent life is organized, places are findable, wants become plans, and the first recap feels personal |
| **1 year** | Seasonal patterns, shared history, city knowledge, and a meaningful year retrospective emerge |
| **5 years** | The archive answers questions memory alone cannot; relationships, interests, and life chapters have depth |
| **20 years** | Media, context, original words, and trustworthy chronology remain accessible across devices and generations of software |

Long-term value must increase without making the person dependent on a fragile account. They should trust the product more because they can leave with their history intact.

## 20. Aesthetic and interaction goals

The app should feel intimate, spacious, tactile, and alive. Aim for a contemporary personal archive with the warmth of a carefully kept album and the retrieval power of a good information system.

Suggested design direction:

- Strong typography and restrained color; let personal media supply much of the visual variety.
- An editorial rhythm that accommodates text-only memories, short clips, ordinary photos, and major milestones equally well.
- Stable layout while media loads; good placeholders and clear progress states.
- Motion that explains relationships: an Experience can move from a date on the timeline to a pin on the map while keeping its identity.
- Subtle haptics where supported, comfortable touch targets, accessible contrast, screen-reader labels, and dynamic text.
- Reduced-motion support, keyboard navigation on desktop, and non-map routes to every essential task.
- Warm, plain language: **Save privately**, **Want to Experience**, **What do you want to remember?**

Avoid the visual weight of an enterprise dashboard, compulsory social performance, a wall of badges, or an AI chat box dominating the archive. Do not use loud celebratory effects for every save. Significant moments can be quiet.

Keep processing, synchronization, and permission errors understandable. **“Saved on this device; waiting to upload”** is more useful than a generic spinner. Make destructive changes undoable where possible and make audience changes visible.

Explore at least a few distinct Life layouts before committing to a design system. Judge them with sparse, dense, media-free, and decade-spanning histories—not only an idealized grid of travel photography.

## 21. Security, ownership, and portability

Treat the archive as intimate personal data. Build appropriate authentication, least-privilege access, encrypted transport and storage, protected credentials, safe media processing, backups, and recoverable deletion from the beginning. Do not claim end-to-end encryption unless the entire key and processing architecture actually supports it. If private media or text is sent to an external AI service, disclose that path and provide meaningful controls.

Define account recovery, session/device management, and protection against unauthorized bulk access. Avoid logging private captions, coordinates, prompts, or media URLs into general analytics. Use narrowly scoped operational telemetry with retention limits. Public content needs reporting/blocking controls and a way to remove abusive or unauthorized material; a small personal product still needs those basics once it hosts public social content.

### Export contract

Before real personal history accumulates, provide an export containing:

- Versioned JSON or another documented open structured format for Experiences and their relationships.
- Original media the person owns or is permitted to export, plus a manifest mapping files to Experiences and checksums where practical.
- Human-readable Markdown or HTML summaries for memories, dates, places, personal reflections, and captions.
- IDs, lifecycle state, audience, participants as permitted, source/provenance, original timezone, approximate-date semantics, and relevant hierarchy.
- A clear report of omitted unavailable or unauthorized contributions.

Exports should not require a running AI model or the Experiences service to be useful. Preserve stable IDs and timestamps through supported re-imports. Test an export/restore round trip with media and shared records, and document any deliberate loss of features rather than claiming perfect portability.

### Deletion and retention

Distinguish removing a media reference, deleting an asset, archiving an Experience, deleting an Experience, disconnecting a source, and deleting an account. Explain shared-record consequences before destructive actions.

Define and disclose actual retention windows for trash, backups, logs, and external processing before launch. Remove deleted/revoked content from serving paths, search indexes, embeddings, derived summaries, queued jobs, and future recaps. Backup expiry may be delayed under a documented policy, but restoring a backup must not resurrect previously revoked access or deleted content.

Give users access to their data and a practical exit. Do not train on private archives by default or hide secondary use behind a capture permission. Sensitive data use must be a deliberate, understandable choice.

## 22. Concrete Experience objects

The examples below use illustrative IDs and dates. Fields are abbreviated; the storage model may differ while preserving the product behavior.

### A. A quiet private memory with no media

```yaml
id: exp_tea_2026_10_18
owner_id: mayank
title: Tea and a long conversation
state: experienced
completion_confirmed: true
time:
  date: 2026-10-18
  precision: day
  timezone: America/New_York
places: []
categories: [Everyday Life]
media: []
visibility: private
personal_reflection:
  author_id: mayank
  text: We stayed at the table long after the tea went cold.
  visibility: private
provenance:
  title: user_authored
  time: user_confirmed
```

This is a complete, valuable Experience. It requires no photo, venue, rating, or audience beyond the owner.

### B. One planned outing becoming a shared memory

```yaml
id: exp_museum_2026_10_24
owner_id: mayank
title: Museum afternoon
state: planned
time:
  start: "2026-10-24T14:00:00-04:00"
  timezone: America/New_York
  precision: exact
places:
  - place_id: place_example_museum
    public_precision: venue
visibility: friends
audience_friend_ids: [nithin]
participation:
  - person_id: mayank
    role: owner
    attendance: unconfirmed
  - person_id: nithin
    role: contributor
    invitation: accepted
    attendance: unconfirmed
inspired_by: exp_friend_prior_museum_visit
media: []
```

After they attend, **the same `exp_museum_2026_10_24`** changes to Experienced. Each person confirms attendance; four approved photos and two favorite moments are added. Mayank’s private reflection remains private. Its timeline entry, map pin, profile count, friend card, and later recap reference this ID. No `post_id` or `memory_id` is created.

### C. A multi-stop night

```yaml
id: exp_fishtown_2026_10_17
owner_id: mayank
title: Saturday Night in Fishtown
state: experienced
time:
  start: "2026-10-17T19:14:00-04:00"
  end: "2026-10-18T01:42:00-04:00"
  timezone: America/New_York
  precision: exact
visibility: friends
audience_friend_ids: [alex, sarah, nithin]
moments:
  - title: Dinner
    place_id: place_example_restaurant
  - title: Bowling
    place_id: place_example_bowling
  - title: Late conversation
    location_disclosure: neighborhood_only
media_summary:
  photos: 24
  videos: 6
personal_rating:
  author_id: mayank
  value: 5
  scale: 5
  visibility: private
```

This counts as one Experience unless the person deliberately reorganizes substantial parts into separate occurrences. Metadata may suggest the time span; the saved record must retain whether the person confirmed it.

### D. An intention without a date

```yaml
id: exp_learn_pottery
owner_id: mayank
title: Try a pottery class
state: want
time: null
visibility: private
categories: [Learning, Art & Culture]
collection_ids: [philadelphia_weekends]
source:
  type: user_idea
personal_note: Something hands-on for a rainy weekend.
```

It appears in Plans and relevant discovery prompts, but not in the completed Experience count. Selecting a class later adds a listing reference and planned date to this same object.

## 23. Staged build plan

The goal is a coherent, personally useful app at each stage. Advance when the core feels trustworthy and pleasant, not when a feature checklist becomes long. Each stage should use the same underlying Experience model.

### Stage 0 — Product skeleton and realistic prototypes

Establish the Experience contract, lifecycle, authorization policy, audience labels, navigation, and an initial visual direction. Use clearly labeled sample histories covering sparse data, ordinary life, large archives, uncertain dates, and shared Experiences.

Prototype capture → detail → Life → map, and discovery → Want → plan → Experienced. Confirm that these feel like one product. Choose the stack and explain capability limits. Define storage, export, deletion, and processing disclosure decisions before ingesting real private media.

**Ready when:** A person can follow the full loop in the prototype, and there is no conceptual fork between a shared post and a remembered Experience.

### Stage 1 — A dependable personal archive

Build account/profile basics, manual/photo capture, optional metadata suggestions, Private saving, stable Experience detail, editable time/place, media handling, timeline, basic map/list, search, Want and Planned states, and basic export. The owner profile centers on confirmed Experience counts.

Make capture resilient to interruptions. Support text-only and undated memories. Provide original/derivative media clarity, accessible navigation, and useful empty states. AI enhancement can be minimal; reliable saving cannot.

**Ready when:** The creator can record a month of ordinary life, find a particular memory by date/place/text, correct it, and export it without losing media or context. Capture is fast enough to use willingly.

### Stage 2 — Complete the core MVP loop

Add mutual friendships, Private/Friends/Public visibility, audience preview, public/basic profile rendering, permission-aware counts, a finite friends feed, public Experience browsing, and simple nearby/manual discovery. Add **Want to Experience** from a friend or listing, basic planning, completion confirmation, and a simple month recap.

Map and timeline must reflect the same records and permission rules. Public sharing requires usable reporting and blocking. A small manually curated discovery set is acceptable if honestly labeled and maintained; do not block the loop on broad provider integration.

**Ready when:** The creator can discover an idea, save it, plan it, do it, capture it, share the same object appropriately, and revisit it on the timeline and map. Another account can see exactly the intended subset. Revocation works across media, search, counts, and caches.

**This is the core MVP boundary:** excellent capture, life archive, profile, social visibility, map/timeline, and the discovery-to-memory loop. It should already be worth using personally. It does not require advanced AI, full collaborative editing, complex group coordination, badges, generated films, or exhaustive live-event coverage.

### Stage 3 — Shared life and richer perspectives

Add selected-friend audiences, contribution consent, collaborative media and moments, participant attendance controls, group availability/planning, individual reflections, richer calendar/people/place/category/media views, and more expressive recaps. Expand imports cautiously with scoped permissions.

Implement ownership transfer, contributor withdrawal, simultaneous-edit handling, and deletion consequences before rolling out collaboration.

**Ready when:** Several people can build one memory together without duplicate Experiences, accidental disclosure, lost contributions, or confusion over who can change what.

### Stage 4 — Grounded intelligence

Add stronger capture clustering, semantic retrieval, Ask Experiences with source links, editable interest preferences, richer nearby recommendations, and contextual resurfacing. Keep useful fallbacks when AI or connectors fail.

**Ready when:** Answers are demonstrably supported by the archive, permission changes propagate, ambiguous history is described honestly, and recommendations help the creator choose something they want to do.

### Stage 5 — A decades-long companion

Explore long-range life chapters, memory reconstruction, editable recap films, deeper city exploration, optional gentle gamification, richer portability, and deliberate long-term stewardship features. Support schema/model migrations without reauthoring personal history.

**Ready when:** Each addition makes the existing archive more meaningful without increasing pressure, maintenance burden, or dependence on opaque AI.

### Explicitly deferred from the first build

Broad email/receipt ingestion, automatic face recognition, continuous location capture, booking/payment infrastructure, generalized messaging, elaborate badges, multi-owner permission unions, generative reconstructions, and movie-making pipelines. These are possibilities, not prerequisites for making the central product excellent.

## 24. Engineering and quality expectations

Choose architecture to protect the product contracts. A modular implementation is sufficient; avoid unnecessary services merely because the long-term vision is broad.

- Maintain one authoritative Experience identity and structured related records.
- Store originals separately from replaceable derivatives and AI outputs.
- Use idempotent imports/uploads and background jobs that can retry safely.
- Make local saves, synchronization, conflicts, and upload completion visible.
- Keep full-text search usable independently of semantic search.
- Centralize authorization and apply it to every derived surface.
- Version exported schemas and make migrations explicit and reversible where practical.
- Retain field provenance and human corrections; later model runs must not overwrite confirmed details silently.
- Treat embedding indexes, recaps, and summaries as rebuildable derivatives, not the only copy of someone’s history.

### Required end-to-end checks

| Scenario | Expected outcome |
| --- | --- |
| Save text only, no date/place, no permissions | A valid private Experience appears in Life and can be found later |
| Select media, lose network, reopen the app | Draft/local record survives; uploads resume without duplication |
| Save a Want, plan it, then confirm attendance | The same ID persists and enters the completed count only after confirmation |
| A future event’s end time passes | No automatic assertion that the user attended |
| Share an old Experience | Feed shows recent sharing and correct historical occurrence time |
| Public → Private, then revisit saved URLs | Unauthorized object/media access fails; feeds, maps, search, AI, and counts stop disclosing it |
| Unfriend or block someone | Friend-derived access and interaction permissions are revoked consistently |
| Friend saves inspiration | Their future object links to the source; it does not copy private content or claim shared attendance |
| Join a shared outing | One canonical ID appears for confirmed participants; no duplicate memories |
| Contributor withdraws a photo | Future object/recap renders stop serving it; other authorized contributions remain intact |
| Search or ask about a private memory from another account | Nothing about its content or existence leaks through results or aggregates |
| Ask an unsupported autobiographical question | The answer explains the gap rather than inventing a memory |
| Import an approximate date across timezones | Precision and timezone remain truthful in timeline, calendar, and export |
| Export, delete a test account, restore supported data | Own records, permitted media, IDs, and relationships recover as documented |
| Browse 20 years of sample history | Navigation remains responsive with progressive loading and stable context |
| Turn off AI, location, notifications, and public discovery | The personal archive and manual planning remain useful |

Test with at least owner, accepted friend, non-friend, blocked user, and logged-out viewer contexts. For collaboration add contributor, withdrawn contributor, and a friend outside the selected audience. Test real authorization boundaries, not only whether buttons are hidden.

### Performance and reliability posture

Keep primary screens responsive with cached permitted metadata, progressive media loading, efficient map clustering, and accessible list rendering. Preserve scroll and filter state. Avoid waiting for AI or full-resolution uploads before a save can finish locally. Establish measurable device-specific budgets during implementation and report observed performance rather than inventing guarantees here.

Do not widen scope to compensate for weak core interactions. If capture feels like paperwork, fix capture. If a memory cannot be found, fix retrieval. If sharing is confusing, fix the audience model before adding more social surfaces.

## 25. Definition of a product worth keeping

Assess progress through lived use and concrete tasks rather than engagement maximization:

- Does the creator voluntarily save ordinary moments because it is easy and worthwhile?
- Can they retrieve a half-remembered place, person, or evening quickly?
- Does a shared Experience retain the richness of a personal memory?
- Can they tell exactly who sees what, and reverse a sharing choice confidently?
- Does discovery produce future plans that feel personally relevant?
- Does the archive become more meaningful without demanding constant maintenance?
- Can they recover and carry their history elsewhere?
- Does the finished interface feel like something they are proud to open and show?

Operational measurements may track save failures, upload completion, retrieval quality, latency, permission correctness, and export integrity. Prefer consented, minimal, aggregate diagnostics. Daily active use, session length, follower totals, and posting frequency are not the product’s north star.

## 26. Instructions to the implementation/design agent

Treat this as the governing product brief. Begin by inspecting the actual codebase and available platform capabilities, then choose the smallest coherent implementation path through Stages 0–2. Do not restart business analysis or introduce a monetization/growth strategy as a prerequisite.

Use the non-negotiable principles to resolve routine decisions. Maintain a short decision log for material departures, especially identity, privacy, ownership, and portability. Surface genuine tradeoffs with a concrete proposed solution. Keep visual and interaction exploration alive; this brief describes the intended experience, not a fixed wireframe to reproduce mechanically.

Deliver usable slices that complete the loop. Prioritize a small number of beautifully connected screens over many disconnected feature demos. Show the creator real capture, real retrieval, real permissions, and real data persistence before expanding the feature surface.

The standard is personal and long-term: **build a home for a life that its owner will still want to open, understand, and trust twenty years from now.**
