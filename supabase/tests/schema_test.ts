// Runs every migration in an embedded Postgres (PGlite) with a stub of Supabase's auth schema,
// then checks the RLS rules from ADR-009. No Docker or Supabase CLI needed:
//   deno test -A supabase/tests/schema_test.ts

import { PGlite } from "npm:@electric-sql/pglite@0.3.14";
import { assertEquals, assertRejects } from "jsr:@std/assert@1";

const MIGRATIONS = new URL("../migrations/", import.meta.url);
const ALICE = "00000000-0000-0000-0000-00000000000a";
const BOB = "00000000-0000-0000-0000-00000000000b";
const CAROL = "00000000-0000-0000-0000-00000000000c";

/// All migrations, or only those before `until` (to put old-shape data in, then apply the rest with `migrate`).
async function setup(until?: string) {
  const db = new PGlite();
  await db.exec(`
    create role authenticated nologin;
    create role anon nologin;
    create schema auth;
    create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable
      as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth to authenticated, anon;
    grant execute on function auth.uid() to authenticated, anon;
  `);
  for (const f of migrationFiles().filter((n) => !until || n < until)) await db.exec(await Deno.readTextFile(new URL(f, MIGRATIONS)));
  await db.exec(`insert into auth.users values ('${ALICE}'), ('${BOB}'), ('${CAROL}');`);
  if (!until) await grants(db);
  return db;
}

function migrationFiles() {
  return [...Deno.readDirSync(MIGRATIONS)].map((f) => f.name).filter((n) => n.endsWith(".sql")).sort();
}

/// Applies the migrations from `from` on, then the grants Supabase gives its API roles.
async function migrate(db: PGlite, from: string) {
  for (const f of migrationFiles().filter((n) => n >= from)) await db.exec(await Deno.readTextFile(new URL(f, MIGRATIONS)));
  await grants(db);
}

async function grants(db: PGlite) {
  await db.exec(`
    grant usage on schema public to authenticated, anon;
    grant select, insert, update, delete on all tables in schema public to authenticated;
    grant select on all tables in schema public to anon;
  `);
}

/// Logged out: the anon role, no user.
async function asAnon<T>(db: PGlite, sql: string, params: unknown[] = []): Promise<T[]> {
  return await db.transaction(async (tx) => {
    await tx.exec(`set local role anon; select set_config('request.jwt.claim.sub', '', true);`);
    return (await tx.query<T>(sql, params)).rows;
  });
}

async function as<T>(db: PGlite, user: string, sql: string, params: unknown[] = []): Promise<T[]> {
  return await db.transaction(async (tx) => {
    await tx.exec(`set local role authenticated; select set_config('request.jwt.claim.sub', '${user}', true);`);
    return (await tx.query<T>(sql, params)).rows;
  });
}

Deno.test("migrations apply and seed cities", async () => {
  const db = await setup();
  const { rows } = await db.query<{ id: string; status: string }>("select id, status from cities order by id");
  assertEquals(rows, [{ id: "new-york", status: "coming" }, { id: "philadelphia", status: "beta" }]);
});

Deno.test("RLS: listings visible only when published; private listings only to their creator", async () => {
  const db = await setup();
  await db.exec(`
    insert into listings (title, category, city_id, status) values
      ('Published tour', 'attraction', 'philadelphia', 'published'),
      ('Draft tour', 'attraction', 'philadelphia', 'draft');
    insert into listings (title, category, city_id, status, visibility, created_by) values
      ('Alice private', 'games', 'philadelphia', 'published', 'private', '${ALICE}');
  `);
  const alice = await as<{ title: string }>(db, ALICE, "select title from listings order by title");
  const bob = await as<{ title: string }>(db, BOB, "select title from listings order by title");
  assertEquals(alice.map((r) => r.title), ["Alice private", "Published tour"]);
  assertEquals(bob.map((r) => r.title), ["Published tour"]);
});

Deno.test("RLS: listing_signals are owner-only", async () => {
  const db = await setup();
  const [{ id }] = (await db.query<{ id: string }>(
    "insert into listings (title, category, city_id, status) values ('X', 'food', 'philadelphia', 'published') returning id",
  )).rows;
  await as(db, ALICE, "insert into listing_signals (user_id, listing_id, interested_at) values ($1, $2, now())", [ALICE, id]);
  assertEquals((await as(db, BOB, "select * from listing_signals")).length, 0);
  assertEquals((await as(db, ALICE, "select * from listing_signals")).length, 1);
  await assertRejects(() => as(db, BOB, "insert into listing_signals (user_id, listing_id) values ($1, $2)", [ALICE, id]));
});

Deno.test("sources: a retried save_id never duplicates (ADR-007)", async () => {
  const db = await setup();
  const insert = "insert into sources (user_id, save_id, url, platform) values ($1, '11111111-1111-1111-1111-111111111111', 'https://vm.tiktok.com/x', 'tiktok') on conflict (user_id, save_id) do nothing";
  await as(db, ALICE, insert, [ALICE]);
  await as(db, ALICE, insert, [ALICE]);
  assertEquals((await as(db, ALICE, "select * from sources")).length, 1);
});

Deno.test("listings: private rows need a creator, catalog rows must not have one", async () => {
  const db = await setup();
  await assertRejects(() => db.exec("insert into listings (title, category, visibility) values ('bad', 'food', 'private')"));
  await assertRejects(() => db.exec(`insert into listings (title, category, created_by) values ('bad', 'food', '${ALICE}')`));
});

// Feedback ------------------------------------------------------------------

type UE = { saved_at: string | null; interested_at: string | null; not_interested_at: string | null; done_at: string | null; rating: number | null; from_recommendation: string | null };

async function published(db: PGlite) {
  return (await db.query<{ id: string }>(
    "insert into listings (title, category, city_id, status) values ('X', 'food', 'philadelphia', 'published') returning id",
  )).rows[0].id;
}
const feedback = (db: PGlite, user: string, id: string, action: string, rating: number | null = null, rec: string | null = null) =>
  as<UE>(db, user, "select * from record_feedback($1, $2, $3::smallint, $4)", [id, action, rating, rec]).then((r) => r[0]);

Deno.test("feedback: save, interested/not interested flip, done, rate, undo", async () => {
  const db = await setup();
  const id = await published(db);
  const { rows: [{ id: REC }] } = await db.query<{ id: string }>(
    `insert into recommendation_requests (user_id, city_id, constraints, results) values ('${ALICE}', 'philadelphia', '{}', '[]') returning id`,
  );

  let ue = await feedback(db, ALICE, id, "save");
  assertEquals(ue.saved_at !== null, true);
  ue = await feedback(db, ALICE, id, "interested");
  assertEquals([ue.interested_at !== null, ue.not_interested_at], [true, null]);
  ue = await feedback(db, ALICE, id, "not_interested");
  assertEquals([ue.interested_at, ue.not_interested_at !== null], [null, true]);
  ue = await feedback(db, ALICE, id, "done", null, REC);
  assertEquals([ue.done_at !== null, ue.from_recommendation], [true, REC]);
  ue = await feedback(db, ALICE, id, "rate", 3);
  assertEquals(ue.rating, 3);
  ue = await feedback(db, ALICE, id, "undone");
  assertEquals([ue.done_at, ue.rating, ue.saved_at !== null], [null, null, true]);
  ue = await feedback(db, ALICE, id, "unsave");
  assertEquals(ue.saved_at, null);

  // Users can write events but not read them (insert-only RLS), so check as admin.
  const { rows: events } = await db.query<{ name: string; props: Record<string, unknown> }>("select name, props from events order by id");
  assertEquals(events.map((e) => e.name), ["saved", "interested", "not_interested", "did_it", "rated", "undid_it", "unsaved"]);
  assertEquals(events[3].props.from_recommendation, true);
  assertEquals(events[4].props.rating, 3);
});

Deno.test("feedback: saving twice keeps the first time", async () => {
  const db = await setup();
  const id = await published(db);
  const first = await feedback(db, ALICE, id, "save");
  const second = await feedback(db, ALICE, id, "save");
  assertEquals(second.saved_at, first.saved_at);
});

Deno.test("feedback: rejects bad input and hidden Experiences", async () => {
  const db = await setup();
  const id = await published(db);
  const draft = (await db.query<{ id: string }>(
    "insert into listings (title, category, city_id, status) values ('D', 'food', 'philadelphia', 'draft') returning id",
  )).rows[0].id;
  await assertRejects(() => feedback(db, ALICE, id, "rate", 3), Error, "Mark it done before rating it");
  await feedback(db, ALICE, id, "done");
  await assertRejects(() => feedback(db, ALICE, id, "rate", 5), Error, "Rating must be 1, 2 or 3");
  await assertRejects(() => feedback(db, ALICE, id, "love"), Error, "Unknown action");
  await assertRejects(() => feedback(db, ALICE, draft, "save"), Error, "Experience not found");
  await assertRejects(() => feedback(db, "", id, "save"), Error, "Not signed in");
  // Bob's feedback is separate from Alice's.
  assertEquals((await feedback(db, BOB, id, "save")).done_at, null);
});

// Data model v2 (ADR-011) ---------------------------------------------------

Deno.test("links and occurrences follow their listing's visibility", async () => {
  const db = await setup();
  const { rows: [{ id: pub }] } = await db.query<{ id: string }>("insert into listings (title, category, city_id, status, kind) values ('Show', 'music', 'philadelphia', 'published', 'event') returning id");
  const { rows: [{ id: draft }] } = await db.query<{ id: string }>("insert into listings (title, category, city_id, status) values ('Draft', 'music', 'philadelphia', 'draft') returning id");
  await db.exec(`
    insert into listing_links (listing_id, kind, url) values ('${pub}', 'tickets', 'https://t.example/1'), ('${draft}', 'website', 'https://d.example');
    insert into listing_occurrences (listing_id, starts_at) values ('${pub}', '2026-11-07 20:00-05'), ('${draft}', '2026-11-08 20:00-05');
  `);
  assertEquals((await as<{ url: string }>(db, ALICE, "select url from listing_links")).map((r) => r.url), ["https://t.example/1"]);
  assertEquals((await as(db, ALICE, "select * from listing_occurrences")).length, 1);
});

Deno.test("friendships: both sides see it, only the addressee accepts", async () => {
  const db = await setup();
  await as(db, ALICE, "insert into friendships (requester_id, addressee_id) values ($1, $2)", [ALICE, BOB]);
  assertEquals((await as(db, BOB, "select * from friendships")).length, 1);
  // Alice can't accept her own request; Bob can.
  assertEquals((await as(db, ALICE, "update friendships set status = 'accepted' returning *")).length, 0);
  assertEquals((await as(db, BOB, "update friendships set status = 'accepted' returning *")).length, 1);
  await assertRejects(() => as(db, BOB, "insert into friendships (requester_id, addressee_id, status) values ($1, $2, 'accepted')", [ALICE, BOB]));
});

Deno.test("groups are visible to members only", async () => {
  const db = await setup();
  const [{ id }] = await as<{ id: string }>(db, ALICE, "insert into groups (name, created_by) values ('Friday crew', $1) returning id", [ALICE]);
  await as(db, ALICE, "insert into group_members (group_id, user_id, role) values ($1, $2, 'owner'), ($1, $3, 'member')", [id, ALICE, BOB]);
  assertEquals((await as(db, BOB, "select name from groups")).length, 1);
  assertEquals((await as(db, BOB, "select * from group_members")).length, 2);
  assertEquals((await as(db, CAROL, "select * from groups")).length, 0);
});

// Personal Experiences (ADR-013, brief §3-5, §9) --------------------------------------------------------------

type Exp = { id: string; title: string; state: string; completed_at: string | null; visibility: string };

const newExperience = (db: PGlite, user: string, fields: Record<string, unknown> = {}) => {
  const f = { title: "Tea and a long conversation", ...fields };
  const cols = Object.keys(f);
  return as<Exp>(db, user, `insert into experiences (${cols.join(", ")}) values (${cols.map((_, i) => `$${i + 1}`).join(", ")}) returning *`, Object.values(f))
    .then((r) => r[0]);
};

const befriend = async (db: PGlite, a: string, b: string) => {
  await as(db, a, "insert into friendships (requester_id, addressee_id) values ($1, $2)", [a, b]);
  await as(db, b, "update friendships set status = 'accepted' where requester_id = $1", [a]);
};

Deno.test("experiences: a text-only, undated, place-less Experience is valid and private by default", async () => {
  const db = await setup();
  const e = await newExperience(db, ALICE);
  assertEquals([e.state, e.visibility, e.completed_at !== null], ["experienced", "private", true]);
  assertEquals((await as(db, ALICE, "select id from experiences")).length, 1);
  assertEquals((await as(db, BOB, "select id from experiences")).length, 0);
  assertEquals((await asAnon(db, "select id from experiences")).length, 0);
});

Deno.test("experiences: Want → Planned → Experienced keeps its id; completed only once experienced", async () => {
  const db = await setup();
  const want = await newExperience(db, ALICE, { title: "Try a pottery class", state: "want" });
  assertEquals(want.completed_at, null);
  const [planned] = await as<Exp>(db, ALICE,
    "update experiences set state = 'planned', starts_at = '2026-10-24 14:00-04', time_precision = 'exact', timezone = 'America/New_York' where id = $1 returning *", [want.id]);
  assertEquals([planned.id, planned.completed_at], [want.id, null]);
  const [done] = await as<Exp & { revision: number }>(db, ALICE, "update experiences set state = 'experienced' where id = $1 returning *", [want.id]);
  assertEquals([done.id, done.completed_at !== null, done.revision], [want.id, true, 3]);
  const [cancelled] = await as<Exp>(db, ALICE, "update experiences set state = 'cancelled' where id = $1 returning *", [want.id]);
  assertEquals(cancelled.completed_at, null);
});

Deno.test("experiences: honest time and ownership", async () => {
  const db = await setup();
  // "Summer 2021" stays a range.
  await newExperience(db, ALICE, { title: "Summer job", starts_at: "2021-06-01", ends_at: "2021-08-31", time_precision: "season" });
  // A date needs a precision, and unknown means no date.
  await assertRejects(() => newExperience(db, ALICE, { starts_at: "2026-10-18" }));
  await assertRejects(() => newExperience(db, ALICE, { time_precision: "day" }));
  await assertRejects(() => newExperience(db, ALICE, { categories: ["shopping"] }));
  // Nobody saves into someone else's archive, or takes over a row by editing it.
  await assertRejects(() => newExperience(db, BOB, { owner_id: ALICE }));
  const e = await newExperience(db, ALICE);
  assertEquals((await as(db, BOB, "update experiences set title = 'mine' where id = $1 returning id", [e.id])).length, 0);
  const [same] = await as<{ owner_id: string }>(db, ALICE, "update experiences set owner_id = $2 where id = $1 returning owner_id", [e.id, ALICE]);
  assertEquals(same.owner_id, ALICE);
});

Deno.test("experiences: a retried save_id never duplicates", async () => {
  const db = await setup();
  const save = "insert into experiences (title, save_id) values ('Run', '22222222-2222-2222-2222-222222222222') on conflict (owner_id, save_id) do nothing";
  await as(db, ALICE, save);
  await as(db, ALICE, save);
  assertEquals((await as(db, ALICE, "select * from experiences")).length, 1);
});

Deno.test("access: friends see Friends Experiences; strangers, blocked people and the logged-out don't", async () => {
  const db = await setup();
  await newExperience(db, ALICE, { title: "Friends dinner", visibility: "friends" });
  await newExperience(db, ALICE, { title: "Public walk", visibility: "public" });
  await newExperience(db, ALICE, { title: "Private tea" });
  await newExperience(db, ALICE, { title: "Draft concert", visibility: "public", is_draft: true });
  const titles = async (user: string) => (await as<{ title: string }>(db, user, "select title from experiences order by title")).map((r) => r.title);

  assertEquals(await titles(BOB), ["Public walk"]);
  assertEquals((await asAnon<{ title: string }>(db, "select title from experiences")).map((r) => r.title), ["Public walk"]);
  await befriend(db, ALICE, BOB);
  assertEquals(await titles(BOB), ["Friends dinner", "Public walk"]);
  assertEquals(await titles(CAROL), ["Public walk"]);
  // Unfriending (or blocking) removes friend access; a block hides public material inside the app too.
  await as(db, BOB, "update friendships set status = 'blocked'");
  assertEquals(await titles(BOB), []);
  await as(db, ALICE, "delete from friendships");
  assertEquals(await titles(BOB), ["Public walk"]);
  // Public → Private revokes at once.
  await as(db, ALICE, "update experiences set visibility = 'private'");
  assertEquals(await titles(CAROL), []);
});

Deno.test("access: reflections stay with their author, even on a Public Experience", async () => {
  const db = await setup();
  const e = await newExperience(db, ALICE, { visibility: "public" });
  await as(db, ALICE, "insert into reflections (experience_id, body, rating) values ($1, 'We stayed long after the tea went cold.', 5)", [e.id]);
  assertEquals((await as(db, ALICE, "select * from reflections")).length, 1);
  assertEquals((await as(db, BOB, "select * from reflections")).length, 0);
  // Unrated is not zero; ratings stay within their scale.
  await assertRejects(() => as(db, ALICE, "update reflections set rating = 0"));
  await assertRejects(() => as(db, ALICE, "update reflections set rating = 4, rating_scale = 3"));
});

Deno.test("collections: group without copying; a public collection never reveals a private Experience", async () => {
  const db = await setup();
  const walk = await newExperience(db, ALICE, { title: "Park Güell", visibility: "public" });
  const tea = await newExperience(db, ALICE, { title: "Late tea" });
  const bobs = await newExperience(db, BOB, { title: "Bob's thing" });
  const [c] = await as<{ id: string }>(db, ALICE, "insert into collections (title, kind, visibility) values ('Barcelona 2024', 'trip', 'public') returning id");
  await as(db, ALICE, "insert into collection_items (collection_id, experience_id, position) values ($1, $2, 0), ($1, $3, 1)", [c.id, walk.id, tea.id]);
  await assertRejects(() => as(db, ALICE, "insert into collection_items (collection_id, experience_id) values ($1, $2)", [c.id, bobs.id]));
  await assertRejects(() => as(db, BOB, "insert into collection_items (collection_id, experience_id) values ($1, $2)", [c.id, bobs.id]));

  assertEquals((await as(db, ALICE, "select * from collection_items")).length, 2);
  assertEquals((await as(db, BOB, "select title from collections")).length, 1);
  const seen = await as<{ experience_id: string }>(db, BOB, "select experience_id from collection_items");
  assertEquals(seen.map((r) => r.experience_id), [walk.id]);
  // Deleting the collection leaves the Experiences.
  await as(db, ALICE, "delete from collections");
  assertEquals((await as(db, ALICE, "select * from experiences")).length, 2);
});

Deno.test("media: owner-only until uploaded; then it follows its Experience's audience", async () => {
  const db = await setup();
  const e = await newExperience(db, ALICE, { visibility: "public" });
  const [m] = await as<{ id: string }>(db, ALICE,
    "insert into media_assets (experience_id, client_id, kind, device_file) values ($1, gen_random_uuid(), 'photo', 'a.heic') returning id", [e.id]);
  assertEquals((await as(db, BOB, "select * from media_assets")).length, 0);
  await as(db, ALICE, "update media_assets set status = 'ready', original_path = $2 where id = $1", [m.id, `${ALICE}/${m.id}/original.heic`]);
  assertEquals((await as(db, BOB, "select * from media_assets")).length, 1);
  await as(db, ALICE, "update experiences set visibility = 'private'");
  assertEquals((await as(db, BOB, "select * from media_assets")).length, 0);
  // Media can't be hung on someone else's Experience.
  const bobs = await newExperience(db, BOB);
  await assertRejects(() => as(db, ALICE, "insert into media_assets (experience_id, client_id, kind) values ($1, gen_random_uuid(), 'photo')", [bobs.id]));
});

Deno.test("feedback: saving a listing creates your own Want; Did it turns that same Want into the memory", async () => {
  const db = await setup();
  const id = await published(db);
  await feedback(db, ALICE, id, "save");
  const [want] = await as<Exp & { listing_id: string }>(db, ALICE, "select * from experiences");
  assertEquals([want.state, want.listing_id, want.visibility], ["want", id, "private"]);
  await feedback(db, ALICE, id, "done");
  const after = await as<Exp>(db, ALICE, "select * from experiences");
  assertEquals(after.map((e) => [e.id, e.state]), [[want.id, "experienced"]]);
  // The time is marked as an estimate: tapping "Did it" isn't proof of when it happened.
  const [{ p }] = await as<{ p: string }>(db, ALICE, "select provenance ->> 'time' as p from experiences");
  assertEquals(p, "estimated");
});

Deno.test("migration: saves, Did its, ratings and captures move into Experiences", async () => {
  const LIFE = "20261024000000_life_archive.sql";
  const db = await setup(LIFE);
  const { rows: [{ id: L1 }] } = await db.query<{ id: string }>("insert into experiences (title, category, city_id, status) values ('Ramen', 'food', 'philadelphia', 'published') returning id");
  const { rows: [{ id: L2 }] } = await db.query<{ id: string }>("insert into experiences (title, category, city_id, status) values ('Jazz', 'music', 'philadelphia', 'published') returning id");
  await db.exec(`
    insert into user_experiences (user_id, experience_id, saved_at) values ('${ALICE}', '${L1}', '2026-10-01');
    insert into user_experiences (user_id, experience_id, saved_at, done_at, rating) values ('${ALICE}', '${L2}', '2026-10-02', '2026-10-05', 3);
    insert into user_experiences (user_id, experience_id, not_interested_at) values ('${BOB}', '${L1}', now());
    insert into captures (user_id, experience_id, kind, taken_at, device_media_id) values ('${ALICE}', '${L2}', 'photo', '2026-10-05', 'x.jpg');
  `);
  await migrate(db, LIFE);
  const rows = await as<{ title: string; state: string; categories: string[]; created_at: string }>(db, ALICE,
    "select title, state, categories, created_at from experiences order by title");
  assertEquals(rows.map((r) => [r.title, r.state, r.categories]), [["Jazz", "experienced", ["music"]], ["Ramen", "want", ["food"]]]);
  assertEquals((await as<{ rating: number; rating_scale: number }>(db, ALICE, "select rating, rating_scale from reflections"))
    .map((r) => [r.rating, r.rating_scale]), [[3, 3]]);
  assertEquals((await as<{ device_file: string }>(db, ALICE, "select device_file from media_assets")).map((r) => r.device_file), ["x.jpg"]);
  assertEquals((await as(db, BOB, "select * from listing_signals")).length, 1);
  assertEquals((await as(db, BOB, "select * from experiences")).length, 0);
});
