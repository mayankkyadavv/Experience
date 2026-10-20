// Edge Runtime router for local development: /<name>/... runs supabase/functions/<name>/index.ts.
// The hosted project does this for us. Each function checks the caller's JWT itself (auth.getUser).

const functions = Deno.env.get("FUNCTIONS_DIR") ?? "/home/deno/functions";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  const name = new URL(req.url).pathname.split("/")[1];
  if (!name || name.startsWith("_") || name.startsWith(".")) return json(404, { error: "Function not found" });

  const servicePath = `${functions}/${name}`;
  try {
    if (!(await Deno.stat(servicePath)).isDirectory) return json(404, { error: "Function not found" });
  } catch {
    return json(404, { error: "Function not found" });
  }

  try {
    // deno-lint-ignore no-explicit-any
    const worker = await (globalThis as any).EdgeRuntime.userWorkers.create({
      servicePath,
      memoryLimitMb: 150,
      workerTimeoutMs: 60_000,
      noModuleCache: false,
      envVars: Object.entries(Deno.env.toObject()),
    });
    return await worker.fetch(req);
  } catch (e) {
    console.error(`${name}:`, e);
    return json(500, { error: `Function "${name}" failed to start. Check \`docker compose logs functions\`.` });
  }
});
