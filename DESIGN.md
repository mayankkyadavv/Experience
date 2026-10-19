---
# gstack: design-md-format=spec
name: Experience
description: A white, living 3D model of your city where color only appears where your life happens; one big question, three good answers, springy and tactile.
colors:
  surface: "#FFFFFF"
  soft: "#F4F4F2"
  map-ground: "#F3F3F0"
  map-water: "#CFE2EC"
  map-park: "#DCEBD8"
  building-low: "#FFFFFF"
  building-mid: "#F4F4F1"
  building-high: "#E7E9EE"
  text: "#0A0A0B"
  text-muted: "#6A6E75"
  hairline: "rgba(10,10,11,0.08)"
  primary: "#0A0A0B"
  on-primary: "#FFFFFF"
  cat-food: "#FF5A36"
  cat-nightlife: "#E63E8C"
  cat-outdoors: "#1FAF5B"
  cat-culture: "#2D6BFF"
  cat-activity: "#FFB300"
  cat-other: "#12B3C6"
  success: "#1FAF5B"
  error: "#E5383B"
  dark-surface: "#0B0B0C"
  dark-raised: "#161618"
  dark-soft: "#1F1F22"
  dark-text: "#F5F5F4"
  dark-text-muted: "#9A9EA6"
typography:
  display:
    fontFamily: Bricolage Grotesque
    fontWeight: 800
    fontSize: 30pt
    letterSpacing: -0.04em
    fontVariation: "opsz 96, wdth 100"
  title:
    fontFamily: Bricolage Grotesque
    fontWeight: 800
    fontSize: 21pt
    letterSpacing: -0.035em
  body:
    fontFamily: SF Pro
    fontSize: 17pt
    lineHeight: 1.4
  label:
    fontFamily: SF Pro
    fontWeight: 600
    fontSize: 12pt
  mono:
    fontFamily: SF Mono
    fontSize: 11pt
    letterSpacing: 0.06em
rounded:
  chip: 8px
  control: 13px
  button: 16px
  card: 28px
  sheet: 34px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  2xl: 32px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.button}"
    height: 52px
  button-secondary:
    backgroundColor: "{colors.soft}"
    textColor: "{colors.text}"
    rounded: "{rounded.button}"
  ask-button:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: 22px
  sheet:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.sheet}"
  recommendation-card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.card}"
  segmented:
    backgroundColor: "{colors.soft}"
    rounded: "{rounded.control}"
  chip:
    borderColor: "{colors.hairline}"
    rounded: 14px
---

# Experience

## Overview

**Creative North Star:** your city as a living, white 3D model; color appears only where your life happens (saves, picks, things done), so the map fills in with you.
**Product context:** iOS app for people living in a city (Philadelphia beta) answering "What should we do?" with three recommendations, plus TikTok capture. Peers: Beli, Google Maps, Fever, Rhyme.
**Mode per surface:** Experience (home map, results flight, your city) · Operate (ask sheet, onboarding, rating) · Read (recommendation card, experience detail).
**Reference:** approved mockup `~/.gstack/projects/mayankkyadavv-Experience/designs/city-first-20261018/preview.html` (2026-10-18). Research notes behind the motion and trays: Family (Benji Taylor), Arc onboarding, Apple Weather, Flighty, Airbnb 2025, Rauno Freiberg, Apple "Designing Fluid Interfaces".
**Key characteristics:**
- A real 3D city fills the screen, slowly orbiting when idle.
- One question in the largest type on the home screen.
- Three swipeable answers; the camera flies to each and a colored beacon rises.
- Things you've done stand as colored pillars on your city.
- White and ink chrome; color comes only from categories and photos.

## Colors

**Strategy:** Restrained chrome, full palette for data. White and ink (#0A0A0B) carry all UI. The six category hues are the only saturated colors and are used for map marks, beacons, pillars, category dots and chips. They never color buttons or text blocks.
**Light or dark:** Light is the default (the founder's call: white, bright, awe). Dark mode is required (CLAUDE.md) and inverts the chrome only: `dark-*` surfaces, white primary buttons with ink text, a dark map style with the same category hues. Categories never change between modes.
Primary buttons are ink on light, white on dark and over photos. Muted text is for supporting facts only, never for anything the user must read to decide.

## Typography

Bricolage Grotesque (OFL, Google Fonts, variable opsz 12-96, wdth 75-100, wght 200-800; bundle the TTF and OFL.txt) is the voice: the home question, screen titles, card titles, city names. Always 800 weight, full width (wdth 100), tight tracking (-0.035 to -0.05em). SF Pro does all body, controls and facts, scaling with Dynamic Type; Bricolage scales with `relativeTo:` and caps at accessibility sizes so titles reflow rather than clip. SF Mono, uppercase and tracked, is used only for small metadata labels ("DID IT · FRIDAY NIGHT").

## Layout

Full-bleed map behind everything; content lives in bottom sheets (34pt radius, 8pt inset from screen edges) and a top glass card. Thumb zone holds every primary action. Recommendation cards are 262pt wide in a horizontal snap carousel. 16-18pt side margins inside sheets. At the largest Dynamic Type sizes, sheets become scrollable full-height pages and the map shrinks to a header.

## Elevation & Depth

Depth comes from the 3D map, then three shadow levels: `lift-sm` (chips, small glass), `lift` (sheets, cards), none for flat content. Shadows always have a y-offset; no zero-offset glows. Exactly one translucent layer at a time: the top glass card over the map (Liquid Glass / material). Everything with reading text sits on opaque white.

## Shapes

Continuous corners. Hierarchy: chip 8 → control 13 → button 16 → card 28 → sheet 34. Nested inner radius = outer radius − inset. Map pillars and beacons are hexagonal prisms.

## Components

- **Ask button:** ink block, Bricolage 30pt "What should we do?" left-aligned over two lines, arrow right; scales to 0.97 on press with a spring.
- **Segmented control:** soft track, white selected segment with `lift-sm`; selection animates.
- **Recommendation card:** photo (128pt) with number and category tag; title; area; fact chips (price, duration, travel time, open until); a "why" line from real data only; actions Interested (ink), Not for us (soft), Save (bookmark, toggles to activity tint). Interested turns green and reads "We're in".
- **Chips (taste):** hairline border, category dot; selected = 14% category tint + category border.
- **Map marks:** saves are 12pt category dots with a white ring; picks are beacons (height 110m, active 260m); done Experiences are pillars (height by rating).
- **Rating:** three large tiles with faces (Not for me / It was good / Loved it); selection tilts and fills the face with activity yellow. Scale is an open founder decision.
- **Capture tray:** thumbnail drops in from the top; "Figuring out what this is…" morphs (blur + slide) into the activity and place; estimated facts appear as chips labelled "(estimated)".
- **States:** every component has loading (shimmer or morphing status line), empty (real map, no fake data, a clear next step), and error (what happened + that nothing was lost) designs.

## Do's and Don'ts

- Do keep the map white; only categories add color.
- Do show exactly three recommendations, each with a reason we can prove.
- Do label every estimate "(estimated)" through `SourcedText`.
- Do give the big motion to rare moments (ask, rate, first save); keep browsing instant.
- Do let every camera move be interrupted by touch.
- Don't invent social proof ("your friends loved this") or fake counts on locked cities.
- Don't put color on buttons or use gradients for CTAs.
- Don't stack translucent layers or use glass for reading surfaces.
- Don't hardcode Philadelphia into layout or copy; it's a "beta" label on generic city screens.
- Don't reduce Experiences to pins: flexible saves are areas, ideas have no mark.

## Motion

- **Approach:** expressive at authored moments, instant elsewhere. Everything is a spring with no bounce (`.spring(duration:, bounce: 0)`), interruptible, velocity-preserving.
- **Easing:** enter(spring) exit(spring) move(spring); camera via map fly/ease APIs.
- **Duration:** micro 0.2s · short 0.4s · medium 0.6-0.8s · camera flight 1.6s · dive 1.4s.
- **Authored moments:** (1) idle orbit of the city; (2) Find 3 things: status lines morph, cards rise, camera flies to each pick, beacons rise; (3) Did it → rating → pillar rises on your city; (4) capture tray drop and text morph.
- **Reduce Motion:** no orbit, no flights (cut to the target), crossfades instead of slides, beacons and pillars appear at full height.
- **Haptics:** light impact on card snap and beacon landing; success on "We're in" and rating.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-18 | Initial design system from the approved city-first mockup | /design-consultation; founder: "this is amazing". Earlier directions (dark Lamplight Atlas, white Postcards) preceded the city-first strategy |
| 2026-10-18 | Light default, white 3D city, six category hues as the only color | Founder wants white, dynamic, awe; color as a reward for real-world activity |
| 2026-10-18 | 3D city rendered from OpenStreetMap vector tiles with custom extrusions (beacons, pillars) | MapKit can't extrude custom shapes or restyle buildings white; see ADR-010 |
