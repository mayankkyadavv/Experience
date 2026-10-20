// Fill in coordinates for catalog entries that have a place but none yet.
// OpenStreetMap Nominatim, one request per second, results cached in catalog/<city>/_geocache.json (dev only).
//
//   deno run -A tools/catalog/geocode.ts --city philadelphia

import { parseArgs } from "jsr:@std/cli@1/parse-args";
import { Entry } from "./schema.ts";

const args = parseArgs(Deno.args, { string: ["city"], default: { city: "philadelphia" } });
const root = new URL("../../", import.meta.url);
const dir = new URL(`catalog/${args.city}/`, root);
const cacheFile = new URL("_geocache.json", dir);
const cache: Record<string, { lat: number; lng: number } | null> = await Deno.readTextFile(cacheFile).then(JSON.parse).catch(() => ({}));

// Results must land inside this box (Philadelphia plus a small margin); anything else is a wrong match.
const BOX: Record<string, [number, number, number, number]> = { philadelphia: [-75.32, 39.85, -74.93, 40.16] };
const box = BOX[args.city];

async function nominatim(q: string) {
  if (q in cache) return cache[q];
  await new Promise((r) => setTimeout(r, 1100));
  const params = new URLSearchParams({ format: "json", limit: "1", q });
  if (box) params.set("viewbox", box.join(",")), params.set("bounded", "1");
  const res = await fetch(`https://nominatim.openstreetmap.org/search?${params}`, {
    headers: { "User-Agent": "Experience-catalog/0.1 (dev)" },
  });
  const [hit] = res.ok ? await res.json() : [];
  cache[q] = hit ? { lat: Number(hit.lat), lng: Number(hit.lon) } : null;
  return cache[q];
}

let found = 0, missing = 0;
for await (const f of Deno.readDir(dir)) {
  if (!f.name.endsWith(".json") || f.name.startsWith("_")) continue;
  const url = new URL(f.name, dir);
  const entry = Entry.parse(JSON.parse(await Deno.readTextFile(url)));
  if (!entry.place || entry.coordinates) continue;
  const city = args.city.replace(/-/g, " ");
  const withCity = (q: string) => q.toLowerCase().includes(city) ? q : `${q}, ${city}`;
  // Nominatim doesn't know floors or suites.
  const street = entry.place.address?.replace(/,?\s*(floor|fl\.?|level|suite|ste\.?|unit|#)\s*[\w-]+/gi, "").trim();
  const queries = [
    entry.place.address && withCity(entry.place.address),
    street && street !== entry.place.address && withCity(street),
    withCity(entry.place.name),
    entry.place.neighborhood && withCity(`${entry.place.name}, ${entry.place.neighborhood}`),
  ].filter(Boolean) as string[];
  let hit: { lat: number; lng: number } | null = null;
  for (const q of queries) if ((hit = await nominatim(q))) break;
  if (hit) {
    entry.coordinates = hit;
    entry.provenance.coordinates = "lookup";
    await Deno.writeTextFile(url, JSON.stringify(entry, null, 2) + "\n");
    found++;
  } else {
    missing++;
    console.log(`  no match: ${entry.slug} (${queries[0]})`);
  }
  await Deno.writeTextFile(cacheFile, JSON.stringify(cache, null, 2) + "\n");
}
console.log(`geocoded ${found}, no match ${missing}`);
