/* Prototype: Little Wash. Muddy felt vehicles roll in; scrub with the sponge (foam), rinse with
   the hose, buff with the towel; when clean they sparkle, toot and drive off. */
function CarWashToy() {
  const { C, felt, wood, shadow, roundRect, circle, ellipse, face, particles, rand, pick, clamp, lerp, ease, TAU } = Lull;
  const P = particles();
  const VEHICLES = ['fire', 'police', 'tractor', 'bus'];
  let order = VEHICLES.slice().sort(() => Math.random() - 0.5);
  let carIndex = 0;
  const S = { w: 0, h: 0 };
  const car = { kind: 'fire', x: 0, targetX: 0, y: 0, w: 260, h: 150, wheel: 0, state: 'in', t: 0, bounce: 0, happy: 0.3, look: { x: 0, y: 0 } };
  let carCanvas = null, mudCanvas = null, mudCtx = null, probe = null, probeCtx = null;
  let mudStart = 1, mudNow = 1, probeTimer = 0, sparkleDone = false;
  let foam = [];                 // foam blobs stuck on the vehicle (vehicle-local coords)
  let tool = 'sponge';
  const tools = [{ id: 'sponge' }, { id: 'hose' }, { id: 'towel' }];
  let toolRects = [];
  let finger = null, lastFinger = null, scrubSound = 0;
  const DPR = () => Math.min(window.devicePixelRatio || 1, 2);

  function layout(s) {
    S.w = s.w; S.h = s.h;
    const landscape = s.w > s.h;
    car.w = Math.min(s.w * (landscape ? 0.46 : 0.78), s.h * (landscape ? 0.62 : 0.4) * 1.75);
    car.h = car.w * 0.58;
    car.y = s.h * (landscape ? 0.5 : 0.47);
    car.targetX = s.w / 2;
    const size = Math.min(76, Math.max(54, Math.min(s.w, s.h) * 0.15));
    const gap = size * 0.35, total = tools.length * size + (tools.length - 1) * gap;
    toolRects = tools.map((t, i) => ({ id: t.id, x: s.w / 2 - total / 2 + i * (size + gap), y: s.h - size - Math.max(14, s.h * 0.03), w: size, h: size }));
    buildCar(false);
  }

  // ---- Vehicle art (side view, facing right), drawn once into an offscreen canvas.
  function vehiclePaths(kind, w, h) {
    const p = { body: [], details: [], wheels: [], windowPath: null, sil: new Path2D() };
    const add = (path, color, kindOf = 'felt') => { p.body.push({ path, color, kindOf }); p.sil.addPath(path); };
    const wy = h * 0.8, wr = h * 0.17;
    if (kind === 'fire') {
      add(roundRect(w * 0.04, h * 0.3, w * 0.66, h * 0.48, h * 0.08), '#C7503F');
      add(roundRect(w * 0.62, h * 0.18, w * 0.32, h * 0.6, h * 0.1), '#D0584A');
      p.windowPath = roundRect(w * 0.7, h * 0.26, w * 0.19, h * 0.22, h * 0.06);
      p.details.push({ path: roundRect(w * 0.04, h * 0.6, w * 0.9, h * 0.06, 3), color: '#F4E3C2' });
      const ladder = new Path2D();
      ladder.rect(w * 0.08, h * 0.17, w * 0.5, h * 0.035); ladder.rect(w * 0.08, h * 0.25, w * 0.5, h * 0.035);
      for (let i = 0; i <= 6; i++) ladder.rect(w * (0.09 + i * 0.077), h * 0.17, w * 0.018, h * 0.11);
      p.details.push({ path: ladder, color: '#D9B98E', kindOf: 'wood' });
      p.details.push({ path: circle(w * 0.79, h * 0.13, h * 0.05), color: '#F2C14E' });
      p.wheels = [[w * 0.2, wy, wr], [w * 0.78, wy, wr]];
    } else if (kind === 'police') {
      add(roundRect(w * 0.04, h * 0.42, w * 0.92, h * 0.36, h * 0.12), '#5E86A8');
      add(roundRect(w * 0.22, h * 0.2, w * 0.5, h * 0.3, h * 0.12), '#6E95B5');
      p.windowPath = roundRect(w * 0.47, h * 0.26, w * 0.2, h * 0.19, h * 0.06);
      p.details.push({ path: roundRect(w * 0.06, h * 0.52, w * 0.88, h * 0.1, 4), color: '#FFF8EC' });
      p.details.push({ path: roundRect(w * 0.36, h * 0.12, w * 0.1, h * 0.07, 4), color: '#D9625A' });
      p.details.push({ path: roundRect(w * 0.47, h * 0.12, w * 0.1, h * 0.07, 4), color: '#6FA8D8' });
      p.details.push({ path: circle(w * 0.93, h * 0.5, h * 0.04), color: '#F6E7A8' });
      p.wheels = [[w * 0.22, wy, wr], [w * 0.76, wy, wr]];
    } else if (kind === 'tractor') {
      add(roundRect(w * 0.42, h * 0.38, w * 0.48, h * 0.32, h * 0.08), '#6E9A64');
      add(roundRect(w * 0.12, h * 0.14, w * 0.34, h * 0.5, h * 0.08), '#7AA66E');
      p.windowPath = roundRect(w * 0.17, h * 0.2, w * 0.24, h * 0.2, h * 0.05);
      p.details.push({ path: roundRect(w * 0.76, h * 0.14, w * 0.04, h * 0.26, 3), color: '#5A4636' });
      p.details.push({ path: roundRect(w * 0.42, h * 0.5, w * 0.48, h * 0.05, 3), color: '#E7C25A' });
      p.wheels = [[w * 0.26, h * 0.74, h * 0.25], [w * 0.8, h * 0.82, h * 0.15]];
    } else {
      add(roundRect(w * 0.03, h * 0.16, w * 0.94, h * 0.62, h * 0.12), '#E2B04A');
      p.windowPath = roundRect(w * 0.76, h * 0.24, w * 0.16, h * 0.22, h * 0.05);
      const win = new Path2D();
      for (let i = 0; i < 4; i++) win.roundRect(w * (0.08 + i * 0.165), h * 0.26, w * 0.13, h * 0.18, h * 0.04);
      p.details.push({ path: win, color: '#CFE3EA' });
      p.details.push({ path: roundRect(w * 0.03, h * 0.56, w * 0.94, h * 0.05, 3), color: '#5A4636' });
      p.wheels = [[w * 0.2, wy, wr], [w * 0.8, wy, wr]];
    }
    for (const [x, y, r] of p.wheels) p.sil.addPath(circle(x, y, r));
    return p;
  }

  function drawVehicle(g, kind, w, h, happy, look) {
    const p = vehiclePaths(kind, w, h);
    for (const b of p.body) felt(g, b.path, b.color, { x: w * 0.45, y: h * 0.4, r: w * 0.5, light: 0.2, shade: 0.16 });
    for (const d of p.details) d.kindOf === 'wood' ? wood(g, d.path, d.color) : felt(g, d.path, d.color, { x: w * 0.5, y: h * 0.4, r: w * 0.4, light: 0.16, shade: 0.1 });
    if (p.windowPath) {
      felt(g, p.windowPath, '#E9F3F4', { x: w * 0.7, y: h * 0.3, r: h * 0.3, light: 0.3, shade: 0.06 });
      const b = windowBox(kind, w, h);
      face(g, b.x, b.y, b.r, { awake: true, happy, look });
    }
    return p;
  }
  function windowBox(kind, w, h) {
    if (kind === 'fire') return { x: w * 0.795, y: h * 0.37, r: h * 0.17 };
    if (kind === 'police') return { x: w * 0.57, y: h * 0.355, r: h * 0.15 };
    if (kind === 'tractor') return { x: w * 0.29, y: h * 0.3, r: h * 0.15 };
    return { x: w * 0.84, y: h * 0.355, r: h * 0.15 };
  }

  function buildCar(fresh) {
    const dpr = DPR();
    const W = Math.ceil(car.w), H = Math.ceil(car.h);
    if (!carCanvas) { carCanvas = document.createElement('canvas'); mudCanvas = document.createElement('canvas'); probe = document.createElement('canvas'); }
    carCanvas.width = mudCanvas.width = W * dpr; carCanvas.height = mudCanvas.height = H * dpr;
    probe.width = 48; probe.height = 28;
    probeCtx = probe.getContext('2d', { willReadFrequently: true });
    mudCtx = mudCanvas.getContext('2d');
    if (fresh !== false || !car.paths) {
      car.paths = vehiclePaths(car.kind, W, H);
      paintMud(W, H, dpr);
      foam = [];
      sparkleDone = false;
    } else {
      car.paths = vehiclePaths(car.kind, W, H);
      paintMud(W, H, dpr, mudNow / Math.max(0.0001, mudStart));
    }
  }

  // Mud: soft felt-brown splats clipped to the vehicle, heavier low down (it came through puddles).
  function paintMud(W, H, dpr, amount = 1) {
    const g = mudCtx;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, W, H);
    g.save();
    g.clip(car.paths.sil);
    const n = Math.round(46 * amount);
    for (let i = 0; i < n; i++) {
      const low = Math.random() < 0.65;
      const x = rand(0, W), y = low ? rand(H * 0.5, H) : rand(H * 0.1, H * 0.7);
      const r = rand(H * 0.06, H * 0.16);
      const blob = new Path2D();
      const k = 7 + Math.floor(Math.random() * 4);
      for (let j = 0; j <= k; j++) {
        const a = (j / k) * TAU, rr = r * rand(0.7, 1.15);
        j === 0 ? blob.moveTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr) : blob.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr);
      }
      blob.closePath();
      felt(g, blob, pick(['#7A5A40', '#6B4E37', '#86664A']), { x, y, r, light: 0.12, shade: 0.2 });
    }
    // drips
    for (let i = 0; i < 10 * amount; i++) {
      const x = rand(W * 0.05, W * 0.95), y = rand(H * 0.35, H * 0.6), len = rand(H * 0.08, H * 0.2);
      felt(g, roundRect(x, y, H * 0.035, len, H * 0.02), '#6B4E37', { x, y, r: len, light: 0.1, shade: 0.15 });
    }
    g.restore();
    measure(true);
  }

  function measure(initial) {
    probeCtx.clearRect(0, 0, probe.width, probe.height);
    probeCtx.drawImage(mudCanvas, 0, 0, probe.width, probe.height);
    const d = probeCtx.getImageData(0, 0, probe.width, probe.height).data;
    let sum = 0;
    for (let i = 3; i < d.length; i += 4) sum += d[i];
    if (initial) mudStart = Math.max(1, sum);
    mudNow = sum;
  }

  function nextVehicle() {
    carIndex = (carIndex + 1) % order.length;
    if (carIndex === 0) order = VEHICLES.slice().sort(() => Math.random() - 0.5);
    car.kind = order[carIndex];
    car.state = 'in'; car.t = 0; car.happy = 0.3;
    car.x = -car.w;
    buildCar(true);
  }

  // ---- Toy protocol
  const toy = {
    resize(s) {
      layout(s);
      if (car.state === 'in' && car.t === 0) car.x = -car.w;
    },
    down(s, p) {
      const hit = toolRects.find((r) => p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h);
      if (hit) { tool = hit.id; Sound.note(tool === 'sponge' ? 5 : tool === 'hose' ? 6 : 7, { gain: 0.08, decay: 0.25 }); return; }
      finger = { x: p.x, y: p.y }; lastFinger = { ...finger };
      work(p, p);
    },
    move(s, p) { if (!finger) return; lastFinger = finger; finger = { x: p.x, y: p.y }; work(lastFinger, finger); },
    up() { finger = null; },
    update(s, dt) {
      P.update(dt);
      car.wheel += 0;
      if (car.state === 'in') {
        car.t += dt;
        const k = Math.min(1, car.t / 1.6);
        car.x = lerp(-car.w * 0.6, car.targetX, ease.out(k));
        car.wheel = car.x / (car.h * 0.17);
        if (k >= 1) { car.state = 'wash'; car.t = 0; Sound.thump(150); }
      } else if (car.state === 'wash') {
        car.x = car.targetX;
        probeTimer += dt;
        if (probeTimer > 0.25) { probeTimer = 0; measure(false); }
        const clean = 1 - mudNow / mudStart;
        car.happy = 0.3 + clean * 0.7;
        if (clean > 0.93 && foam.length < 4 && !sparkleDone) { sparkleDone = true; car.state = 'shine'; car.t = 0; shine(); }
      } else if (car.state === 'shine') {
        car.t += dt;
        car.bounce = Math.sin(Math.min(1, car.t / 0.5) * Math.PI) * 10;
        if (car.t > 1.6) { car.state = 'out'; car.t = 0; Sound.note(4, { gain: 0.1, decay: 0.3 }); Sound.note(7, { gain: 0.1, decay: 0.4, when: 0.14 }); }
      } else if (car.state === 'out') {
        car.t += dt;
        const k = Math.min(1, car.t / 1.4);
        car.x = lerp(car.targetX, S.w + car.w * 0.8, k * k);
        car.wheel = car.x / (car.h * 0.17);
        if (k >= 1) nextVehicle();
      }
      for (const f of foam) { f.age += dt; f.wob = Math.sin(f.age * 3 + f.seed) * 0.08; }
      if (finger) car.look = { x: clamp((finger.x - car.x) / car.w * 2, -1, 1), y: clamp((finger.y - car.y) / car.h * 2, -1, 1) };
      else car.look = { x: car.look.x * 0.95, y: car.look.y * 0.95 };
      scrubSound = Math.max(0, scrubSound - dt);
    },
    draw(s, ctx) {
      // Room: linen wall with a soft sage tile band, a wooden floor.
      const floorY = car.y + car.h * 0.5;
      ctx.fillStyle = C.linen; ctx.fillRect(0, 0, s.w, s.h);
      const tile = roundRect(-10, s.h * 0.12, s.w + 20, floorY - s.h * 0.12, 0);
      felt(ctx, tile, '#DCE6DA', { x: s.w * 0.3, y: s.h * 0.2, r: s.w, light: 0.18, shade: 0.06, fuzz: false });
      ctx.strokeStyle = 'rgba(130,155,130,0.25)'; ctx.lineWidth = 1;
      for (let x = 0; x < s.w; x += 34) { ctx.beginPath(); ctx.moveTo(x, s.h * 0.12); ctx.lineTo(x, floorY); ctx.stroke(); }
      for (let y = s.h * 0.12; y < floorY; y += 34) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(s.w, y); ctx.stroke(); }
      wood(ctx, roundRect(-10, floorY, s.w + 20, s.h - floorY + 10, 0), '#D9B98E', { y: floorY + 40, h: 80 });
      // Overhead shower bar (the rinse) and side brushes, for the room's story.
      wood(ctx, roundRect(s.w * 0.12, s.h * 0.1, s.w * 0.76, 12, 6), '#C9A57A');
      for (let i = 0; i < 7; i++) felt(ctx, circle(s.w * (0.17 + i * 0.11), s.h * 0.1 + 14, 5), C.water, { x: 0, y: 0, r: 6 });
      // Vehicle
      const cx = car.x - car.w / 2, cy = car.y - car.h / 2 - car.bounce;
      shadow(ctx, car.x, floorY - 2, car.w * 1.05, car.h * 0.22, 0.22);
      ctx.save();
      ctx.translate(cx, cy);
      drawVehicleLive(ctx);
      ctx.restore();
      // Foam (stuck on the vehicle) and particles
      for (const f of foam) {
        const x = cx + f.x, y = cy + f.y;
        felt(ctx, circle(x, y, f.r * (1 + f.wob)), '#FFFDF8', { x, y, r: f.r, light: 0.35, shade: 0.12 });
        ctx.strokeStyle = 'rgba(160,200,215,0.55)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(x - f.r * 0.3, y - f.r * 0.3, f.r * 0.35, Math.PI, 1.5 * Math.PI); ctx.stroke();
      }
      P.draw(ctx);
      // Tool tray
      drawTools(ctx, s);
      if (finger) drawToolAtFinger(ctx);
    },
  };

  function drawVehicleLive(ctx) {
    const W = car.w, H = car.h;
    const p = car.paths;
    // Wheels behind the body
    for (const [x, y, r] of p.wheels) {
      felt(ctx, circle(x, y, r), '#3F3430', { x, y, r, light: 0.12, shade: 0.2 });
      felt(ctx, circle(x, y, r * 0.45), '#CFC6BA', { x, y, r: r * 0.45, light: 0.3, shade: 0.1 });
      ctx.save(); ctx.translate(x, y); ctx.rotate(car.wheel);
      ctx.strokeStyle = 'rgba(73,53,42,0.5)'; ctx.lineWidth = 2;
      for (let i = 0; i < 3; i++) { ctx.rotate(TAU / 3); ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(r * 0.4, 0); ctx.stroke(); }
      ctx.restore();
    }
    drawVehicle(ctx, car.kind, W, H, car.happy, car.look);
    ctx.drawImage(mudCanvas, 0, 0, W, H);
    if (car.state === 'shine') {
      const k = Math.min(1, car.t / 1.2);
      ctx.save(); ctx.clip(p.sil);
      const gx = lerp(-W * 0.3, W * 1.3, k);
      const g = ctx.createLinearGradient(gx - 40, 0, gx + 40, H);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      ctx.restore();
    }
  }

  function local(p) { return { x: p.x - (car.x - car.w / 2), y: p.y - (car.y - car.h / 2) }; }

  // What the finger does with each tool.
  function work(a, b) {
    if (car.state !== 'wash') return;
    const la = local(a), lb = local(b);
    const dist = Math.hypot(lb.x - la.x, lb.y - la.y);
    const steps = Math.max(1, Math.ceil(dist / 6));
    const dpr = DPR();
    const r = car.h * (tool === 'hose' ? 0.16 : 0.13);
    mudCtx.save();
    mudCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    mudCtx.globalCompositeOperation = 'destination-out';
    for (let i = 0; i <= steps; i++) {
      const x = lerp(la.x, lb.x, i / steps), y = lerp(la.y, lb.y, i / steps);
      const g = mudCtx.createRadialGradient(x, y, 0, x, y, r);
      const strength = tool === 'hose' ? 0.22 : tool === 'sponge' ? 0.14 : 0.06;
      g.addColorStop(0, `rgba(0,0,0,${strength})`); g.addColorStop(1, 'rgba(0,0,0,0)');
      mudCtx.fillStyle = g;
      mudCtx.beginPath(); mudCtx.arc(x, y, r, 0, TAU); mudCtx.fill();
    }
    mudCtx.restore();
    const onCar = lb.x > 0 && lb.x < car.w && lb.y > 0 && lb.y < car.h;
    if (tool === 'sponge' && onCar) {
      if (Math.random() < 0.5 && foam.length < 90) foam.push({ x: lb.x + rand(-12, 12), y: lb.y + rand(-12, 12), r: rand(6, 13), age: 0, seed: rand(0, 6) });
      if (scrubSound <= 0) { Sound.shh(0.12, 0.018); scrubSound = 0.16; if (Math.random() < 0.4) Sound.plip(rand(700, 1100)); }
    } else if (tool === 'hose') {
      foam = foam.filter((f) => Math.hypot(f.x - lb.x, f.y - lb.y) > car.h * 0.22 || Math.random() < 0.3);
      for (let i = 0; i < 3; i++) P.add({ x: b.x + rand(-6, 6), y: b.y - 30, vx: rand(-40, 40), vy: rand(120, 220), g: 500, life: 0.6, r: rand(2, 4), color: 'rgba(160,205,220,0.9)' });
      if (scrubSound <= 0) { Sound.shh(0.2, 0.025); scrubSound = 0.18; }
    } else if (tool === 'towel') {
      foam = foam.filter((f) => Math.hypot(f.x - lb.x, f.y - lb.y) > car.h * 0.18);
      if (Math.random() < 0.25) P.add({ x: b.x + rand(-18, 18), y: b.y + rand(-18, 18), vy: -20, life: 0.7, r: rand(2, 3.5), color: 'rgba(255,248,220,0.95)' });
    }
  }

  function shine() {
    for (let i = 0; i < 18; i++) {
      const a = rand(0, TAU), sp = rand(40, 140);
      P.add({ x: car.x + rand(-car.w * 0.4, car.w * 0.4), y: car.y + rand(-car.h * 0.4, car.h * 0.2), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 40, drag: 0.94, life: 1.1, r: rand(2, 4.5), color: pick(['#FFF6D8', '#FFFFFF', '#F6E3A1']) });
    }
    [5, 7, 9, 10].forEach((d, i) => Sound.note(d, { gain: 0.12, decay: 0.6, when: i * 0.09 }));
  }

  function drawTools(ctx, s) {
    for (const r of toolRects) {
      const active = r.id === tool;
      const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
      shadow(ctx, cx, r.y + r.h - 2, r.w * 0.9, r.h * 0.2, 0.18);
      felt(ctx, roundRect(r.x, r.y - (active ? 6 : 0), r.w, r.h, r.w * 0.28), active ? C.paper : C.cream, { x: cx, y: cy, r: r.w * 0.6, light: 0.2, shade: 0.12 });
      drawToolIcon(ctx, r.id, cx, cy - (active ? 6 : 0), r.w * 0.36);
    }
  }
  function drawToolIcon(ctx, id, x, y, r) {
    if (id === 'sponge') {
      felt(ctx, roundRect(x - r, y - r * 0.6, r * 2, r * 1.2, r * 0.35), '#F2C94C', { x, y, r, light: 0.25, shade: 0.15 });
      for (let i = 0; i < 4; i++) felt(ctx, circle(x + rand(-r * 0.6, r * 0.6), y - r * 0.75, r * 0.22), '#FFFFFF', { x, y, r: r * 0.2 });
    } else if (id === 'hose') {
      felt(ctx, roundRect(x - r * 0.9, y - r * 0.25, r * 1.4, r * 0.5, r * 0.25), C.terracotta, { x, y, r, light: 0.2, shade: 0.15 });
      felt(ctx, roundRect(x + r * 0.35, y - r * 0.4, r * 0.55, r * 0.8, r * 0.2), '#8C8C8C', { x, y, r: r * 0.5, light: 0.3, shade: 0.12 });
      for (let i = 0; i < 3; i++) felt(ctx, circle(x + r * 1.1, y - r * 0.3 + i * r * 0.3, r * 0.1), C.water, { x, y, r: r * 0.1 });
    } else {
      felt(ctx, roundRect(x - r, y - r * 0.75, r * 2, r * 1.5, r * 0.25), C.water, { x, y, r, light: 0.25, shade: 0.12 });
      ctx.strokeStyle = 'rgba(255,255,255,0.6)'; ctx.lineWidth = 2;
      for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.moveTo(x - r, y - r * 0.4 + i * r * 0.4); ctx.lineTo(x + r, y - r * 0.4 + i * r * 0.4); ctx.stroke(); }
    }
  }
  function drawToolAtFinger(ctx) {
    ctx.save(); ctx.globalAlpha = 0.9;
    drawToolIcon(ctx, tool, finger.x, finger.y - 30, 18);
    ctx.restore();
  }

  car.kind = order[0];
  return toy;
}
