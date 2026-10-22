// Builds the sample profile used to show the app: a fictional person, clearly labelled "Sample profile" in the app
// (profiles.is_sample), in its own local account. Never run against a real person's account: the brief forbids
// inventing history in a real archive (§19). Everything it makes can be removed with --remove.
//
//   swift tools/demo/gradients.swift                       # once, on the Mac: renders the placeholder images
//   docker compose run --rm tools deno task demo           # build (or rebuild) the sample profile
//   docker compose run --rm tools deno task demo --remove  # delete it and its media
//
// Sign in as it from the app: Settings → Developer → Use the sample profile (Debug builds).

import { parseArgs } from "jsr:@std/cli@1/parse-args";
import { createClient } from "npm:@supabase/supabase-js@2";

const LOCAL_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6ImV4cGVyaWVuY2UtbG9jYWwiLCJpYXQiOjE3NjAwMDAwMDAsImV4cCI6MjI0MDAwMDAwMH0.q95zZrpDTV16yQ5rgAooYQPzmX5ZCE_Ps3Th8xGS1RI";
export const SAMPLE_EMAIL = "sample@experiences.local";
export const SAMPLE_PASSWORD = "experiences-sample-profile";

const args = parseArgs(Deno.args, { boolean: ["remove"], string: ["seed"], default: { seed: "2026" } });
const url = Deno.env.get("SUPABASE_URL") ?? "http://localhost:54321";
if (!/localhost|127\.0\.0\.1|gateway/.test(url)) {
  console.error("Refusing to run against a non-local backend: sample profiles are for the local stack only.");
  Deno.exit(1);
}
const db = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? LOCAL_ANON_KEY, { auth: { persistSession: false } });
const IMAGES = new URL("./.images/", import.meta.url);

// Deterministic randomness, so the same seed builds the same profile.
let state = Number(args.seed) >>> 0 || 1;
const rand = () => {
  state = (state + 0x6d2b79f5) >>> 0;
  let t = state;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const pick = <T>(xs: T[]) => xs[Math.floor(rand() * xs.length)];
const shuffle = <T>(xs: T[]) => xs.map((x) => [rand(), x] as const).sort((a, b) => a[0] - b[0]).map(([, x]) => x);
const between = (lo: number, hi: number) => Math.floor(lo + rand() * (hi - lo + 1));

// --- Account -----------------------------------------------------------------------------------------------

let session = (await db.auth.signInWithPassword({ email: SAMPLE_EMAIL, password: SAMPLE_PASSWORD })).data.session;
if (!session) {
  const { data, error } = await db.auth.signUp({ email: SAMPLE_EMAIL, password: SAMPLE_PASSWORD });
  if (error || !data.session) throw new Error(`sign up: ${error?.message}`);
  session = data.session;
}
const me = session.user.id;

async function removeEverything() {
  // Storage first (the rows say where the files are), then rows; media rows go with their Experiences.
  const { data: folders } = await db.storage.from("media").list(me, { limit: 1000 });
  for (const f of folders ?? []) {
    const { data: files } = await db.storage.from("media").list(`${me}/${f.name}`, { limit: 1000 });
    const paths = (files ?? []).map((x) => `${me}/${f.name}/${x.name}`);
    if (paths.length) await db.storage.from("media").remove(paths);
  }
  await db.from("collections").delete().eq("owner_id", me);
  await db.from("experiences").delete().eq("owner_id", me);
}

await removeEverything();
if (args.remove) {
  await db.from("profiles").update({ is_sample: true, bio: null, display_name: null, username: null }).eq("user_id", me);
  console.log("✓ removed the sample profile's Experiences, collections and media");
  Deno.exit(0);
}

try {
  await Deno.stat(new URL("food-1.jpg", IMAGES));
} catch {
  console.error("No placeholder images. Run `swift tools/demo/gradients.swift` on the Mac first.");
  Deno.exit(1);
}

const { error: profileError } = await db.from("profiles").upsert({
  user_id: me, city_id: "philadelphia", onboarded_at: new Date().toISOString(), is_sample: true,
  display_name: "Jordan Lee", username: "jordan_sample", bio: "Philly food, late nights, and a few big trips.",
  onboarding: { likes: ["food", "live_music", "nightlife", "arts_culture"] },
});
if (profileError) throw profileError;
console.log(`✓ signed in as the sample profile (${SAMPLE_EMAIL})`);

// --- Building blocks ---------------------------------------------------------------------------------------

type Theme = "food" | "night" | "sights" | "festival" | "sea" | "city" | "nature" | "home";
type Plan = {
  id: string;
  title: string;
  state?: "want" | "experienced";
  categories: string[];
  start?: string; // ISO with offset
  end?: string;
  precision?: string;
  timezone?: string;
  place?: { name: string; locality: string; lat: number; lng: number; cityId?: string };
  listingId?: string;
  description?: string;
  theme?: Theme;
  photos?: number;
  visibility?: "private" | "public";
};

const used = new Map<Theme, number>();
function nextImage(theme: Theme) {
  const n = (used.get(theme) ?? between(0, 7)) % 8 + 1;
  used.set(theme, n);
  return `${theme}-${n}`;
}

/** Local wall-clock time in a zone, as an ISO instant (Intl gives the zone's offset at that moment). */
function at(date: string, time: string, tz: string) {
  const guess = new Date(`${date}T${time}:00Z`);
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: tz, timeZoneName: "longOffset" }).formatToParts(guess);
  const off = parts.find((p) => p.type === "timeZoneName")?.value.replace("GMT", "") || "+00:00";
  return new Date(`${date}T${time}:00${off === "" ? "+00:00" : off}`).toISOString();
}

const plans: Plan[] = [];
const collections: { title: string; kind: string; visibility: string; members: string[] }[] = [];

// --- Philadelphia, from the real catalog --------------------------------------------------------------------

const PHL = "America/New_York";
const { data: listings, error: listErr } = await db.from("listings")
  .select("id, title, category, listing_places(role, places(name, neighborhood, lat, lng))")
  .eq("city_id", "philadelphia").eq("status", "published");
if (listErr) throw listErr;
// deno-lint-ignore no-explicit-any
const withPlace = (listings ?? []).filter((l: any) => l.listing_places?.some((p: any) => p.role === "primary" && p.places?.lat));
const groups: Record<string, string[]> = {
  food: ["food", "cafe", "dessert", "market"],
  night: ["bar", "nightlife", "music", "comedy"],
  sights: ["arts_culture", "attraction"],
};
const life: Record<string, string> = {
  food: "food", cafe: "food", dessert: "food", market: "food", bar: "nightlife", nightlife: "nightlife",
  music: "music", comedy: "arts_culture", arts_culture: "arts_culture", attraction: "arts_culture",
};
const words: Record<string, string[]> = {
  food: ["Worth the wait.", "Ordered too much and regret nothing.", "Sat by the window until they started stacking chairs.",
    "The kind of place I'd take someone visiting.", "Went back for seconds the next week."],
  night: ["Didn't plan to stay out that late.", "Danced more than I meant to.", "Walked home the long way.",
    "Found a corner table and talked for hours."],
  sights: ["Took the slow way through.", "Brought a friend who'd never been.", "Quiet on a weekday morning.",
    "Stayed until they turned the lights down."],
};

// A random day between two dates, with an hour that fits the kind of thing.
function phillyDay(from: Date, to: Date, kind: string) {
  const d = new Date(from.getTime() + rand() * (to.getTime() - from.getTime()));
  const day = d.toISOString().slice(0, 10);
  const hour = kind === "night" ? between(20, 22) : kind === "food" ? pick([11, 12, 13, 18, 19, 20]) : between(10, 16);
  return { day, start: at(day, `${String(hour).padStart(2, "0")}:${pick(["00", "15", "30", "45"])}`, PHL) };
}

const chosen: Record<string, ReturnType<typeof shuffle>> = {};
for (const [kind, cats] of Object.entries(groups)) {
  // deno-lint-ignore no-explicit-any
  chosen[kind] = shuffle(withPlace.filter((l: any) => cats.includes(l.category)));
}
const counts: Record<string, number> = { food: 9, night: 8, sights: 6 };
const summer: string[] = [], dates: string[] = [];
const range = { from: new Date("2024-03-01"), to: new Date("2026-10-19") };
for (const [kind, n] of Object.entries(counts)) {
  // deno-lint-ignore no-explicit-any
  for (const l of (chosen[kind] as any[]).slice(0, n)) {
    const place = l.listing_places.find((p: { role: string }) => p.role === "primary").places;
    const inSummer = summer.length < 5 && rand() < 0.35;
    const when = inSummer ? phillyDay(new Date("2025-06-05"), new Date("2025-08-28"), kind) : phillyDay(range.from, range.to, kind);
    const id = crypto.randomUUID();
    plans.push({
      id, title: l.title, categories: [life[l.category]], start: when.start, precision: rand() < 0.4 ? "exact" : "day", timezone: PHL,
      place: { name: place.name, locality: [place.neighborhood, "Philadelphia"].filter(Boolean).join(", "), lat: place.lat, lng: place.lng, cityId: "philadelphia" },
      listingId: l.id, description: rand() < 0.45 ? pick(words[kind]) : undefined,
      theme: kind === "night" ? "night" : kind === "food" ? "food" : pick(["sights", "city"] as Theme[]),
      photos: rand() < 0.22 ? 0 : between(1, 4), visibility: rand() < 0.35 ? "public" : "private",
    });
    if (inSummer) summer.push(id);
    if (kind !== "sights" && rand() < 0.5 && dates.length < 5) dates.push(id);
  }
}
collections.push({ title: "Summer in Philly 2025", kind: "season", visibility: "public", members: summer });
collections.push({ title: "Date nights", kind: "ritual", visibility: "private", members: dates });

// Wants: a few more listings, saved for someday.
// deno-lint-ignore no-explicit-any
for (const l of [...(chosen.food as any[]).slice(9, 11), ...(chosen.night as any[]).slice(8, 10), ...(chosen.sights as any[]).slice(6, 7)]) {
  const place = l.listing_places.find((p: { role: string }) => p.role === "primary").places;
  plans.push({
    id: crypto.randomUUID(), title: l.title, state: "want", categories: [life[l.category]], listingId: l.id,
    place: { name: place.name, locality: [place.neighborhood, "Philadelphia"].filter(Boolean).join(", "), lat: place.lat, lng: place.lng, cityId: "philadelphia" },
    theme: l.category in { bar: 1, nightlife: 1, music: 1, comedy: 1 } ? "night" : "food", photos: 0,
  });
}

// --- Around the world: real places, each in its own timezone ----------------------------------------------

function trip(title: string, kind: string, visibility: string, tz: string,
              stops: [string, string, string, number, number, string, string, Theme, number, string?][]) {
  const members: string[] = [];
  for (const [t, date, time, lat, lng, name, locality, theme, photos, description] of stops) {
    const id = crypto.randomUUID();
    plans.push({
      id, title: t, categories: theme === "food" ? ["food", "travel"] : theme === "festival" ? ["music", "travel"] : ["travel"],
      start: at(date, time, tz), precision: "exact", timezone: tz, place: { name, locality, lat, lng },
      theme, photos, description, visibility: visibility as Plan["visibility"],
    });
    members.push(id);
  }
  collections.push({ title, kind, visibility, members });
}

trip("Barcelona 2024", "trip", "public", "Europe/Madrid", [
  ["Sagrada Família in the morning light", "2024-06-08", "09:30", 41.4036, 2.1744, "Sagrada Família", "Eixample, Barcelona", "sights", 5, "Couldn't stop looking up."],
  ["Tapas crawl through El Born", "2024-06-08", "20:45", 41.3851, 2.1823, "El Born", "El Born, Barcelona", "food", 4],
  ["A swim at Barceloneta", "2024-06-10", "16:00", 41.3784, 2.1925, "Barceloneta Beach", "Barceloneta, Barcelona", "sea", 3],
  ["Park Güell", "2024-06-11", "10:15", 41.4145, 2.1527, "Park Güell", "Gràcia, Barcelona", "sights", 4],
  ["Sunset from the Bunkers del Carmel", "2024-06-12", "21:10", 41.4194, 2.1617, "Bunkers del Carmel", "El Carmel, Barcelona", "city", 3, "Half the city was up there with us."],
]);
trip("Tomorrowland 2025", "event", "public", "Europe/Brussels", [
  ["Tomorrowland, day one", "2025-07-18", "14:00", 51.0911, 4.3713, "De Schorre", "Boom", "festival", 5],
  ["Mainstage at sunset", "2025-07-19", "21:30", 51.0911, 4.3713, "De Schorre", "Boom", "festival", 4, "The whole field went quiet for a second, then didn't."],
  ["Mornings at DreamVille", "2025-07-20", "10:00", 51.0937, 4.3651, "DreamVille", "Boom", "nature", 2],
  ["Last night at Tomorrowland", "2025-07-20", "23:40", 51.0911, 4.3713, "De Schorre", "Boom", "festival", 5],
]);
trip("Tokyo, spring 2026", "trip", "private", "Asia/Tokyo", [
  ["Shibuya Crossing after dark", "2026-04-02", "20:30", 35.6595, 139.7005, "Shibuya Crossing", "Shibuya, Tokyo", "city", 4],
  ["Breakfast at Tsukiji Outer Market", "2026-04-03", "07:45", 35.6654, 139.7707, "Tsukiji Outer Market", "Chūō, Tokyo", "food", 4, "Tamagoyaki on a stick at 8 a.m."],
  ["teamLab Planets", "2026-04-03", "18:00", 35.6491, 139.7898, "teamLab Planets", "Kōtō, Tokyo", "festival", 3],
  ["Cherry blossoms along the Meguro River", "2026-04-05", "17:20", 35.6416, 139.698, "Meguro River", "Meguro, Tokyo", "nature", 5],
]);
trip("Iceland 2023", "trip", "private", "Atlantic/Reykjavik", [
  ["Northern lights outside Reykjavík", "2023-02-17", "23:15", 64.1466, -21.9426, "Grótta lighthouse", "Seltjarnarnes, Reykjavík", "nature", 3, "Green for about ten minutes, then gone."],
  ["Blue Lagoon in the snow", "2023-02-18", "15:00", 63.8804, -22.4495, "Blue Lagoon", "Grindavík", "sea", 2],
]);

// Quieter things: no photos, honest about time.
plans.push({ id: crypto.randomUUID(), title: "The summer I learned to swim", categories: ["milestones"], start: "2009-06-01T04:00:00Z",
  end: "2009-08-31T23:59:00Z", precision: "season", timezone: PHL, photos: 0 });
plans.push({ id: crypto.randomUUID(), title: "First apartment in Philly", categories: ["milestones"], start: "2022-08-01T04:00:00Z",
  end: "2022-08-31T23:59:00Z", precision: "month", timezone: PHL, description: "Two boxes and a mattress on the floor.", photos: 0 });
plans.push({ id: crypto.randomUUID(), title: "Thanksgiving at home", categories: ["everyday"], start: at("2024-11-28", "17:00", PHL),
  precision: "day", timezone: PHL, theme: "home", photos: 3, description: "Everyone stayed for pie." });
plans.push({ id: crypto.randomUUID(), title: "Hike in the Dolomites", state: "want", categories: ["outdoors", "travel"], photos: 0 });
plans.push({ id: crypto.randomUUID(), title: "Night market in Taipei", state: "want", categories: ["food", "travel"], photos: 0 });

// --- Write it ---------------------------------------------------------------------------------------------

const experienceRows = plans.map((p) => ({
  id: p.id, save_id: p.id, title: p.title, state: p.state ?? "experienced", categories: p.categories,
  starts_at: p.start ?? null, ends_at: p.end ?? null, time_precision: p.start ? p.precision ?? "day" : "unknown",
  timezone: p.start ? p.timezone ?? null : null, description: p.description ?? null, visibility: p.visibility ?? "private",
  place_name: p.place?.name ?? null, place_locality: p.place?.locality ?? null, place_lat: p.place?.lat ?? null,
  place_lng: p.place?.lng ?? null, city_id: p.place?.cityId ?? null, listing_id: p.listingId ?? null,
  completed_at: (p.state ?? "experienced") === "experienced" ? p.start ?? new Date().toISOString() : null,
}));
const { error: expErr } = await db.from("experiences").insert(experienceRows);
if (expErr) throw expErr;
console.log(`✓ ${plans.filter((p) => p.state !== "want").length} Experiences, ${plans.filter((p) => p.state === "want").length} Want to Experience`);

let uploaded = 0;
const mediaRows = [];
const covers: [string, string][] = [];
for (const p of plans) {
  for (let i = 0; i < (p.photos ?? 0); i++) {
    const image = nextImage(p.theme ?? "city");
    const clientId = crypto.randomUUID();
    const base = `${me}/${p.id}/${clientId}`;
    const original = await Deno.readFile(new URL(`${image}.jpg`, IMAGES));
    const thumb = await Deno.readFile(new URL(`${image}.thumb.jpg`, IMAGES));
    const a = await db.storage.from("media").upload(`${base}.jpg`, original, { contentType: "image/jpeg", upsert: true });
    const b = await db.storage.from("media").upload(`${base}.thumb.jpg`, thumb, { contentType: "image/jpeg", upsert: true });
    if (a.error || b.error) throw a.error ?? b.error;
    const portrait = Number(image.split("-")[1]) % 3 !== 0;
    mediaRows.push({
      id: clientId, experience_id: p.id, client_id: clientId, kind: "photo", position: i, status: "ready",
      original_path: `${base}.jpg`, thumb_path: `${base}.thumb.jpg`, width: portrait ? 900 : 1200, height: portrait ? 1200 : 900,
      byte_size: original.byteLength, content_type: "image/jpeg", taken_at: p.start ?? null,
      alt_text: "Placeholder image for the sample profile",
    });
    if (i === 0) covers.push([p.id, clientId]);
    uploaded++;
  }
}
if (mediaRows.length) {
  const { error } = await db.from("media_assets").insert(mediaRows);
  if (error) throw error;
}
for (const [exp, media] of covers) await db.from("experiences").update({ cover_media_id: media }).eq("id", exp);
console.log(`✓ ${uploaded} placeholder photos uploaded`);

for (const c of collections) {
  const { data, error } = await db.from("collections").insert({ title: c.title, kind: c.kind, visibility: c.visibility }).select("id").single();
  if (error) throw error;
  // Members in the order they happened.
  const order = c.members.map((id) => plans.find((p) => p.id === id)!).sort((a, b) => (a.start ?? "").localeCompare(b.start ?? ""));
  const { error: itemsErr } = await db.from("collection_items").insert(order.map((p, position) => ({ collection_id: data.id, experience_id: p.id, position })));
  if (itemsErr) throw itemsErr;
}
console.log(`✓ ${collections.length} collections: ${collections.map((c) => c.title).join(", ")}`);
console.log("\nSign in from the app: You → Settings → Developer → Use the sample profile");
