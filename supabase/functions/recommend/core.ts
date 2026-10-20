// Recommender v1: hard filters, then a transparent score, then three varied picks.
// Every reason shown to the user is built from data we hold (saves, onboarding answers,
// hours, dates). Never social proof we can't back up (CLAUDE.md provenance rule).

import { clockLabel, type DateRange, dayLabel, fits, type WeeklyHours, type When, windowFor } from "./time.ts";

export type Category =
  | "food" | "cafe" | "dessert" | "bar" | "nightlife" | "music" | "comedy" | "arts_culture" | "attraction"
  | "outdoors" | "sports" | "active" | "class" | "games" | "shopping" | "market" | "event" | "wellness" | "lodging" | "other";

export type Who = "solo" | "date" | "friends" | "group" | "family";
export type Mood = "chill" | "active" | "food" | "creative" | "nightlife" | "outdoors" | "something_new" | "surprise";

/** The six color groups in DESIGN.md. Also used to keep the three picks varied. */
export const CATEGORY_GROUP: Record<Category, "food" | "nightlife" | "outdoors" | "culture" | "activity" | "other"> = {
  food: "food", cafe: "food", dessert: "food", market: "food",
  bar: "nightlife", nightlife: "nightlife", music: "nightlife", comedy: "nightlife",
  outdoors: "outdoors", sports: "outdoors", active: "outdoors", wellness: "outdoors",
  arts_culture: "culture", attraction: "culture",
  class: "activity", games: "activity", event: "activity",
  shopping: "other", lodging: "other", other: "other",
};

/** Onboarding chips → categories (and the "unusual" tag). Labels are what the user tapped. */
export const LIKE_CHIPS: Record<string, { label: string; categories: Category[]; tag?: string }> = {
  food: { label: "Food spots", categories: ["food", "cafe"] },
  live_music: { label: "Live music", categories: ["music"] },
  comedy: { label: "Comedy", categories: ["comedy"] },
  museums: { label: "Museums", categories: ["arts_culture", "attraction"] },
  classes: { label: "Classes", categories: ["class"] },
  outdoors: { label: "Outdoors", categories: ["outdoors", "active"] },
  bars: { label: "Bars", categories: ["bar", "nightlife"] },
  games: { label: "Games & arcades", categories: ["games"] },
  markets: { label: "Markets", categories: ["market", "shopping"] },
  weird: { label: "Something weird", categories: [], tag: "unusual" },
  sports: { label: "Sports", categories: ["sports", "active"] },
  dessert: { label: "Dessert", categories: ["dessert"] },
};

const MOOD_CATEGORIES: Record<Mood, Category[]> = {
  chill: ["cafe", "outdoors", "arts_culture", "wellness", "dessert"],
  active: ["active", "sports", "outdoors"],
  food: ["food", "dessert", "market", "cafe"],
  creative: ["class", "arts_culture"],
  nightlife: ["bar", "nightlife", "music", "comedy"],
  outdoors: ["outdoors"],
  something_new: [],
  surprise: [],
};

export interface Constraints {
  when: When;
  hours: number; // how long they have
  budget: number | null; // dollars per person; 0 = free only; null = no preference
  who: Who;
  groupSize?: number;
  mood?: Mood;
  location?: { lat: number; lng: number };
}

export interface CandidateExperience {
  id: string;
  title: string;
  category: Category;
  tags: string[];
  goodFor: Who[];
  priceMinCents: number | null;
  priceMaxCents: number | null;
  durationMinMinutes: number | null;
  durationMaxMinutes: number | null;
  groupMin: number | null;
  groupMax: number | null;
  hours: WeeklyHours[];
  dates: DateRange[];
  place: { lat: number; lng: number } | null;
}

export interface UserState {
  experienceId: string;
  category: Category;
  savedAt?: string;
  interestedAt?: string;
  notInterestedAt?: string;
  doneAt?: string;
  rating?: 1 | 2 | 3;
}

export interface Profile {
  likes: string[]; // LIKE_CHIPS keys
}

export interface Pick {
  experienceId: string;
  score: number;
  reasons: string[];
  facts: { price?: string; duration?: string; travelMinutes?: number; openUntil?: string };
}

export interface Input {
  constraints: Constraints;
  nowLocal: number; // local wall-clock ms in the city's timezone
  candidates: CandidateExperience[];
  states: UserState[];
  profile: Profile;
  count?: number;
}

const DAY = 86_400_000;
const NOT_INTERESTED_COOLDOWN_DAYS = 60;
const MAX_TRAVEL_MINUTES = 40;

function haversineKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const h = Math.sin(r(b.lat - a.lat) / 2) ** 2 + Math.cos(r(a.lat)) * Math.cos(r(b.lat)) * Math.sin(r(b.lng - a.lng) / 2) ** 2;
  return 12_742 * Math.asin(Math.sqrt(h));
}

/** A rough door-to-door estimate: walking under ~1.2 km, otherwise city driving/transit. Shown as an estimate. */
export function travelMinutes(km: number): number {
  return Math.round(km < 1.2 ? (km / 5) * 60 : 6 + (km / 20) * 60);
}

export function priceLabel(min: number | null, max: number | null): string | undefined {
  if (min === null) return undefined;
  if ((max ?? min) === 0) return "Free";
  const d = (c: number) => `$${Math.round(c / 100)}`;
  return max !== null && max !== min ? `${d(min)}–${d(max)}` : d(min);
}

export function durationLabel(min: number | null, max: number | null): string | undefined {
  if (min === null) return undefined;
  // Half hours read as "1.5 hrs"; other odd minutes as "1 hr 20 min".
  const f = (m: number) =>
    m < 60 ? `${m} min`
    : m % 60 === 0 ? `${m / 60} hr${m === 60 ? "" : "s"}`
    : m % 30 === 0 ? `${m / 60} hrs`
    : `${Math.floor(m / 60)} hr ${m % 60} min`;
  return max !== null && max !== min ? `${f(min)}–${f(max)}` : f(min);
}

const whoMatches = (goodFor: Who[], who: Who) =>
  goodFor.length === 0 || goodFor.includes(who) || (who === "group" && goodFor.includes("friends"));

/** Taste weight per category: onboarding likes, then what the user did with past Experiences. */
export function tasteWeights(profile: Profile, states: UserState[]): Map<Category, number> {
  const w = new Map<Category, number>();
  const add = (c: Category, v: number) => w.set(c, (w.get(c) ?? 0) + v);
  for (const like of profile.likes) for (const c of LIKE_CHIPS[like]?.categories ?? []) add(c, 1);
  for (const s of states) {
    if (s.savedAt) add(s.category, 0.3);
    if (s.interestedAt) add(s.category, 0.3);
    if (s.notInterestedAt) add(s.category, -0.4);
    if (s.doneAt && s.rating) add(s.category, s.rating === 3 ? 0.8 : s.rating === 2 ? 0.3 : -0.6);
  }
  for (const [c, v] of w) w.set(c, Math.max(-2, Math.min(3, v)));
  return w;
}

export function recommend(input: Input): Pick[] {
  const { constraints: k, nowLocal, profile } = input;
  const count = input.count ?? 3;
  const win = windowFor(k.when, k.hours, nowLocal);
  const stateById = new Map(input.states.map((s) => [s.experienceId, s]));
  const taste = tasteWeights(profile, input.states);
  const doneCategories = new Set(input.states.filter((s) => s.doneAt).map((s) => s.category));
  const likedChip = (c: Category, tags: string[]) =>
    profile.likes.map((l) => LIKE_CHIPS[l]).find((chip) => chip && (chip.categories.includes(c) || (chip.tag && tags.includes(chip.tag))));
  const moodCats = k.mood ? MOOD_CATEGORIES[k.mood] : [];

  const scored: (Pick & { group: string })[] = [];
  for (const e of input.candidates) {
    const st = stateById.get(e.id);
    // Hard filters ----------------------------------------------------------
    if (st?.doneAt) continue; // MVP: recommend new things; repeats come later
    if (st?.notInterestedAt && nowLocal - Date.parse(st.notInterestedAt) < NOT_INTERESTED_COOLDOWN_DAYS * DAY) continue;
    if (!whoMatches(e.goodFor, k.who)) continue;
    if (k.groupSize && ((e.groupMin && k.groupSize < e.groupMin) || (e.groupMax && k.groupSize > e.groupMax))) continue;
    if (k.budget !== null && e.priceMinCents !== null) {
      if (k.budget === 0 ? (e.priceMaxCents ?? e.priceMinCents) > 0 : e.priceMinCents > k.budget * 100) continue;
    }
    if (k.budget === 0 && e.priceMinCents === null) continue; // "free" must be known to be free
    const need = Math.min(e.durationMinMinutes ?? 60, k.hours * 60);
    if ((e.durationMinMinutes ?? 0) > k.hours * 60) continue;
    const fit = fits(win, need, e.hours, e.dates);
    if (!fit) continue;
    let travel: number | undefined;
    if (k.location && e.place) {
      travel = travelMinutes(haversineKm(k.location, e.place));
      if (travel > MAX_TRAVEL_MINUTES) continue;
    }

    // Score -------------------------------------------------------------------
    const reasons: string[] = [];
    let score = 1 + (taste.get(e.category) ?? 0);
    if (st?.savedAt) {
      score += 2;
      reasons.push(`You saved this on ${dayLabel(Date.parse(st.savedAt))}`);
    }
    const chip = likedChip(e.category, e.tags);
    if (chip) {
      score += chip.tag ? 1 : 0;
      reasons.push(`You picked ${chip.label}`);
    }
    if (moodCats.includes(e.category)) {
      score += 1.5;
      reasons.push(`Fits "${k.mood!.replace("_", " ")}"`);
    }
    if (k.mood === "something_new" && !doneCategories.has(e.category)) {
      score += 1;
      reasons.push("Something you haven't done");
    }
    const endingSoon = e.dates.find((r) => {
      const end = Date.parse(r.end);
      return end >= nowLocal - DAY && end - nowLocal < 21 * DAY;
    });
    if (endingSoon) {
      score += 0.4;
      reasons.push(`Only until ${dayLabel(Date.parse(endingSoon.end))}`);
    }
    if (travel !== undefined) score -= Math.min(1, travel / MAX_TRAVEL_MINUTES) * 0.8;
    if (e.priceMinCents === null) score -= 0.2;

    scored.push({
      experienceId: e.id,
      score,
      reasons: reasons.slice(0, 2),
      facts: {
        price: priceLabel(e.priceMinCents, e.priceMaxCents),
        duration: durationLabel(e.durationMinMinutes, e.durationMaxMinutes),
        travelMinutes: travel,
        openUntil: fit.closesAt !== null ? `Open till ${clockLabel(fit.closesAt)}` : undefined,
      },
      group: CATEGORY_GROUP[e.category],
    });
  }

  // Three varied picks: each pick from an already-used color group pays a penalty.
  const picks: Pick[] = [];
  const used = new Map<string, number>();
  const pool = [...scored];
  while (picks.length < count && pool.length) {
    let bestIdx = 0, best = -Infinity;
    pool.forEach((p, i) => {
      const adj = p.score - 1.2 * (used.get(p.group) ?? 0);
      if (adj > best || (adj === best && p.experienceId < pool[bestIdx].experienceId)) { best = adj; bestIdx = i; }
    });
    const [p] = pool.splice(bestIdx, 1);
    used.set(p.group, (used.get(p.group) ?? 0) + 1);
    picks.push({ experienceId: p.experienceId, score: p.score, reasons: p.reasons, facts: p.facts });
  }
  return picks;
}
