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
