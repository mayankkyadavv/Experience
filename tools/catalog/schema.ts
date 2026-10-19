// A catalog Experience as stored in catalog/<city>/<slug>.json (ADR-009).
// Drafts are AI-researched and every fact is `estimated`; the founder reviews an entry,
// fixes it, and sets status "reviewed", which publishes it with `curated` provenance.

import { z } from "npm:zod@4";

export const CATEGORIES = [
  "food", "cafe", "dessert", "bar", "nightlife", "music", "comedy", "arts_culture", "attraction",
  "outdoors", "sports", "active", "class", "games", "shopping", "market", "event", "wellness", "lodging", "other",
] as const;
export const OCCASIONS = ["solo", "date", "friends", "group", "family"] as const;

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, "HH:MM, 24-hour");
const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "YYYY-MM-DD");
const range = (max: number) => z.object({ min: z.number().min(0).max(max), max: z.number().min(0).max(max) })
  .refine((r) => r.max >= r.min, "max must be ≥ min");

export const Provenance = z.enum(["curated", "estimated", "lookup"]);

/** The researched facts. Shared by the drafter's tool schema and the stored entry. */
export const Facts = z.object({
  title: z.string().min(3).max(80).describe("The activity in words, e.g. 'Night tour of Eastern State Penitentiary', not just the venue name"),
  intent: z.string().max(160).nullable().describe("Why someone would do this, one short sentence"),
  description: z.string().min(20).max(400).describe("What it is and what to expect, 1-3 plain sentences, no hype"),
  category: z.enum(CATEGORIES),
  tags: z.array(z.string().max(30)).max(8).describe("Lowercase, e.g. 'unusual', 'seasonal', 'rainy-day', 'cheap', 'outdoor-seating'"),
  good_for: z.array(z.enum(OCCASIONS)).describe("Who it suits"),
  location_requirement: z.enum(["exact", "flexible", "none"]),
  place: z.object({
    name: z.string(),
    address: z.string().nullable(),
    neighborhood: z.string().nullable().describe("Philadelphia neighborhood, e.g. 'Fishtown', 'Old City'"),
  }).nullable(),
  price_usd: range(1000).nullable().describe("Typical cost per person in US dollars; {min:0,max:0} = free; null if unknown"),
  duration_minutes: range(24 * 60).nullable().describe("Typical time spent"),
  group_size: range(100).nullable().describe("Sensible group size range"),
  hours: z.array(z.object({ day: z.number().int().min(0).max(6).describe("0 = Sunday"), open: hhmm, close: hhmm }))
    .describe("Weekly opening hours; close earlier than open means past midnight; [] if no fixed hours"),
  dates: z.array(z.object({ start: isoDate, end: isoDate })).describe("Only for seasonal or dated things; [] if year-round"),
  sources: z.array(z.string().url()).describe("Pages the facts came from (official site first)"),
  uncertain: z.array(z.string()).describe("Fields you could not verify"),
});
export type Facts = z.infer<typeof Facts>;

export const Entry = Facts.extend({
  slug: z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/),
  city: z.string(),
  status: z.enum(["draft", "reviewed", "archived"]),
  coordinates: z.object({ lat: z.number(), lng: z.number() }).nullable(),
  image_url: z.string().url().nullable(),
  provenance: z.record(z.string(), Provenance),
  notes: z.string().optional(),
  drafted_at: z.string().optional(),
  model: z.string().optional(),
});
export type Entry = z.infer<typeof Entry>;

export const slugify = (s: string) =>
  s.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "").replace(/['’]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 60);
