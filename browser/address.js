// The address bar follows the page an F app shows (its [data-bend-address] mark): a new page pushes an
// entry, or replaces it when it answers an address sent from here. The first load, back and forward send
// the address to the app as an "address · <path>" event, through a hidden button's click.
const root = document.getElementById('app');
let last, follow = true;
const send = () => {
  const b = document.createElement('button');
  b.hidden = true; b.dataset.bendEvent = 'address · ' + location.pathname;
  root.append(b); b.click(); b.remove(); follow = true;
};
new MutationObserver(() => {
  const a = root.querySelector('[data-bend-address]')?.dataset.bendAddress;
  if (!a || a === last) return;
  last = a;
  if (a !== location.pathname) history[follow ? 'replaceState' : 'pushState'](null, '', a);
  follow = false;
}).observe(root, {subtree: true, childList: true, attributes: true, attributeFilter: ['data-bend-address']});
addEventListener('popstate', send);
send();
