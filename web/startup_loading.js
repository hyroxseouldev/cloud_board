(() => {
  const root = document.getElementById('app-startup');
  const error = document.getElementById('startup-error');
  const retry = document.getElementById('startup-retry');
  let finished = false;
  const visibility = () => root.toggleAttribute('data-paused', document.hidden);
  const hide = () => root.setAttribute('data-paused', '');
  const scriptError = event => {
    if (event.target?.tagName === 'SCRIPT' || /\/(main\.dart|flutter_bootstrap)\.js(?:[?#]|$)/.test(event.filename || '')) {
      window.appStartup.fail();
    }
  };
  const reload = () => window.location.reload();
  const cleanup = () => {
    document.removeEventListener('visibilitychange', visibility);
    window.removeEventListener('pagehide', hide);
    window.removeEventListener('pageshow', visibility);
    window.removeEventListener('error', scriptError, true);
    retry.removeEventListener('click', reload);
  };
  window.appStartup = {
    fail() {
      if (finished) return;
      root.setAttribute('data-failed', '');
      root.removeAttribute('aria-label');
      root.setAttribute('role', 'alert');
      error.hidden = false;
      retry.focus();
    },
    ready() {
      if (finished) return;
      finished = true;
      cleanup();
      root.remove();
    },
  };
  visibility();
  document.addEventListener('visibilitychange', visibility);
  window.addEventListener('pagehide', hide);
  window.addEventListener('pageshow', visibility);
  window.addEventListener('error', scriptError, true);
  retry.addEventListener('click', reload);
  // Engine event is sent only after the first Flutter frame is rendered. There
  // is no minimum brand duration, timer or dependency on Firebase completion.
  window.addEventListener('flutter-first-frame', window.appStartup.ready, {once: true});
})();
