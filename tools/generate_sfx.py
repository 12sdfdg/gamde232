"""Procedural casual-game SFX pack generator (v2).

Sound design is modelled on a reference pack: layered, bright, punchy
mobile-game sounds (sub impacts, square-wave trills, tremolo chimes,
party horn, crowd cheer, cash register).

Usage: python3 tools/generate_sfx.py [output_dir]
Writes 44.1 kHz / 16-bit stereo WAV (plus OGG and MP3 if ffmpeg exists).
"""
import os
import shutil
import subprocess
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
RNG = np.random.default_rng(7)


# ------------------------------------------------------------------ basics
def n_of(d):
    return int(round(d * SR))


def tt(d):
    return np.arange(n_of(d)) / SR


def hz(name):
    steps = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    return 440.0 * 2 ** ((steps[name[:-1]] + (int(name[-1]) - 4) * 12) / 12)


def track(f, d):
    """Constant or per-sample frequency -> array."""
    return np.broadcast_to(np.asarray(f, float), (n_of(d),)).copy()


def glide(f0, f1, d, curve="exp"):
    x = np.linspace(0, 1, n_of(d))
    return f0 * (f1 / f0) ** x if curve == "exp" else f0 + (f1 - f0) * x


def additive(f, d, amps, phase_rand=True):
    """Sum of harmonics k*f with amplitudes amps[k-1] (band-limited)."""
    f = track(f, d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros_like(ph)
    for k, a in enumerate(amps, 1):
        if a == 0:
            continue
        mask = (k * f < SR / 2 - 1000).astype(float)
        p0 = RNG.uniform(0, 2 * np.pi) if phase_rand else 0
        out += a * mask * np.sin(k * ph + p0)
    return out


def sine(f, d):
    return additive(f, d, [1.0], phase_rand=False)


def square(f, d, n=15):
    return additive(f, d, [1 / k if k % 2 else 0 for k in range(1, n + 1)], False)


def saw(f, d, n=30):
    return additive(f, d, [1 / k for k in range(1, n + 1)], False)


def tri(f, d):
    return additive(f, d, [((-1) ** ((k - 1) // 2)) / k ** 2 if k % 2 else 0 for k in range(1, 12)], False)


def noise(d):
    return RNG.standard_normal(n_of(d)) * 0.4


def perc(d, a=0.002, decay=0.1):
    """Linear attack, exponential decay with time constant `decay` (s)."""
    t = tt(d)
    e = np.exp(-t / decay)
    na = max(1, n_of(a))
    e[:na] *= np.linspace(0, 1, na)
    return e


def adsr(d, a=0.01, dc=0.05, s=0.7, r=0.1):
    n = n_of(d)
    na, nd, nr = n_of(a), n_of(dc), n_of(r)
    ns = max(0, n - na - nd - nr)
    e = np.concatenate([np.linspace(0, 1, na, endpoint=False), np.linspace(1, s, nd, endpoint=False),
                        np.full(ns, s), np.linspace(s, 0, nr)])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def _sos(kind, f, order=2):
    nyq = SR / 2 - 200
    if kind == "band":
        f = [max(20, f[0]), min(nyq, f[1])]
    else:
        f = min(nyq, max(20, f))
    return butter(order, f, kind, fs=SR, output="sos")


def lp(x, f, o=2):
    return sosfilt(_sos("low", f, o), x)


def hp(x, f, o=2):
    return sosfilt(_sos("high", f, o), x)


def bp(x, lo, hi, o=2):
    return sosfilt(_sos("band", (lo, hi), o), x)


def moving_filter(x, f0, f1, kind="low", blocks=48):
    n = len(x)
    out = np.zeros(n)
    hop = max(1, n // blocks)
    win = np.hanning(hop * 2)
    for i in range(0, n, hop):
        a = max(0, i - hop // 2)
        seg = x[a:a + hop * 2]
        fc = f0 * (f1 / f0) ** (i / max(1, n))
        y = (lp if kind == "low" else hp)(seg, fc)
        out[a:a + len(seg)] += y * win[:len(seg)]
    return out


def place(total, *parts):
    """parts: (time, signal, gain[, pan]) -> stereo (2, N). pan -1..1."""
    out = np.zeros((2, n_of(total)))
    for p in parts:
        t0, sig, g = p[:3]
        pan = p[3] if len(p) > 3 else 0.0
        i = n_of(t0)
        if i >= out.shape[1]:
            continue
        seg = sig[: out.shape[1] - i] * g
        if seg.ndim == 2:
            out[:, i:i + seg.shape[1]] += seg
        else:
            ang = (pan + 1) * np.pi / 4
            out[0, i:i + len(seg)] += seg * np.cos(ang) * 1.414
            out[1, i:i + len(seg)] += seg * np.sin(ang) * 1.414
    return out


def reverb(st, size=1.0, wet=0.2, bright=7000, predelay=0.012):
    """Stereo noise-IR reverb (decorrelated L/R)."""
    n = st.shape[1]
    t = tt(size)
    outs = []
    for ch in range(2):
        ir = RNG.standard_normal(len(t)) * np.exp(-t * 6.9 / size)
        ir = lp(ir, bright)
        ir = np.concatenate([np.zeros(n_of(predelay)), ir])
        ir /= np.sqrt(np.sum(ir ** 2))
        src = st[ch] if st.ndim == 2 else st
        outs.append(fftconvolve(src, ir)[: n + len(ir)])
    w = np.array(outs)
    dry = np.zeros_like(w)
    dry[:, :n] = st if st.ndim == 2 else st[None, :]
    return dry + w * wet


def echo(st, delay=0.09, fb=0.35, repeats=4, pingpong=True):
    n = st.shape[1]
    out = np.zeros((2, n + n_of(delay * repeats)))
    out[:, :n] += st
    for r in range(1, repeats + 1):
        i = n_of(delay * r)
        g = fb ** r
        src = st[::-1] if (pingpong and r % 2) else st
        out[:, i:i + n] += src * g
    return out


def master(st, peak_db=-0.8, drive=1.6, tail_db=-60, fade=0.015, trim=True):
    st = st - st.mean(axis=1, keepdims=True)
    st /= np.max(np.abs(st)) + 1e-9
    st = np.tanh(st * drive) / np.tanh(drive)  # gentle saturation for loudness
    if trim:
        mono = np.max(np.abs(st), axis=0)
        idx = np.where(mono > 10 ** (tail_db / 20))[0]
        if len(idx):
            st = st[:, : idx[-1] + 1]
    nf = min(n_of(fade), st.shape[1] // 4)
    if nf:
        st[:, -nf:] *= np.linspace(1, 0, nf)
    return st / (np.max(np.abs(st)) + 1e-9) * 10 ** (peak_db / 20)


# ------------------------------------------------------------------ layers
def sub_boom(d=0.5, f0=110, f1=38, decay=0.18):
    return sine(glide(f0, f1, d), d) * perc(d, 0.001, decay)


def thump(d=0.15, f0=260, f1=90, decay=0.04):
    return sine(glide(f0, f1, d), d) * perc(d, 0.0005, decay)


def snap(d=0.03, lo=2000, hi=12000, decay=0.006):
    return bp(noise(d), lo, hi) * perc(d, 0.0003, decay)


def pluck_pop(d=0.12, f0=1150, f1=680, decay=0.035):
    """Round 'bloop' (reference Enter attack: 1.1k -> 700 Hz + sub octave)."""
    return (sine(glide(f0, f1, 0.05).tolist() + [f1] * (n_of(d) - n_of(0.05)), d) * perc(d, 0.001, decay)
            + 0.5 * sine(f1 / 2, d) * perc(d, 0.001, decay * 1.4))


def bell(f, d, decay=0.3, partials=((1, 1, 1), (2.0, 0.35, 0.6), (2.76, 0.25, 0.4), (5.4, 0.12, 0.25),
                                     (8.93, 0.05, 0.15))):
    t = tt(d)
    out = np.zeros_like(t)
    for r, a, k in partials:
        if f * r < SR / 2 - 500:
            out += a * np.sin(2 * np.pi * f * r * t + RNG.uniform(0, 6.28)) * np.exp(-t / (decay * k))
    na = n_of(0.001)
    out[:na] *= np.linspace(0, 1, na)
    return out


def coin(f=None, d=0.35):
    f = f or RNG.uniform(3000, 5200)
    return bell(f, d, RNG.uniform(0.05, 0.12), ((1, 1, 1), (1.53, 0.6, 0.7), (2.41, 0.4, 0.5),
                                                  (3.2, 0.25, 0.3))) + 0.4 * np.pad(snap(0.01, 5000, 14000, 0.002), (0, n_of(d) - n_of(0.01)))


def sparkles(total, count=30, lo=2500, hi=9000, decay=0.5, length=0.04, density_decay=None):
    """Random short shiny blips spread across `total`, returned as stereo."""
    parts = []
    for _ in range(count):
        t0 = RNG.exponential(density_decay) if density_decay else RNG.uniform(0, total)
        if t0 >= total:
            continue
        f = RNG.uniform(lo, hi)
        d = length * RNG.uniform(0.6, 1.5)
        s = sine(f, d) * perc(d, 0.001, d / 4)
        parts.append((t0, s, RNG.uniform(0.3, 1.0) * np.exp(-t0 / decay), RNG.uniform(-0.9, 0.9)))
    return place(total + 0.1, *parts)


def chiptrill(notes, rate=20, d=0.6, decay=0.18, wave="square"):
    """Fast alternating square-wave trill (reference Enter sparkle)."""
    step = 1 / rate
    parts = []
    k = 0
    t0 = 0.0
    while t0 < d:
        f = hz(notes[k % len(notes)]) if isinstance(notes[0], str) else notes[k % len(notes)]
        s = (square if wave == "square" else tri)(f, step * 1.3) * adsr(step * 1.3, 0.002, 0.01, 0.6, step * 0.5)
        parts.append((t0, s, np.exp(-t0 / decay), 0.35 * (-1) ** k))
        k += 1
        t0 += step
    return place(d + 0.1, *parts)


def chime_trem(freqs, d, rate=12, depth=0.85, decay=0.9, release=0.15):
    """Sustained chord with deep tremolo (reference Level Up shimmer)."""
    t = tt(d)
    parts = []
    for i, (f, g) in enumerate(freqs):
        ph = i * np.pi / len(freqs)
        trem = 1 - depth * 0.5 * (1 - np.cos(2 * np.pi * rate * t + ph))
        tone = sine(f, d) + 0.08 * sine(f * 2, d) + 0.05 * sine(f * 3, d)
        env = perc(d, 0.004, decay) * adsr(d, 0.0, 0.0, 1.0, release)
        parts.append((0, tone * trem * env, g, (-0.5 + i / max(1, len(freqs) - 1)) * 0.8))
    return place(d, *parts)


def party_horn(f_track, d):
    """Paper party blower: buzzy reed tone (reference Confetti)."""
    jitter = lp(RNG.standard_normal(n_of(d)), 30) * 0.02
    f = track(f_track, d) * (1 + jitter)
    amps_db = [0, -10, -15, -14, -12, -16, -18, -20, -22, -24, -26, -28, -30, -32]
    tone = additive(f, d, [10 ** (a / 20) for a in amps_db])
    buzz = hp(noise(d), 2000) * 0.05
    return tone + buzz


def voices_yay(d=0.8, n=9, base=330):
    """Synthetic crowd 'Yaaay!' cheer: formant-filtered voices with rising pitch."""
    vowels = [(300, 2300, 3000), (650, 1900, 2700), (500, 2200, 2900)]  # y -> aa -> ay
    out = np.zeros(n_of(d))
    x = np.linspace(0, 1, n_of(d))
    for _ in range(n):
        f0 = base * RNG.uniform(0.8, 1.35)
        contour = f0 * (1 + 0.15 * x + 0.5 * np.clip((x - 0.75) / 0.25, 0, 1) ** 2)
        contour *= 1 + 0.02 * np.sin(2 * np.pi * RNG.uniform(5, 7) * tt(d))
        src = saw(contour, d, 40) + 0.15 * noise(d)
        shaped = np.zeros_like(src)
        weights = [np.clip(1 - x / 0.15, 0, 1), np.clip(np.minimum(x / 0.15, (1 - x) / 0.4), 0, 1),
                   np.clip((x - 0.6) / 0.4, 0, 1)]
        for (f1, f2, f3), w in zip(vowels, weights):
            v = bp(src, f1 * 0.8, f1 * 1.25) + 0.6 * bp(src, f2 * 0.88, f2 * 1.12) + 0.3 * bp(src, f3 * 0.9, f3 * 1.1)
            shaped += v * w
        start = RNG.uniform(0, 0.05)
        env = adsr(d, 0.05, 0.1, 0.85, 0.12)
        out += np.roll(shaped * env, n_of(start))
    return out / n


def tick(v=1):
    """Plastic flapper hitting a wheel peg."""
    cfg = {1: (2600, 950, 1.0), 2: (3100, 1150, 0.9), 3: (2200, 800, 1.1), 4: (3600, 1350, 0.8)}
    hi, body, g = cfg[v]
    d = 0.06
    click = snap(d, hi * 0.6, hi * 2.2, 0.0025)
    ring = (sine(hi, d) * 0.4 + sine(body, d)) * perc(d, 0.0003, 0.008)
    knock = thump(d, body * 0.35, body * 0.25, 0.006) * 0.6
    return (click * 1.2 + ring * 0.6 + knock) * g


def whoosh(d, f0=400, f1=4000, peak=0.5):
    x = np.linspace(0, 1, n_of(d))
    env = np.where(x < peak, (x / peak) ** 2, ((1 - x) / (1 - peak)) ** 1.5)
    return moving_filter(noise(d), f0, f1, "low", 40) * env


# ------------------------------------------------------------------ sounds
def s_click():
    st = place(0.08, (0, pluck_pop(0.06, 1500, 900, 0.012), 1.0), (0, snap(0.01, 3000, 12000, 0.0015), 0.5))
    return master(st, -2, drive=1.2)


def s_hover():
    st = place(0.08, (0, sine(glide(1900, 2300, 0.05), 0.05) * adsr(0.05, 0.004, 0.01, 0.5, 0.03), 1.0),
               (0, sine(glide(3800, 4600, 0.05), 0.05) * adsr(0.05, 0.004, 0.01, 0.5, 0.03), 0.2))
    return master(st, -9, drive=1.0)


def s_notification():
    a = bell(hz("C#7"), 0.9, 0.25) + 0.6 * sine(hz("C#6"), 0.9) * perc(0.9, 0.003, 0.2)
    b = bell(hz("F#7"), 1.2, 0.35) + 0.6 * sine(hz("F#6"), 1.2) * perc(1.2, 0.003, 0.3)
    st = place(1.4, (0, pluck_pop(0.1, 1200, 800, 0.03), 0.5), (0, a, 0.7, -0.2), (0.11, b, 0.9, 0.2))
    st = st + sparkles(1.3, 10, 5000, 10000, 0.3, 0.03, 0.15)[:, : st.shape[1]] * 0.15
    return master(reverb(echo(st, 0.11, 0.25, 3), 1.2, 0.25))


def s_cash_collect():
    """Reference 'Cashout': drawer clunk + bright register bell (~7 kHz ring)."""
    ching = bell(1314, 0.7, 0.35, ((1, 0.5, 1), (2.81, 0.7, 0.8), (5.31, 1.0, 0.6), (6.19, 0.35, 0.4)))
    st = place(0.9,
               (0, snap(0.04, 5000, 14000, 0.008), 0.6),
               (0.0, thump(0.12, 330, 160, 0.025), 0.35),
               (0.07, thump(0.12, 200, 120, 0.025), 0.25),
               (0.07, bp(noise(0.12), 300, 1500) * perc(0.12, 0.002, 0.02), 0.3),
               (0.17, ching, 1.0, 0.1),
               (0.17, coin(4200, 0.3), 0.3, -0.4))
    return master(reverb(st, 0.6, 0.12))


def s_cash_collect_2():
    """Coin shower into a register ching."""
    parts = []
    t = 0.0
    for i in range(16):
        parts.append((t, coin(RNG.uniform(2800, 5600), 0.3), RNG.uniform(0.5, 0.9), RNG.uniform(-0.8, 0.8)))
        t += RNG.uniform(0.025, 0.06)
    ching = bell(1314, 0.8, 0.4, ((1, 0.5, 1), (2.81, 0.7, 0.8), (5.31, 1.0, 0.6), (6.19, 0.35, 0.4)))
    parts += [(t, thump(0.15, 300, 150, 0.04), 0.7), (t + 0.03, ching, 1.2)]
    parts += [(0, thump(0.15, 220, 120, 0.04), 0.4)]
    st = place(t + 1.0, *parts)
    return master(reverb(st, 0.7, 0.15))


def s_level_up():
    """Reference Level Up: impact + glitter burst + tremolo F# major chime + falling whistle."""
    chord = chime_trem([(1480, 0.8), (1865, 1.0), (2217, 0.85), (2960, 1.0), (3729, 0.35)], 1.65,
                       rate=12, depth=0.8, decay=0.9, release=0.12)
    whistle_d = 1.4
    wf = glide(5900, 3700, whistle_d) * (1 + 0.006 * np.sin(2 * np.pi * 12 * tt(whistle_d)))
    whistle = sine(wf, whistle_d) * adsr(whistle_d, 0.08, 0.1, 0.8, 0.1)
    rise = sine(glide(700, 1480, 0.12), 0.12) * adsr(0.12, 0.005, 0.02, 0.8, 0.03)
    st = place(1.9,
               (0, sub_boom(0.5, 120, 45, 0.12), 0.4),
               (0, snap(0.08, 1500, 14000, 0.02), 0.6),
               (0, whoosh(0.35, 800, 9000, 0.2), 0.35),
               (0, rise, 0.25),
               (0.08, chord, 0.55),
               (0.2, whistle, 0.22, 0.3),
               (0.02, sparkles(0.45, 45, 1500, 9000, 0.25, 0.035), 0.5),
               (0.02, sine(hz("F#5"), 0.6) * perc(0.6, 0.01, 0.2), 0.15))
    return master(reverb(st, 1.1, 0.22))


def s_buy():
    """Purchase: pop + two rising coin dings + small sparkle."""
    st = place(1.0,
               (0, pluck_pop(0.12, 1200, 700, 0.03), 0.8),
               (0, thump(0.15, 240, 110, 0.04), 0.5),
               (0.06, coin(hz("B7") / 2, 0.4), 0.6, -0.3),
               (0.13, coin(hz("E8") / 2, 0.6), 0.8, 0.3),
               (0.13, bell(1314, 0.6, 0.3, ((1, 0.4, 1), (2.81, 0.6, 0.8), (5.31, 1.0, 0.6))), 0.5),
               (0.15, sparkles(0.4, 12, 4000, 9000, 0.2, 0.03), 0.4))
    return master(reverb(st, 0.7, 0.15))


def s_losing_money():
    """Coins tumbling down + sad descending 'womp'."""
    parts = []
    for i in range(9):
        f = 5200 * 0.86 ** i
        parts.append((i * 0.06, coin(f, 0.25), 0.8 - i * 0.05, RNG.uniform(-0.6, 0.6)))
    d = 0.9
    womp = additive(glide(330, 110, d), d, [1, 0.5, 0.3, 0.2, 0.1, 0.06]) * adsr(d, 0.03, 0.1, 0.8, 0.3)
    womp = moving_filter(womp, 2500, 400, "low", 24)
    parts += [(0.45, womp, 0.8), (0.45, sub_boom(0.6, 90, 40, 0.2), 0.5)]
    st = place(1.6, *parts)
    return master(reverb(st, 0.8, 0.15))


def s_win():
    """Reference Win: big sub boom + crowd 'Yaaay!' + rising arpeggio + slide-whistle up."""
    yay = voices_yay(0.85, 10, 340)
    arp = []
    for i, nm in enumerate(["F#6", "A#6", "C#7", "F#7", "A#7"]):
        s = square(hz(nm), 0.09, 7) * adsr(0.09, 0.002, 0.02, 0.6, 0.04)
        arp.append((0.38 + i * 0.05, s, 0.18, (-1) ** i * 0.4))
    sw_d = 0.24
    slide = additive(glide(700, 2400, sw_d), sw_d, [1, 0.3, 0.15]) * adsr(sw_d, 0.02, 0.02, 0.9, 0.01)
    st = place(1.4,
               (0.0, sub_boom(0.7, 100, 30, 0.25), 1.0),
               (0.0, thump(0.2, 220, 90, 0.06), 0.6),
               (0.0, snap(0.15, 1500, 12000, 0.04), 0.5),
               (0.02, yay, 2.2),
               *arp,
               (0.66, slide, 0.35),
               (0.88, sparkles(0.4, 14, 4000, 9000, 0.2, 0.03), 0.4))
    st = st + place(st.shape[1] / SR, (0.02, chime_trem([(1480, 0.5), (1865, 0.6), (2217, 0.5)], 1.2, 12, 0.7, 0.4), 0.12))
    return master(reverb(st, 1.0, 0.18), drive=2.0)


def s_lose():
    """Sad trombone 'wah wah wah waaah' with mute-wah filter."""
    parts = []
    seq = [("D4", 0.0, 0.32), ("C#4", 0.36, 0.32), ("C4", 0.72, 0.32), ("B3", 1.08, 1.1)]
    for i, (nm, t0, d) in enumerate(seq):
        x = np.linspace(0, 1, n_of(d))
        f = hz(nm) * (1 + (0.03 * np.sin(2 * np.pi * 5.5 * tt(d)) * np.clip((x - 0.2) * 3, 0, 1) if i == 3 else 0))
        if i == 3:
            f = f * (1 - 0.05 * x)
        tone = additive(f, d, [1 / k ** 0.8 for k in range(1, 30)]) * adsr(d, 0.03, 0.05, 0.85, 0.12 if i < 3 else 0.4)
        tone = moving_filter(tone, 350, 2400 if i < 3 else 900, "low", 16)
        parts.append((t0, tone, 0.6))
    parts.append((1.08, sub_boom(0.8, 80, 40, 0.3), 0.3))
    st = place(2.3, *parts)
    return master(reverb(st, 0.9, 0.15), -4, drive=1.2)


def s_accept():
    """Reference Enter: round pop + fast F#/A# square trill with ping-pong echo."""
    trill = chiptrill([1512, 1906], rate=20, d=0.55, decay=0.13)
    st = place(1.0,
               (0, pluck_pop(0.14, 1150, 700, 0.04), 1.0),
               (0, thump(0.1, 400, 330, 0.03), 0.4),
               (0.04, trill, 0.35))
    return master(reverb(echo(st, 0.075, 0.3, 3), 0.6, 0.12))


def s_confetti():
    """Reference Confetti: party popper bang + party horn toot (538 Hz, drop to 450)."""
    d1, d2 = 0.62, 0.45
    f1 = 538 * (1 + 0.03 * np.exp(-tt(d1) / 0.03))
    f2 = glide(463, 441, d2)
    horn = np.concatenate([party_horn(f1, d1) * adsr(d1, 0.02, 0.05, 0.9, 0.005),
                           party_horn(f2, d2) * adsr(d2, 0.005, 0.05, 0.7, 0.2) * 0.6])
    horn = lp(horn, 7000)
    pop = bp(noise(0.12), 400, 9000) * perc(0.12, 0.0005, 0.02)
    paper = sparkles(1.0, 40, 3000, 11000, 0.4, 0.015, 0.3)
    st = place(1.4,
               (0, pop, 1.6),
               (0, thump(0.12, 220, 70, 0.03), 0.9),
               (0.12, horn, 0.55),
               (0.02, paper, 0.25))
    return master(reverb(st, 0.6, 0.12))


def s_wheel_spin():
    dur = 4.6
    parts = []
    t0, gap, i = 0.0, 0.032, 0
    while t0 < dur - 0.25:
        parts.append((t0, tick(1 + i % 4), 0.8, 0.3 * np.sin(i * 0.7)))
        i += 1
        t0 += gap
        gap *= 1.042
    x = tt(dur)
    rot = (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(np.geomspace(6, 0.6, n_of(dur))) / SR))
    parts.append((0, bp(noise(dur), 250, 2500) * np.exp(-x / 1.4) * rot, 0.12))
    st = place(dur, *parts)
    return master(reverb(st, 0.35, 0.08))


def s_wheel_start():
    dur = 1.1
    parts = [(0, thump(0.2, 180, 60, 0.05), 1.0), (0, snap(0.05, 800, 6000, 0.01), 0.8),
             (0, sub_boom(0.4, 90, 40, 0.12), 0.6), (0.02, whoosh(0.9, 300, 5000, 0.45), 0.3)]
    t0, gap, i = 0.1, 0.17, 0
    while t0 < dur - 0.03:
        parts.append((t0, tick(1 + i % 4), 0.75, 0.3 * np.sin(i)))
        i += 1
        t0 += gap
        gap = max(0.032, gap * 0.78)
    return master(reverb(place(dur, *parts), 0.35, 0.08))


def s_unboxing_1():
    """Box shake/rattle, lid pop, reveal chime."""
    parts = []
    for k in range(3):
        t0 = k * 0.13
        parts += [(t0, thump(0.1, 160, 90, 0.03), 0.6), (t0, bp(noise(0.08), 400, 3000) * perc(0.08, 0.002, 0.02), 0.5)]
    pop_t = 0.45
    parts += [(pop_t, pluck_pop(0.12, 900, 500, 0.04), 0.9), (pop_t, snap(0.06, 1000, 9000, 0.012), 0.7),
              (pop_t, sub_boom(0.4, 110, 45, 0.12), 0.6),
              (pop_t + 0.05, chime_trem([(1480, 0.8), (1865, 1.0), (2217, 0.85), (2960, 0.9)], 1.0, 12, 0.7, 0.45), 0.5),
              (pop_t + 0.03, sparkles(0.5, 30, 2500, 9500, 0.25, 0.035), 0.5)]
    return master(reverb(place(1.7, *parts), 1.0, 0.2))


def s_unboxing_2():
    """Epic reveal: riser + boom + big shimmering chord + glitter."""
    b = 0.9
    riser = (moving_filter(noise(b), 300, 9000, "low", 40) * np.linspace(0, 1, n_of(b)) ** 2.5 * 0.9
             + square(glide(220, 880, b), b, 7) * np.linspace(0, 1, n_of(b)) ** 2 * 0.25)
    trill = chiptrill([1512, 1906], rate=16, d=b, decay=10)
    trill = trill * np.concatenate([np.linspace(0, 1, n_of(b)) ** 3, np.zeros(trill.shape[1] - n_of(b))])
    chord = chime_trem([(740, 0.6), (1480, 0.8), (1865, 1.0), (2217, 0.85), (2960, 1.0)], 1.6, 12, 0.75, 0.8)
    st = place(2.8,
               (0, riser, 0.6), (0, trill, 0.2),
               (b, sub_boom(0.9, 110, 30, 0.3), 1.0),
               (b, snap(0.3, 2000, 14000, 0.08), 0.6),
               (b, chord, 0.6),
               (b, sparkles(1.0, 60, 2500, 10000, 0.4, 0.035), 0.6),
               (b + 0.05, whoosh(0.8, 3000, 600, 0.1), 0.3))
    return master(reverb(st, 1.4, 0.25), drive=1.8)


def s_riser():
    d = 3.0
    x = np.linspace(0, 1, n_of(d))
    f = glide(140, 1300, d)
    voices = sum(saw(f * (1 + det), d, 25) for det in (-0.012, -0.004, 0.004, 0.012)) / 4
    voices = moving_filter(voices, 600, 9000, "low", 48)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(3 + 22 * x ** 2) / SR)
    nz = moving_filter(noise(d), 300, 14000, "low", 48)
    l = voices * trem * x ** 1.8 * 0.6 + nz * x ** 2.5 * 0.5
    r = np.roll(l, n_of(0.011))
    st = np.array([l, r])
    st[:, -n_of(0.02):] *= np.linspace(1, 0, n_of(0.02))
    return master(reverb(st, 0.6, 0.15), trim=False)


def s_wheel_tick(v):
    return master(place(0.07, (0, tick(v), 1.0)), -2, drive=1.2)


def s_error():
    d1, d2 = 0.1, 0.22
    a = square(hz("E4"), d1, 9) * adsr(d1, 0.002, 0.02, 0.7, 0.03)
    b = square(hz("C4"), d2, 9) * adsr(d2, 0.002, 0.03, 0.7, 0.08)
    st = place(0.45, (0, lp(a, 2500), 0.6), (0.12, lp(b, 2500), 0.7), (0, thump(0.1, 200, 100, 0.03), 0.4),
               (0.12, thump(0.12, 160, 80, 0.03), 0.4))
    return master(reverb(st, 0.3, 0.1), -2)


SOUNDS = [
    ("01_click", s_click),
    ("02_notification", s_notification),
    ("03_cash_collect", s_cash_collect),
    ("04_cash_collect_2", s_cash_collect_2),
    ("05_level_up", s_level_up),
    ("06_buy_something", s_buy),
    ("07_losing_money", s_losing_money),
    ("08_win", s_win),
    ("09_lose", s_lose),
    ("10_hover", s_hover),
    ("11_enter_accept", s_accept),
    ("12_confetti", s_confetti),
    ("13_wheel_spin", s_wheel_spin),
    ("14_unboxing_1", s_unboxing_1),
    ("15_unboxing_2", s_unboxing_2),
    ("16_riser_suspension", s_riser),
    ("17_wheel_tick_1", lambda: s_wheel_tick(1)),
    ("18_wheel_tick_2", lambda: s_wheel_tick(2)),
    ("19_wheel_tick_3", lambda: s_wheel_tick(3)),
    ("20_wheel_tick_4", lambda: s_wheel_tick(4)),
    ("21_wheel_start", s_wheel_start),
    ("22_error_denied", s_error),
]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "sfx_pack"
    only = sys.argv[2:]  # optional subset of names
    os.makedirs(f"{out}/wav", exist_ok=True)
    ff = shutil.which("ffmpeg")
    if ff:
        os.makedirs(f"{out}/ogg", exist_ok=True)
        os.makedirs(f"{out}/mp3", exist_ok=True)
    for name, fn in SOUNDS:
        if only and name not in only:
            continue
        st = fn()
        path = f"{out}/wav/{name}.wav"
        wavfile.write(path, SR, (st.T * 32767).astype(np.int16))
        if ff:
            subprocess.run([ff, "-v", "error", "-y", "-i", path, "-q:a", "6", f"{out}/ogg/{name}.ogg"], check=True)
            subprocess.run([ff, "-v", "error", "-y", "-i", path, "-b:a", "192k", f"{out}/mp3/{name}.mp3"], check=True)
        print(f"{name:24s} {st.shape[1] / SR:5.2f}s")


if __name__ == "__main__":
    main()
