const http = require('http');
const os   = require('os');

const html = `<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Exercise 8 — Cloud DevOps</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      min-height: 100vh;
      display: grid;
      place-items: center;
      font-family: 'Segoe UI', system-ui, sans-serif;
      background: #0a0f1e;
      background-image:
        radial-gradient(ellipse 80% 60% at 50% -10%, rgba(56,189,248,.18), transparent),
        radial-gradient(ellipse 60% 40% at 80% 100%, rgba(129,140,248,.12), transparent);
      color: #e2e8f0;
      padding: 2rem 1rem;
    }

    .card {
      width: min(680px, 100%);
      background: rgba(255,255,255,.04);
      border: 1px solid rgba(255,255,255,.08);
      border-radius: 20px;
      padding: 2.5rem 2rem;
      box-shadow: 0 32px 64px rgba(0,0,0,.5);
      animation: rise .6s cubic-bezier(.22,1,.36,1) both;
    }

    /* ── Header ── */
    .header { display: flex; align-items: center; gap: 1rem; margin-bottom: 2rem; }
    .logo {
      width: 48px; height: 48px; flex-shrink: 0;
      background: linear-gradient(135deg, #38bdf8, #818cf8);
      border-radius: 14px;
      display: grid; place-items: center;
      font-size: 1.5rem;
    }
    .title { font-size: 1.4rem; font-weight: 700; letter-spacing: -.02em; }
    .subtitle { font-size: .875rem; color: #64748b; margin-top: .15rem; }

    /* ── Status banner ── */
    .status {
      display: flex; align-items: center; gap: .75rem;
      background: rgba(34,197,94,.08);
      border: 1px solid rgba(34,197,94,.2);
      border-radius: 12px;
      padding: .75rem 1rem;
      margin-bottom: 2rem;
    }
    .dot {
      width: 10px; height: 10px; border-radius: 50%;
      background: #22c55e;
      box-shadow: 0 0 0 3px rgba(34,197,94,.25);
      animation: pulse 2s infinite;
    }
    .status-text { font-size: .9rem; color: #86efac; font-weight: 500; }

    /* ── Info grid ── */
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: .75rem;
      margin-bottom: 2rem;
    }
    .tile {
      background: rgba(255,255,255,.03);
      border: 1px solid rgba(255,255,255,.06);
      border-radius: 12px;
      padding: 1rem;
    }
    .tile-label { font-size: .75rem; color: #64748b; text-transform: uppercase; letter-spacing: .06em; margin-bottom: .35rem; }
    .tile-value { font-size: .95rem; font-weight: 600; color: #f1f5f9; word-break: break-all; }
    .tile-value.accent { color: #38bdf8; }

    /* ── Stack badges ── */
    .stack { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: 2rem; }
    .badge {
      font-size: .78rem; font-weight: 600;
      padding: .3rem .75rem; border-radius: 9999px;
      border: 1px solid;
    }
    .badge-blue  { color: #38bdf8; background: rgba(56,189,248,.1);  border-color: rgba(56,189,248,.2); }
    .badge-violet{ color: #a78bfa; background: rgba(167,139,250,.1); border-color: rgba(167,139,250,.2); }
    .badge-green { color: #4ade80; background: rgba(74,222,128,.1);  border-color: rgba(74,222,128,.2); }
    .badge-orange{ color: #fb923c; background: rgba(251,146,60,.1);  border-color: rgba(251,146,60,.2); }

    /* ── Flow diagram ── */
    .flow {
      display: flex; align-items: center; flex-wrap: wrap;
      gap: .5rem; justify-content: center;
      font-size: .82rem; color: #94a3b8;
      background: rgba(255,255,255,.02);
      border: 1px solid rgba(255,255,255,.05);
      border-radius: 12px; padding: .9rem 1rem;
      margin-bottom: 2rem;
    }
    .flow-node {
      background: rgba(56,189,248,.1); color: #38bdf8;
      border: 1px solid rgba(56,189,248,.2);
      border-radius: 8px; padding: .3rem .65rem;
      font-weight: 600; white-space: nowrap;
    }
    .flow-arrow { color: #334155; font-size: 1rem; }

    /* ── Footer ── */
    .footer { text-align: center; font-size: .8rem; color: #334155; }

    /* ── YouTube ── */
    .yt-section { margin-bottom: 2rem; }
    .yt-label {
      font-size: .78rem; color: #64748b;
      text-transform: uppercase; letter-spacing: .06em;
      margin-bottom: .5rem;
    }
    .yt-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: .75rem;
    }
    @media (max-width: 480px) {
      .yt-grid { grid-template-columns: 1fr; }
    }
    .yt-item { }
    .yt-title {
      font-size: .75rem; color: #94a3b8;
      margin-bottom: .4rem;
    }
    .yt-frame {
      position: relative;
      width: 100%;
      padding-bottom: 56.25%; /* 16:9 */
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid rgba(255,255,255,.06);
    }
    /* Shorts là 9:16 */
    .yt-frame.shorts { padding-bottom: 177.78%; }
    .yt-frame iframe {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      border: 0;
    }

    /* ── Animations ── */
    @keyframes rise {
      from { opacity: 0; transform: translateY(24px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    @keyframes pulse {
      0%,100% { box-shadow: 0 0 0 3px rgba(34,197,94,.25); }
      50%      { box-shadow: 0 0 0 6px rgba(34,197,94,.1); }
    }

    /* ── Canvas particles (background) ── */
    #canvas {
      position: fixed;
      inset: 0;
      pointer-events: none;
      z-index: 0;
    }
    body > .card { position: relative; z-index: 1; }

    /* ── Cursor trail ── */
    .trail {
      position: fixed;
      width: 8px; height: 8px;
      border-radius: 50%;
      pointer-events: none;
      z-index: 9999;
      transform: translate(-50%, -50%);
      transition: opacity .4s;
    }

    /* ── Tile hover glow ── */
    .tile {
      transition: transform .2s, box-shadow .2s, border-color .2s;
      cursor: default;
    }
    .tile:hover {
      transform: translateY(-3px) scale(1.02);
      border-color: rgba(56,189,248,.3);
      box-shadow: 0 0 20px rgba(56,189,248,.12);
    }

    /* ── Badge hover ── */
    .badge {
      transition: transform .15s, box-shadow .15s;
      cursor: default;
    }
    .badge:hover {
      transform: scale(1.08);
      box-shadow: 0 0 12px rgba(255,255,255,.1);
    }

    /* ── Flow node hover ── */
    .flow-node {
      transition: background .2s, box-shadow .2s, transform .2s;
      cursor: default;
    }
    .flow-node:hover {
      background: rgba(56,189,248,.2);
      box-shadow: 0 0 14px rgba(56,189,248,.3);
      transform: scale(1.06);
    }

    /* ── Card shimmer border on hover ── */
    .card {
      transition: box-shadow .3s;
    }
    .card:hover {
      box-shadow: 0 32px 64px rgba(0,0,0,.5), 0 0 0 1px rgba(56,189,248,.15);
    }
  </style>
</head>
<body>
  <canvas id="canvas"></canvas>
  <div class="card">

    <!-- Header -->
    <div class="header">
      <div class="logo">☁️</div>
      <div>
        <div class="title">Exercise 8 — Cloud DevOps</div>
        <div class="subtitle">AWS VPC · EC2 · ALB · Kubernetes</div>
      </div>
    </div>

    <!-- Status -->
    <div class="status">
      <div class="dot"></div>
      <span class="status-text">Ứng dụng đang chạy ổn định phía sau ALB</span>
    </div>

    <!-- Info tiles -->
    <div class="grid">
      <div class="tile">
        <div class="tile-label">Hostname</div>
        <div class="tile-value accent" id="hostname">—</div>
      </div>
      <div class="tile">
        <div class="tile-label">Runtime</div>
        <div class="tile-value">Node.js ${process.version}</div>
      </div>
      <div class="tile">
        <div class="tile-label">Platform</div>
        <div class="tile-value">Linux / Docker</div>
      </div>
      <div class="tile">
        <div class="tile-label">Port</div>
        <div class="tile-value accent">80</div>
      </div>
    </div>

    <!-- Stack -->
    <div class="stack">
      <span class="badge badge-blue">AWS ALB</span>
      <span class="badge badge-blue">EC2 t3.small</span>
      <span class="badge badge-violet">Kubernetes</span>
      <span class="badge badge-violet">Minikube</span>
      <span class="badge badge-green">Docker</span>
      <span class="badge badge-green">Node.js</span>
      <span class="badge badge-orange">Terraform</span>
    </div>

    <!-- Flow -->
    <div class="flow">
      <span class="flow-node">Internet</span>
      <span class="flow-arrow">→</span>
      <span class="flow-node">ALB :80</span>
      <span class="flow-arrow">→</span>
      <span class="flow-node">EC2 :30080</span>
      <span class="flow-arrow">→</span>
      <span class="flow-node">K8s Service</span>
      <span class="flow-arrow">→</span>
      <span class="flow-node">Pod :80</span>
    </div>

    <!-- YouTube -->
    <div class="yt-section">
      <div class="yt-label">🎵 Nhạc nền</div>
      <div class="yt-grid">

        <!-- Video 1: Ấn Độ Mixi (16:9) -->
        <div class="yt-item">
          <div class="yt-title">🎶 Ấn Độ Mixi</div>
          <div class="yt-frame">
            <iframe
              id="yt1"
              src="https://www.youtube.com/embed/PD61lIYrG-M?loop=1&playlist=PD61lIYrG-M"
              title="Ấn Độ Mixi"
              frameborder="0"
              allow="encrypted-media"
              allowfullscreen>
            </iframe>
          </div>
        </div>

        <!-- Video 2: Shorts (9:16) -->
        <div class="yt-item">
          <div class="yt-title">🎶 Shorts</div>
          <div class="yt-frame shorts">
            <iframe
              id="yt2"
              src="https://www.youtube.com/embed/wLoUtL6BkKM?loop=1&playlist=wLoUtL6BkKM"
              title="Shorts"
              frameborder="0"
              allow="encrypted-media"
              allowfullscreen>
            </iframe>
          </div>
        </div>

      </div>
    </div>

    <div class="footer">Cloud DevOps © 2026</div>
  </div>

  <script>
    // ── Hostname API ────────────────────────────────────────────────────
    fetch('/api/info').then(r => r.json()).then(d => {
      document.getElementById('hostname').textContent = d.hostname;
    }).catch(() => {});

    // ── Particles canvas ────────────────────────────────────────────────
    const canvas = document.getElementById('canvas');
    const ctx    = canvas.getContext('2d');
    let W, H, particles = [];

    function resize() {
      W = canvas.width  = window.innerWidth;
      H = canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    const COLORS = ['#38bdf8','#818cf8','#4ade80','#fb923c','#f472b6'];

    class Particle {
      constructor() { this.reset(); }
      reset() {
        this.x  = Math.random() * W;
        this.y  = Math.random() * H;
        this.r  = Math.random() * 2 + 0.5;
        this.vx = (Math.random() - .5) * .4;
        this.vy = (Math.random() - .5) * .4;
        this.color = COLORS[Math.floor(Math.random() * COLORS.length)];
        this.alpha = Math.random() * .5 + .1;
      }
      update() {
        this.x += this.vx;
        this.y += this.vy;
        if (this.x < 0 || this.x > W || this.y < 0 || this.y > H) this.reset();
      }
      draw() {
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2);
        ctx.fillStyle = this.color;
        ctx.globalAlpha = this.alpha;
        ctx.fill();
        ctx.globalAlpha = 1;
      }
    }

    for (let i = 0; i < 120; i++) particles.push(new Particle());

    // Draw lines between nearby particles
    function drawLinks() {
      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const dx = particles[i].x - particles[j].x;
          const dy = particles[i].y - particles[j].y;
          const dist = Math.sqrt(dx*dx + dy*dy);
          if (dist < 100) {
            ctx.beginPath();
            ctx.moveTo(particles[i].x, particles[i].y);
            ctx.lineTo(particles[j].x, particles[j].y);
            ctx.strokeStyle = '#38bdf8';
            ctx.globalAlpha = (1 - dist/100) * .08;
            ctx.lineWidth = .5;
            ctx.stroke();
            ctx.globalAlpha = 1;
          }
        }
      }
    }

    function animate() {
      ctx.clearRect(0, 0, W, H);
      drawLinks();
      particles.forEach(p => { p.update(); p.draw(); });
      requestAnimationFrame(animate);
    }
    animate();

    // ── Cursor trail ────────────────────────────────────────────────────
    const trailColors = ['#38bdf8','#818cf8','#4ade80','#f472b6','#fb923c'];
    let trailIdx = 0;

    document.addEventListener('mousemove', e => {
      const dot = document.createElement('div');
      dot.className = 'trail';
      dot.style.cssText = \`
        left:\${e.clientX}px;
        top:\${e.clientY}px;
        background:\${trailColors[trailIdx % trailColors.length]};
        opacity:.7;
      \`;
      document.body.appendChild(dot);
      trailIdx++;
      setTimeout(() => { dot.style.opacity = '0'; }, 100);
      setTimeout(() => dot.remove(), 500);
    });
  </script>
</body>
</html>`;

const server = http.createServer((req, res) => {
  if (req.url === '/api/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ hostname: os.hostname(), platform: os.platform() }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html);
});

const PORT = process.env.PORT || 80;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));
