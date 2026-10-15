(() => {
  // Redirect auth must share its origin with Firebase's /__/auth/ helper.
  // Preserve deep links and use replace so Back cannot create a redirect loop.
  const current = new URL(window.location.href);
  if (current.hostname !== 'cloud-board-development.web.app') return;
  current.protocol = 'https:';
  current.hostname = 'cloud-board-development.firebaseapp.com';
  current.port = '';
  window.location.replace(current.href);
})();
