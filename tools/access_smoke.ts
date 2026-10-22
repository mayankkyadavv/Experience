// Live check of the one access rule against the local stack (brief §9, §24): the same rule must govern an
// Experience's row, its media rows and the media files in Storage, for owner, stranger, friend, blocked
// and logged-out viewers, and revoking must fail closed everywhere.
//
//   docker compose run --rm tools deno task access     # inside Docker
//   deno task access                                    # from your Mac (defaults to http://localhost:54321)

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const LOCAL_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6ImV4cGVyaWVuY2UtbG9jYWwiLCJpYXQiOjE3NjAwMDAwMDAsImV4cCI6MjI0MDAwMDAwMH0.q95zZrpDTV16yQ5rgAooYQPzmX5ZCE_Ps3Th8xGS1RI";
const url = Deno.env.get("SUPABASE_URL") ?? "http://localhost:54321";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? LOCAL_ANON_KEY;

let failures = 0;
function check(what: string, ok: boolean) {
  console.log(`${ok ? "✓" : "✗"} ${what}`);
  if (!ok) failures++;
}

async function person(name: string): Promise<{ db: SupabaseClient; id: string }> {
  const db = createClient(url, anonKey, { auth: { persistSession: false } });
  const { data, error } = await db.auth.signUp({ email: `${name}-${crypto.randomUUID().slice(0, 8)}@example.com`, password: crypto.randomUUID() });
  if (error || !data.user) throw new Error(`sign up ${name}: ${error?.message}`);
  return { db, id: data.user.id };
}

const alice = await person("alice");
const bob = await person("bob");
const carol = await person("carol");
const anon = createClient(url, anonKey, { auth: { persistSession: false } });

// Alice keeps a private memory with one photo.
const { data: exp, error: expErr } = await alice.db.from("experiences")
  .insert({ title: "Tea and a long conversation", time_precision: "day", starts_at: "2026-10-18T16:00:00Z", timezone: "America/New_York" })
  .select().single();
if (expErr) throw expErr;
check("a new Experience is private by default", exp.visibility === "private");

const clientId = crypto.randomUUID();
const path = `${alice.id}/${exp.id}/${clientId}.jpg`;
const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const up = await alice.db.storage.from("media").upload(path, bytes, { contentType: "image/jpeg", upsert: true });
check("the owner uploads into their own folder", !up.error);
const again = await alice.db.storage.from("media").upload(path, bytes, { contentType: "image/jpeg", upsert: true });
check("a retried upload of the same file is harmless", !again.error);
const { error: maErr } = await alice.db.from("media_assets")
  .insert({ experience_id: exp.id, client_id: clientId, kind: "photo", original_path: path, status: "ready" });
check("the owner records the media", !maErr);

const intruder = await bob.db.storage.from("media").upload(`${alice.id}/${exp.id}/evil.jpg`, bytes, { contentType: "image/jpeg" });
check("nobody writes into someone else's folder", !!intruder.error);

async function sees(who: SupabaseClient) {
  const row = (await who.from("experiences").select("id").eq("id", exp.id)).data?.length === 1;
  const media = (await who.from("media_assets").select("id").eq("experience_id", exp.id)).data?.length === 1;
  const signed = await who.storage.from("media").createSignedUrl(path, 60);
  let file = false;
  if (signed.data?.signedUrl) file = (await fetch(signed.data.signedUrl)).ok;
  return { row, media, file };
}
const all = (s: { row: boolean; media: boolean; file: boolean }) => s.row && s.media && s.file;
const none = (s: { row: boolean; media: boolean; file: boolean }) => !s.row && !s.media && !s.file;

check("the owner sees row, media and file", all(await sees(alice.db)));
check("private: a stranger sees nothing", none(await sees(bob.db)));
check("private: logged out sees nothing", none(await sees(anon)));

// Friends.
await alice.db.from("experiences").update({ visibility: "friends" }).eq("id", exp.id);
check("friends: not yet friends sees nothing", none(await sees(bob.db)));
await alice.db.from("friendships").insert({ requester_id: alice.id, addressee_id: bob.id });
await bob.db.from("friendships").update({ status: "accepted" }).eq("requester_id", alice.id);
check("friends: an accepted friend sees row, media and file", all(await sees(bob.db)));
check("friends: someone else still sees nothing", none(await sees(carol.db)));
await bob.db.from("friendships").update({ status: "blocked" }).eq("requester_id", alice.id);
check("friends: blocked, access is gone everywhere", none(await sees(bob.db)));

// Public, then back to private.
await alice.db.from("experiences").update({ visibility: "public" }).eq("id", exp.id);
check("public: a stranger sees it", all(await sees(carol.db)));
check("public: logged out sees it", all(await sees(anon)));
check("public: a blocked person still doesn't, inside the app", none(await sees(bob.db)));
const { data: kept } = await carol.db.storage.from("media").createSignedUrl(path, 60);
await alice.db.from("experiences").update({ visibility: "private" }).eq("id", exp.id);
check("public → private: the stranger loses row, media and file", none(await sees(carol.db)));
// A URL signed before the change is a bearer token: it keeps working until it expires. That is why the app
// signs for minutes, not days. Measured here so the limit stays visible.
const stillWorks = kept?.signedUrl ? (await fetch(kept.signedUrl)).ok : false;
console.log(`  note: a link signed before going private ${stillWorks ? "still works until it expires (60 s here)" : "stopped working at once"}`);

// Reflections never leave their author.
await alice.db.from("experiences").update({ visibility: "public" }).eq("id", exp.id);
await alice.db.from("reflections").insert({ experience_id: exp.id, body: "We stayed long after the tea went cold." });
check("reflections stay with their author on a Public Experience",
  ((await carol.db.from("reflections").select("id")).data ?? []).length === 0);

if (failures) {
  console.error(`\n${failures} access check(s) failed`);
  Deno.exit(1);
}
console.log("\nall access checks passed");
