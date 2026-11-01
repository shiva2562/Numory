// Numory promo: every scene, transition and effect, built into #world and driven by one paused GSAP timeline.
// Shared by landscape/ (1920x1080) and portrait/ (1080x1920); the layout branches on P (portrait).
// Times come from assets/edit.js (the same edit score.py reads), on a 120 BPM grid: a beat is 0.5 s, a bar 2 s.
// Deterministic: a seeded generator, no clock, no network. Anything that changes every frame (the game's board, its
// clock, the sparks, the synthwave floor, the globe) is a pure function of the time t, drawn by one ticker tween.
//
// The play screen is the game's own (lib/features/play/play_screen.dart, lib/theme.dart) at its logical size,
// 400 x 866 dp, with the same colours, glows, fonts, rules and juice: the sparks use the app's numbers and its
// physics, the clock starts with the numbers, a wrong tap shakes the board and glitches it red.
window.buildNumoryPromo = (opts = {}) => {
  const A = opts.assets || 'assets/';
  const E = window.NUMORY_EDIT, CUT = E.cuts, DUR = E.duration, BEAT = 60 / E.bpm;
  const root = document.getElementById('root');
  const W = +root.dataset.width, H = +root.dataset.height, P = H > W;
  const world = document.getElementById('world');
  const tl = gsap.timeline({ paused: true });
  const VARS = (window.__hyperframes && window.__hyperframes.getVariables && window.__hyperframes.getVariables()) || {};
  const CTA = VARS.cta || 'Coming soon to Google Play';
  const L = (land, port) => (P ? port : land);

  // ---------- palette and the app's glows (lib/theme.dart) ----------
  const C = { ink: '#07030F', board: '#05020B', cell: '#140B26', tile: '#F2FDFF', text: '#F4F0FF', muted: '#9A8FB8', magenta: '#FF2BD6', cyan: '#19F0FF', violet: '#8B3DFF', good: '#3DFF9A', bad: '#FF3355', gold: '#FFE45C' };
  const rgb = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
  const rgba = (h, a) => { const [r, g, b] = Array.isArray(h) ? h : rgb(h); return `rgba(${r},${g},${b},${+a.toFixed(3)})`; };
  const mixc = (a, b, t) => { const x = Array.isArray(a) ? a : rgb(a), y = Array.isArray(b) ? b : rgb(b); return x.map((v, i) => Math.round(v + (y[i] - v) * t)); };
  const glow = (h, s = 1) => `0 0 ${4 * s}px ${rgba(h, 0.9)}, 0 0 ${12 * s}px ${rgba(h, 0.6)}, 0 0 ${28 * s}px ${rgba(h, 0.35)}`;
  const boxGlow = (h, s = 1, a = 1) => `0 0 ${10 * s}px ${rgba(h, 0.55 * a)}, 0 0 ${30 * s}px ${2 * s}px ${rgba(h, 0.25 * a)}`;

  // ---------- helpers ----------
  function mulberry32(a) {
    return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
  }
  const rnd = mulberry32(20261101);
  const R = (a, b) => a + (b - a) * rnd();
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const easeIO = x => x < 0.5 ? 2 * x * x : 1 - (-2 * x + 2) ** 2 / 2;

  function el(tag, cls, parent, css, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (css) for (const k in css) e.style[k] = typeof css[k] === 'number' && !/opacity|zIndex|fontWeight|lineHeight|flex/.test(k) ? css[k] + 'px' : css[k];
    if (html !== undefined) e.innerHTML = html;
    (parent || world).appendChild(e);
    return e;
  }
  const img = (src, parent, css) => { const e = el('img', 'abs', parent, css); e.src = src; e.decoding = 'sync'; return e; };
  function canvas(parent, w, h, res, css) {
    const c = el('canvas', 'abs', parent, Object.assign({ left: 0, top: 0, width: w, height: h }, css || {}));
    c.width = Math.round(w * res); c.height = Math.round(h * res);
    const ctx = c.getContext('2d');
    ctx.scale(res, res);
    return { el: c, ctx, w, h, res };
  }
  function scene(id, z, tIn, tOut) {
    const s = el('div', 'scene', world, { zIndex: z });
    s.id = id;
    if (tIn <= 0) gsap.set(s, { autoAlpha: 1 }); else tl.set(s, { autoAlpha: 1 }, tIn);
    if (tOut !== undefined) tl.set(s, { autoAlpha: 0 }, tOut);
    return s;
  }
  // Nothing on the timeline sits at exactly 0: a state that holds from the first frame is set on the element itself, so
  // it is also what the timeline reverts to (the runtime runs the timeline to the end and back before it seeks).
  const show = (e, t) => tl.set(e, { autoAlpha: 1 }, t);
  const hide = (e, t) => (t <= 0 ? gsap.set(e, { autoAlpha: 0 }) : tl.set(e, { autoAlpha: 0 }, t));

  // per-frame work: fn(t) runs while t is in [t0, t1)
  const frames = [];
  const onFrame = (t0, t1, fn) => frames.push({ t0, t1, fn });

  // a neon line of type: core plus magenta / cyan ghosts (the app's _NeonLetter), glow scaled to the size
  function neon(parent, html, size, css = {}, o = {}) {
    const { core = '#FFF4FD', split = 0.045, ghosts = true, glowColor = null, strength = 1 } = o;
    const box = el('div', 'neon', parent, Object.assign({ fontSize: size, letterSpacing: '0.04em' }, css));
    const s = (size / 56) * strength;
    if (ghosts) {
      el('div', 'ghost', box, { color: rgba(C.magenta, 0.85), textShadow: glow(C.magenta, s), transform: `translateX(${-split * size}px)` }, html);
      el('div', 'ghost', box, { color: rgba(C.cyan, 0.85), textShadow: glow(C.cyan, s), transform: `translateX(${split * size}px)` }, html);
    }
    el('div', 'core', box, { color: core, textShadow: glowColor ? glow(glowColor, s * 0.8) : 'none' }, html);
    return box;
  }
  // a tube catching: dark beats (seconds from t), then on
  const TUBE = [[0, 0.12], [0.26, 0.33], [0.48, 0.52], [0.70, 0.74]]; // the app's Wordmark launch
  const FLICK = [[0, 0.12], [0.22, 0.30], [0.38, 0.42], [0.55, 0.58]].map(([a, b]) => [a * 0.7, b * 0.7]); // the app's Flicker (700 ms)
  function flickerOn(e, t, dark = TUBE, low = 0.12) {
    hide(e, 0);
    t = Math.max(t, 0.001);
    tl.set(e, { autoAlpha: low }, t);
    for (const [a, b] of dark) {
      if (a > 0) tl.set(e, { autoAlpha: low }, t + a);
      tl.set(e, { autoAlpha: 1 }, t + b);
    }
  }
  // lands exactly on t: drops in from big, a squash on impact
  function slam(e, t, from = 1.7, dur = 0.16) {
    hide(e, 0);
    tl.fromTo(e, { scale: from, autoAlpha: 0 }, { scale: 1, autoAlpha: 1, duration: dur, ease: 'power4.in', immediateRender: false }, t - dur);
    tl.to(e, { keyframes: [{ scale: 1.05, duration: 0.05 }, { scale: 1, duration: 0.2, ease: 'back.out(3)' }] }, t);
  }
  function riseIn(e, t, dy = 30, dur = 0.4) {
    hide(e, 0);
    tl.fromTo(e, { y: dy, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: dur, ease: 'power3.out', immediateRender: false }, t);
  }
  function popIn(e, t, s0 = 0.5, dur = 0.32) {
    hide(e, 0);
    tl.fromTo(e, { scale: s0, autoAlpha: 0 }, { scale: 1, autoAlpha: 1, duration: dur, ease: 'back.out(2.2)', immediateRender: false }, t);
  }
  function fadeOut(e, t, dur = 0.2) {
    tl.to(e, { autoAlpha: 0, duration: dur, immediateRender: false }, t);
  }
  function shake(target, t, amp = 14, dur = 0.3) {
    const k = [];
    const n = Math.round(dur / 0.035);
    for (let i = 0; i < n; i++) { const a = amp * (1 - i / n); k.push({ x: R(-a, a), y: R(-a, a), duration: 0.035, ease: 'none' }); }
    k.push({ x: 0, y: 0, duration: 0.035 });
    tl.to(target, { keyframes: k }, t);
  }
  function flash(parent, t, color = '#fff', peak = 0.9, dur = 0.35, z = 900) {
    const f = el('div', 'fill', parent || world, { background: color, opacity: 0, zIndex: z });
    tl.fromTo(f, { opacity: peak }, { opacity: 0, duration: dur, ease: 'power2.out', immediateRender: false }, t);
    return f;
  }
  // a VHS tear: bands of magenta, cyan and white slide across for a few frames, the frame jitters
  function glitchCut(t, len = 0.2, z = 960) {
    const g = el('div', 'fill', world, { zIndex: z });
    hide(g, 0); show(g, t - len / 2); hide(g, t + len / 2);
    const n = 9;
    for (let i = 0; i < n; i++) {
      const b = el('div', 'abs', g, { left: 0, width: W, top: R(0, H), height: R(6, H * 0.06), background: [C.magenta, C.cyan, '#fff', C.violet][i % 4], opacity: R(0.35, 0.85), mixBlendMode: 'screen' });
      const k = [];
      for (let f = 0; f < 6; f++) k.push({ x: R(-W * 0.3, W * 0.3), y: R(-40, 40), scaleY: R(0.4, 1.6), duration: len / 6, ease: 'steps(1)' });
      tl.to(b, { keyframes: k }, t - len / 2);
    }
    shake(world, t - len / 2, 18, len);
  }
  // a laser line sweeps down the frame; the next scene is revealed above it
  function laserWipe(next, t, dur = 0.3) {
    const line = el('div', 'abs', world, { left: -40, width: W + 80, top: 0, height: 6, zIndex: 970, background: '#fff', boxShadow: `0 0 18px 6px ${C.cyan}, 0 0 60px 18px ${rgba(C.magenta, 0.7)}` });
    hide(line, 0); show(line, t - dur); hide(line, t + 0.02);
    tl.fromTo(line, { y: -10 }, { y: H + 10, duration: dur, ease: 'power2.in', immediateRender: false }, t - dur);
    tl.set(next, { autoAlpha: 1 }, t - dur);
    tl.fromTo(next, { clipPath: 'inset(0% 0% 100% 0%)' }, { clipPath: 'inset(0% 0% 0% 0%)', duration: dur, ease: 'power2.in', immediateRender: false }, t - dur);
  }

  // ---------- the synthwave night (lib/theme.dart _SynthwavePainter, with the camera's own numbers) ----------
  function drawSynth(ctx, w, h, o) {
    const { horizon = 0.7, dim = 1, phase = 0, sun = null, fan = 0.96, lift = 0, scan = true, pulse = 0, stars = null } = o;
    const hy = h * horizon;
    let g = ctx.createLinearGradient(0, 0, 0, hy);
    g.addColorStop(0, C.ink); g.addColorStop(0.6, '#1A0733'); g.addColorStop(1, rgba(mixc('#4A0E5C', C.ink, 0.5 - 0.5 * lift), 1));
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, hy + 1);
    if (stars) for (const s of stars) { ctx.fillStyle = rgba('#ffffff', s.a * (0.6 + 0.4 * Math.sin(s.p + phase * 2))); ctx.fillRect(s.x * w, s.y * hy, s.s, s.s); }
    if (sun && sun.a > 0) {
      const { r, cx = w / 2, cy } = sun;
      ctx.save();
      ctx.globalAlpha = sun.a;
      let hg = ctx.createRadialGradient(cx, cy, r * 0.6, cx, cy, r * 1.9);
      hg.addColorStop(0, rgba(C.magenta, 0.28 + 0.12 * pulse)); hg.addColorStop(1, rgba(C.magenta, 0));
      ctx.fillStyle = hg; ctx.fillRect(cx - r * 2, cy - r * 2, r * 4, r * 4);
      ctx.beginPath(); ctx.rect(0, 0, w, hy); ctx.clip();
      ctx.beginPath();
      ctx.rect(cx - r, cy - r, 2 * r, 2 * r);
      for (let i = 0; i < 6; i++) { const y = cy + r * (0.05 + i * 0.16); ctx.rect(cx - r, y, 2 * r, r * (0.025 + i * 0.012)); }
      ctx.clip('evenodd');
      const sg = ctx.createLinearGradient(0, cy - r, 0, cy + r);
      sg.addColorStop(0, C.gold); sg.addColorStop(0.5, '#FF7A3D'); sg.addColorStop(1, C.magenta);
      ctx.fillStyle = sg; ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
    // horizon
    g = ctx.createLinearGradient(0, hy - 30, 0, hy + 30);
    g.addColorStop(0, rgba(C.magenta, 0)); g.addColorStop(0.5, rgba(C.magenta, (0.22 + 0.2 * pulse) * dim)); g.addColorStop(1, rgba(C.magenta, 0));
    ctx.fillStyle = g; ctx.fillRect(0, hy - 30, w, 60);
    ctx.fillStyle = rgba(C.magenta, 0.9 * dim); ctx.fillRect(0, hy - 1.5, w, 3);
    // floor
    g = ctx.createLinearGradient(0, hy, 0, h);
    g.addColorStop(0, '#12052A'); g.addColorStop(1, C.ink);
    ctx.fillStyle = g; ctx.fillRect(0, hy, w, h - hy);
    ctx.save();
    ctx.beginPath(); ctx.rect(0, hy, w, h - hy); ctx.clip();
    const depth = h - hy, v = ((phase % 1) + 1) % 1;
    const lw = Math.max(1.2, h / 700);
    for (let i = 0; i < 14; i++) {
      const p = (i + v) / 14, y = hy + depth * p * p, fade = clamp(p * 1.6, 0, 1);
      ctx.fillStyle = rgba(C.cyan, (0.14 + 0.1 * pulse) * dim * fade); ctx.fillRect(0, y - lw * 2, w, lw * 4);
      ctx.fillStyle = rgba(C.cyan, (0.55 + 0.25 * pulse) * dim * fade); ctx.fillRect(0, y - lw / 2, w, lw);
    }
    const bottom = fan * w;
    for (let i = -12; i <= 12; i++) {
      const x1 = w / 2 + i * bottom;
      ctx.lineWidth = lw * 4; ctx.strokeStyle = rgba(C.cyan, 0.12 * dim);
      ctx.beginPath(); ctx.moveTo(w / 2, hy); ctx.lineTo(x1, h); ctx.stroke();
      ctx.lineWidth = lw; ctx.strokeStyle = rgba(C.cyan, (0.45 + 0.2 * pulse) * dim);
      ctx.beginPath(); ctx.moveTo(w / 2, hy); ctx.lineTo(x1, h); ctx.stroke();
    }
    ctx.restore();
    if (scan) { ctx.fillStyle = 'rgba(0,0,0,0.13)'; for (let y = 0; y < h; y += 4) ctx.fillRect(0, y, w, 1.5); }
  }
  // a full-frame synthwave layer whose numbers are functions of t
  function synthLayer(parent, t0, t1, params) {
    const cv = canvas(parent, W, H, 1);
    onFrame(t0, t1, t => { cv.ctx.clearRect(0, 0, W, H); drawSynth(cv.ctx, W, H, params(t)); });
    return cv;
  }
  // floor phase: rows advance one spacing per `per` seconds; piecewise speeds integrate to a continuous phase
  function phaseOf(t, table) { // table: [[from, rowsPerSecond], ...] sorted
    let ph = 0;
    for (let i = 0; i < table.length; i++) {
      const [a, sp] = table[i], b = i + 1 < table.length ? table[i + 1][0] : Infinity;
      if (t <= a) break;
      ph += (Math.min(t, b) - a) * sp;
    }
    return ph;
  }
  const kick = t => { const d = drumsAt(t); if (!d) return 0; const x = (t % BEAT) / BEAT; return Math.exp(-x * 6); };
  function drumsAt(t) { return (t >= 2 && t < CUT.stop) || (t >= CUT.modes && t < CUT.chimp) || (t >= CUT.chimpDrop && t < CUT.final + 0.5); }
  const STARS = Array.from({ length: 90 }, () => ({ x: R(0, 1), y: R(0, 0.9), s: R(1, 2.6), a: R(0.15, 0.6), p: R(0, 6.28) }));

  // ---------- the game: one round on the board, as a function of time ----------
  const SW = 400, SH = 866, PB = 9; // logical screen (dp) and the phone's frame
  const BW = 368, BH = BW * 8 / 5, BX = 16, BY = 72 + (SH - 72 - 54 - BH) / 2; // the board, as the app lays it out
  const CW = (BW - 9) / 5, CHh = (BH - 9) / 8;
  const fmt = s => { const c = Math.floor(s * 100 + 1e-6); return `${Math.floor(c / 100)}.${String(c % 100).padStart(2, '0')}`; };

  function roundModel(r) {
    const cellOf = {}, numAt = {}, tapAt = {};
    for (const k in r.cells) { cellOf[+k] = r.cells[k]; numAt[r.cells[k]] = +k; }
    for (const [n, t] of r.taps) tapAt[n] = t;
    const finish = r.taps.length === r.count ? r.taps[r.taps.length - 1][1] : null;
    const wrong = r.wrong ? { num: r.wrong[0], t: r.wrong[1] } : null;
    const end = finish !== null ? finish : wrong ? wrong.t : null;
    const events = [r.appear, ...r.taps.map(x => x[1]), ...(wrong ? [wrong.t] : [])].sort((a, b) => a - b);
    const state = t => {
      let next = 1;
      while (tapAt[next] !== undefined && tapAt[next] <= t) next++;
      return { shown: t >= r.appear, hidden: tapAt[1] !== undefined && t >= tapAt[1], lost: !!wrong && t >= wrong.t, won: finish !== null && t >= finish, next };
    };
    const elapsed = t => t < r.appear ? 0 : (end !== null && t >= end ? end : t) - r.appear + (r.clockOffset || 0);
    return { r, cellOf, numAt, tapAt, finish, wrong, end, events, state, elapsed };
  }
  // the app's _Cell decoration for a square, in a state
  const EMPTY = { fill: [...rgb(C.cell), 0.7], edge: [...rgb(C.violet), 0.18], glow: null, label: null };
  function cellLook(m, st, cell) {
    const n = m.numAt[cell];
    if (n === undefined || !st.shown) return EMPTY;
    if (st.lost && n === m.wrong.num) return { fill: [...rgb(C.bad), 1], edge: [...rgb(C.bad), 1], glow: [C.bad, 1.2], label: n, color: C.ink };
    if (st.lost && cell === m.cellOf[st.next]) return { fill: [...rgb(C.gold), 1], edge: [...rgb(C.gold), 1], glow: [C.gold, 1.2], label: n, color: C.ink };
    if (m.tapAt[n] !== undefined && st.next > n) return { fill: [...rgb(C.good), 0.10], edge: [...rgb(C.good), 0.45], glow: null, label: null };
    if (st.hidden && !st.lost) return { fill: [...rgb(C.tile), 1], edge: [...rgb(C.cyan), 1], glow: [C.cyan, 0.8], label: null };
    return { fill: [...rgb(C.cell), 0], edge: [...rgb(C.cyan), 0.35], glow: null, label: n, color: st.lost ? C.muted : '#DFFBFF', lglow: !st.lost };
  }
  const mix4 = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
  function boxShadowOf(gl, a) { return gl && a > 0.01 ? boxGlow(gl[0], gl[1], a) : 'none'; }

  // the sparks (lib/features/play/sparks.dart): same counts, speeds, lives, sizes and physics, solved in closed form
  function burst(seed, x, y, t0, count, speed, colors) {
    const r = mulberry32(seed), out = [];
    for (let i = 0; i < count; i++) {
      const a = r() * Math.PI * 2, v = (120 + r() * 260) * speed;
      out.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, color: colors[Math.floor(r() * colors.length)], life: 0.35 + r() * 0.35 * speed, size: 1.5 + r() * 2.5, t0 });
    }
    return out;
  }
  const KD = Math.log(1 / 0.04), GRAV = 320;
  function drawSparks(ctx, sparks, t) {
    for (const s of sparks) {
      const age = t - s.t0;
      if (age < 0 || age >= s.life) continue;
      const e = 1 - Math.exp(-KD * age);
      const px = s.x + s.vx * e / KD, py = s.y + s.vy * e / KD + (GRAV / KD) * (age - e / KD);
      const f = 1 - age / s.life;
      const hr = s.size * 2.2 + 4;
      const hg = ctx.createRadialGradient(px, py, 0, px, py, hr);
      hg.addColorStop(0, rgba(s.color, 0.6 * f)); hg.addColorStop(1, rgba(s.color, 0));
      ctx.fillStyle = hg; ctx.beginPath(); ctx.arc(px, py, hr, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = rgba(mixc(s.color, '#ffffff', 0.5), f); ctx.beginPath(); ctx.arc(px, py, s.size * f + 0.5, 0, Math.PI * 2); ctx.fill();
    }
  }

  const HOME_SVG = `<svg width="24" height="24" viewBox="0 0 24 24" style="filter: drop-shadow(0 0 2px ${C.cyan}) drop-shadow(0 0 6px ${rgba(C.cyan, 0.6)})"><path fill="${C.cyan}" d="M10 19v-5h4v5c0 .55.45 1 1 1h3c.55 0 1-.45 1-1v-7h1.7c.46 0 .68-.57.33-.87L12.67 3.6c-.38-.34-.96-.34-1.34 0l-8.36 7.53c-.34.3-.13.87.33.87H5v7c0 .55.45 1 1 1h3c.55 0 1-.45 1-1z"/></svg>`;
  const SHARE_SVG = `<svg width="18" height="18" viewBox="0 0 24 24"><path fill="${C.cyan}" d="M16 5l-1.42 1.42-1.59-1.59V16h-1.98V4.83L9.42 6.42 8 5l4-4 4 4zm4 5v11c0 1.1-.9 2-2 2H6a2 2 0 0 1-2-2V10c0-1.11.89-2 2-2h3v2H6v11h12V10h-3V8h3a2 2 0 0 1 2 2z"/></svg>`;

  // a neon button (lib/theme.dart NeonButton), breathing on its 1.6 s loop
  function neonButton(parent, label, t0, t1) {
    const b = el('div', 'neonbtn', parent, { position: 'relative' });
    el('div', '', b, { textShadow: glow(C.magenta, 0.7) }, label.toUpperCase());
    onFrame(t0, t1, t => {
      const wave = Math.sin(((t - t0) / 1.6) * Math.PI * 2) * 0.5 + 0.5;
      b.style.transform = `scale(${1 + 0.04 * wave})`;
      b.style.boxShadow = `${boxGlow(C.magenta, 0.6 + 0.5 * wave)}, 8px 0 22px ${rgba(C.cyan, 0.25 + 0.2 * wave)}`;
    });
    return b;
  }

  // the play screen in a phone. Returns the phone (to place and move) and its board (for the camera)
  function phone(parent, round, o) {
    const m = roundModel(round);
    const { cx, cy, scale, t0, t1 } = o;
    const ph = el('div', 'phone', parent, { left: cx - (SW + 2 * PB) / 2, top: cy - (SH + 2 * PB) / 2, width: SW + 2 * PB, height: SH + 2 * PB, boxShadow: `0 0 30px ${rgba(C.magenta, 0.55)}, 0 0 90px ${rgba(C.violet, 0.45)}, 0 40px 120px rgba(0,0,0,.6)` });
    gsap.set(ph, { scale });
    const scr = el('div', 'screen', ph, { width: SW, height: SH });
    const res = scale * 1.25;
    const bg = canvas(scr, SW, SH, res);
    drawSynth(bg.ctx, SW, SH, { horizon: 0.7, dim: 0.45, phase: 0.35, fan: 0.96, lift: 0 }); // calm: the floor stands still in a round
    // top bar
    const bar = el('div', 'topbar', scr);
    el('div', 'home', bar, {}, HOME_SVG);
    el('div', 'label', bar, {}, `${round.mode.toUpperCase()} · ${round.count}`);
    const clock = el('div', 'clock', bar, {}, '0.00');
    const best = el('div', 'best', bar, {}, `Best ${round.bestBefore}`);
    // board
    const bb = el('div', 'boardbox', scr, { left: BX, top: BY, width: BW, height: BH });
    const board = el('div', 'board', bb, { boxShadow: `${boxGlow(C.cyan, 0.7)}, ${boxGlow(C.magenta, 0.4)}` });
    const cells = [];
    for (let i = 0; i < 40; i++) {
      const c = el('div', 'cellbox', board, { left: 3 + (i % 5) * CW + 2, top: 3 + Math.floor(i / 5) * CHh + 2, width: CW - 4, height: CHh - 4 });
      const sp = el('span', '', c);
      cells.push({ c, sp, last: '' });
    }
    // overlays: the glitch, the flash, the touches, the sparks
    const fx = canvas(bb, BW + 240, BH + 240, res, { left: -120, top: -120, zIndex: 5 });
    const flashEl = el('div', 'fill', bb, { borderRadius: 18, opacity: 0, zIndex: 4, background: `radial-gradient(circle, ${rgba(C.tile, 0.55)} 0%, ${rgba(C.cyan, 0.25)} 50%, rgba(0,0,0,0) 100%)` });
    const line = el('div', 'playline', scr, { top: SH - 16 - 24 });
    // sparks: one burst per tap, as the app fires them
    const sparks = [];
    const center = cell => [120 + 4.5 + CW * (cell % 5 + 0.5), 120 + 4.5 + CHh * (Math.floor(cell / 5) + 0.5)];
    round.taps.forEach(([n, t], i) => {
      const [x, y] = center(m.cellOf[n]);
      if (t === m.finish) sparks.push(...burst(9000 + i * 31 + n, x, y, t, 70, 2.2, [C.cyan, C.magenta, C.gold, C.good, C.tile]));
      else sparks.push(...burst(9000 + i * 31 + n, x, y, t, 14, 1, [C.cyan, C.magenta, C.tile]));
    });
    if (m.wrong) { const [x, y] = center(m.cellOf[m.wrong.num]); sparks.push(...burst(777, x, y, m.wrong.t, 24, 1, [C.bad, C.magenta])); }
    // touches: a soft fingertip on each tapped square
    const touches = [...round.taps.map(([n, t]) => [m.cellOf[n], t]), ...(m.wrong ? [[m.cellOf[m.wrong.num], m.wrong.t]] : [])];
    for (const [cell, t] of touches) {
      const [x, y] = center(cell);
      const d = el('div', 'abs', bb, { left: x - 120 - 30, top: y - 120 - 30, width: 60, height: 60, borderRadius: '50%', zIndex: 6, background: 'radial-gradient(circle, rgba(255,255,255,.55) 0%, rgba(255,255,255,.25) 45%, rgba(255,255,255,0) 70%)', border: '2px solid rgba(255,255,255,.6)' });
      hide(d, 0);
      tl.fromTo(d, { scale: 0.5, autoAlpha: 0.95 }, { scale: 1.35, autoAlpha: 0, duration: 0.32, ease: 'power2.out', immediateRender: false }, t);
    }
    if (m.finish !== null) tl.fromTo(flashEl, { opacity: 1 }, { opacity: 0, duration: 0.7, ease: 'none', immediateRender: false }, m.finish);
    // result card
    let card = null;
    if (round.card !== undefined) {
      if (m.finish !== null) {
        card = el('div', 'card', bb, { borderColor: rgba(C.gold, 0.8), boxShadow: boxGlow(C.gold, 0.6), zIndex: 8 });
        const ttl = el('div', '', card, { fontFamily: 'var(--display)', fontWeight: 900, fontSize: 24, letterSpacing: 2, color: '#FFF6C2', textShadow: glow(C.gold) }, 'NEW BEST');
        el('div', '', card, { marginTop: 8, fontFamily: 'var(--display)', fontWeight: 900, fontSize: 42, color: '#E6FFF3', textShadow: glow(C.good, 1.2) }, `${fmt(m.elapsed(m.finish))} s`);
        const chip = el('div', 'chip', card, { marginTop: 14 });
        el('div', '', chip, { fontFamily: 'var(--display)', fontWeight: 900, fontSize: 26, letterSpacing: 1, color: '#FFD6F5', textShadow: glow(C.magenta) }, `#${round.rank}`);
        el('div', '', chip, { fontFamily: 'var(--body)', fontWeight: 900, fontSize: 11, color: C.muted }, 'IN THE WORLD · ALL TIME');
        const bw = el('div', '', card, { marginTop: 20 }); neonButton(bw, 'Play again', round.card, t1);
        el('div', '', card, { marginTop: 14, display: 'flex', alignItems: 'center', gap: '8px', fontFamily: 'var(--body)', fontWeight: 700, fontSize: 15, color: C.cyan }, `${SHARE_SVG}<span>Share</span>`);
        flickerOn(ttl, round.card, FLICK, 0.15);
        popIn(chip, round.card + 0.25, 0.7, 0.3);
      } else {
        card = el('div', 'card', bb, { borderColor: rgba(C.bad, 0.8), boxShadow: boxGlow(C.bad, 0.6), zIndex: 8 });
        const ttl = el('div', '', card, { fontFamily: 'var(--display)', fontWeight: 900, fontSize: 30, letterSpacing: 2, color: '#FFD0D8', textShadow: glow(C.bad) }, 'OOPS');
        el('div', '', card, { marginTop: 10, fontFamily: 'var(--body)', fontWeight: 700, fontSize: 16, color: C.muted, textAlign: 'center' },
          `That was <span style="color:${C.bad};text-shadow:${glow(C.bad, 0.6)}">${m.wrong.num}</span>. You needed <span style="color:${C.gold};text-shadow:${glow(C.gold, 0.6)}">${m.state(m.wrong.t).next}</span>.`);
        const bw = el('div', '', card, { marginTop: 20 }); neonButton(bw, 'Try again', round.card, t1);
        flickerOn(ttl, round.card, FLICK, 0.15);
      }
      hide(card, 0);
      tl.fromTo(card, { autoAlpha: 0, scale: 0.94 }, { autoAlpha: 1, scale: 1, duration: 0.18, ease: 'power2.out', immediateRender: false }, round.card);
    }

    onFrame(t0, t1, t => {
      const st = m.state(t);
      // the clock: magenta while playing, green on a win, red on a loss
      const cc = st.won ? C.good : st.lost ? C.bad : C.magenta;
      clock.textContent = fmt(m.elapsed(t));
      clock.style.color = rgba(mixc(cc, C.text, 0.35), 1);
      clock.style.textShadow = glow(cc);
      if (st.won) best.textContent = `Best ${fmt(m.elapsed(m.finish))}`;
      // the line under the board
      const showCard = card && t >= round.card;
      let text = '', lc = C.muted, lg = 'none';
      if (!st.lost && !st.won && st.shown) {
        if (!st.hidden) text = 'Tap 1, then the rest in order.';
        else { text = `Next: ${st.next}`; lc = C.cyan; lg = glow(C.cyan, 0.6); }
      }
      if (st.won && !showCard) { text = ''; }
      line.textContent = text; line.style.color = lc; line.style.textShadow = lg;
      // squares: the app's AnimatedContainer eases the decoration over 140 ms, the number swaps at once
      let te = -1;
      for (const e of m.events) if (e <= t) te = e;
      const k = te < 0 ? 1 : clamp((t - te) / 0.14, 0, 1);
      const prev = k < 1 ? m.state(te - 1e-6) : null;
      for (let i = 0; i < 40; i++) {
        const now = cellLook(m, st, i);
        let fill = now.fill, edge = now.edge, gl = now.glow, ga = 1;
        if (prev) {
          const was = cellLook(m, prev, i);
          fill = mix4(was.fill, now.fill, k); edge = mix4(was.edge, now.edge, k);
          if (was.glow && now.glow) gl = [mixc(was.glow[0], now.glow[0], k), was.glow[1] + (now.glow[1] - was.glow[1]) * k];
          else if (was.glow) { gl = was.glow; ga = 1 - k; } else if (now.glow) ga = k;
        }
        const bgc = rgba(fill.slice(0, 3), fill[3]), bdc = rgba(edge.slice(0, 3), edge[3]), shd = boxShadowOf(gl, ga);
        const lab = now.label === null ? '' : String(now.label);
        const key = [bgc, bdc, shd, lab, now.color || '', now.lglow ? 'g' : ''].join('|');
        const cl = cells[i];
        if (cl.last !== key) {
          cl.c.style.background = bgc; cl.c.style.borderColor = bdc; cl.c.style.boxShadow = shd;
          cl.sp.textContent = lab;
          cl.sp.style.color = now.color || '#fff';
          cl.sp.style.textShadow = now.lglow ? glow(C.cyan, 0.8) : 'none';
          cl.last = key;
        }
      }
      // a wrong tap shakes the board and tears it with red scanlines (play_screen.dart _shake, _GlitchPainter)
      let dx = 0;
      fx.ctx.clearRect(0, 0, fx.w, fx.h);
      if (m.wrong && t >= m.wrong.t && t < m.wrong.t + 0.45) {
        const v = (t - m.wrong.t) / 0.45, fade = 1 - v;
        dx = Math.sin(v * Math.PI * 9) * 12 * (1 - v);
        const gr = mulberry32(Math.floor(v * 12) + 3);
        fx.ctx.save(); fx.ctx.translate(120, 120);
        fx.ctx.fillStyle = rgba(C.bad, 0.18 * fade); fx.ctx.fillRect(0, 0, BW, BH);
        for (let i = 0; i < 7; i++) {
          const y = gr() * BH, hh = 2 + gr() * 10, sh = (gr() - 0.5) * 40 * fade;
          fx.ctx.fillStyle = rgba(i % 2 ? C.cyan : C.bad, 0.35 * fade); fx.ctx.fillRect(sh, y, BW, hh);
        }
        fx.ctx.restore();
      }
      board.style.transform = dx ? `translateX(${dx}px)` : '';
      drawSparks(fx.ctx, sparks, t);
    });
    return { el: ph, board: bb, model: m };
  }

  // a board on its own (the modes scene): numbers light up one per sixteenth
  function bareBoard(parent, b, step, x, y, w, t1) {
    const h = w * 8 / 5, s = w / BW;
    const box = el('div', 'abs', parent, { left: x, top: y, width: BW, height: BH, transformOrigin: '0 0', transform: `scale(${s})` });
    const board = el('div', 'board', box, { boxShadow: `${boxGlow(C.cyan, 0.7)}, ${boxGlow(C.magenta, 0.4)}` });
    const cellOf = {}; for (const k in b.cells) cellOf[+k] = b.cells[k];
    for (let i = 0; i < 40; i++) el('div', 'cellbox', board, { left: 3 + (i % 5) * CW + 2, top: 3 + Math.floor(i / 5) * CHh + 2, width: CW - 4, height: CHh - 4, background: rgba(C.cell, 0.7), borderColor: rgba(C.violet, 0.18) });
    for (let n = 1; n <= b.count; n++) {
      const i = cellOf[n], t = b.start + (n - 1) * step;
      const c = el('div', 'cellbox', board, { left: 3 + (i % 5) * CW + 2, top: 3 + Math.floor(i / 5) * CHh + 2, width: CW - 4, height: CHh - 4, background: 'transparent', borderColor: rgba(C.cyan, 0.35), zIndex: 2 });
      el('span', '', c, { color: '#DFFBFF', textShadow: glow(C.cyan, 0.8) }, String(n));
      hide(c, 0);
      tl.fromTo(c, { autoAlpha: 1, scale: 1.5, backgroundColor: rgba(C.tile, 1) }, { scale: 1, backgroundColor: 'rgba(20,11,38,0)', duration: 0.22, ease: 'power3.out', immediateRender: false }, t);
    }
    return { box, h };
  }

  // =====================================================================================================
  // 0-6  HOOK: a Medium board, the clock already running. Memorise. Tap 1. The rest from memory. A new best.
  // =====================================================================================================
  const hookEnd = CUT.title;
  {
    const s = scene('s-hook', 50, 0, hookEnd);
    synthLayer(s, 0, hookEnd, t => ({ horizon: L(0.74, 0.8), dim: 0.75, phase: phaseOf(t, [[0, 1 / 3], [2, 1.0]]), fan: L(0.3, 0.9), pulse: kick(t) * 0.6, stars: STARS }));
    const r = E.hook;
    const pc = L({ x: 1340, y: 548, s: 1.12 }, { x: 540, y: 1236, s: 1.48 });
    const ph = phone(s, r, { cx: pc.x, cy: pc.y, scale: pc.s, t0: 0, t1: hookEnd });
    // the camera: a slow push while memorising, a kick on "tap 1", a lift on the finish
    tl.fromTo(ph.el, { scale: pc.s * 0.97, rotation: L(-2, 0) }, { scale: pc.s, rotation: L(-1, 0), duration: 2, ease: 'none' }, 0);
    tl.to(ph.el, { keyframes: [{ scale: pc.s * 1.04, duration: 0.06 }, { scale: pc.s * 1.0, duration: 0.3, ease: 'power2.out' }] }, 2.0);
    tl.to(ph.el, { rotation: 0, scale: pc.s * 1.03, duration: 2, ease: 'sine.inOut' }, 2.4);
    tl.to(ph.el, { keyframes: [{ y: -14, duration: 0.08 }, { y: 0, duration: 0.5, ease: 'back.out(2)' }] }, r.taps[r.taps.length - 1][1]);

    // the words: MEMORISE. / TAP 1. NOW REMEMBER. / BEAT THE CLOCK.
    const tx = L({ left: 130, top: 300, size: 108, sub: 34 }, { left: 0, top: 200, size: 104, sub: 34 });
    const col = el('div', 'abs', s, P ? { left: 0, width: W, top: tx.top, height: 330 } : { left: tx.left, top: tx.top, width: 900, height: 480 });
    const head = (html, top, size, o) => { const w = el('div', 'abs', col, { top, left: 0, width: P ? W : 900, transformOrigin: P ? '50% 50%' : '0% 50%' }); neon(w, html, size, Object.assign({ position: 'relative', display: 'inline-block' }, P ? { left: '50%', transform: 'translateX(-50%)' } : {}), o); return w; };
    const sub = (html, top) => el('div', 'sub', col, Object.assign({ top, fontSize: tx.sub, width: P ? W : 900, textAlign: P ? 'center' : 'left' }, P ? { left: 0 } : { left: 6 }), html);

    // on from the first frame (it is the thumbnail), with a stutter of the tube a moment later
    const m1 = head('MEMORISE.', 0, tx.size);
    for (const [a, b] of [[0.14, 0.18], [0.26, 0.31]]) { tl.set(m1, { autoAlpha: 0.15 }, a); tl.set(m1, { autoAlpha: 1 }, b); }
    const s1 = sub('The clock is <b>already running</b>.', tx.size * 1.25);
    fadeOut(m1, 1.9, 0.1); fadeOut(s1, 1.9, 0.1);

    const t1a = head('TAP 1.', 0, tx.size);
    slam(t1a, 2.0);
    const t1b = head('NOW REMEMBER.', tx.size * 1.08, tx.size * L(0.62, 0.62), { core: '#FFD6F5', glowColor: C.magenta });
    slam(t1b, 2.5, 1.5);
    const s2 = sub('The rest turn white. <b>Tap them in order.</b>', tx.size * 1.85);
    if (P) gsap.set(s2, { top: tx.size * 1.85 });
    riseIn(s2, 2.6, 20, 0.3);
    fadeOut(t1a, 3.95, 0.08); fadeOut(t1b, 3.95, 0.08); fadeOut(s2, 3.95, 0.08);

    const b1 = head('BEAT THE', 0, tx.size * 0.86);
    const b2 = head('CLOCK.', tx.size * 0.92, tx.size * 0.86, { core: '#E6FFF3', glowColor: C.good });
    slam(b1, 4.0); slam(b2, 4.25);
    const s3 = sub('Lowest time wins.', tx.size * 1.92);
    riseIn(s3, 4.5, 20, 0.3);
    if (!P) { tl.to(col, { y: -20, duration: 6, ease: 'none' }, 0); }
    // the finish: the frame flares
    flash(s, r.taps[r.taps.length - 1][1], rgba(C.cyan, 1), 0.12, 0.35, 40);
  }

  // =====================================================================================================
  // 6-8  TITLE: the sun comes up over the grid, the NUMORY sign catches, the three verbs on the beats
  // =====================================================================================================
  {
    const s = scene('s-title', 50, CUT.title, CUT.fail);
    const hz = L(0.6, 0.56);
    const sr = L(250, 300);
    synthLayer(s, CUT.title, CUT.fail, t => {
      const u = clamp((t - CUT.title) / 0.7, 0, 1);
      const rise = 1 - (1 - u) ** 3;
      return { horizon: hz, dim: 1, phase: phaseOf(t, [[CUT.title, 2.2]]), fan: L(0.3, 0.9), pulse: kick(t), lift: 1, stars: STARS,
        sun: { r: sr, cy: H * hz + sr * 0.9 - (sr * 1.25) * rise, a: 1 } };
    });
    const ws = L(210, 148);
    const wrap = el('div', 'abs', s, { left: 0, width: W, top: L(H * hz - sr * 0.35 - ws * 1.35, H * hz - sr * 0.35 - ws * 1.6), height: ws * 1.2, textAlign: 'center' });
    const letters = [];
    const row = el('div', 'abs', wrap, { left: 0, width: W, top: 0, display: 'flex', justifyContent: 'center' });
    for (const ch of 'NUMORY') { const l = neon(row, ch, ws, { position: 'relative', letterSpacing: '0.07em' }); letters.push(l); }
    flickerOn(row, CUT.title + 0.02);
    // the app's bob: each letter lifts in turn
    letters.forEach((l, i) => tl.fromTo(l, { y: 0 }, { keyframes: [{ y: -ws * 0.07, duration: 0.22, ease: 'sine.out' }, { y: 0, duration: 0.22, ease: 'sine.in' }], immediateRender: false }, CUT.title + 0.9 + i * 0.09));
    tl.fromTo(wrap, { scale: 1 }, { scale: 1.05, duration: 2, ease: 'none' }, CUT.title);
    const words = P ? [['REMEMBER', 0, 0], ['TAP IN ORDER', 1, 0], ['BEAT THE CLOCK', 2, 0]] : [['REMEMBER ·', 0, 0], ['TAP IN ORDER ·', 1, 0], ['BEAT THE CLOCK', 2, 0]];
    const tag = el('div', 'abs', s, P ? { left: 0, width: W, top: H * hz + 150 } : { left: 0, width: W, top: H * hz + 120, display: 'flex', justifyContent: 'center', gap: '22px' });
    words.forEach(([w, i]) => {
      const d = el('div', P ? 'abs' : '', tag, Object.assign({ fontFamily: 'var(--body)', fontWeight: 900, fontSize: L(40, 50), letterSpacing: '0.06em', color: C.cyan, textShadow: glow(C.cyan, 1.2) }, P ? { left: 0, width: W, textAlign: 'center', top: i * 76 } : { position: 'relative' }), w);
      slam(d, CUT.title + 0.5 + i * 0.5, 1.4, 0.12);
    });
  }

  // =====================================================================================================
  // 8-12  ONE WRONG TAP: a Hard board, six good taps, then the wrong square. Red, the shake, OOPS. Silence.
  // =====================================================================================================
  {
    const s = scene('s-fail', 50, CUT.fail, CUT.modes);
    laserWipe(s, CUT.fail, 0.25);
    const r = E.fail;
    synthLayer(s, CUT.fail, CUT.modes, t => {
      const after = t >= CUT.stop;
      return { horizon: L(0.74, 0.8), dim: after ? 0.45 : 0.75, phase: phaseOf(t, [[CUT.fail, 1.0], [CUT.stop, 0]]), fan: L(0.3, 0.9), pulse: kick(t) * 0.6, stars: STARS };
    });
    const red = el('div', 'fill', s, { background: `radial-gradient(ellipse at 50% 50%, rgba(255,51,85,0) 40%, ${rgba(C.bad, 0.45)} 100%)`, zIndex: 3 });
    hide(red, 0);
    tl.fromTo(red, { autoAlpha: 1 }, { autoAlpha: 0.35, duration: 0.8, ease: 'power2.out', immediateRender: false }, CUT.stop);
    const pc = L({ x: 1340, y: 548, s: 1.12 }, { x: 540, y: 1236, s: 1.48 });
    const ph = phone(s, r, { cx: pc.x, cy: pc.y, scale: pc.s, t0: CUT.fail, t1: CUT.modes });
    gsap.set(ph.el, { zIndex: 4 });
    tl.fromTo(ph.el, { scale: pc.s * 0.98, rotation: L(1.5, 0) }, { scale: pc.s, rotation: 0, duration: 1, ease: 'power2.out' }, CUT.fail);
    shake(ph.el, CUT.stop, 16, 0.35);
    // the riser: the camera pushes into the board, then the white-out on the downbeat
    tl.to(ph.el, { scale: pc.s * 1.18, duration: CUT.modes - (CUT.modes - 0.75), ease: 'power2.in' }, CUT.modes - 0.75);
    flash(world, CUT.modes, '#fff', 0.8, 0.35, 950);

    const tx = L({ left: 130, top: 330, size: 100, sub: 34 }, { left: 0, top: 200, size: 92, sub: 34 });
    const col = el('div', 'abs', s, P ? { left: 0, width: W, top: tx.top, zIndex: 5 } : { left: tx.left, top: tx.top, width: 900, zIndex: 5 });
    const head = (html, top, size, o) => { const w = el('div', 'abs', col, { top, left: 0, width: P ? W : 900, transformOrigin: P ? '50% 50%' : '0% 50%' }); neon(w, html, size, Object.assign({ position: 'relative', display: 'inline-block' }, P ? { left: '50%', transform: 'translateX(-50%)' } : {}), o); return w; };
    const a = head('ONE WRONG', 0, tx.size);
    const b = head('TAP...', tx.size * 1.04, tx.size);
    flickerOn(a, CUT.fail + 0.25, [[0, 0.05], [0.1, 0.16]]);
    flickerOn(b, CUT.fail + 0.5, [[0, 0.05], [0.1, 0.16]]);
    const sub = el('div', 'sub', col, Object.assign({ top: tx.size * 2.25, fontSize: tx.sub, width: P ? W : 900, textAlign: P ? 'center' : 'left' }, { left: 0 }), 'Hard: <b>15 numbers</b>. All from memory.');
    riseIn(sub, CUT.fail + 0.75, 20, 0.3);
    // the wrong tap: the words turn
    const c = head("...AND IT'S OVER.", tx.size * 2.2, L(54, 58), { core: '#FFD0D8', glowColor: C.bad, ghosts: true });
    fadeOut(sub, CUT.stop - 0.05, 0.05);
    slam(c, CUT.stop, 1.3, 0.1);
    tl.to([a, b], { opacity: 0.35, duration: 0.15, immediateRender: false }, CUT.stop);
    shake(col, CUT.stop, 12, 0.3);
  }

  // =====================================================================================================
  // 12-16  MODES: Easy 5, Medium 9, Hard 15. Each board lights up one number per sixteenth, the game's notes
  // =====================================================================================================
  {
    const s = scene('s-modes', 50, CUT.modes, CUT.world);
    synthLayer(s, CUT.modes, CUT.world, t => ({ horizon: L(0.84, 0.86), dim: 0.8, phase: phaseOf(t, [[CUT.modes, 1.0]]), fan: L(0.3, 0.9), pulse: kick(t), stars: STARS }));
    const hs = L(92, 96);
    const headBox = el('div', 'abs', s, { left: 0, width: W, top: L(70, 200), textAlign: 'center' });
    const h1 = neon(headBox, '5, 9 OR 15', hs, { position: 'relative', display: 'inline-block' });
    const h2w = el('div', '', headBox, { marginTop: hs * 0.06 });
    neon(h2w, 'NUMBERS.', hs, { position: 'relative', display: 'inline-block' }, { core: '#FFD6F5', glowColor: C.magenta });
    slam(h1, CUT.modes); slam(h2w, CUT.modes + 0.25);
    const sub = el('div', 'sub', s, { left: 0, width: W, top: L(70 + hs * 2.2, 200 + hs * 2.25), fontSize: L(34, 36), textAlign: 'center' }, 'Three modes. <b>Seconds a round.</b>');
    riseIn(sub, CUT.modes + 0.5, 20, 0.3);
    const step = E.modes.step;
    const bw = L(330, 322), gap = L(90, 16);
    const total = 3 * bw + 2 * gap, x0 = (W - total) / 2, by = L(420, 820);
    E.modes.boards.forEach((b, i) => {
      const x = x0 + i * (bw + gap);
      const g = el('div', 'abs', s, { left: 0, top: 0, width: W, height: H });
      const bb = bareBoard(g, b, step, x, by, bw);
      const pill = el('div', 'pill', g, { left: x + bw / 2, top: by - L(74, 80), height: L(52, 56), padding: '0 26px', fontSize: L(22, 24), color: '#FFE3F8', background: rgba(C.magenta, 0.18), borderColor: C.magenta, boxShadow: boxGlow(C.magenta, 0.6), textShadow: glow(C.magenta, 0.6) }, `${b.mode.toUpperCase()} · ${b.count}`);
      gsap.set(pill, { xPercent: -50 });
      hide(g, 0);
      tl.fromTo(g, { autoAlpha: 0, y: 60 }, { autoAlpha: 1, y: 0, duration: 0.3, ease: 'back.out(1.6)', immediateRender: false }, b.start - 0.12);
      // the board being filled is lit; the others rest a little dimmer
      const done = b.start + (b.count - 1) * step + 0.2;
      if (i < 2) tl.to(g, { opacity: 0.55, duration: 0.25, immediateRender: false }, E.modes.boards[i + 1].start - 0.1);
      tl.to(g, { opacity: 1, duration: 0.2, immediateRender: false }, CUT.world - 0.5);
      tl.to(pill, { keyframes: [{ scale: 1.12, duration: 0.06 }, { scale: 1, duration: 0.25 }] }, done);
    });
    glitchCut(CUT.world, 0.2);
  }

  // =====================================================================================================
  // 16-20  THE WORLD: a wireframe globe, the rank counting down one sixteenth at a time, landing on 18.0
  // =====================================================================================================
  {
    const s = scene('s-world', 50, CUT.world, CUT.chimp);
    synthLayer(s, CUT.world, CUT.chimp, t => ({ horizon: L(0.86, 0.9), dim: 0.7, phase: phaseOf(t, [[CUT.world, 1.0]]), fan: L(0.3, 0.9), pulse: kick(t), stars: STARS }));
    const G = L({ x: 1450, y: 540, r: 340 }, { x: 540, y: 960, r: 340 });
    const gc = canvas(s, W, H, 1);
    const pings = Array.from({ length: 26 }, (_, i) => ({ lat: R(-55, 60), lon: R(0, 360), t: CUT.world + 0.25 + i * 0.125 + R(0, 0.06) }));
    onFrame(CUT.world, CUT.chimp, t => {
      const ctx = gc.ctx;
      ctx.clearRect(0, 0, W, H);
      const rot = (t - CUT.world) * 0.55 + 1.2, tilt = 0.32;
      const { x: cx, y: cy, r } = G;
      const proj = (la, lo) => { // orthographic, tilted toward the viewer
        const a = la * Math.PI / 180, b = lo * Math.PI / 180 + rot;
        let x = Math.cos(a) * Math.sin(b), y = Math.sin(a), z = Math.cos(a) * Math.cos(b);
        const y2 = y * Math.cos(tilt) - z * Math.sin(tilt), z2 = y * Math.sin(tilt) + z * Math.cos(tilt);
        return [cx + x * r, cy - y2 * r, z2];
      };
      const hg = ctx.createRadialGradient(cx, cy, r * 0.2, cx, cy, r * 1.35);
      hg.addColorStop(0, rgba(C.violet, 0.22)); hg.addColorStop(0.75, rgba(C.magenta, 0.08)); hg.addColorStop(1, rgba(C.magenta, 0));
      ctx.fillStyle = hg; ctx.beginPath(); ctx.arc(cx, cy, r * 1.35, 0, Math.PI * 2); ctx.fill();
      const pulse = kick(t);
      const stroke = (pts, front) => {
        ctx.beginPath();
        let pen = false;
        for (const [x, y, z] of pts) { if ((z >= 0) === front) { pen ? ctx.lineTo(x, y) : ctx.moveTo(x, y); pen = true; } else pen = false; }
        ctx.stroke();
      };
      for (const front of [false, true]) {
        ctx.lineWidth = front ? 2.2 : 1.2;
        ctx.strokeStyle = front ? rgba(C.cyan, 0.75 + 0.2 * pulse) : rgba(C.violet, 0.35);
        ctx.shadowColor = front ? C.cyan : 'transparent'; ctx.shadowBlur = front ? 10 : 0;
        for (let la = -60; la <= 60; la += 30) stroke(Array.from({ length: 73 }, (_, k) => proj(la, k * 5)), front);
        for (let lo = 0; lo < 360; lo += 30) stroke(Array.from({ length: 37 }, (_, k) => proj(-90 + k * 5, lo)), front);
      }
      ctx.shadowBlur = 0;
      ctx.lineWidth = 3; ctx.strokeStyle = rgba(C.magenta, 0.8); ctx.shadowColor = C.magenta; ctx.shadowBlur = 18;
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke(); ctx.shadowBlur = 0;
      for (const p of pings) {
        if (t < p.t) continue;
        const [x, y, z] = proj(p.lat, p.lon);
        if (z < 0.05) continue;
        const age = t - p.t, f = clamp(1 - age / 0.8, 0, 1);
        ctx.fillStyle = rgba(C.magenta, 0.9); ctx.beginPath(); ctx.arc(x, y, 4 + 2 * z, 0, Math.PI * 2); ctx.fill();
        if (f > 0) { ctx.strokeStyle = rgba(C.magenta, f); ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(x, y, 6 + (1 - f) * 34, 0, Math.PI * 2); ctx.stroke(); }
      }
    });
    tl.fromTo(gc.el, { scale: 0.7, autoAlpha: 0, transformOrigin: `${G.x}px ${G.y}px` }, { scale: 1, autoAlpha: 1, duration: 0.5, ease: 'back.out(1.5)', immediateRender: false }, CUT.world);

    const hs = L(84, 92);
    const col = el('div', 'abs', s, P ? { left: 0, width: W, top: 190 } : { left: 130, top: 170, width: 900 });
    const line = (html, top, o) => { const w = el('div', 'abs', col, { top, left: 0, width: P ? W : 900, transformOrigin: P ? '50% 50%' : '0% 50%' }); neon(w, html, hs, Object.assign({ position: 'relative', display: 'inline-block' }, P ? { left: '50%', transform: 'translateX(-50%)' } : {}), o); return w; };
    const a = line('RACE THE', 0), b = line('WHOLE WORLD.', hs * 1.04, { core: '#FFD6F5', glowColor: C.magenta });
    slam(a, CUT.world); slam(b, CUT.world + 0.25);
    const sub = el('div', 'sub', col, { left: P ? 0 : 6, width: P ? W : 900, top: hs * 2.3, fontSize: L(34, 34), textAlign: P ? 'center' : 'left' }, 'Easy, Medium and Hard each have<br>a <b>global leaderboard</b>.');
    riseIn(sub, CUT.world + 0.5, 20, 0.3);
    // the rank chip, the app's, big
    const rk = E.rank;
    const chip = el('div', 'chip', s, P ? { position: 'absolute', left: W / 2, top: 1340, minWidth: 560, minHeight: 210, borderRadius: 30, borderWidth: 2, boxShadow: boxGlow(C.magenta, 1) } : { position: 'absolute', left: 130, top: 660, minWidth: 600, minHeight: 230, borderRadius: 32, borderWidth: 2, boxShadow: boxGlow(C.magenta, 1) });
    const num = el('div', '', chip, { fontFamily: 'var(--display)', fontWeight: 900, fontSize: L(118, 112), letterSpacing: 3, color: '#FFD6F5', textShadow: glow(C.magenta, 2.4), lineHeight: 1.05 }, '#9,999');
    const cap = el('div', '', chip, { fontFamily: 'var(--body)', fontWeight: 900, fontSize: L(30, 30), color: C.muted, letterSpacing: 1, marginTop: 6 }, 'IN THE WORLD · ALL TIME');
    if (P) gsap.set(chip, { xPercent: -50 });
    popIn(chip, rk.start - 0.25, 0.6, 0.3);
    hide(cap, 0); riseIn(cap, rk.land, 14, 0.25);
    const ease = gsap.parseEase('power3.out');
    onFrame(CUT.world, CUT.chimp, t => {
      const k = clamp(Math.floor((t - rk.start) / ((rk.land - rk.start) / rk.ticks)), 0, rk.ticks);
      const v = Math.round(rk.from + (rk.to - rk.from) * ease(k / rk.ticks));
      num.textContent = '#' + v.toLocaleString('en-US');
    });
    for (let k = 0; k < rk.ticks; k++) tl.fromTo(num, { y: -10 }, { y: 0, duration: 0.1, ease: 'power2.out', immediateRender: false }, rk.start + k * (rk.land - rk.start) / rk.ticks);
    tl.to(chip, { keyframes: [{ scale: 1.12, duration: 0.06 }, { scale: 1, duration: 0.35, ease: 'back.out(3)' }] }, rk.land);
    tl.to(num, { keyframes: [{ color: '#ffffff', duration: 0.05 }, { color: '#FFD6F5', duration: 0.4 }] }, rk.land);
    // sparks from the chip on the landing
    const sp = canvas(s, W, H, 1, { zIndex: 6 });
    const ccx = P ? W / 2 : 130 + 300, ccy = P ? 1340 + 105 : 660 + 115;
    const fire = burst(4242, ccx, ccy, rk.land, 90, 3.2, [C.magenta, C.cyan, C.gold, C.tile]);
    onFrame(rk.land, CUT.chimp, t => { sp.ctx.clearRect(0, 0, W, H); sp.ctx.save(); sp.ctx.translate(ccx, ccy); sp.ctx.scale(2.2, 2.2); sp.ctx.translate(-ccx, -ccy); drawSparks(sp.ctx, fire, t); sp.ctx.restore(); });
    // out: the lights go off
    const black = el('div', 'fill', world, { background: '#000', zIndex: 940 });
    hide(black, 0); show(black, CUT.chimp - 0.125); hide(black, CUT.chimp);
  }

  // =====================================================================================================
  // 20-24  THE CHIMP TEST: a neon chimp on a dark wall catches, then the chimp himself: can you beat him?
  // =====================================================================================================
  {
    const s = scene('s-chimp', 50, CUT.chimp, CUT.end);
    // the wall: dark bricks under a violet wash
    const wall = canvas(s, W, H, 1);
    {
      const ctx = wall.ctx, bwid = L(120, 110), bh = L(46, 42);
      ctx.fillStyle = '#05020A'; ctx.fillRect(0, 0, W, H);
      for (let y = 0, row = 0; y < H; y += bh, row++) {
        for (let x = -(row % 2) * bwid / 2; x < W; x += bwid) {
          const l = R(0.85, 1.15);
          ctx.fillStyle = `rgb(${Math.round(22 * l)},${Math.round(12 * l)},${Math.round(34 * l)})`;
          ctx.fillRect(x + 3, y + 3, bwid - 6, bh - 6);
        }
      }
      const v = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.2, W / 2, H / 2, Math.max(W, H) * 0.75);
      v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,0.85)');
      ctx.fillStyle = v; ctx.fillRect(0, 0, W, H);
    }
    const sg = L({ x: 1330, y: 520, w: 820 }, { x: 540, y: 820, w: 900 });
    const signH = sg.w * 988 / 1024;
    const light = el('div', 'abs', s, { left: sg.x - sg.w, top: sg.y - sg.w, width: sg.w * 2, height: sg.w * 2, borderRadius: '50%', background: `radial-gradient(circle, ${rgba(C.magenta, 0.32)} 0%, ${rgba(C.violet, 0.16)} 35%, rgba(0,0,0,0) 65%)`, mixBlendMode: 'screen' });
    const sign = img(A + 'art/chimp_sign.webp', s, { left: sg.x - sg.w / 2, top: sg.y - signH / 2, width: sg.w, height: signH });
    const SIGN = [[0, 0.06], [0.1, 0.16], [0.24, 0.36], [0.45, 0.5]];
    flickerOn(sign, CUT.chimp, SIGN, 0.06);
    flickerOn(light, CUT.chimp, SIGN, 0.0);
    // a tube that never quite settles
    for (const d of [1.13, 1.71]) { tl.set([sign, light], { opacity: 0.55 }, CUT.chimp + d); tl.set([sign, light], { opacity: 1 }, CUT.chimp + d + 0.05); }
    tl.fromTo(sign, { scale: 1 }, { scale: 1.04, duration: 4, ease: 'none', immediateRender: false }, CUT.chimp);

    const hs = L(104, 96);
    const col = el('div', 'abs', s, P ? { left: 0, width: W, top: 1300, zIndex: 3 } : { left: 120, top: 250, width: 860, zIndex: 3 });
    const line = (html, top, size, o) => { const w = el('div', 'abs', col, { top, left: 0, width: P ? W : 860, transformOrigin: P ? '50% 50%' : '0% 50%' }); neon(w, html, size, Object.assign({ position: 'relative', display: 'inline-block' }, P ? { left: '50%', transform: 'translateX(-50%)' } : {}), o); return w; };
    const a = line('THE', 0, hs * 0.7, { core: '#E6FBFF', glowColor: C.cyan });
    const b = line('CHIMP TEST', hs * 0.78, hs, { core: '#FFD6F5', glowColor: C.magenta });
    flickerOn(a, CUT.chimp + 0.5, [[0, 0.05], [0.1, 0.18]]);
    flickerOn(b, CUT.chimp + 0.62, [[0, 0.06], [0.14, 0.22], [0.3, 0.34]]);
    const sub = el('div', 'sub', col, { left: P ? 0 : 6, width: P ? W : 860, top: hs * 2.0, fontSize: L(36, 36), textAlign: P ? 'center' : 'left' }, 'The number-memory challenge<br><b>chimpanzees famously ace.</b>');
    riseIn(sub, CUT.chimp + 1.0, 20, 0.35);

    // 22.0: the drop. The chimp rises in front of his sign; the question lands
    const D = CUT.chimpDrop;
    tl.to([a, b, sub], { autoAlpha: 0, duration: 0.12, immediateRender: false }, D - 0.12);
    tl.to(sign, { opacity: 0.45, duration: 0.3, immediateRender: false }, D);
    tl.to(light, { opacity: 0.6, duration: 0.3, immediateRender: false }, D);
    const ch = L({ x: 1330, w: 760 }, { x: 560, w: 1000 });
    const chH = ch.w * 854 / 1007;
    const chimp = img(A + 'art/chimp_3d.webp', s, { left: ch.x - ch.w / 2, top: H - chH + L(6, 40), width: ch.w, height: chH, zIndex: 2 });
    chimp.style.transformOrigin = '50% 100%';
    hide(chimp, 0);
    tl.fromTo(chimp, { autoAlpha: 1, y: chH * 0.9 }, { y: 0, duration: 0.35, ease: 'back.out(1.4)', immediateRender: false }, D - 0.05);
    for (let k = 1; k < 4; k++) tl.to(chimp, { keyframes: [{ scaleY: 0.975, scaleX: 1.015, duration: 0.06 }, { scaleY: 1, scaleX: 1, duration: 0.3, ease: 'sine.out' }] }, D + k * BEAT);
    const q = el('div', 'abs', s, P ? { left: 0, width: W, top: 200, zIndex: 3 } : { left: 120, top: 300, width: 860, zIndex: 3 });
    const qa = el('div', 'abs', q, { left: 0, width: P ? W : 860, top: 0 });
    neon(qa, 'CAN YOU BEAT', L(84, 82), Object.assign({ position: 'relative', display: 'inline-block' }, P ? { left: '50%', transform: 'translateX(-50%)' } : {}));
    const qb = el('div', 'abs', q, { left: 0, width: P ? W : 860, top: L(96, 94) });
    neon(qb, 'A CHIMP?', L(150, 140), Object.assign({ position: 'relative', display: 'inline-block' }, P ? { left: '50%', transform: 'translateX(-50%)' } : {}), { core: '#FFD6F5', glowColor: C.magenta });
    slam(qa, D); slam(qb, D + 0.5, 1.6, 0.14);
    qa.style.transformOrigin = qb.style.transformOrigin = P ? '50% 50%' : '0% 50%';
    flash(world, D, rgba(C.magenta, 1), 0.35, 0.35, 930);
  }

  // =====================================================================================================
  // 24-28  END CARD: the home screen's sun and grid, the sign catches, the question, the call to action
  // =====================================================================================================
  {
    const s = scene('s-end', 50, CUT.end);
    glitchCut(CUT.end, 0.2);
    const hz = L(0.62, 0.52), sr = L(230, 290);
    synthLayer(s, CUT.end, DUR + 1, t => {
      const u = clamp((t - CUT.end) / 0.8, 0, 1), rise = 1 - (1 - u) ** 3;
      const hit = t >= CUT.final ? Math.exp(-(t - CUT.final) * 3) : 0;
      return { horizon: hz, dim: 1, phase: phaseOf(t, [[CUT.end, 1.6], [CUT.final, 0.8]]), fan: L(0.3, 0.9), pulse: Math.max(kick(t), hit), lift: 1, stars: STARS,
        sun: { r: sr * (1 + 0.04 * hit), cy: H * hz + sr * 0.9 - sr * 1.25 * rise, a: 1 } };
    });
    const ws = L(176, 150);
    const wtop = L(H * hz - sr * 0.35 - ws * 1.75, H * hz - sr * 0.35 - ws * 1.9);
    const logo = el('div', 'abs', s, { left: 0, width: W, top: wtop, height: ws * 1.2, display: 'flex', justifyContent: 'center' });
    const letters = [];
    for (const ch of 'NUMORY') letters.push(neon(logo, ch, ws, { position: 'relative', letterSpacing: '0.07em' }));
    flickerOn(logo, CUT.end + 0.05);
    letters.forEach((l, i) => tl.fromTo(l, { y: 0 }, { keyframes: [{ y: -ws * 0.07, duration: 0.22, ease: 'sine.out' }, { y: 0, duration: 0.22, ease: 'sine.in' }], immediateRender: false }, CUT.end + 1.0 + i * 0.09));
    // the app's stutter: one letter dips once a loop
    tl.set(letters[3], { opacity: 0.25 }, CUT.final + 1.0); tl.set(letters[3], { opacity: 1 }, CUT.final + 1.08);
    tl.set(letters[3], { opacity: 0.25 }, CUT.final + 1.16); tl.set(letters[3], { opacity: 1 }, CUT.final + 1.2);
    const tag = el('div', 'abs', s, { left: 0, width: W, top: wtop + ws * 1.18, textAlign: 'center', fontFamily: 'var(--body)', fontWeight: 900, fontSize: L(30, 30), letterSpacing: '0.08em', color: '#F2FDFF', textShadow: glow(C.cyan, 1.1) }, 'REMEMBER · TAP IN ORDER · BEAT THE CLOCK');
    riseIn(tag, CUT.end + 0.4, 16, 0.3);
    // the question and the call to action, over the floor
    const qy = L(H * hz + 70, H * hz + 120);
    const q = el('div', 'abs', s, { left: 0, width: W, top: qy, textAlign: 'center' });
    neon(q, P ? 'HOW FAST IS' : 'HOW FAST IS YOUR MEMORY?', L(64, 84), { position: 'relative', display: 'inline-block' });
    if (P) { const q2 = el('div', '', q, { marginTop: 8 }); neon(q2, 'YOUR MEMORY?', 84, { position: 'relative', display: 'inline-block' }, { core: '#FFD6F5', glowColor: C.magenta }); }
    slam(q, CUT.end + 1.0, 1.4, 0.14);
    const cta = el('div', 'cta', s, { left: W / 2, top: qy + L(120, 230), height: L(118, 126), boxShadow: `${boxGlow(C.magenta, 1.2)}, 10px 0 30px ${rgba(C.cyan, 0.4)}` });
    const inner = el('div', '', cta, { padding: L('0 44px 0 14px', '0 44px 0 14px'), gap: L('22px', '22px'), fontSize: L(40, 32), letterSpacing: '0.05em', textShadow: glow(C.magenta, 0.9) });
    const ic = el('img', '', inner, { width: L(92, 98), height: L(92, 98), boxShadow: `0 0 18px ${rgba(C.magenta, 0.6)}` }); ic.src = A + 'art/icon.webp'; ic.decoding = 'sync';
    el('span', '', inner, {}, CTA.toUpperCase());
    hide(cta, 0);
    tl.fromTo(cta, { xPercent: -50, scale: 0.6, autoAlpha: 0 }, { xPercent: -50, scale: 1, autoAlpha: 1, duration: 0.4, ease: 'back.out(2)', immediateRender: false }, CUT.end + 1.5);
    tl.to(cta, { scale: 1.05, duration: BEAT, ease: 'sine.inOut', yoyo: true, repeat: 5 }, CUT.final + 0.1);
    // 26.0: the last hit
    tl.to(logo, { keyframes: [{ scale: 1.1, duration: 0.06 }, { scale: 1, duration: 0.4, ease: 'back.out(3)' }] }, CUT.final);
    flash(s, CUT.final, '#fff', 0.4, 0.35, 800);
    shake(world, CUT.final, 12, 0.3);
    const sp = canvas(s, W, H, 1, { zIndex: 7 });
    const fire = [];
    for (let k = 0; k < 6; k++) fire.push(...burst(500 + k, W / 2 + (k - 2.5) * ws * 0.78, wtop + ws * 0.55, CUT.final, 40, 3, [C.magenta, C.cyan, C.gold, C.tile]));
    onFrame(CUT.final, DUR + 1, t => { sp.ctx.clearRect(0, 0, W, H); sp.ctx.save(); sp.ctx.translate(W / 2, wtop); sp.ctx.scale(2, 2); sp.ctx.translate(-W / 2, -wtop); drawSparks(sp.ctx, fire, t); sp.ctx.restore(); });
  }

  // the hook into the title: a white flare and a tear
  flash(world, CUT.title, '#fff', 0.55, 0.25, 950);
  glitchCut(CUT.title, 0.16);

  // ---------- the ticker: everything that is a function of t ----------
  const clockObj = { t: 0 };
  tl.fromTo(clockObj, { t: 0 }, { t: DUR, duration: DUR, ease: 'none', modifiers: { t: v => { const t = +v; for (const f of frames) if (t >= f.t0 && t < f.t1) f.fn(t); return v; } } }, 0);
  tl.set({}, {}, DUR);
  return tl;
};
