const http = require("http");
const port = process.env.PORT || 3000;

const html = `
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Hello kube</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #0f172a;
        --card: rgba(15, 23, 42, 0.9);
        --text: #e2e8f0;
        --muted: #94a3b8;
        --accent: #38bdf8;
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        font-family: Arial, Helvetica, sans-serif;
        color: var(--text);
        background:
          radial-gradient(circle at top, rgba(56, 189, 248, 0.25), transparent 35%),
          linear-gradient(135deg, #020617, #0f172a 55%, #111827);
      }

      .card {
        width: min(92vw, 640px);
        padding: 32px;
        border: 1px solid rgba(148, 163, 184, 0.18);
        border-radius: 24px;
        background: var(--card);
        box-shadow: 0 24px 80px rgba(2, 6, 23, 0.45);
      }

      .badge {
        display: inline-block;
        padding: 6px 12px;
        border-radius: 999px;
        font-size: 12px;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--accent);
        background: rgba(56, 189, 248, 0.12);
      }

      h1 {
        margin: 18px 0 12px;
        font-size: clamp(2rem, 5vw, 3.5rem);
        line-height: 1.05;
      }

      p {
        margin: 0 0 20px;
        color: var(--muted);
        line-height: 1.6;
      }

      .grid {
        display: grid;
        gap: 12px;
        grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      }

      .tile {
        padding: 14px 16px;
        border-radius: 16px;
        background: rgba(15, 23, 42, 0.55);
        border: 1px solid rgba(148, 163, 184, 0.14);
      }

      .tile span {
        display: block;
        font-size: 12px;
        color: var(--muted);
        margin-bottom: 6px;
      }

      .tile strong {
        font-size: 16px;
      }

      a {
        color: var(--accent);
        text-decoration: none;
      }
    </style>
  </head>
  <body>
    <main class="card">
      <span class="badge">Kubernetes demo</span>
      <h1>Hello kube</h1>
      <p>
        Tiny Node.js server running in a container. It serves this UI for the browser,
        and exposes a small health endpoint for Kubernetes probes.
      </p>
      <section class="grid">
        <div class="tile">
          <span>UI</span>
          <strong>HTML page</strong>
        </div>
        <div class="tile">
          <span>Health</span>
          <strong><a href="/health">/health</a></strong>
        </div>
        <div class="tile">
          <span>API</span>
          <strong><a href="/api">/api</a></strong>
        </div>
      </section>
    </main>
  </body>
</html>
`;

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  if (req.url === "/api") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ message: "Hello from the tiny Node server" }));
    return;
  }

  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(html);
});

server.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});