const apiStatus = document.getElementById('apiStatus');
const counterValue = document.getElementById('counterValue');
const refreshBtn = document.getElementById('refreshBtn');
const themeBtn = document.getElementById('themeBtn');

let count = 0;

function updateStatus() {
  const isOnline = navigator.onLine;
  apiStatus.textContent = isOnline ? 'Online' : 'Offline';
  apiStatus.style.color = isOnline ? 'var(--accent)' : '#fca5a5';
}

refreshBtn.addEventListener('click', () => {
  count += 1;
  counterValue.textContent = String(count);
  updateStatus();
});

themeBtn.addEventListener('click', () => {
  document.documentElement.classList.toggle('light-theme');
});

window.addEventListener('online', updateStatus);
window.addEventListener('offline', updateStatus);

updateStatus();
