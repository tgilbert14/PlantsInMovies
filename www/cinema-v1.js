/* Logical state is sent immediately. Choreography never gates an action. */
(() => {
  const root = document.documentElement;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)');
  let userPaused = false;
  try { userPaused = localStorage.getItem('pim-motion-off') === '1'; } catch (_) {}
  function motion() {
    const off = userPaused || reduce.matches || Boolean(navigator.connection?.saveData);
    root.dataset.motion = off ? 'off' : 'on';
    const b = document.getElementById('motion-control');
    if (b) {
      b.setAttribute('aria-pressed', String(off));
      b.disabled = reduce.matches || Boolean(navigator.connection?.saveData);
      b.title = b.disabled ? 'Motion is off to respect your device preference' : (off ? 'Resume motion' : 'Pause motion');
    }
  }
  function send(name, value) { if (window.Shiny?.setInputValue) Shiny.setInputValue(name, value, {priority:'event'}); }
  document.addEventListener('click', e => {
    const world = e.target.closest('[data-world]');
    if (world) {
      document.querySelectorAll('[data-world]').forEach(b => b.setAttribute('aria-pressed', String(b === world)));
      send('world', world.dataset.world);
    }
    const family = e.target.closest('[data-family]');
    if (family) {
      document.querySelectorAll('[data-family]').forEach(b => b.setAttribute('aria-pressed', String(b === family)));
      send('family', family.dataset.family);
    }
    if (e.target.closest('#motion-control')) {
      userPaused = !(root.dataset.motion === 'off');
      try {localStorage.setItem('pim-motion-off', userPaused ? '1':'0');} catch(_) {}
      motion();
    }
    if (e.target.closest('#reset-states')) send('reset_states', Date.now());
  });
  document.addEventListener('keydown', e => {
    const remove = e.target.closest('.state-picker .remove');
    if (remove && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault();
      remove.click();
      document.querySelector('.state-picker .selectize-input input')?.focus();
      // Selectize schedules onFocus on a zero-delay timer after token removal.
      // Close after that callback, provided the user has not started typing.
      setTimeout(() => {
        const input = document.querySelector('.state-picker .selectize-input input');
        if (input && document.activeElement === input && !input.value)
          document.getElementById('state')?.selectize?.close();
      }, 0);
    }
  });
  reduce.addEventListener('change', motion);
  function status(text, offline = false) {
    const el = document.querySelector('.connection-status');
    if(el) {el.textContent=text; el.classList.toggle('offline',offline);}
  }
  function ready() {
    motion();
    const picker = document.querySelector('.state-picker');
    if (picker) {
      const labelRemovals = () => picker.querySelectorAll('.item[data-value] .remove').forEach(a => {
        a.setAttribute('aria-label', 'Remove ' + a.closest('.item').dataset.value);
        a.setAttribute('role', 'button');
        a.tabIndex = 0;
      });
      labelRemovals();
      new MutationObserver(labelRemovals).observe(picker, {childList:true,subtree:true});
    }
    if (window.jQuery) {
      $(document).on('shiny:connected',()=>{
        status('Ready to explore');
        const active = document.querySelector('[data-world][aria-pressed=true]');
        if(active) send('world',active.dataset.world);
      });
      $(document).on('shiny:disconnected',()=>status('Disconnected · reload to reconnect',true));
      $(document).on('shiny:busy',()=>status('Updating…'));
      $(document).on('shiny:idle',()=>status('Ready to explore'));
    }
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',ready,{once:true}); else ready();
})();
