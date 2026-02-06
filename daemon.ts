// daemon.ts — Trading daemon: serves dashboard + runs live.ua every 30 min
//
// Usage: bun run daemon.ts
//        ./serve.sh run          (same thing)
//        ./serve.sh install      (auto-start on login via launchd)

const PROJECT_ROOT = import.meta.dir;
const PORT = 8080;
const UIUA_BIN = "/Users/amygdala/.cargo/bin/uiua";
const INTERVAL_MS = 30 * 60 * 1000; // 30 minutes

function ts(): string {
  return new Date().toISOString().replace("T", " ").slice(0, 19);
}

function log(msg: string) {
  console.log(`[${ts()}] ${msg}`);
}

// --- Data refresh: download SVXY and Gold CSVs ---

async function refreshData() {
  for (const script of ["download_svxy.ts", "download_gold.ts", "download_nanc.ts", "download_pelosi_stocks.ts", "download_goog.ts", "gen_benchmark.ts"]) {
    try {
      log(`Running ${script}...`);
      const proc = Bun.spawn(["bun", "run", script], {
        cwd: PROJECT_ROOT,
        stdout: "pipe",
        stderr: "pipe",
      });
      const [stdout, stderr] = await Promise.all([
        new Response(proc.stdout).text(),
        new Response(proc.stderr).text(),
      ]);
      const code = await proc.exited;
      if (stdout.trim()) log(stdout.trim());
      if (code !== 0) log(`${script} failed (code ${code}): ${stderr.trim()}`);
    } catch (e) {
      log(`${script} error: ${e}`);
    }
  }
}

// --- Scheduler: run live.ua ---

let running = false;

async function runLiveUa() {
  if (running) {
    log("live.ua already running — skipping");
    return;
  }
  running = true;
  log("Refreshing SVXY/Gold data...");
  await refreshData();
  log("Running live.ua...");

  try {
    const proc = Bun.spawn([UIUA_BIN, "run", "live.ua"], {
      cwd: PROJECT_ROOT,
      stdout: "pipe",
      stderr: "pipe",
    });

    const [stdout, stderr] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
    ]);
    const code = await proc.exited;

    if (stdout.trim()) log(stdout.trim());
    if (stderr.trim()) log(`stderr: ${stderr.trim()}`);
    log(`live.ua exited with code ${code}`);
  } catch (e) {
    log(`live.ua error: ${e}`);
  } finally {
    running = false;
  }
}

// --- HTTP server: serve static files ---

const MIME: Record<string, string> = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".txt": "text/plain",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
  ".woff": "font/woff",
};

function getMime(path: string): string {
  const ext = path.slice(path.lastIndexOf("."));
  return MIME[ext] || "application/octet-stream";
}

Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    let path = url.pathname;

    // Redirect root to basePath so Next.js hydration works
    if (path === "/") {
      return Response.redirect(url.origin + "/web/out/", 302);
    }

    // Directory index: /web/out/ → /web/out/index.html
    if (path.endsWith("/")) path += "index.html";

    const filePath = PROJECT_ROOT + path;
    const file = Bun.file(filePath);

    if (await file.exists()) {
      return new Response(file, {
        headers: {
          "Content-Type": getMime(path),
          "Cache-Control": path.startsWith("/data/") ? "no-cache" : "max-age=3600",
        },
      });
    }

    return new Response("Not Found", { status: 404 });
  },
});

log(`Dashboard: http://localhost:${PORT}/web/out/index.html`);

// Run live.ua once on startup, then every 30 min
runLiveUa();
setInterval(runLiveUa, INTERVAL_MS);

log(`Scheduler: live.ua every ${INTERVAL_MS / 60000} min`);
