import { useMemo, useState } from 'react';

export default function App() {
  const [count, setCount] = useState(0);
  const [darkMode, setDarkMode] = useState(true);

  const statusText = useMemo(() => (navigator.onLine ? 'Online' : 'Offline'), []);

  return (
    <main className="app-shell">
      <section className="hero-card">
        <p className="eyebrow">Cloud DevOps Demo</p>
        <h1>React FE chạy bằng Vite</h1>
        <p className="lead">
          Đây là giao diện React đơn giản để bạn chạy nhanh bằng lệnh <strong>npm run dev</strong>.
        </p>

        <div className="actions">
          <button className="btn btn-primary" onClick={() => setCount((value) => value + 1)}>
            Refresh trạng thái
          </button>
          <button className="btn btn-secondary" onClick={() => setDarkMode((value) => !value)}>
            {darkMode ? 'Chuyển sang light mode' : 'Chuyển sang dark mode'}
          </button>
        </div>
      </section>

      <section className="stats-grid">
        <article className="stat-card accent-blue">
          <span>API Status</span>
          <strong style={{ color: navigator.onLine ? 'var(--accent)' : '#fca5a5' }}>{statusText}</strong>
          <small>Backend đang chạy</small>
        </article>
        <article className="stat-card accent-green">
          <span>Deploy</span>
          <strong>Argo CD</strong>
          <small>GitOps ready</small>
        </article>
        <article className="stat-card accent-gold">
          <span>Counter</span>
          <strong>{count}</strong>
          <small>Nhấn nút để tăng</small>
        </article>
      </section>

      <section className="panel-grid">
        <article className="panel-card">
          <h2>Chạy nhanh</h2>
          <ol>
            <li>cd CICD_repo/FE</li>
            <li>npm install</li>
            <li>npm run dev</li>
          </ol>
        </article>

        <article className="panel-card">
          <h2>Ghi chú</h2>
          <ul>
            <li>Trang này đã chuyển sang React + Vite.</li>
            <li>Bạn có thể mở tại http://localhost:3000.</li>
            <li>Build production bằng npm run build.</li>
          </ul>
        </article>
      </section>
    </main>
  );
}
