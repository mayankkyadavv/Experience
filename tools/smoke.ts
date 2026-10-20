// End-to-end check of the local stack: sign up, pick Philadelphia, ask "What should we do?",
// give feedback on the picks, ask again.
//
//   docker compose run --rm tools deno task smoke    # inside Docker
//   deno task smoke                                   # from your Mac (defaults to http://localhost:54321)
//   deno task smoke -- --when weekend --hours 4 --budget 50 --who date --mood something_new

import { parseArgs } from "jsr:@std/cli@1/parse-args";
import { createClient } from "npm:@supabase/supabase-js@2";

const LOCAL_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6ImV4cGVyaWVuY2UtbG9jYWwiLCJpYXQiOjE3NjAwMDAwMDAsImV4cCI6MjI0MDAwMDAwMH0.q95zZrpDTV16yQ5rgAooYQPzmX5ZCE_Ps3Th8xGS1RI";

const args = parseArgs(Deno.args, {
  string: ["when", "who", "mood", "budget", "hours", "likes"],
  default: { when: "tonight", who: "friends", hours: "3", budget: "60", likes: "comedy,live_music,food" },
});
const url = Deno.env.get("SUPABASE_URL") ?? "http://localhost:54321";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? LOCAL_ANON_KEY;

function fail(step: string, detail: unknown): never {
  console.error(`✗ ${step}: ${typeof detail === "string" ? detail : JSON.stringify(detail)}`);
  console.error(`  Is the stack up? Run \`docker compose up -d\` and check \`docker compose ps\`.`);
  Deno.exit(1);
}

const supabase = createClient(url, anonKey, { auth: { persistSession: false } });

const email = `smoke-${crypto.randomUUID().slice(0, 8)}@example.com`;
const { data: signUp, error: signUpError } = await supabase.auth.signUp({ email, password: crypto.randomUUID() });
if (signUpError || !signUp.session) fail("sign up", signUpError?.message ?? "no session returned");
console.log(`✓ signed up ${email}`);

const likes = args.likes.split(",").map((s) => s.trim()).filter(Boolean);
const { error: profileError } = await supabase.from("profiles")
  .upsert({ user_id: signUp.user!.id, city_id: "philadelphia", onboarding: { likes }, onboarded_at: new Date().toISOString() });
if (profileError) fail("profile", profileError.message);
console.log(`✓ city philadelphia, likes ${likes.join(", ")}`);

const constraints = {
  when: args.when,
  hours: Number(args.hours),
  budget: args.budget === "any" ? null : Number(args.budget),
  who: args.who,
  ...(args.mood ? { mood: args.mood } : {}),
};
// deno-lint-ignore no-explicit-any
type Pick = any;
async function ask(): Promise<{ requestId: string | null; picks: Pick[] }> {
  const res = await fetch(`${url}/functions/v1/recommend`, {
    method: "POST",
    headers: { Authorization: `Bearer ${signUp.session!.access_token}`, apikey: anonKey, "content-type": "application/json" },
    body: JSON.stringify(constraints),
  });
  const body = await res.json().catch(() => null);
  if (!res.ok) fail(`recommend (HTTP ${res.status})`, body);
  return body;
}

const body = await ask();
console.log(`✓ recommend ${JSON.stringify(constraints)}\n`);
print(body.picks);

if (body.picks.length >= 3) {
  const [a, b, c] = body.picks.map((p: Pick) => p.experience);
  const fb = async (experience: Pick, action: string, rating?: number) => {
    const { error } = await supabase.rpc("record_feedback", {
      p_experience_id: experience.id, p_action: action, p_rating: rating, p_recommendation_id: body.requestId,
    });
    if (error) fail(`feedback ${action}`, error.message);
  };
  await fb(a, "save");
  await fb(b, "not_interested");
  await fb(c, "done");
  await fb(c, "rate", 3);
  console.log(`\n✓ feedback: saved "${a.title}", not interested in "${b.title}", did and loved "${c.title}"`);

  const again = await ask();
  const ids = again.picks.map((p: Pick) => p.experience.id);
  if (ids.includes(b.id) || ids.includes(c.id)) fail("re-ask", "a not-interested or done Experience came back");
  console.log("✓ asked again: not-interested and done picks are gone\n");
  print(again.picks);
}

function print(picks: Pick[]) {
  if (picks.length === 0) console.log("  No picks fit. Try --when weekend, a longer --hours, or --budget any.");
  for (const [i, p] of picks.entries()) {
    const est = (field: string) => p.experience.provenance?.[field] === "estimated" ? " (estimated)" : "";
    const facts = [p.facts.price, p.facts.duration, p.facts.openUntil].filter(Boolean).join(" · ");
    console.log(`  ${i + 1}. ${p.experience.title}${est("title")}  [${p.experience.category}]`);
    if (p.experience.place) console.log(`     ${p.experience.place.name}${p.experience.place.neighborhood ? `, ${p.experience.place.neighborhood}` : ""}`);
    if (facts) console.log(`     ${facts}`);
    for (const r of p.reasons) console.log(`     · ${r}`);
  }
}
