// SPDX-License-Identifier: GPL-3.0-or-later
// Listen before the module graph starts, including failures in its dependencies.
addEventListener('error', event => {
  if (!(event.target instanceof HTMLScriptElement) || event.target.id !== 'farey-app') return;
  const message = document.getElementById('fatal');
  if (!message.hidden) return;
  message.hidden = false;
  message.textContent = 'The spatial view could not load. Reload this page. If you downloaded the package, keep its files together and start it with python3 serve.py instead of opening index.html directly.';
  document.querySelectorAll('.controls button, .controls input, .controls select').forEach(control => { control.disabled = true; });
  document.getElementById('xr').textContent = 'VR unavailable while the view cannot load';
}, true);
