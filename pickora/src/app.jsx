/* Pickora — random picker wheel. Runs fully in the browser; React 18 UMD globals. */
const { useState, useEffect, useLayoutEffect, useRef, useMemo, useCallback } = React;

/* ================= constants ================= */

const STORAGE_KEY = 'pickora:v1';
const MAX_ENTRIES = 1000;
const MAX_NUMBERS = 1000;
const SAMPLE_NAMES = [
  'Olena', 'Marcus', 'Sofia 🎸', 'Taras', 'Aiko', 'Dmytro',
  'Priya', 'Jonas', 'Iryna', 'Leo', 'Bohdana Kovalenko-Shevchuk', 'Mateo',
];
const DURATIONS = { quick: 3000, normal: 5600, slow: 9000 };
const SPEEDS = [['quick', 'Quick'], ['normal', 'Normal'], ['slow', 'Slow']];
const MODES = [['names', 'Names'], ['yesno', 'Yes / No'], ['numbers', 'Numbers'], ['teams', 'Teams']];
const SEG_TONES = ['seg1', 'seg2', 'seg3', 'seg4', 'seg5', 'seg6'];
const TEAM_NAMES = ['Gold', 'Coral', 'Cloud', 'Mint', 'Rose', 'Ink'];
const YN = {
  yes: { label: 'Yes', tone: 'mint' },
  no: { label: 'No', tone: 'signal' },
  maybe: { label: 'Maybe', tone: 'gold' },
};
const LABEL_FONT = '"Onest", system-ui, -apple-system, "Segoe UI", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"';

/* ================= small utils ================= */

let uidSeq = 0;
const uid = () => 'e' + Date.now().toString(36) + (uidSeq++).toString(36);
const mod = (a, n) => ((a % n) + n) % n;
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

function randomU32() {
  try {
    const a = new Uint32Array(1);
    crypto.getRandomValues(a);
    return a[0];
  } catch (e) {
    return Math.floor(Math.random() * 0x100000000);
  }
}
/* unbiased integer in [0, n) */
function randInt(n) {
  const limit = Math.floor(0x100000000 / n) * n;
  let x;
  do { x = randomU32(); } while (x >= limit);
  return x % n;
}
const rand01 = () => randomU32() / 0x100000000;
function shuffled(list) {
  const a = list.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = randInt(i + 1);
    const t = a[i]; a[i] = a[j]; a[j] = t;
  }
  return a;
}

const segmenter = typeof Intl !== 'undefined' && Intl.Segmenter ? new Intl.Segmenter(undefined, { granularity: 'grapheme' }) : null;
const graphemes = (s) => (segmenter ? Array.from(segmenter.segment(s), (x) => x.segment) : Array.from(s));
function lenBucket(text) {
  const n = graphemes(text).length;
  if (n <= 12) return 's';
  if (n <= 22) return 'm';
  if (n <= 40) return 'l';
  return 'xl';
}
/* trims by whole graphemes so emoji and combined letters never break */
function fitText(ctx, text, maxW) {
  if (ctx.measureText(text).width <= maxW) return text;
  const g = graphemes(text);
  let lo = 0, hi = g.length;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (ctx.measureText(g.slice(0, mid).join('').trimEnd() + '…').width <= maxW) lo = mid;
    else hi = mid - 1;
  }
  return lo > 0 ? g.slice(0, lo).join('').trimEnd() + '…' : '';
}

/* the pointer sits at 12 o'clock; segment i covers [i*s, (i+1)*s) measured clockwise from the top
   of the unrotated wheel. Rotating the wheel clockwise by R puts wheel angle -R under the pointer. */
const indexAt = (R, n) => Math.min(n - 1, Math.floor(mod(-R, 360) / (360 / n)));
const pegCount = (n) => (n <= 1 ? 12 : n <= 48 ? n * Math.ceil(12 / n) : 48);

function cubicBezier(x1, y1, x2, y2) {
  const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
  const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
  const sx = (t) => ((ax * t + bx) * t + cx) * t;
  const sy = (t) => ((ay * t + by) * t + cy) * t;
  const dsx = (t) => (3 * ax * t + 2 * bx) * t + cx;
  return (x) => {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    let t = x;
    for (let i = 0; i < 8; i++) {
      const err = sx(t) - x;
      if (Math.abs(err) < 1e-7) return sy(t);
      const d = dsx(t);
      if (Math.abs(d) < 1e-6) break;
      t -= err / d;
    }
    let lo = 0, hi = 1;
    t = x;
    for (let i = 0; i < 40; i++) {
      const v = sx(t);
      if (Math.abs(v - x) < 1e-7) break;
      if (v < x) lo = t; else hi = t;
      t = (lo + hi) / 2;
    }
    return sy(t);
  };
}
/* brief build-up, long crawl at the end: the suspense lives in the last turn */
const SPIN_EASE = cubicBezier(0.22, 0.0, 0.06, 1);

/* ================= sound ================= */

const Sound = (() => {
  let ctx = null;
  const get = () => {
    try {
      if (!ctx) {
        const AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return null;
        ctx = new AC();
      }
      if (ctx.state === 'suspended') ctx.resume();
      return ctx;
    } catch (e) {
      return null;
    }
  };
  const blip = (freq, dur, gain, when) => {
    const c = get();
    if (!c) return;
    const t = c.currentTime + (when || 0);
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = 'triangle';
    o.frequency.setValueAtTime(freq, t);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(gain, t + 0.004);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(c.destination);
    o.start(t);
    o.stop(t + dur + 0.03);
  };
  return {
    unlock: () => { get(); },
    tick: () => blip(1650 + Math.random() * 300, 0.035, 0.07),
    win: () => { blip(523.25, 0.2, 0.11); blip(659.25, 0.2, 0.11, 0.09); blip(783.99, 0.38, 0.13, 0.18); },
  };
})();

/* ================= state ================= */

function withTrailing(names) {
  /* the editor always ends with exactly one empty row to type into */
  let list = names;
  const activeIdx = [];
  list.forEach((n, i) => { if (!n.out) activeIdx.push(i); });
  let k = activeIdx.length - 1;
  while (k > 0 && list[activeIdx[k]].text === '' && list[activeIdx[k - 1]].text === '') k--;
  if (k < activeIdx.length - 1) {
    const drop = new Set(activeIdx.slice(k + 1).map((i) => list[i].id));
    list = list.filter((n) => !drop.has(n.id));
  }
  const active = list.filter((n) => !n.out);
  if (!active.length || active[active.length - 1].text !== '') list = [...list, { id: uid(), text: '', out: false }];
  return list;
}

function defaultState() {
  return {
    v: 1,
    mode: 'names',
    names: withTrailing(SAMPLE_NAMES.map((t) => ({ id: uid(), text: t, out: false }))),
    isSample: true,
    noRepeat: false,
    speed: 'normal',
    sound: true,
    yesno: { maybe: false, question: '' },
    numbers: { from: '1', to: '100', drawn: [] },
    teams: { count: 3 },
    history: { names: [], yesno: [], numbers: [] },
    pending: null,
  };
}

function loadState() {
  const d = defaultState();
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return d;
    const s = JSON.parse(raw);
    if (!s || s.v !== 1) return d;
    const names = Array.isArray(s.names)
      ? s.names.filter((x) => x && typeof x.text === 'string').map((x) => ({ id: String(x.id || uid()), text: x.text, out: !!x.out, pickedAt: x.pickedAt }))
      : d.names;
    return {
      ...d,
      ...s,
      mode: MODES.some((m) => m[0] === s.mode) ? s.mode : 'names',
      speed: DURATIONS[s.speed] ? s.speed : 'normal',
      names: withTrailing(names),
      yesno: { ...d.yesno, ...s.yesno },
      numbers: { ...d.numbers, ...s.numbers, drawn: Array.isArray(s.numbers && s.numbers.drawn) ? s.numbers.drawn.map(Number).filter(Number.isFinite) : [] },
      teams: { ...d.teams, ...s.teams },
      history: { ...d.history, ...s.history },
    };
  } catch (e) {
    return d;
  }
}

function parseRange(numbers) {
  const fs = String(numbers.from).trim(), ts = String(numbers.to).trim();
  const f = Number(fs), t = Number(ts);
  if (fs === '' || ts === '' || !Number.isInteger(f) || !Number.isInteger(t)) return { ok: false, error: 'Use whole numbers, like 1 and 100.' };
  if (Math.abs(f) > 1e9 || Math.abs(t) > 1e9) return { ok: false, error: 'Keep numbers under one billion.' };
  if (f >= t) return { ok: false, error: '“To” has to be bigger than “From”.' };
  if (t - f + 1 > MAX_NUMBERS) return { ok: false, error: 'Up to 1,000 numbers fit on the wheel. Narrow the range.' };
  return { ok: true, from: f, to: t };
}

const nameItems = (names) => names.filter((n) => !n.out && n.text.trim()).map((n) => ({ key: n.id, label: n.text.trim() }));

function getItems(s) {
  if (s.mode === 'yesno') {
    const kinds = s.yesno.maybe ? ['yes', 'no', 'maybe'] : ['yes', 'no'];
    const reps = s.yesno.maybe ? 3 : 4;
    const out = [];
    for (let r = 0; r < reps; r++) kinds.forEach((k) => out.push({ key: k + '-' + r, label: YN[k].label, tone: YN[k].tone, kind: k }));
    return out;
  }
  if (s.mode === 'numbers') {
    const r = parseRange(s.numbers);
    if (!r.ok) return [];
    const drawn = new Set(s.numbers.drawn);
    const out = [];
    for (let v = r.from; v <= r.to; v++) if (!drawn.has(v)) out.push({ key: String(v), label: String(v), dial: true });
    return out;
  }
  return nameItems(s.names);
}

const sigOf = (items) => items.length + ':' + items.map((i) => i.key).join('|');

function removeKey(s, mode, key) {
  if (mode === 'names') {
    const now = Date.now();
    return { ...s, names: withTrailing(s.names.map((n) => (n.id === key ? { ...n, out: true, pickedAt: now } : n))) };
  }
  if (mode === 'numbers') {
    const v = Number(key);
    if (s.numbers.drawn.includes(v)) return s;
    return { ...s, numbers: { ...s.numbers, drawn: [...s.numbers.drawn, v] } };
  }
  return s;
}
function restoreKey(s, mode, key) {
  if (mode === 'names') return { ...s, names: withTrailing(s.names.map((n) => (n.id === key ? { ...n, out: false, pickedAt: undefined } : n))) };
  if (mode === 'numbers') return { ...s, numbers: { ...s.numbers, drawn: s.numbers.drawn.filter((v) => v !== Number(key)) } };
  return s;
}
function applyPending(s) {
  if (!s.pending) return s;
  const next = removeKey(s, s.pending.mode, s.pending.key);
  return { ...next, pending: null };
}

/* ================= palette (read from CSS tokens) ================= */

function readPalette() {
  const cs = getComputedStyle(document.documentElement);
  const v = (name) => cs.getPropertyValue(name).trim();
  return {
    seg1: v('--seg-1'), seg2: v('--seg-2'), seg3: v('--seg-3'), seg4: v('--seg-4'), seg5: v('--seg-5'), seg6: v('--seg-6'),
    ink: v('--ink'), paper: v('--cloud'), gold: v('--gold'), mint: v('--mint'), signal: v('--signal'), rose: v('--rose'),
    stageLo: v('--stage-lo'), dim: v('--seg-dim'), onStage3: v('--on-stage-3'),
  };
}
/* ink segments carry light text; everything else carries ink */
const fgFor = (tone) => (tone === 'seg6' ? 'paper' : 'ink');
function toneAt(items, i) {
  const it = items[i];
  if (it && it.tone) return it.tone;
  const n = items.length;
  let c = i % 6;
  /* never let the last segment share a colour with the first */
  if (n > 1 && i === n - 1 && c === 0) c = 2;
  return SEG_TONES[c];
}

/* ================= wheel drawing ================= */

function drawWheel(canvas, size, items, hi, P) {
  const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
  const px = Math.max(1, Math.round(size * dpr));
  if (canvas.width !== px) { canvas.width = px; canvas.height = px; }
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, size, size);

  const c = size / 2;
  const rimW = Math.max(9, size * 0.036);
  const R = c - 1;
  const r = R - rimW + 0.5;
  const hubR = size * 0.125;
  const n = items.length;
  const start0 = -Math.PI / 2;

  if (n === 0) {
    ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.fillStyle = P.stageLo; ctx.fill();
    ctx.setLineDash([5, 9]); ctx.lineWidth = 2; ctx.strokeStyle = P.onStage3;
    ctx.beginPath(); ctx.arc(c, c, r * 0.78, 0, Math.PI * 2); ctx.stroke();
    ctx.beginPath(); ctx.arc(c, c, r * 0.48, 0, Math.PI * 2); ctx.stroke();
    ctx.setLineDash([]);
  } else {
    const s = (Math.PI * 2) / n;
    for (let i = 0; i < n; i++) {
      const a0 = start0 + i * s;
      ctx.beginPath();
      if (n === 1) ctx.arc(c, c, r, 0, Math.PI * 2);
      else { ctx.moveTo(c, c); ctx.arc(c, c, r, a0, a0 + s); ctx.closePath(); }
      ctx.fillStyle = P[toneAt(items, i)];
      ctx.fill();
      if (hi >= 0 && i !== hi) { ctx.fillStyle = P.dim; ctx.fill(); }
    }
    if (n > 1 && n <= 360) {
      ctx.strokeStyle = P.stageLo;
      ctx.lineWidth = n > 90 ? 0.6 : n > 30 ? 1 : 1.5;
      ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const a = start0 + i * s;
        ctx.moveTo(c, c);
        ctx.lineTo(c + Math.cos(a) * r, c + Math.sin(a) * r);
      }
      ctx.stroke();
    }

    /* labels: sized from the chord available at the text's radius; numbers fall back to dial ticks */
    const textR = r - Math.max(10, size * 0.032);
    const innerR = hubR + size * 0.03;
    const fsMax = Math.max(11, size * 0.047);
    const chordK = 0.58;
    const sizeFor = (ang) => Math.min(fsMax, chordK * 2 * (textR * 0.8) * Math.sin(Math.min(ang, Math.PI) / 2));
    let step = 1;
    let fs = n === 1 ? fsMax : sizeFor(s);
    if (fs < 9 && items[0].dial) {
      const steps = [2, 5, 10, 20, 25, 50, 100, 200, 250, 500];
      for (const st of steps) { step = st; fs = sizeFor(s * st); if (fs >= 10) break; }
    }
    if (fs >= 8) {
      ctx.textBaseline = 'middle';
      ctx.font = '600 ' + fs.toFixed(1) + 'px ' + LABEL_FONT;
      const angEff = Math.min(s * step, Math.PI);
      const rMin = n === 1 ? innerR : Math.max(innerR, fs / (chordK * 2 * Math.sin(angEff / 2)));
      const maxW = textR - rMin;
      if (maxW > fs * 1.2) {
        for (let i = 0; i < n; i++) {
          const it = items[i];
          if (step > 1 && Number(it.label) % step !== 0) continue;
          const mid = n === 1 ? Math.PI / 2 : start0 + (i + 0.5) * s;
          const tone = toneAt(items, i);
          const t = fitText(ctx, it.label, maxW);
          if (!t) continue;
          ctx.save();
          ctx.translate(c, c);
          ctx.rotate(mid);
          ctx.textAlign = 'right';
          ctx.fillStyle = P[fgFor(tone)];
          if (hi >= 0 && i !== hi) ctx.globalAlpha = 0.32;
          ctx.fillText(t, textR, 0);
          ctx.restore();
        }
      }
    }
    if (hi >= 0 && n > 1) {
      ctx.beginPath(); ctx.moveTo(c, c); ctx.arc(c, c, r - 2, start0 + hi * s, start0 + (hi + 1) * s); ctx.closePath();
      ctx.lineWidth = 4; ctx.lineJoin = 'round'; ctx.strokeStyle = P.paper; ctx.stroke();
    }
  }

  /* rim and pegs */
  ctx.beginPath(); ctx.arc(c, c, R - rimW / 2, 0, Math.PI * 2);
  ctx.lineWidth = rimW; ctx.strokeStyle = P.ink; ctx.stroke();
  const pegs = pegCount(n);
  const pr = R - rimW / 2;
  const pegR = Math.max(2, rimW * 0.2);
  ctx.fillStyle = P.gold;
  for (let k = 0; k < pegs; k++) {
    const a = start0 + (k * Math.PI * 2) / pegs;
    ctx.beginPath(); ctx.arc(c + Math.cos(a) * pr, c + Math.sin(a) * pr, pegR, 0, Math.PI * 2); ctx.fill();
  }
}

/* ================= hooks ================= */

function useReducedMotion() {
  const q = '(prefers-reduced-motion: reduce)';
  const [v, setV] = useState(() => !!(window.matchMedia && window.matchMedia(q).matches));
  useEffect(() => {
    if (!window.matchMedia) return undefined;
    const m = window.matchMedia(q);
    const h = () => setV(m.matches);
    if (m.addEventListener) m.addEventListener('change', h); else m.addListener(h);
    return () => { if (m.removeEventListener) m.removeEventListener('change', h); else m.removeListener(h); };
  }, []);
  return v;
}

/* ================= icons ================= */

const Svg = (props) => React.createElement('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': 'true', ...props });
const IconShuffle = () => <Svg><path d="M16 3h5v5" /><path d="M4 20 21 3" /><path d="M21 16v5h-5" /><path d="m15 15 6 6" /><path d="M4 4l5 5" /></Svg>;
const IconSort = () => <Svg><path d="M7 4v16" /><path d="m3 16 4 4 4-4" /><path d="M14 6h7" /><path d="M14 12h5" /><path d="M14 18h3" /></Svg>;
const IconMore = () => <Svg><circle cx="5" cy="12" r="1.2" /><circle cx="12" cy="12" r="1.2" /><circle cx="19" cy="12" r="1.2" /></Svg>;
const IconX = () => <Svg><path d="M6 6l12 12" /><path d="M18 6 6 18" /></Svg>;
const IconList = () => <Svg><path d="M9 6h11" /><path d="M9 12h11" /><path d="M9 18h11" /><path d="M4 6h.01" /><path d="M4 12h.01" /><path d="M4 18h.01" /></Svg>;
const IconPaste = () => <Svg><rect x="6" y="4" width="12" height="17" rx="2" /><path d="M9 4V3h6v1" /><path d="M9 10h6" /><path d="M9 14h6" /><path d="M9 18h3" /></Svg>;
const IconSound = () => <Svg><path d="M4 9v6h4l5 4V5L8 9z" /><path d="M16.5 8.5a5 5 0 0 1 0 7" /><path d="M19 6a8.5 8.5 0 0 1 0 12" /></Svg>;
const IconMute = () => <Svg><path d="M4 9v6h4l5 4V5L8 9z" /><path d="m17 9 5 6" /><path d="m22 9-5 6" /></Svg>;
const IconExpand = () => <Svg><path d="M4 9V4h5" /><path d="M20 9V4h-5" /><path d="M4 15v5h5" /><path d="M20 15v5h-5" /></Svg>;
const IconUndo = () => <Svg><path d="M9 14 4 9l5-5" /><path d="M4 9h10a6 6 0 0 1 0 12h-3" /></Svg>;
const IconMinus = () => <Svg><path d="M6 12h12" /></Svg>;
const IconCopy = () => <Svg><rect x="8" y="8" width="12" height="12" rx="2" /><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3" /></Svg>;

function PickMark() {
  return (
    <svg viewBox="0 0 22 26" aria-hidden="true">
      <path d="M11 25C6 19 1.4 12.4 1.4 7.3 1.4 3.4 5.2 1 11 1s9.6 2.4 9.6 6.3C20.6 12.4 16 19 11 25Z" style={{ fill: 'var(--signal)', stroke: 'var(--ink)' }} strokeWidth="1.6" />
      <circle cx="11" cy="7.6" r="2.2" style={{ fill: 'var(--ink)' }} />
    </svg>
  );
}

/* ================= stage: wheel ================= */

function WheelStage(props) {
  const { apiRef, items, mode, result, spinning, reduced, state, status, onSpin, onDragStart, onRemove, onKeep, onUndoRemove, onToggleNoRepeat, onSpeed, onLoadExample } = props;
  const wrapRef = useRef(null);
  const rotorRef = useRef(null);
  const canvasRef = useRef(null);
  const nameRef = useRef(null);
  const readoutRef = useRef(null);
  const pickRef = useRef(null);
  const rotRef = useRef(0);
  const spinRef = useRef(false);
  const dragRef = useRef(null);
  const rafRef = useRef(0);
  const reducedRef = useRef(reduced);
  const itemsRef = useRef(items);
  const [size, setSize] = useState(0);
  const [fontsTick, setFontsTick] = useState(0);
  const [settle, setSettle] = useState(0);
  const palette = useMemo(readPalette, []);
  reducedRef.current = reduced;
  itemsRef.current = items;

  const n = items.length;
  const sig = useMemo(() => sigOf(items), [items]);
  const hi = result && !spinning && result.mode === mode && result.sig === sig ? result.index : -1;

  const setRot = (R) => {
    rotRef.current = R;
    if (rotorRef.current) rotorRef.current.style.transform = 'rotate(' + R + 'deg)';
  };
  const writeName = (text, tone, muted) => {
    const el = nameRef.current;
    if (!el) return;
    el.firstChild.textContent = text;
    el.dataset.len = lenBucket(text);
    el.classList.toggle('is-muted', !!muted);
    if (tone && readoutRef.current) readoutRef.current.style.setProperty('--tone', palette[tone]);
  };

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return undefined;
    const measure = () => setSize(Math.round(el.getBoundingClientRect().width));
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => setFontsTick((t) => t + 1));
    return () => cancelAnimationFrame(rafRef.current);
  }, []);

  useLayoutEffect(() => {
    setRot(rotRef.current);
  }, []);

  useLayoutEffect(() => {
    if (canvasRef.current && size) drawWheel(canvasRef.current, size, items, hi, palette);
  }, [items, hi, size, fontsTick, palette]);

  /* idle readout: whatever sits under the pointer, or the winner */
  useLayoutEffect(() => {
    if (spinRef.current) return;
    if (result && result.mode === mode) { writeName(result.label, result.tone, false); return; }
    if (!n) {
      writeName(mode === 'numbers' ? 'Fix the range' : 'Type or paste names', 'seg3', true);
      return;
    }
    const i = indexAt(rotRef.current, n);
    writeName(items[i].label, toneAt(items, i), false);
  }, [items, result, mode, spinning]);

  /* ---- the spin itself ---- */
  const run = (list, opts) => {
    if (spinRef.current || list.length < 2) return false;
    spinRef.current = true;
    const count = list.length;
    const seg = 360 / count;
    const target = randInt(count);
    const offset = 0.14 + rand01() * 0.72; /* keep clear of the dividers */
    const theta = (target + offset) * seg;
    const dir = opts.dir < 0 ? -1 : 1;
    const power = clamp(opts.power || 1, 0.6, 2);
    const red = reducedRef.current;
    const dur = red ? 480 : opts.durationMs * (0.92 + rand01() * 0.16) * (0.85 + 0.15 * power);
    const turns = red ? 0 : Math.max(2, Math.round((dur / 1000) * 1.3 * power));
    const R0 = rotRef.current;
    const Rf = dir > 0 ? R0 + turns * 360 + mod(-theta - R0, 360) : R0 - turns * 360 - mod(R0 + theta, 360);
    const W = red ? 0 : 7 + 5 * rand01();
    const wu = red ? 0 : 320;
    const Rw = R0 - dir * W;
    const pegA = 360 / pegCount(count);
    let lastIdx = -1;
    let lastPeg = Math.floor(mod(-R0, 360) / pegA);
    let lastTick = 0;
    let prevR = R0;
    let prevT = performance.now();
    const t0 = prevT;
    if (pickRef.current) pickRef.current.classList.remove('settle');

    const step = (now) => {
      const el = now - t0;
      let R;
      if (el < wu) {
        const u = el / wu;
        R = R0 - dir * W * (0.5 - 0.5 * Math.cos(Math.PI * u));
      } else {
        const u = Math.min(1, (el - wu) / dur);
        R = Rw + (Rf - Rw) * SPIN_EASE(u);
      }
      setRot(R);
      const idx = indexAt(R, count);
      const nameEl = nameRef.current;
      if (idx !== lastIdx || (nameEl && nameEl.firstChild && !nameEl.firstChild.textContent)) { lastIdx = idx; writeName(list[idx].label, toneAt(list, idx), false); }
      const dt = Math.max(1, now - prevT);
      const v = ((R - prevR) / dt) * 1000;
      prevR = R; prevT = now;
      const th = mod(-R, 360);
      const peg = Math.floor(th / pegA);
      if (peg !== lastPeg) {
        lastPeg = peg;
        if (opts.sound && now - lastTick > 28) { lastTick = now; Sound.tick(); }
      }
      if (!red && pickRef.current) {
        const f = mod(th, pegA) / pegA;
        const d = Math.min(f, 1 - f) * pegA;
        const zone = Math.min(pegA * 0.42, 7);
        const amt = d < zone ? 1 - d / zone : 0;
        const sp = Math.min(1, Math.abs(v) / 80);
        pickRef.current.style.transform = 'rotate(' + (-Math.sign(v) * amt * sp * 26).toFixed(2) + 'deg)';
      }
      if (el < wu + dur) rafRef.current = requestAnimationFrame(step);
      else finish();
    };
    const finish = () => {
      setRot(mod(Rf, 360));
      const got = indexAt(Rf, count); /* the winner is read from the final angle, never assumed */
      if (got !== target && window.console) console.warn('Pickora: pointer/target mismatch', got, target);
      if (pickRef.current) {
        pickRef.current.style.transform = '';
        if (!red) { pickRef.current.classList.remove('settle'); void pickRef.current.offsetWidth; pickRef.current.classList.add('settle'); }
      }
      writeName(list[got].label, toneAt(list, got), false);
      spinRef.current = false;
      if (opts.sound) Sound.win();
      setSettle((k) => k + 1);
      opts.onDone(got);
    };
    rafRef.current = requestAnimationFrame(step);
    return true;
  };

  useEffect(() => {
    apiRef.current = { run, isSpinning: () => spinRef.current };
  });

  /* ---- drag / flick ---- */
  const angleAt = (e) => {
    const b = wrapRef.current.getBoundingClientRect();
    const x = e.clientX - (b.left + b.width / 2);
    const y = e.clientY - (b.top + b.height / 2);
    return { a: (Math.atan2(x, -y) * 180) / Math.PI, dist: Math.hypot(x, y), radius: b.width / 2 };
  };
  const onPointerDown = (e) => {
    if (spinRef.current || e.button > 0) return;
    if (e.target.closest && e.target.closest('.hub')) return;
    const p = angleAt(e);
    if (p.dist > p.radius) return;
    dragRef.current = { id: e.pointerId, last: p.a, acc: 0, R0: rotRef.current, x: e.clientX, y: e.clientY, moved: false, samples: [{ t: performance.now(), R: rotRef.current }] };
    try { wrapRef.current.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
  };
  const onPointerMove = (e) => {
    const d = dragRef.current;
    if (!d || d.id !== e.pointerId) return;
    const p = angleAt(e);
    let delta = p.a - d.last;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    d.last = p.a;
    if (p.dist < 14) return;
    d.acc += delta;
    if (!d.moved && (Math.abs(d.acc) > 3 || Math.hypot(e.clientX - d.x, e.clientY - d.y) > 10)) {
      d.moved = true;
      onDragStart();
    }
    if (d.moved) {
      setRot(d.R0 + d.acc);
      const list = itemsRef.current;
      if (list.length) { const i = indexAt(rotRef.current, list.length); writeName(list[i].label, toneAt(list, i), false); }
      d.samples.push({ t: performance.now(), R: rotRef.current });
      if (d.samples.length > 10) d.samples.shift();
    }
  };
  const onPointerUp = (e) => {
    const d = dragRef.current;
    if (!d || d.id !== e.pointerId) return;
    dragRef.current = null;
    if (!d.moved) { onSpin({}); return; }
    const now = performance.now();
    const recent = d.samples.filter((s) => now - s.t < 120);
    let v = 0;
    if (recent.length >= 2) {
      const a = recent[0], b = recent[recent.length - 1];
      v = ((b.R - a.R) / Math.max(16, b.t - a.t)) * 1000;
    }
    if (Math.abs(v) > 150) onSpin({ dir: Math.sign(v), power: Math.min(2, Math.abs(v) / 650) });
  };
  const onPointerCancel = () => { dragRef.current = null; };

  const isWinner = !!(result && result.mode === mode && !spinning);
  const canRemove = isWinner && mode !== 'yesno';
  const pendingHere = isWinner && state.pending && state.pending.mode === mode && state.pending.key === result.key;
  const label = spinning ? 'Spinning' : isWinner ? (mode === 'yesno' ? 'The answer' : 'Winner') : n ? 'Under the pointer' : mode === 'numbers' ? 'Range needed' : 'Empty wheel';
  const recent = (state.history[mode] || []).slice(0, 6);
  const spinLabel = spinning ? 'Spinning…' : n === 0 ? (mode === 'numbers' ? 'Fix the range' : 'Add names to spin') : n === 1 ? 'Add one more to spin' : isWinner ? 'Spin again' : 'Spin the wheel';

  return (
    <section className="stage" aria-label="Wheel">
      {mode === 'yesno' && state.yesno.question.trim() ? <p className="question">“{state.yesno.question.trim()}”</p> : null}
      <div ref={readoutRef} className={'readout' + (isWinner ? ' is-winner' : '')}>
        <div className="readout-label">{label}</div>
        <div ref={nameRef} key={isWinner ? 'w' + settle : 'live'} className="readout-name" aria-hidden="true"><span></span></div>
        <div className="readout-bar"></div>
      </div>

      <div
        ref={wrapRef}
        className="wheel-wrap"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerCancel}
      >
        <div className="wheel-shadow"></div>
        <div ref={rotorRef} className="rotor"><canvas ref={canvasRef} role="img" aria-label={n ? 'Wheel with ' + n + ' entries' : 'Empty wheel'}></canvas></div>
        <div className="pick-anchor">
          <svg ref={pickRef} className="pick" viewBox="0 0 40 50" aria-hidden="true">
            <path d="M20 48C11 37 2.5 25 2.5 14.5 2.5 6.7 9.6 2 20 2s17.5 4.7 17.5 12.5C37.5 25 29 37 20 48Z" style={{ fill: 'var(--signal)', stroke: 'var(--ink)' }} strokeWidth="3" />
            <circle cx="20" cy="14" r="4.5" style={{ fill: 'var(--ink)' }} />
          </svg>
        </div>
        <button type="button" className="hub" onClick={() => onSpin({})} disabled={spinning || n < 2} aria-label={spinLabel}>
          SPIN
          {n > 1 ? <small>{n.toLocaleString('en-US')}</small> : null}
        </button>
      </div>

      <div className="controls">
        {mode === 'names' && n === 0 && !spinning ? (
          <button type="button" className="btn-spin" onClick={onLoadExample}>Load example names</button>
        ) : (
          <button type="button" className="btn-spin" onClick={() => onSpin({})} disabled={spinning || n < 2}>
            {spinLabel}
            {!spinning && n > 1 ? <kbd className="pointer-only">Space</kbd> : null}
          </button>
        )}
        {canRemove ? (
          result.removed ? (
            <button type="button" className="btn-stage" onClick={onUndoRemove}><IconUndo /><span className="clip">Put “{result.label}” back</span></button>
          ) : pendingHere ? (
            <button type="button" className="btn-stage" onClick={onKeep}><IconUndo /><span className="clip">Keep “{result.label}” in</span></button>
          ) : (
            <button type="button" className="btn-stage" onClick={onRemove}><IconMinus /><span className="clip">Remove “{result.label}”</span></button>
          )
        ) : null}
      </div>

      <div className="options">
        {mode !== 'yesno' ? (
          <button type="button" role="switch" aria-checked={state.noRepeat} className="switch" onClick={onToggleNoRepeat}>
            <span className="track"></span>No repeats
          </button>
        ) : null}
        <div className="speed" role="group" aria-label="Spin length">
          <span className="speed-label">Spin</span>
          {SPEEDS.map(([k, l]) => (
            <button key={k} type="button" className="chip" aria-pressed={state.speed === k} disabled={spinning} onClick={() => onSpeed(k)}>{l}</button>
          ))}
        </div>
      </div>

      {recent.length ? (
        <div className="recent">
          <span className="recent-label">Recent</span>
          {recent.map((h, i) => <span className="item" key={h.t + '-' + i} title={h.label}>{h.label}</span>)}
        </div>
      ) : null}

      <p className={'hint' + (status ? ' is-alert' : '')} aria-live="polite">
        {status || (pendingHere
          ? '“' + result.label + '” leaves the wheel on the next spin.'
          : n > 60 && !items[0].dial
            ? n.toLocaleString('en-US') + ' entries are too many to label. Watch the name above the wheel.'
            : <>
                <span className="pointer-only">Press Space or click the wheel. Drag it to fling.</span>
                <span className="touch-only">Tap the wheel, or flick it with your finger.</span>
              </>)}
      </p>
    </section>
  );
}

/* ================= stage: teams ================= */

function TeamsStage({ teams, players, count, onMake, onCopy, copied }) {
  const sizes = teamSizes(players, count);
  return (
    <section className="stage" aria-label="Teams">
      <div className="teams-head">
        <h2 className="teams-title">{teams ? teams.groups.length + ' teams' : 'Split into ' + count + ' teams'}</h2>
        <p className="teams-sub">{players < 2 ? 'Add at least two names to make teams.' : players + ' players · sizes ' + sizes.join(' · ')}</p>
      </div>
      {teams ? (
        <div className="board" key={teams.made}>
          {teams.groups.map((g, gi) => {
            const tone = SEG_TONES[gi % 6];
            return (
              <article className="team" key={gi} style={{ '--team': 'var(--seg-' + ((gi % 6) + 1) + ')', '--team-fg': tone === 'seg6' ? 'var(--cloud)' : 'var(--ink)' }}>
                <div className="team-head"><strong>{teamName(gi)}</strong><span>{g.length} {g.length === 1 ? 'player' : 'players'}</span></div>
                <ol>{g.map((p, pi) => <li key={pi} style={{ animationDelay: Math.min(1200, (pi * teams.groups.length + gi) * 45) + 'ms' }}>{p}</li>)}</ol>
              </article>
            );
          })}
        </div>
      ) : (
        <div className="board-empty">Your teams will appear here. Names are dealt at random, and team sizes never differ by more than one.</div>
      )}
      <div className="controls">
        <button type="button" className="btn-spin" onClick={onMake} disabled={players < 2}>
          {teams ? 'Shuffle teams again' : 'Make teams'}
          {players >= 2 ? <kbd className="pointer-only">Space</kbd> : null}
        </button>
        {teams ? <button type="button" className="btn-stage" onClick={onCopy}><IconCopy />{copied || 'Copy teams'}</button> : null}
      </div>
    </section>
  );
}
const teamName = (i) => 'Team ' + (i < TEAM_NAMES.length ? TEAM_NAMES[i] : i + 1);
function teamSizes(players, count) {
  if (players < 1) return [];
  const k = clamp(count, 1, players);
  const base = Math.floor(players / k), extra = players % k;
  return Array.from({ length: k }, (_, i) => base + (i < extra ? 1 : 0));
}

/* ================= panel: names editor ================= */

function NamesEditor({ names, isSample, pendingKey, toneMap, update, onReset, title, extra }) {
  const [bulk, setBulk] = useState(false);
  const [bulkText, setBulkText] = useState('');
  const [menu, setMenu] = useState(false);
  const [confirm, setConfirm] = useState(null);
  const [note, setNote] = useState('');
  const inputs = useRef(new Map());
  const focusReq = useRef(null);
  const menuRef = useRef(null);

  const active = names.filter((n) => !n.out);
  const filled = active.filter((n) => n.text.trim());
  const picked = names.filter((n) => n.out).sort((a, b) => (b.pickedAt || 0) - (a.pickedAt || 0));
  const dupes = useMemo(() => {
    const seen = new Set();
    let d = 0;
    filled.forEach((n) => { const k = n.text.trim().toLocaleLowerCase(); if (seen.has(k)) d++; else seen.add(k); });
    return d;
  }, [names]);

  useLayoutEffect(() => {
    const r = focusReq.current;
    if (!r) return;
    focusReq.current = null;
    const el = inputs.current.get(r.id);
    if (!el) return;
    el.focus();
    const p = r.pos === 'end' ? el.value.length : r.pos === 'start' ? 0 : r.pos;
    try { el.setSelectionRange(p, p); } catch (e) { /* ignore */ }
  });

  useEffect(() => {
    if (!menu) return undefined;
    const close = (e) => { if (menuRef.current && !menuRef.current.contains(e.target)) setMenu(false); };
    const esc = (e) => { if (e.key === 'Escape') setMenu(false); };
    document.addEventListener('pointerdown', close);
    document.addEventListener('keydown', esc);
    return () => { document.removeEventListener('pointerdown', close); document.removeEventListener('keydown', esc); };
  }, [menu]);

  useEffect(() => {
    if (!note) return undefined;
    const t = setTimeout(() => setNote(''), 3200);
    return () => clearTimeout(t);
  }, [note]);

  const focusRow = (id, pos) => { focusReq.current = { id, pos }; };
  const activeIdOffset = (id, delta) => {
    const i = active.findIndex((n) => n.id === id);
    const j = i + delta;
    return j >= 0 && j < active.length ? active[j].id : null;
  };

  const change = (id, text) => update((ns) => ns.map((n) => (n.id === id ? { ...n, text } : n)));

  const onKeyDown = (e, id) => {
    const el = e.currentTarget;
    if (e.key === 'Enter') {
      e.preventDefault();
      const caret = el.selectionStart == null ? el.value.length : el.selectionStart;
      const end = el.selectionEnd == null ? caret : el.selectionEnd;
      const before = el.value.slice(0, caret), after = el.value.slice(end);
      const nx = activeIdOffset(id, 1);
      const focusNow = (target) => { const t = inputs.current.get(target); if (t) t.focus(); };
      if (!el.value.trim()) { if (nx) focusNow(nx); return; }
      const nextRow = nx && active.find((n) => n.id === nx);
      if (!after && nextRow && nextRow.text === '') { focusNow(nx); return; }
      const newId = uid();
      update((ns) => {
        const i = ns.findIndex((n) => n.id === id);
        const copy = ns.slice();
        copy[i] = { ...copy[i], text: before };
        copy.splice(i + 1, 0, { id: newId, text: after, out: false });
        return copy;
      });
      focusRow(newId, 'start');
    } else if (e.key === 'Backspace' && el.value === '') {
      const prev = activeIdOffset(id, -1);
      const nx = activeIdOffset(id, 1);
      if (!prev && !nx) return;
      e.preventDefault();
      update((ns) => ns.filter((n) => n.id !== id));
      focusRow(prev || nx, prev ? 'end' : 'start');
    } else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      const target = activeIdOffset(id, e.key === 'ArrowDown' ? 1 : -1);
      if (target) {
        e.preventDefault();
        const t = inputs.current.get(target);
        if (t) { t.focus(); const p = Math.min(el.selectionStart || 0, t.value.length); try { t.setSelectionRange(p, p); } catch (err) { /* ignore */ } }
      }
    }
  };

  const onPaste = (e, id) => {
    const text = (e.clipboardData && e.clipboardData.getData('text')) || '';
    if (!/[\r\n]/.test(text)) return;
    e.preventDefault();
    const el = e.currentTarget;
    const lines = text.split(/\r\n|\r|\n/).map((l) => l.replace(/\t+/g, ' ').trim()).filter(Boolean);
    if (!lines.length) return;
    const before = el.value.slice(0, el.selectionStart || 0);
    const after = el.value.slice(el.selectionEnd || 0);
    lines[0] = before + lines[0];
    lines[lines.length - 1] = lines[lines.length - 1] + after;
    const room = MAX_ENTRIES - filled.filter((n) => n.id !== id).length;
    const take = lines.slice(0, Math.max(0, room));
    if (take.length < lines.length) setNote('Only the first ' + MAX_ENTRIES.toLocaleString('en-US') + ' entries fit. ' + (lines.length - take.length) + ' lines were skipped.');
    else if (take.length > 1) setNote('Added ' + take.length + ' entries.');
    if (!take.length) return;
    const ids = take.map((_, k) => (k === 0 ? id : uid()));
    update((ns) => {
      const i = ns.findIndex((n) => n.id === id);
      if (i < 0) return ns;
      const rows = take.map((t, k) => (k === 0 ? { ...ns[i], text: t } : { id: ids[k], text: t, out: false }));
      const copy = ns.slice();
      copy.splice(i, 1, ...rows);
      return copy;
    });
    focusRow(ids[ids.length - 1], 'end');
  };

  const onBlur = (id) => {
    const i = active.findIndex((n) => n.id === id);
    const row = active[i];
    if (row && row.text === '' && i < active.length - 1) update((ns) => ns.filter((n) => n.id !== id));
  };

  const remove = (id) => {
    const nx = activeIdOffset(id, 1) || activeIdOffset(id, -1);
    update((ns) => ns.filter((n) => n.id !== id));
    if (nx) focusRow(nx, 'end');
  };

  const enterBulk = () => {
    setBulkText(filled.map((n) => n.text).join('\n'));
    setBulk(true);
  };
  const onBulk = (v) => {
    setBulkText(v);
    const lines = v.split(/\r\n|\r|\n/).map((l) => l.trim()).filter(Boolean).slice(0, MAX_ENTRIES);
    update((ns) => {
      const old = ns.filter((n) => !n.out && n.text.trim());
      const act = lines.map((t, i) => ({ id: old[i] ? old[i].id : uid(), text: t, out: false }));
      return [...act, ...ns.filter((n) => n.out)];
    });
  };

  const shuffleList = () => {
    update((ns) => [...shuffled(ns.filter((n) => !n.out && n.text.trim())), ...ns.filter((n) => n.out)]);
    if (bulk) setBulk(false);
    setNote('Shuffled.');
  };
  const sortList = () => {
    const coll = new Intl.Collator(undefined, { sensitivity: 'base', numeric: true });
    update((ns) => [...ns.filter((n) => !n.out && n.text.trim()).sort((a, b) => coll.compare(a.text.trim(), b.text.trim())), ...ns.filter((n) => n.out)]);
    if (bulk) setBulk(false);
    setNote('Sorted A to Z.');
  };
  const dedupe = () => {
    const seen = new Set();
    update((ns) => ns.filter((n) => {
      if (n.out || !n.text.trim()) return true;
      const k = n.text.trim().toLocaleLowerCase();
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    }));
    setMenu(false);
    setNote('Removed ' + dupes + (dupes === 1 ? ' duplicate.' : ' duplicates.'));
  };
  const doConfirm = () => {
    if (confirm === 'clear') { update(() => []); setBulk(false); setNote('List cleared.'); }
    if (confirm === 'reset') { onReset(); setBulk(false); setNote('Example list restored.'); }
    setConfirm(null);
  };
  const returnAll = () => update((ns) => ns.map((n) => (n.out ? { ...n, out: false, pickedAt: undefined } : n)));
  const returnOne = (id) => update((ns) => ns.map((n) => (n.id === id ? { ...n, out: false, pickedAt: undefined } : n)));

  return (
    <>
      <div className="panel-inner">
        <div className="panel-head">
          <h2 className="panel-title">{title}</h2>
          <span className="count">{filled.length.toLocaleString('en-US')} on the wheel</span>
        </div>
        {isSample ? <p className="sample-note"><b>Example list.</b> Type over it or paste your own, one per line.</p> : null}
        {extra}
        <div className="toolbar">
          <button type="button" className="tool" aria-pressed={!bulk} onClick={() => setBulk(false)}><IconList />Rows</button>
          <button type="button" className="tool" aria-pressed={bulk} onClick={() => (bulk ? setBulk(false) : enterBulk())}><IconPaste />Paste list</button>
          <button type="button" className="tool" onClick={shuffleList} disabled={filled.length < 2}><IconShuffle />Shuffle</button>
          <button type="button" className="tool" onClick={sortList} disabled={filled.length < 2}><IconSort />A–Z</button>
          <div ref={menuRef} style={{ position: 'relative' }}>
            <button type="button" className="tool" aria-haspopup="menu" aria-expanded={menu} aria-label="More list actions" onClick={() => setMenu((m) => !m)}><IconMore /></button>
            {menu ? (
              <div className="menu" role="menu">
                <button type="button" role="menuitem" onClick={dedupe} disabled={!dupes}>Remove duplicates{dupes ? ' (' + dupes + ')' : ''}</button>
                <button type="button" role="menuitem" onClick={() => { setMenu(false); setConfirm('clear'); }} disabled={!filled.length && !picked.length}>Clear the list</button>
                <button type="button" role="menuitem" className="danger" onClick={() => { setMenu(false); setConfirm('reset'); }}>Reset to example</button>
              </div>
            ) : null}
          </div>
        </div>
        {confirm ? (
          <div className="confirm" role="alertdialog" aria-label="Confirm">
            <p>{confirm === 'clear' ? 'Remove every name from the list?' : 'Replace your list with the example names?'}</p>
            <button type="button" className="go" onClick={doConfirm} autoFocus>{confirm === 'clear' ? 'Clear' : 'Reset'}</button>
            <button type="button" onClick={() => setConfirm(null)}>Cancel</button>
          </div>
        ) : null}

        {bulk ? (
          <>
            <label className="sr-only" htmlFor="bulk-list">Names, one per line</label>
            <textarea id="bulk-list" className="bulk" value={bulkText} onChange={(e) => onBulk(e.target.value)} placeholder={'Olena\nMarcus\nSofia'} spellCheck={false} autoFocus></textarea>
            <p className="bulk-note">One entry per line. The wheel updates as you type. Empty lines are ignored.</p>
          </>
        ) : (
          <ul className="rows">
            {active.map((n, i) => {
              const tone = toneMap.get(n.id);
              const isEmpty = !n.text.trim();
              const pending = pendingKey === n.id;
              const last = i === active.length - 1;
              return (
                <li key={n.id} className={'row' + (isEmpty ? ' is-empty' : '') + (pending ? ' is-pending' : '')} style={tone ? { '--sw': 'var(--' + tone.replace('seg', 'seg-') + ')' } : undefined}>
                  <span className="swatch" aria-hidden="true"></span>
                  <input
                    id={'entry-' + n.id}
                    ref={(el) => { if (el) inputs.current.set(n.id, el); else inputs.current.delete(n.id); }}
                    value={n.text}
                    placeholder={last ? (active.length === 1 ? 'Type a name and press Enter' : 'Add another…') : ''}
                    aria-label={last && isEmpty ? 'New entry' : 'Entry ' + (i + 1)}
                    autoComplete="off"
                    autoCapitalize="words"
                    spellCheck={false}
                    enterKeyHint="next"
                    maxLength={120}
                    onChange={(e) => change(n.id, e.target.value)}
                    onKeyDown={(e) => onKeyDown(e, n.id)}
                    onPaste={(e) => onPaste(e, n.id)}
                    onBlur={() => onBlur(n.id)}
                  />
                  {!(last && isEmpty) ? (
                    <button type="button" className="del" aria-label={'Delete ' + (n.text.trim() || 'empty row')} onClick={() => remove(n.id)}><IconX /></button>
                  ) : <span></span>}
                  {pending ? <span className="flag">Leaves on next spin</span> : null}
                </li>
              );
            })}
          </ul>
        )}

        {picked.length ? (
          <div className="picked">
            <div className="picked-head">
              <h3>Picked · {picked.length}</h3>
              <button type="button" className="linkish" onClick={returnAll}>Return all</button>
            </div>
            <ul>
              {picked.map((n) => (
                <li key={n.id}><span title={n.text}>{n.text.trim()}</span><button type="button" onClick={() => returnOne(n.id)} aria-label={'Return ' + n.text.trim() + ' to the wheel'}>Return</button></li>
              ))}
            </ul>
          </div>
        ) : null}
      </div>
      <PanelFoot note={note || (dupes ? dupes + (dupes === 1 ? ' duplicate in the list' : ' duplicates in the list') : '')} />
    </>
  );
}

const SaveCtx = React.createContext('saved');
function PanelFoot({ note }) {
  const saved = React.useContext(SaveCtx);
  return (
    <div className="panel-foot">
      <span className={'saved' + (saved === 'saved' ? '' : ' is-off')}>{saved === 'saved' ? 'Saved on this device' : 'Not saved: storage is blocked'}</span>
      <span aria-live="polite">{note}</span>
    </div>
  );
}

/* ================= panel: yes / no ================= */

function YesNoPanel({ state, setState, palette }) {
  const tally = { yes: 0, no: 0, maybe: 0 };
  state.history.yesno.forEach((h) => { if (tally[h.kind] != null) tally[h.kind]++; });
  const kinds = state.yesno.maybe ? ['yes', 'no', 'maybe'] : ['yes', 'no'];
  return (
    <>
      <div className="panel-inner">
        <div className="panel-head"><h2 className="panel-title">Ask the wheel</h2></div>
        <div className="field">
          <label htmlFor="yn-question">Your question</label>
          <input id="yn-question" className="text-in" value={state.yesno.question} maxLength={140} placeholder="Should we order pizza tonight?" autoComplete="off"
            onChange={(e) => setState((s) => ({ ...s, yesno: { ...s.yesno, question: e.target.value } }))} />
        </div>
        <div className="field">
          <button type="button" role="switch" aria-checked={state.yesno.maybe} className="switch" onClick={() => setState((s) => ({ ...s, yesno: { ...s.yesno, maybe: !s.yesno.maybe } }))}>
            <span className="track"></span>Add “Maybe”
          </button>
        </div>
        <div className="field">
          <span className="label">Tally</span>
          <div className="tally">
            {kinds.map((k) => (
              <div key={k}><strong>{tally[k]}</strong><span><i style={{ '--c': palette[YN[k].tone] }}></i>{YN[k].label}</span></div>
            ))}
          </div>
          <div>
            <button type="button" className="linkish" disabled={!state.history.yesno.length} onClick={() => setState((s) => ({ ...s, history: { ...s.history, yesno: [] } }))}>Clear tally</button>
          </div>
        </div>
      </div>
      <PanelFoot note="Each answer has the same chance." />
    </>
  );
}

/* ================= panel: numbers ================= */

function NumbersPanel({ state, setState }) {
  const r = parseRange(state.numbers);
  const set = (patch) => setState((s) => ({ ...s, numbers: { ...s.numbers, ...patch } }));
  const drawn = state.numbers.drawn;
  const remaining = r.ok ? r.to - r.from + 1 - drawn.filter((v) => v >= r.from && v <= r.to).length : 0;
  const presets = [['1', '6', 'Dice 1–6'], ['1', '10', '1–10'], ['1', '100', '1–100'], ['1', '1000', '1–1000']];
  return (
    <>
      <div className="panel-inner">
        <div className="panel-head">
          <h2 className="panel-title">Number range</h2>
          <span className="count">{r.ok ? remaining.toLocaleString('en-US') + ' on the wheel' : ''}</span>
        </div>
        <div className="range-row">
          <div className="field">
            <label htmlFor="num-from">From</label>
            <input id="num-from" className="text-in" inputMode="numeric" value={state.numbers.from} aria-invalid={!r.ok} onChange={(e) => set({ from: e.target.value.replace(/[^\d-]/g, ''), drawn: [] })} />
          </div>
          <span className="dash">to</span>
          <div className="field">
            <label htmlFor="num-to">To</label>
            <input id="num-to" className="text-in" inputMode="numeric" value={state.numbers.to} aria-invalid={!r.ok} onChange={(e) => set({ to: e.target.value.replace(/[^\d-]/g, ''), drawn: [] })} />
          </div>
        </div>
        {!r.ok ? <p className="error" role="alert">{r.error}</p> : null}
        <div className="presets">
          {presets.map(([f, t, l]) => (
            <button key={l} type="button" className="tool" aria-pressed={String(state.numbers.from) === f && String(state.numbers.to) === t} onClick={() => set({ from: f, to: t, drawn: [] })}>{l}</button>
          ))}
        </div>
        <div className="field">
          <div className="picked-head">
            <span className="label">Drawn · {drawn.length}</span>
            <button type="button" className="linkish" disabled={!drawn.length} onClick={() => set({ drawn: [] })}>Return all</button>
          </div>
          {drawn.length ? (
            <div className="drawn">{drawn.slice().reverse().map((v) => <span key={v}>{v}</span>)}</div>
          ) : (
            <p className="sample-note">Turn on “No repeats” under the wheel to draw each number once, like a raffle.</p>
          )}
        </div>
      </div>
      <PanelFoot note="" />
    </>
  );
}

/* ================= app ================= */

function App() {
  const [state, setState] = useState(loadState);
  const [result, setResult] = useState(null);
  const [spinning, setSpinning] = useState(false);
  const [spinItems, setSpinItems] = useState(null);
  const [status, setStatus] = useState('');
  const [announce, setAnnounce] = useState('');
  const [focusMode, setFocusMode] = useState(false);
  const [teams, setTeams] = useState(null);
  const [copied, setCopied] = useState('');
  const [saved, setSaved] = useState('saved');
  const reduced = useReducedMotion();
  const stageApi = useRef(null);
  const stateRef = useRef(state);
  stateRef.current = state;
  const palette = useMemo(readPalette, []);

  const liveItems = useMemo(() => getItems(state), [state.mode, state.names, state.yesno, state.numbers]);
  const items = spinItems || liveItems;

  const toneMap = useMemo(() => {
    const m = new Map();
    if (state.mode === 'names' || state.mode === 'teams') {
      const it = nameItems(state.names);
      it.forEach((x, i) => m.set(x.key, toneAt(it, i)));
    }
    return m;
  }, [state.names, state.mode]);

  /* persist */
  useEffect(() => {
    const t = setTimeout(() => {
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
        setSaved('saved');
      } catch (e) {
        setSaved('off');
      }
    }, 250);
    return () => clearTimeout(t);
  }, [state]);

  useEffect(() => {
    if (!status) return undefined;
    const t = setTimeout(() => setStatus(''), 3500);
    return () => clearTimeout(t);
  }, [status]);

  /* a winner that was edited or deleted from the list stops being shown as the winner */
  useEffect(() => {
    if (result && !result.removed && !spinning && result.mode === state.mode && !liveItems.some((i) => i.key === result.key)) setResult(null);
  }, [liveItems]);

  const updateNames = useCallback((fn) => {
    setState((s) => ({ ...s, names: withTrailing(fn(s.names)), isSample: false }));
  }, []);

  const spin = useCallback((opts) => {
    const api = stageApi.current;
    if (!api || api.isSpinning()) return;
    let s = stateRef.current;
    if (s.mode === 'teams') return;
    if (s.pending) s = applyPending(s);
    const list = getItems(s);
    if (list.length < 2) {
      setState(s);
      setStatus(s.mode === 'numbers' ? 'Set a valid range first.' : list.length === 1 ? 'Add one more entry to spin.' : 'Add at least two entries to spin.');
      return;
    }
    if (s.sound) Sound.unlock();
    const mode = s.mode;
    const started = api.run(list, {
      dir: opts && opts.dir,
      power: opts && opts.power,
      durationMs: DURATIONS[s.speed],
      sound: s.sound,
      onDone: (index) => {
        const it = list[index];
        const tone = toneAt(list, index);
        setSpinning(false);
        setSpinItems(null);
        setResult({ mode, key: it.key, label: it.label, tone, index, sig: sigOf(list), removed: false });
        setAnnounce((mode === 'yesno' ? 'The answer is ' : 'The winner is ') + it.label);
        setState((prev) => {
          const entry = { label: it.label, t: Date.now() };
          if (it.kind) entry.kind = it.kind;
          const next = { ...prev, history: { ...prev.history, [mode]: [entry, ...(prev.history[mode] || [])].slice(0, 30) } };
          if (prev.noRepeat && mode !== 'yesno') next.pending = { mode, key: it.key };
          return next;
        });
      },
    });
    if (started) {
      setState(s);
      setSpinItems(list);
      setSpinning(true);
      setResult(null);
      setStatus('');
      setAnnounce('Spinning');
    }
  }, []);

  const makeTeams = useCallback(() => {
    const s = stateRef.current;
    const players = nameItems(s.names).map((x) => x.label);
    if (players.length < 2) { setStatus('Add at least two names to make teams.'); return; }
    const k = clamp(s.teams.count, 2, players.length);
    const order = shuffled(players);
    const groups = Array.from({ length: k }, () => []);
    order.forEach((p, i) => groups[i % k].push(p));
    setTeams({ groups: shuffled(groups).sort((a, b) => b.length - a.length), made: Date.now() });
    setCopied('');
    setAnnounce(k + ' teams made');
  }, []);

  const copyTeams = () => {
    if (!teams) return;
    const text = teams.groups.map((g, i) => teamName(i) + ': ' + g.join(', ')).join('\n');
    const done = () => setCopied('Copied');
    const fail = () => setCopied('Copy blocked. Select the names instead.');
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fail);
      else fail();
    } catch (e) { fail(); }
  };

  /* keyboard: Space / Enter spin unless the person is typing or on a control */
  useEffect(() => {
    const onKey = (e) => {
      const t = e.target;
      if (e.key === 'Escape' && focusMode) { setFocusMode(false); return; }
      if (e.key !== ' ' && e.key !== 'Enter') return;
      if (e.metaKey || e.ctrlKey || e.altKey || e.repeat) return;
      if (t && t.closest && t.closest('input, textarea, select, button, a, [contenteditable="true"], [role="menu"]')) return;
      e.preventDefault();
      if (stateRef.current.mode === 'teams') makeTeams(); else spin({});
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [spin, makeTeams, focusMode]);

  const setMode = (m) => {
    if (spinning) return;
    setResult(null);
    setStatus('');
    setState((s) => ({ ...s, mode: m }));
  };

  const removeWinner = () => {
    if (!result) return;
    setState((s) => {
      const base = s.pending && s.pending.key === result.key ? { ...s, pending: null } : s;
      return removeKey(base, result.mode, result.key);
    });
    setResult((r) => ({ ...r, removed: true }));
  };
  const undoRemove = () => {
    if (!result) return;
    setState((s) => restoreKey(s, result.mode, result.key));
    setResult((r) => ({ ...r, removed: false }));
  };
  const keepWinner = () => setState((s) => ({ ...s, pending: null }));
  const resetExample = () => {
    const d = defaultState();
    setResult(null);
    setState((s) => ({ ...s, names: d.names, isSample: true, pending: null }));
  };

  const mode = state.mode;
  const playerCount = nameItems(state.names).length;
  const teamCount = clamp(state.teams.count, 2, Math.max(2, Math.min(20, playerCount)));

  const teamExtra = (
    <div className="field" style={{ marginBottom: 6 }}>
      <span className="label" id="team-count-label">Number of teams</span>
      <div className="stepper" role="group" aria-labelledby="team-count-label">
        <button type="button" aria-label="Fewer teams" disabled={teamCount <= 2} onClick={() => setState((s) => ({ ...s, teams: { count: Math.max(2, teamCount - 1) } }))}>−</button>
        <output aria-live="polite">{teamCount}</output>
        <button type="button" aria-label="More teams" disabled={teamCount >= Math.min(20, playerCount)} onClick={() => setState((s) => ({ ...s, teams: { count: teamCount + 1 } }))}>+</button>
      </div>
      <p className="sizes">{playerCount >= 2 ? 'Sizes: ' + teamSizes(playerCount, teamCount).join(' · ') : 'Add players to see team sizes.'}</p>
    </div>
  );

  return (
    <SaveCtx.Provider value={saved}>
      <div className={'app' + (focusMode ? ' is-focus' : '')}>
        <div className="frame">
          <header className="topbar">
            <div className="brand"><PickMark />Pickora</div>
            <div className="modes" role="tablist" aria-label="Picker type">
              {MODES.map(([k, l]) => (
                <button key={k} type="button" role="tab" aria-selected={mode === k} disabled={spinning && mode !== k} onClick={() => setMode(k)}>{l}</button>
              ))}
            </div>
            <div className="top-actions">
              <button type="button" className="icon-btn" aria-pressed={state.sound} aria-label={state.sound ? 'Sound on' : 'Sound off'} title={state.sound ? 'Sound on' : 'Sound off'} onClick={() => setState((s) => ({ ...s, sound: !s.sound }))}>
                {state.sound ? <IconSound /> : <IconMute />}
              </button>
              <button type="button" className="icon-btn" aria-pressed={focusMode} aria-label="Big screen" title="Big screen (Esc to exit)" onClick={() => setFocusMode((f) => !f)}><IconExpand /></button>
            </div>
          </header>

          <main className="layout">
            {mode === 'teams' ? (
              <TeamsStage teams={teams} players={playerCount} count={teamCount} onMake={makeTeams} onCopy={copyTeams} copied={copied} />
            ) : (
              <WheelStage
                apiRef={stageApi}
                items={items}
                mode={mode}
                result={result}
                spinning={spinning}
                reduced={reduced}
                state={state}
                status={status}
                onSpin={spin}
                onDragStart={() => setResult(null)}
                onRemove={removeWinner}
                onKeep={keepWinner}
                onUndoRemove={undoRemove}
                onToggleNoRepeat={() => setState((s) => ({ ...s, noRepeat: !s.noRepeat, pending: s.noRepeat ? null : s.pending }))}
                onSpeed={(k) => setState((s) => ({ ...s, speed: k }))}
                onLoadExample={resetExample}
              />
            )}

            <div className="ad-banner ad-wrap" aria-label="Advertisement">
              <span className="ad-tag">Advertisement</span>
              <div className="ad">Ad slot · 320 × 100</div>
            </div>

            <aside className="side">
              <section className="panel" aria-label="List">
                <fieldset disabled={spinning}>
                  {mode === 'yesno' ? (
                    <YesNoPanel state={state} setState={setState} palette={palette} />
                  ) : mode === 'numbers' ? (
                    <NumbersPanel state={state} setState={setState} />
                  ) : (
                    <NamesEditor
                      names={state.names}
                      isSample={state.isSample}
                      pendingKey={state.pending && state.pending.mode === 'names' ? state.pending.key : null}
                      toneMap={toneMap}
                      update={updateNames}
                      onReset={resetExample}
                      title={mode === 'teams' ? 'Players' : 'Entries'}
                      extra={mode === 'teams' ? teamExtra : null}
                    />
                  )}
                </fieldset>
              </section>
              <div className="ad-wrap ad-rect-wrap" aria-label="Advertisement">
                <span className="ad-tag">Advertisement</span>
                <div className="ad ad-rect">Ad slot · 300 × 250</div>
              </div>
            </aside>
          </main>

          <footer className="foot">
            <p>Pickora runs in your browser. Your lists stay on this device.</p>
            <p>Results use your browser’s secure random generator.</p>
          </footer>
        </div>
        <div className="sr-only" aria-live="assertive">{announce}</div>
      </div>
    </SaveCtx.Provider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
