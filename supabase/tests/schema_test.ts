// Runs every migration in an embedded Postgres (PGlite) with a stub of Supabase's auth schema,
// then checks the RLS rules from ADR-009. No Docker or Supabase CLI needed:
//   deno test -A supabase/tests/schema_test.ts

import { PGlite } from "npm:@electric-sql/pglite@0.3.14";
import { assertEquals, assertRejects } from "jsr:@std/assert@1";

const MIGRATIONS = new URL("../migrations/", import.meta.url);
const ALICE = "00000000-0000-0000-0000-00000000000a";
const BOB = "00000000-0000-0000-0000-00000000000b";

async function setup() {
  const db = new PGlite();
  await db.exec(`
    create role authenticated nologin;
    create role anon nologin;
    create schema auth;
    create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable
      as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth to authenticated;
    grant execute on function auth.uid() to authenticated;
  `);
  const files = [...Deno.readDirSync(MIGRATIONS)].map((f) => f.name).filter((n) => n.endsWith(".sql")).sort();
  for (const f of files) await db.exec(await Deno.readTextFile(new URL(f, MIGRATIONS)));
  await db.exec(`
    grant usage on schema public to authenticated;
    grant select, insert, update, delete on all tables in schema public to authenticated;
    insert into auth.users values ('${ALICE}'), ('${BOB}');
  `);
  return db;
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

Deno.test("RLS: catalog visible only when published; private Experiences only to their creator", async () => {
  const db = await setup();
  await db.exec(`
    insert into experiences (title, category, city_id, status) values
      ('Published tour', 'attraction', 'philadelphia', 'published'),
      ('Draft tour', 'attraction', 'philadelphia', 'draft');
    insert into experiences (title, category, city_id, status, visibility, created_by) values
      ('Alice private', 'games', 'philadelphia', 'published', 'private', '${ALICE}');
  `);
  const alice = await as<{ title: string }>(db, ALICE, "select title from experiences order by title");
  const bob = await as<{ title: string }>(db, BOB, "select title from experiences order by title");
  assertEquals(alice.map((r) => r.title), ["Alice private", "Published tour"]);
  assertEquals(bob.map((r) => r.title), ["Published tour"]);
});

Deno.test("RLS: user_experiences are owner-only", async () => {
  const db = await setup();
  const [{ id }] = (await db.query<{ id: string }>(
    "insert into experiences (title, category, city_id, status) values ('X', 'food', 'philadelphia', 'published') returning id",
  )).rows;
  await as(db, ALICE, "insert into user_experiences (user_id, experience_id, saved_at) values ($1, $2, now())", [ALICE, id]);
  assertEquals((await as(db, BOB, "select * from user_experiences")).length, 0);
  assertEquals((await as(db, ALICE, "select * from user_experiences")).length, 1);
  await assertRejects(() => as(db, BOB, "insert into user_experiences (user_id, experience_id) values ($1, $2)", [ALICE, id]));
});

Deno.test("sources: a retried save_id never duplicates (ADR-007)", async () => {
  const db = await setup();
  const insert = "insert into sources (user_id, save_id, url, platform) values ($1, '11111111-1111-1111-1111-111111111111', 'https://vm.tiktok.com/x', 'tiktok') on conflict (user_id, save_id) do nothing";
  await as(db, ALICE, insert, [ALICE]);
  await as(db, ALICE, insert, [ALICE]);
  assertEquals((await as(db, ALICE, "select * from sources")).length, 1);
});

Deno.test("experiences: private rows need a creator, catalog rows must not have one", async () => {
  const db = await setup();
  await assertRejects(() => db.exec("insert into experiences (title, category, visibility) values ('bad', 'food', 'private')"));
  await assertRejects(() => db.exec(`insert into experiences (title, category, created_by) values ('bad', 'food', '${ALICE}')`));
});

// Feedback ------------------------------------------------------------------

type UE = { saved_at: string | null; interested_at: string | null; not_interested_at: string | null; done_at: string | null; rating: number | null; from_recommendation: string | null };

async function published(db: PGlite) {
  return (await db.query<{ id: string }>(
    "insert into experiences (title, category, city_id, status) values ('X', 'food', 'philadelphia', 'published') returning id",
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
    "insert into experiences (title, category, city_id, status) values ('D', 'food', 'philadelphia', 'draft') returning id",
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

Deno.test("links and occurrences follow their Experience's visibility", async () => {
  const db = await setup();
  const { rows: [{ id: pub }] } = await db.query<{ id: string }>("insert into experiences (title, category, city_id, status, kind) values ('Show', 'music', 'philadelphia', 'published', 'event') returning id");
  const { rows: [{ id: draft }] } = await db.query<{ id: string }>("insert into experiences (title, category, city_id, status) values ('Draft', 'music', 'philadelphia', 'draft') returning id");
  await db.exec(`
    insert into experience_links (experience_id, kind, url) values ('${pub}', 'tickets', 'https://t.example/1'), ('${draft}', 'website', 'https://d.example');
    insert into experience_occurrences (experience_id, starts_at) values ('${pub}', '2026-11-07 20:00-05'), ('${draft}', '2026-11-08 20:00-05');
  `);
  assertEquals((await as<{ url: string }>(db, ALICE, "select url from experience_links")).map((r) => r.url), ["https://t.example/1"]);
  assertEquals((await as(db, ALICE, "select * from experience_occurrences")).length, 1);
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
  await db.exec(`insert into auth.users values ('00000000-0000-0000-0000-00000000000c')`);
  assertEquals((await as(db, "00000000-0000-0000-0000-00000000000c", "select * from groups")).length, 0);
});

Deno.test("captures are owner-only", async () => {
  const db = await setup();
  await as(db, ALICE, "insert into captures (user_id, kind, taken_at) values ($1, 'photo', now())", [ALICE]);
  assertEquals((await as(db, ALICE, "select * from captures")).length, 1);
  assertEquals((await as(db, BOB, "select * from captures")).length, 0);
  await assertRejects(() => as(db, BOB, "insert into captures (user_id, kind, taken_at) values ($1, 'video', now())", [ALICE]));
});
