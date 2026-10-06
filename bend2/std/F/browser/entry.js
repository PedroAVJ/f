import {startBend} from './shell.js';
const root = document.getElementById('app');
startBend(root, {onMessage(message) {
  if (message.type !== 'error' && message.type !== 'stderr') return;
  const error = document.createElement('p');
  error.setAttribute('role', 'alert');
  error.textContent = message.text || 'The preview could not start.';
  root.after(error);
}});
await import('./address.js');
