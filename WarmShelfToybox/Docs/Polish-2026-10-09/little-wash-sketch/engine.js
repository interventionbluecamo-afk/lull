/* Lull prototype engine: felt-and-wood canvas rendering, soft sounds, touch. Shared by every toy. */
const Lull = (() => {
  const TAU = Math.PI * 2;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const ease = {
    out: (t) => 1 - Math.pow(1 - t, 3),
    inOut: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
    back: (t) => { const c = 1.7; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
  };
  const reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // The toybox palette (WarmShelfPalette in the app).
  const C = {
    linen: '#F8F3E9', paper: '#FFFCF6', cream: '#EEE3D1', line: '#D8CBB8', ink: '#49352A',
    cocoa: '#654B3A', rhubarb: '#A6473C', terracotta: '#C96F50', sage: '#829B82', sand: '#C8A477',
    water: '#83AAB9', butter: '#D9B452', lavender: '#A696B3', petal: '#DD998B',
  };

  // ---------- Felt texture: a tile of tiny fibres, light and dark, laid at random angles.
  function fibreTile(size = 192, density = 2600) {
    const c = document.createElement('canvas');
    c.width = c.height = size;
    const g = c.getContext('2d');
    for (let i = 0; i < density; i++) {
      const x = Math.random() * size, y = Math.random() * size;
      const a = Math.random() * TAU, l = 2 + Math.random() * 7;
      const light = Math.random() < 0.5;
      g.strokeStyle = light ? `rgba(255,255,255,${0.05 + Math.random() * 0.12})` : `rgba(60,40,30,${0.04 + Math.random() * 0.09})`;
      g.lineWidth = 0.6 + Math.random() * 0.7;
      g.beginPath();
      g.moveTo(x, y);
      g.quadraticCurveTo(x + Math.cos(a + 0.6) * l * 0.5, y + Math.sin(a + 0.6) * l * 0.5, x + Math.cos(a) * l, y + Math.sin(a) * l);
      g.stroke();
    }
    return c;
  }
  function grainTile(w = 256, h = 64) {
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const g = c.getContext('2d');
    for (let i = 0; i < 46; i++) {
      const y = Math.random() * h, amp = 0.6 + Math.random() * 2.2, ph = Math.random() * TAU;
      g.strokeStyle = `rgba(90,55,30,${0.05 + Math.random() * 0.08})`;
      g.lineWidth = 0.5 + Math.random();
      g.beginPath();
      for (let x = 0; x <= w; x += 8) g.lineTo(x, y + Math.sin(x / 40 + ph) * amp);
      g.stroke();
    }
    return c;
  }
  let fibre, grain, fibrePattern = null, grainPattern = null;

  // ---------- Canvas stage with DPR, resize and pointer input.
  function stage(canvas, toy) {
    const ctx = canvas.getContext('2d');
    if (!fibre) { fibre = fibreTile(); grain = grainTile(); }
    fibrePattern = ctx.createPattern(fibre, 'repeat');
    grainPattern = ctx.createPattern(grain, 'repeat');
    const s = { canvas, ctx, w: 0, h: 0, dpr: 1, t: 0, running: false, pointers: new Map() };
    function resize() {
      const r = canvas.getBoundingClientRect();
      s.dpr = Math.min(window.devicePixelRatio || 1, 2.5);
      s.w = r.width; s.h = r.height;
      canvas.width = Math.round(r.width * s.dpr);
      canvas.height = Math.round(r.height * s.dpr);
      toy.resize && toy.resize(s);
    }
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    resize();
    const pos = (e) => { const r = canvas.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; };
    canvas.addEventListener('pointerdown', (e) => {
      Sound.unlock();
      canvas.setPointerCapture(e.pointerId);
      const p = pos(e); s.pointers.set(e.pointerId, p);
      toy.down && toy.down(s, p, e.pointerId);
      e.preventDefault();
    });
    canvas.addEventListener('pointermove', (e) => {
      if (!s.pointers.has(e.pointerId)) return;
      const p = pos(e); s.pointers.set(e.pointerId, p);
      toy.move && toy.move(s, p, e.pointerId);
      e.preventDefault();
    });
    const up = (e) => {
      if (!s.pointers.has(e.pointerId)) return;
      const p = pos(e); s.pointers.delete(e.pointerId);
      toy.up && toy.up(s, p, e.pointerId);
    };
    canvas.addEventListener('pointerup', up);
    canvas.addEventListener('pointercancel', up);
    let last = performance.now();
    function frame(now) {
      if (!s.running) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now; s.t += dt;
      ctx.setTransform(s.dpr, 0, 0, s.dpr, 0, 0);
      toy.update && toy.update(s, dt);
      toy.draw(s, ctx);
      requestAnimationFrame(frame);
    }
    s.start = () => { if (s.running) return; s.running = true; last = performance.now(); requestAnimationFrame(frame); };
    s.stop = () => { s.running = false; };
    return s;
  }

  // ---------- Drawing helpers.
  // A felt shape: flat dye, fibre overlay, soft top-left light, a darker rim and a fuzzy edge.
  function felt(ctx, path, color, o = {}) {
    const { x = 0, y = 0, r = 40, light = 0.22, shade = 0.18, fuzz = true } = o;
    ctx.save();
    if (fuzz) { ctx.shadowColor = color; ctx.shadowBlur = 1.6; }
    ctx.fillStyle = color;
    ctx.fill(path);
    ctx.shadowBlur = 0;
    ctx.clip(path);
    const g = ctx.createRadialGradient(x - r * 0.35, y - r * 0.45, r * 0.1, x, y, r * 1.25);
    g.addColorStop(0, `rgba(255,252,246,${light})`);
    g.addColorStop(0.55, 'rgba(255,252,246,0)');
    g.addColorStop(1, `rgba(40,25,15,${shade})`);
    ctx.fillStyle = g;
    ctx.fill(path);
    ctx.globalAlpha = 0.85;
    ctx.fillStyle = fibrePattern;
    ctx.fill(path);
    ctx.restore();
  }
  function wood(ctx, path, color = '#D9B98E', o = {}) {
    ctx.save();
    ctx.fillStyle = color;
    ctx.fill(path);
    ctx.clip(path);
    ctx.globalAlpha = 0.9;
    ctx.fillStyle = grainPattern;
    ctx.fill(path);
    ctx.globalAlpha = 1;
    if (o.y !== undefined) {
      const g = ctx.createLinearGradient(0, o.y - (o.h || 40) / 2, 0, o.y + (o.h || 40) / 2);
      g.addColorStop(0, 'rgba(255,250,240,0.35)');
      g.addColorStop(0.4, 'rgba(255,250,240,0)');
      g.addColorStop(1, 'rgba(70,40,20,0.22)');
      ctx.fillStyle = g;
      ctx.fill(path);
    }
    ctx.restore();
  }
  function shadow(ctx, x, y, w, h, a = 0.18) {
    const g = ctx.createRadialGradient(x, y, 0, x, y, w / 2);
    g.addColorStop(0, `rgba(73,53,42,${a})`);
    g.addColorStop(1, 'rgba(73,53,42,0)');
    ctx.save();
    ctx.translate(x, y); ctx.scale(1, h / w); ctx.translate(-x, -y);
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(x, y, w / 2, 0, TAU); ctx.fill();
    ctx.restore();
  }
  function circle(x, y, r) { const p = new Path2D(); p.arc(x, y, r, 0, TAU); return p; }
  function ellipse(x, y, rx, ry, rot = 0) { const p = new Path2D(); p.ellipse(x, y, rx, ry, rot, 0, TAU); return p; }
  function roundRect(x, y, w, h, r) { const p = new Path2D(); p.roundRect(x, y, w, h, r); return p; }
  // A sleepy (or awake) felt face, the house style: two dark eyes, rosy cheeks, a small smile.
  function face(ctx, x, y, r, o = {}) {
    const { awake = true, happy = 0.5, look = { x: 0, y: 0 }, blush = 0.55 } = o;
    ctx.save();
    const ex = r * 0.34, ey = -r * 0.05;
    ctx.fillStyle = `rgba(221,153,139,${blush})`;
    for (const sx of [-1, 1]) { ctx.beginPath(); ctx.ellipse(x + sx * r * 0.52, y + r * 0.2, r * 0.17, r * 0.11, 0, 0, TAU); ctx.fill(); }
    ctx.fillStyle = C.ink; ctx.strokeStyle = C.ink; ctx.lineCap = 'round'; ctx.lineWidth = Math.max(1.4, r * 0.07);
    for (const sx of [-1, 1]) {
      if (awake) {
        ctx.beginPath(); ctx.ellipse(x + sx * ex + look.x * r * 0.06, y + ey + look.y * r * 0.06, r * 0.085, r * 0.11, 0, 0, TAU); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.85)';
        ctx.beginPath(); ctx.arc(x + sx * ex + look.x * r * 0.06 - r * 0.025, y + ey - r * 0.04, r * 0.028, 0, TAU); ctx.fill();
        ctx.fillStyle = C.ink;
      } else {
        ctx.beginPath(); ctx.arc(x + sx * ex, y + ey - r * 0.02, r * 0.09, 0.15 * Math.PI, 0.85 * Math.PI); ctx.stroke();
      }
    }
    ctx.beginPath();
    const mw = r * (0.14 + happy * 0.1);
    ctx.arc(x, y + r * 0.12, mw, 0.2 * Math.PI, 0.8 * Math.PI);
    ctx.stroke();
    ctx.restore();
  }

  // ---------- Particles: soft motes, droplets, foam.
  function particles() {
    const list = [];
    return {
      list,
      add(p) { list.push(Object.assign({ vx: 0, vy: 0, g: 0, life: 1, age: 0, r: 3, color: '#fff', drag: 0.98, kind: 'dot' }, p)); },
      update(dt) {
        for (let i = list.length - 1; i >= 0; i--) {
          const p = list[i];
          p.age += dt;
          p.vx *= p.drag; p.vy = p.vy * p.drag + p.g * dt;
          p.x += p.vx * dt; p.y += p.vy * dt;
          if (p.age >= p.life) list.splice(i, 1);
        }
      },
      draw(ctx) {
        for (const p of list) {
          const k = 1 - p.age / p.life;
          ctx.globalAlpha = Math.max(0, k) * (p.alpha ?? 1);
          ctx.fillStyle = p.color;
          ctx.beginPath(); ctx.arc(p.x, p.y, p.r * (p.grow ? 1 + (1 - k) * p.grow : 1), 0, TAU); ctx.fill();
          if (p.kind === 'bubble') {
            ctx.globalAlpha *= 0.9; ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.lineWidth = 1;
            ctx.stroke();
          }
        }
        ctx.globalAlpha = 1;
      },
    };
  }

  return { TAU, clamp, lerp, rand, pick, ease, C, stage, felt, wood, shadow, circle, ellipse, roundRect, face, particles, reduceMotion };
})();

/* Soft synthesized sounds, the same family as the app's sound book: felt-piano plucks, soap pops,
   water plips and splashes. Quiet by default; nothing plays until the first touch. */
const Sound = (() => {
  let ac = null, master = null, on = true;
  const PENTA = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5];
  function unlock() {
    if (!ac) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      ac = new AC();
      master = ac.createGain(); master.gain.value = 0.6;
      const comp = ac.createDynamicsCompressor();
      comp.threshold.value = -18; comp.ratio.value = 3;
      master.connect(comp); comp.connect(ac.destination);
    }
    if (ac.state === 'suspended') ac.resume();
  }
  const ready = () => on && ac && ac.state === 'running';
  function env(g, t, a, peak, d) { g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(peak, t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d); }
  function pluck(f, o = {}) {
    if (!ready()) return;
    const { gain = 0.16, decay = 0.5, bright = 0.3, when = 0 } = o;
    const t = ac.currentTime + when;
    [1, 0.3, 0.11, 0.045].forEach((a, i) => {
      const osc = ac.createOscillator(), g = ac.createGain();
      osc.frequency.value = f * (i + 1);
      const amp = i === 0 ? a : a * (0.5 + bright);
      env(g, t, 0.006, gain * amp, decay / (1 + 0.8 * i));
      osc.connect(g); g.connect(master);
      osc.start(t); osc.stop(t + decay + 0.1);
    });
  }
  function note(degree, o) { pluck(PENTA[Math.max(0, Math.min(PENTA.length - 1, degree))], o); }
  function sweep(f0, f1, dur, gain, type = 'sine', when = 0) {
    if (!ready()) return;
    const t = ac.currentTime + when, osc = ac.createOscillator(), g = ac.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(f0, t); osc.frequency.exponentialRampToValueAtTime(f1, t + dur);
    env(g, t, 0.004, gain, dur);
    osc.connect(g); g.connect(master); osc.start(t); osc.stop(t + dur + 0.05);
  }
  function noise(dur, filterF, q, gain, when = 0, type = 'bandpass') {
    if (!ready()) return;
    const t = ac.currentTime + when;
    const n = Math.floor(ac.sampleRate * dur);
    const buf = ac.createBuffer(1, n, ac.sampleRate), d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    const src = ac.createBufferSource(); src.buffer = buf;
    const f = ac.createBiquadFilter(); f.type = type; f.frequency.value = filterF; f.Q.value = q;
    const g = ac.createGain(); env(g, t, 0.01, gain, dur);
    src.connect(f); f.connect(g); g.connect(master); src.start(t);
  }
  const pop = (size = 1) => { sweep(900 / size, 480 / size, 0.06, 0.18); noise(0.02, 1800 / size, 1, 0.05); };
  const plip = (f = 700) => sweep(f, f * 1.6, 0.09, 0.12);
  const splash = (big = 1) => { noise(0.35 * big, 700, 0.7, 0.07 * big, 0, 'lowpass'); plip(520); plip(640 + Math.random() * 120); };
  const thump = (f = 180) => sweep(f, f * 0.7, 0.12, 0.2);
  const shh = (dur = 0.3, gain = 0.03) => noise(dur, 900, 0.6, gain, 0, 'lowpass');
  return { unlock, pluck, note, pop, plip, splash, thump, shh, sweep, noise, PENTA, toggle(v) { on = v; } };
})();
