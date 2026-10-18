// Place search: turns an extracted candidate into a real place with coordinates and an id.
//
// Apple Maps Server API is the planned default (ledger R14) but needs an Apple Developer
// account to mint a Maps token. Until APPLE_MAPS_AUTH_TOKEN is set, this falls back to
// OpenStreetMap Nominatim (free, no key, 1 request/second) so the spike runs today.

import type { ExtractedPlace } from "./extract.ts";

export interface PlaceMatch {
  provider: "apple_maps" | "openstreetmap";
  /** Provider's stable id; the only lookup field we'd store permanently. */
  placeId: string | null;
  name: string | null;
  address: string | null;
  lat: number;
  lng: number;
  providerCategory: string | null;
  query: string;
  /** How well the result's name matches the extracted name. */
  nameMatch: "strong" | "weak" | "none";
}

const USER_AGENT = "Experience-identify-spike/0.1 (Phase 0 research)";

function tokens(s: string): Set<string> {
  return new Set(
    s.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "")
      .replace(/['’]s\b/g, "").split(/[^a-z0-9]+/)
      .filter((t) => t.length > 1 && !["the", "and", "of", "la", "le", "el"].includes(t)),
  );
}

function nameMatch(extracted: string | null, found: string | null): PlaceMatch["nameMatch"] {
  if (!extracted || !found) return "none";
  const a = tokens(extracted);
  const b = tokens(found);
  if (a.size === 0 || b.size === 0) return "none";
  const shared = [...a].filter((t) => b.has(t)).length;
  const ratio = shared / Math.min(a.size, b.size);
  return ratio >= 0.6 ? "strong" : ratio > 0 ? "weak" : "none";
}

function queriesFor(place: ExtractedPlace): string[] {
  const where = [place.neighborhood, place.city, place.region, place.country].filter(Boolean).join(", ");
  const qs = [
    place.search_query,
    place.name && place.address ? `${place.name}, ${place.address}` : null,
    place.name && where ? `${place.name}, ${where}` : null,
    !place.name && where ? where : null, // activity / natural place with only an area
  ].filter((q): q is string => !!q);
  return [...new Set(qs)];
}

// --- OpenStreetMap Nominatim ------------------------------------------------------------

let lastNominatimCall = 0;

async function nominatim(query: string): Promise<any[]> {
  const wait = lastNominatimCall + 1100 - Date.now(); // usage policy: max 1 request/second
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastNominatimCall = Date.now();
  const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=3&addressdetails=1&accept-language=en&q=${encodeURIComponent(query)}`;
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(10000) });
  return res.ok ? res.json() : [];
}

async function searchOsm(place: ExtractedPlace, query: string): Promise<PlaceMatch | null> {
  const results = await nominatim(query);
  if (results.length === 0) return null;
  const scored = results.map((r) => ({ r, m: nameMatch(place.name, r.name || null) }));
  const best = scored.find((s) => s.m === "strong") ?? scored.find((s) => s.m === "weak") ?? scored[0];
  return {
    provider: "openstreetmap",
    placeId: `osm:${best.r.osm_type}/${best.r.osm_id}`,
    name: best.r.name || null,
    address: best.r.display_name ?? null,
    lat: Number(best.r.lat),
    lng: Number(best.r.lon),
    providerCategory: best.r.type ? `${best.r.category}/${best.r.type}` : null,
    query,
    nameMatch: best.m,
  };
}

// --- Apple Maps Server API (untested until a Maps token exists) --------------------------

let appleAccess: { token: string; expiresAt: number } | null = null;

async function appleAccessToken(authToken: string): Promise<string> {
  if (appleAccess && appleAccess.expiresAt > Date.now() + 60_000) return appleAccess.token;
  const res = await fetch("https://maps-api.apple.com/v1/token", {
    headers: { Authorization: `Bearer ${authToken}` },
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) throw new Error(`Apple Maps token exchange failed: HTTP ${res.status}`);
  const body: any = await res.json();
  appleAccess = { token: body.accessToken, expiresAt: Date.now() + body.expiresInSeconds * 1000 };
  return appleAccess.token;
}

async function searchApple(place: ExtractedPlace, query: string, authToken: string): Promise<PlaceMatch | null> {
  const token = await appleAccessToken(authToken);
  const res = await fetch(`https://maps-api.apple.com/v1/search?lang=en-US&q=${encodeURIComponent(query)}`, {
    headers: { Authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) throw new Error(`Apple Maps search failed: HTTP ${res.status}`);
  const results: any[] = ((await res.json()) as any).results ?? [];
  if (results.length === 0) return null;
  const scored = results.slice(0, 3).map((r) => ({ r, m: nameMatch(place.name, r.name ?? null) }));
  const best = scored.find((s) => s.m === "strong") ?? scored.find((s) => s.m === "weak") ?? scored[0];
  return {
    provider: "apple_maps",
    placeId: best.r.id ?? null,
    name: best.r.name ?? null,
    address: (best.r.formattedAddressLines ?? []).join(", ") || null,
    lat: best.r.coordinate.latitude,
    lng: best.r.coordinate.longitude,
    providerCategory: best.r.poiCategory ?? null,
    query,
    nameMatch: best.m,
  };
}

// --- Public ------------------------------------------------------------------------------

export function providerName(): PlaceMatch["provider"] {
  return process.env.APPLE_MAPS_AUTH_TOKEN ? "apple_maps" : "openstreetmap";
}

/** Tries each query until one gives a strong name match; otherwise returns the best weaker hit. */
export async function findPlace(place: ExtractedPlace): Promise<PlaceMatch | null> {
  if (place.kind === "idea") return null;
  const appleToken = process.env.APPLE_MAPS_AUTH_TOKEN;
  let fallback: PlaceMatch | null = null;
  for (const query of queriesFor(place)) {
    const match = appleToken ? await searchApple(place, query, appleToken) : await searchOsm(place, query);
    if (!match) continue;
    // With no venue name (activity / natural place), an area hit is the best we can do.
    if (match.nameMatch === "strong" || !place.name) return match;
    if (!fallback || (match.nameMatch === "weak" && fallback.nameMatch === "none")) fallback = match;
  }
  return fallback;
}
