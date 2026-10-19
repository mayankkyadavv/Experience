// POST /functions/v1/recommend  { when, hours, budget, who, groupSize?, mood?, location? }
// → { requestId, picks: [{ experience, score, reasons, facts }] }
//
// Reads with the caller's JWT (RLS applies), writes the request log with the service role.

import { createClient } from "npm:@supabase/supabase-js@2";
import { type CandidateExperience, type Constraints, type Mood, recommend, type UserState, type Who } from "./core.ts";
import { toLocal, type When } from "./time.ts";

const WHEN: When[] = ["now", "tonight", "tomorrow", "weekend"];
const WHO: Who[] = ["solo", "date", "friends", "group", "family"];
const MOOD: Mood[] = ["chill", "active", "food", "creative", "nightlife", "outdoors", "something_new", "surprise"];

function parseConstraints(b: Record<string, unknown>): Constraints | string {
  if (!WHEN.includes(b.when as When)) return "when must be one of " + WHEN.join(", ");
  if (typeof b.hours !== "number" || b.hours <= 0 || b.hours > 16) return "hours must be a number between 0 and 16";
  if (b.budget !== null && (typeof b.budget !== "number" || b.budget < 0)) return "budget must be null or a non-negative number";
  if (!WHO.includes(b.who as Who)) return "who must be one of " + WHO.join(", ");
  if (b.mood !== undefined && !MOOD.includes(b.mood as Mood)) return "mood must be one of " + MOOD.join(", ");
  const loc = b.location as { lat?: unknown; lng?: unknown } | undefined;
  if (loc !== undefined && (typeof loc?.lat !== "number" || typeof loc?.lng !== "number")) return "location must be { lat, lng }";
  return {
    when: b.when as When, hours: b.hours, budget: b.budget as number | null, who: b.who as Who,
    groupSize: typeof b.groupSize === "number" ? b.groupSize : undefined, mood: b.mood as Mood | undefined,
    location: loc as Constraints["location"],
  };
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });
  const auth = req.headers.get("Authorization");
  if (!auth) return json(401, { error: "Missing Authorization" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return json(401, { error: "Not signed in" });

  const constraints = parseConstraints(await req.json().catch(() => ({})));
  if (typeof constraints === "string") return json(400, { error: constraints });

  const { data: profile } = await asUser.from("profiles").select("city_id, onboarding").eq("user_id", user.id).maybeSingle();
  if (!profile?.city_id) return json(409, { error: "Pick a city first" });
  const { data: city } = await asUser.from("cities").select("id, timezone").eq("id", profile.city_id).single();
  if (!city) return json(409, { error: "Unknown city" });

  const [{ data: rows, error }, { data: states }] = await Promise.all([
    asUser.from("experiences")
      .select("*, experience_places(role, places(lat, lng, name, neighborhood))")
      .eq("city_id", city.id)
      .eq("status", "published"),
    asUser.from("user_experiences").select("*, experiences(category)"),
  ]);
  if (error) return json(500, { error: error.message });

  // deno-lint-ignore no-explicit-any
  const primaryPlace = (r: any) => (r.experience_places ?? []).find((p: any) => p.role === "primary")?.places ?? null;
  // deno-lint-ignore no-explicit-any
  const candidates: CandidateExperience[] = (rows ?? []).map((r: any) => ({
    id: r.id, title: r.title, category: r.category, tags: r.tags, goodFor: r.good_for,
    priceMinCents: r.price_min_cents, priceMaxCents: r.price_max_cents,
    durationMinMinutes: r.duration_min_minutes, durationMaxMinutes: r.duration_max_minutes,
    groupMin: r.group_min, groupMax: r.group_max, hours: r.hours, dates: r.dates,
    place: primaryPlace(r)?.lat != null ? { lat: primaryPlace(r).lat, lng: primaryPlace(r).lng } : null,
  }));
  // deno-lint-ignore no-explicit-any
  const userStates: UserState[] = (states ?? []).map((s: any) => ({
    experienceId: s.experience_id, category: s.experiences?.category ?? "other",
    savedAt: s.saved_at ?? undefined, interestedAt: s.interested_at ?? undefined,
    notInterestedAt: s.not_interested_at ?? undefined, doneAt: s.done_at ?? undefined, rating: s.rating ?? undefined,
  }));

  const picks = recommend({
    constraints, nowLocal: toLocal(Date.now(), city.timezone), candidates, states: userStates,
    profile: { likes: (profile.onboarding?.likes as string[]) ?? [] },
  });

  const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: logged } = await service.from("recommendation_requests")
    .insert({ user_id: user.id, city_id: city.id, constraints, results: picks })
    .select("id").single();

  const byId = new Map((rows ?? []).map((r: { id: string }) => [r.id, r]));
  return json(200, {
    requestId: logged?.id ?? null,
    picks: picks.map((p) => {
      // deno-lint-ignore no-explicit-any
      const r: any = byId.get(p.experienceId);
      const place = primaryPlace(r);
      return {
        experience: {
          id: r.id, title: r.title, category: r.category, imageUrl: r.image_url, provenance: r.provenance,
          place: place ? { name: place.name, neighborhood: place.neighborhood, lat: place.lat, lng: place.lng } : null,
        },
        score: p.score, reasons: p.reasons, facts: p.facts,
      };
    }),
  });
});
