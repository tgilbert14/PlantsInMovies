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

/* The atlas lens is optional. Native sliders provide the same control on keys/touch. */
(() => {
  const root = document.documentElement;
  const send = (name,value) => window.Shiny?.setInputValue(name,value,{priority:'event'});
  const positions = new WeakMap();
  function paintLens(scene,x,y) {
    const surface=scene.querySelector('.scene-specimen'), img=surface?.querySelector('img'), lens=surface?.querySelector('.specimen-lens');
    if(!img?.naturalWidth || !lens || !surface.classList.contains('lens-active')) return;
    x=Math.max(0,Math.min(100,x)); y=Math.max(0,Math.min(100,y)); positions.set(scene,{x,y});
    const w=surface.clientWidth,h=surface.clientHeight,scale=Math.max(w/img.naturalWidth,h/img.naturalHeight)*1.65,iw=img.naturalWidth*scale,ih=img.naturalHeight*scale;
    const px=x*w/100,py=y*h/100,part=surface.dataset.plate==='arrakis'?0:surface.dataset.plate==='islanublar'?1:.5;
    // The lens stays inside its plate; its sampled point follows the full image crop.
    const radius=lens.offsetWidth/2, cx=Math.max(radius,Math.min(w-radius,px)),cy=Math.max(radius,Math.min(h-radius,py));
    lens.style.left=(cx-radius)+'px';lens.style.top=(cy-radius)+'px';
    lens.style.backgroundImage='url("'+img.getAttribute('src')+'")';
    lens.style.backgroundSize=(iw*2)+'px '+(ih*2)+'px';
    lens.style.backgroundPosition=(radius-6-(px-(w-iw)*part)*2)+'px '+(radius-6-(py-(h-ih)/2)*2)+'px';
  }
  function plateState(img) {
    const scene=img.closest('.world-scene'); if(!scene)return;
    const button=scene.querySelector('.lens-toggle'), caption=scene.querySelector('.lens-tools>span');
    if(!img.complete)return;
    button.disabled=!img.naturalWidth;
    const label=img.naturalWidth?'ILLUSTRATIVE PLATE / 2× DETAIL':'Illustration unavailable';
    if(caption.textContent!==label)caption.textContent=label;
    if(!img.naturalWidth){button.setAttribute('aria-pressed','false');scene.querySelector('.scene-specimen').classList.remove('lens-active');scene.querySelector('.lens-sliders').hidden=true;}
    else {const p=positions.get(scene)||{x:50,y:50};paintLens(scene,p.x,p.y);}
  }
  document.addEventListener('load',e=>{if(e.target.matches?.('.scene-specimen img'))plateState(e.target);},true);
  document.addEventListener('error',e=>{if(e.target.matches?.('.scene-specimen img'))plateState(e.target);},true);
  document.addEventListener('click',e=>{
    const toggle=e.target.closest('.lens-toggle');
    if(toggle){
      const scene=toggle.closest('.world-scene'),active=toggle.getAttribute('aria-pressed')!=='true';
      const img=scene.querySelector('.scene-specimen img');
      if(!img.naturalWidth){toggle.disabled=true;scene.querySelector('.lens-tools>span').textContent=img.complete?'Illustration unavailable':'Loading illustration…';return;}
      toggle.setAttribute('aria-pressed',String(active));
      scene.querySelector('.scene-specimen').classList.toggle('lens-active',active);
      scene.querySelector('.lens-sliders').hidden=!active;
      const pos=positions.get(scene)||{x:50,y:50};paintLens(scene,pos.x,pos.y);
    }
    if(e.target.closest('#next-world')){
      const worlds=[...document.querySelectorAll('.world-button')],at=worlds.findIndex(el=>el.getAttribute('aria-pressed')==='true');
      worlds[(at+1)%worlds.length]?.click();
    }
    if(e.target.closest('.world-button')){
      root.classList.remove('reel-changing');
      requestAnimationFrame(()=>root.classList.add('reel-changing'));
    }
    const collect=e.target.closest('#collect-family');
    if(collect&&!collect.disabled)send('collect_family',{world:collect.dataset.collectWorld,family:collect.dataset.collectFamily,nonce:Date.now()});
    const remove=e.target.closest('[data-remove-note]');
    if(remove){send('remove_note',remove.dataset.removeNote);document.querySelector('#notebook-heading')?.focus();}
    if(e.target.closest('#clear-notebook'))send('clear_notebook',Date.now());
  });
  document.addEventListener('input',e=>{
    if(!e.target.matches('.lens-x,.lens-y'))return;
    const scene=e.target.closest('.world-scene');
    paintLens(scene,Number(scene.querySelector('.lens-x').value),Number(scene.querySelector('.lens-y').value));
  });
  document.addEventListener('pointermove',e=>{
    const surface=e.target.closest('.scene-specimen.lens-active');if(!surface)return;
    const r=surface.getBoundingClientRect(),scene=surface.closest('.world-scene');
    const x=100*(e.clientX-r.left)/r.width,y=100*(e.clientY-r.top)/r.height;
    scene.querySelector('.lens-x').value=String(x);scene.querySelector('.lens-y').value=String(y);paintLens(scene,x,y);
  },{passive:true});
  window.addEventListener('resize',()=>document.querySelectorAll('.world-scene').forEach(scene=>{const p=positions.get(scene);if(p)paintLens(scene,p.x,p.y);}),{passive:true});
  let heroVisible=true;
  document.addEventListener('visibilitychange',()=>{root.dataset.hidden=String(document.hidden||!heroVisible);});
  function ready(){
    const scenes=document.getElementById('world_scene');
    if(scenes){const inspect=()=>scenes.querySelectorAll('.scene-specimen img').forEach(plateState);new MutationObserver(inspect).observe(scenes,{childList:true,subtree:true});inspect();}
    if('IntersectionObserver' in window){
      const observer=new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){entry.target.classList.add('reveal-ready');observer.unobserve(entry.target);}}),{threshold:.08});
      document.querySelectorAll('.family-section,.notebook-section,.all-worlds-section,.connections-section').forEach(el=>observer.observe(el));
      const ambient=new IntersectionObserver(entries=>entries.forEach(entry=>{heroVisible=entry.isIntersecting;root.dataset.hidden=String(!heroVisible||document.hidden);}),{threshold:0});
      const hero=document.querySelector('.atlas-arrival');if(hero)ambient.observe(hero);
    }
    if(window.Shiny)Shiny.addCustomMessageHandler('notebook-saved',message=>{
      const button=document.getElementById('collect-family');
      if(!button||button.dataset.collectWorld!==message.world||button.dataset.collectFamily!==message.family)return;
      const feedback=document.getElementById('collect-feedback');if(feedback)feedback.textContent=message.replaced?'Saved counts updated.':'Saved to your notebook.';
      if(button){button.classList.remove('notebook-stamped');requestAnimationFrame(()=>button.classList.add('notebook-stamped'));}
    });
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ready,{once:true});else ready();
})();
