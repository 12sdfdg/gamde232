"""Procedural game SFX pack generator.

Usage: python3 tools/generate_sfx.py [output_dir]
Produces 44.1 kHz / 16-bit WAV files (and OGG/MP3 if ffmpeg is available).
"""
import os
import subprocess
import shutil
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
RNG = np.random.default_rng(42)


# ---------------------------------------------------------------- primitives
def tt(dur):
    return np.arange(int(dur * SR)) / SR


def silence(dur):
    return np.zeros(int(dur * SR))


def note(name):
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12) / 12)


def phase_of(freq, dur):
    """Phase for constant or time-varying frequency (array)."""
    n = int(dur * SR)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2 * np.pi * np.cumsum(f) / SR


def sine(freq, dur):
    return np.sin(phase_of(freq, dur))


def tri(freq, dur):
    p = phase_of(freq, dur)
    return 2 / np.pi * np.arcsin(np.sin(p))


def square(freq, dur, harmonics=9):
    p = phase_of(freq, dur)
    out = np.zeros_like(p)
    for k in range(1, harmonics * 2, 2):
        out += np.sin(k * p) / k
    return out * 4 / np.pi * 0.8


def saw(freq, dur, harmonics=14):
    p = phase_of(freq, dur)
    out = np.zeros_like(p)
    for k in range(1, harmonics + 1):
        out += np.sin(k * p) / k * (-1) ** (k + 1)
    return out * 2 / np.pi * 0.8


def noise(dur):
    return RNG.uniform(-1, 1, int(dur * SR))


def env(dur, a=0.005, d=None, curve=6.0):
    """Attack then exponential decay over the remainder."""
    n = int(dur * SR)
    na = max(1, int(a * SR))
    e = np.ones(n)
    e[:na] = np.linspace(0, 1, na)
    rest = n - na
    if rest > 0:
        x = np.linspace(0, 1, rest)
        e[na:] = np.exp(-curve * x) if d is None else np.exp(-x * (rest / SR) / d)
    return e


def adsr(dur, a=0.01, d=0.05, s=0.7, r=0.1):
    n = int(dur * SR)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    ns = max(0, n - na - nd - nr)
    e = np.concatenate([np.linspace(0, 1, na, endpoint=False),
                        np.linspace(1, s, nd, endpoint=False),
                        np.full(ns, s),
                        np.linspace(s, 0, nr)])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def lp(x, fc, order=2):
    return sosfilt(butter(order, min(fc, SR / 2 - 100), "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, min(hi, SR / 2 - 100)], "band", fs=SR, output="sos"), x)


def sweep_filter(x, f_start, f_end, kind="low", blocks=64):
    """Crude time-varying filter: process in overlapping blocks."""
    n = len(x)
    out = np.zeros(n)
    size = n // blocks + 1
    win = np.hanning(size * 2)
    for i in range(blocks + 1):
        start = max(0, i * size - size)
        seg = x[start:start + size * 2]
        if len(seg) == 0:
            continue
        frac = i / blocks
        fc = f_start * (f_end / f_start) ** frac
        y = (lp if kind == "low" else hp)(seg, fc)
        out[start:start + len(seg)] += y * win[:len(seg)]
    return out


def bell(freq, dur, decay=0.25, bright=1.0):
    """Metallic coin/bell tone with inharmonic partials."""
    t = tt(dur)
    partials = [(1.0, 1.0, 1.0), (2.0, 0.5 * bright, 0.6), (2.76, 0.35 * bright, 0.45),
                (5.4, 0.2 * bright, 0.25), (8.93, 0.08 * bright, 0.15)]
    out = np.zeros_like(t)
    for ratio, amp, dk in partials:
        f = freq * ratio
        if f < SR / 2 - 500:
            out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / (decay * dk))
    a = int(0.002 * SR)
    out[:a] *= np.linspace(0, 1, a)
    return out


def blip(freq, dur, kind="sine", decay=None):
    osc = {"sine": sine, "tri": tri, "square": square, "saw": saw}[kind]
    return osc(freq, dur) * env(dur, 0.003, decay)


def reverb(x, size=0.8, mix=0.2, bright=6000):
    ir_t = tt(size)
    ir = noise(size) * np.exp(-ir_t / (size / 5))
    ir = lp(ir, bright)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = fftconvolve(x, ir)[: len(x) + len(ir)]
    dry = np.pad(x, (0, len(wet) - len(x)))
    return dry * (1 - mix) + wet * mix * 1.5


def mix(dur, *parts):
    """parts: (offset_seconds, signal, gain)."""
    out = np.zeros(int(dur * SR))
    for off, sig, g in parts:
        i = int(off * SR)
        if i >= len(out):
            continue
        seg = sig[: len(out) - i]
        out[i:i + len(seg)] += seg * g
    return out


def vibrato(base, dur, rate=6, depth=0.01, delay=0.0):
    t = tt(dur)
    ramp = np.clip((t - delay) / 0.15, 0, 1)
    return base * (1 + depth * ramp * np.sin(2 * np.pi * rate * t))


def finalize(x, peak_db=-1.0, fade=0.01, trim=True):
    x = x - np.mean(x)
    if trim:
        thr = 10 ** (-70 / 20) * np.max(np.abs(x))
        idx = np.where(np.abs(x) > thr)[0]
        if len(idx):
            x = x[: idx[-1] + 1]
    nf = min(int(fade * SR), len(x) // 4)
    if nf > 0:
        x[-nf:] *= np.linspace(1, 0, nf)
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)
    return x


# ---------------------------------------------------------------- sounds
def s_click():
    n = hp(noise(0.004), 2000) * env(0.004, 0.0005, curve=4)
    body = sine(np.linspace(2600, 1500, int(0.03 * SR)), 0.03) * env(0.03, 0.0005, curve=9)
    return finalize(mix(0.06, (0, n, 0.6), (0, body, 1.0)), peak_db=-3)


def s_hover():
    f = np.linspace(1100, 1500, int(0.06 * SR))
    x = tri(f, 0.06) * adsr(0.06, 0.006, 0.01, 0.6, 0.04)
    return finalize(lp(x, 5000), peak_db=-10)


def s_notification():
    a = bell(note("E6"), 0.6, decay=0.35, bright=0.4) + 0.4 * sine(note("E5"), 0.6) * env(0.6, 0.004, curve=7)
    b = bell(note("A6"), 0.9, decay=0.45, bright=0.4) + 0.4 * sine(note("A5"), 0.9) * env(0.9, 0.004, curve=6)
    x = mix(1.1, (0, a, 0.8), (0.12, b, 1.0))
    return finalize(reverb(x, 0.9, 0.22))


def s_cash_collect():
    clink = hp(noise(0.01), 4000) * env(0.01, 0.0005, curve=5)
    x = mix(1.0,
            (0, clink, 0.5),
            (0, bell(note("B6"), 0.6, 0.18), 0.8),
            (0.07, bell(note("E7"), 0.9, 0.3), 1.0),
            (0.07, sine(note("E6"), 0.5) * env(0.5, 0.003, curve=8), 0.3))
    return finalize(reverb(x, 0.6, 0.15))


def s_cash_collect_2():
    parts = []
    t = 0.0
    scale = ["E6", "G#6", "B6", "E7", "G#7", "B7", "E7", "B7"]
    for i, nm in enumerate(scale):
        f = note(nm) * (1 + RNG.uniform(-0.004, 0.004))
        parts.append((t, bell(f, 0.5, 0.12 + 0.03 * (i == len(scale) - 1) * 4), 0.7 + 0.04 * i))
        parts.append((t, hp(noise(0.006), 5000) * env(0.006, 0.0003), 0.25))
        t += 0.045 + RNG.uniform(-0.008, 0.008)
    x = mix(1.2, *parts)
    return finalize(reverb(x, 0.7, 0.18))


def s_level_up():
    arp = ["C5", "E5", "G5", "C6", "E6", "G6"]
    parts = []
    for i, nm in enumerate(arp):
        d = 0.12
        parts.append((i * 0.06, square(note(nm), d, 5) * env(d, 0.002, curve=5), 0.35))
        parts.append((i * 0.06, tri(note(nm) * 2, d) * env(d, 0.002, curve=6), 0.2))
    chord_t = len(arp) * 0.06
    chord_d = 0.9
    for nm in ["C6", "E6", "G6", "C7"]:
        f = vibrato(note(nm), chord_d, 6, 0.006, 0.15)
        parts.append((chord_t, (square(f, chord_d, 4) * 0.5 + tri(f, chord_d)) * adsr(chord_d, 0.01, 0.1, 0.6, 0.6), 0.22))
    for k in range(10):
        f = note("C7") * 2 ** (RNG.integers(0, 12) / 12)
        parts.append((chord_t + k * 0.05, bell(f, 0.3, 0.06, 0.3), 0.15))
    x = mix(1.6, *parts)
    return finalize(reverb(lp(x, 9000), 0.8, 0.2))


def s_buy():
    drawer = bp(noise(0.12), 800, 3000) * env(0.12, 0.002, curve=10)
    thump = sine(np.linspace(140, 70, int(0.12 * SR)), 0.12) * env(0.12, 0.002, curve=8)
    x = mix(1.0,
            (0, thump, 0.7),
            (0, drawer, 0.35),
            (0.06, bell(note("G6"), 0.5, 0.15), 0.7),
            (0.13, bell(note("D7"), 0.8, 0.28), 0.9),
            (0.13, bell(note("G7"), 0.6, 0.2, 0.3), 0.35))
    return finalize(reverb(x, 0.6, 0.15))


def s_losing_money():
    parts = []
    notes = ["E7", "C7", "A6", "F6", "D6", "B5"]
    for i, nm in enumerate(notes):
        parts.append((i * 0.09, bell(note(nm), 0.4, 0.12, 0.6), 0.8 - i * 0.07))
    d = 0.9
    f = np.geomspace(500, 150, int(d * SR))
    slide = saw(f, d, 8) * adsr(d, 0.02, 0.1, 0.7, 0.4)
    parts.append((0.25, lp(slide, 1800), 0.35))
    x = mix(1.4, *parts)
    return finalize(reverb(x, 0.6, 0.15))


def s_win():
    parts = []
    seq = [("G4", 0.0, 0.12), ("C5", 0.13, 0.12), ("E5", 0.26, 0.12), ("G5", 0.39, 0.25),
           ("E5", 0.66, 0.1), ("G5", 0.78, 0.9)]
    for nm, t0, d in seq:
        f = vibrato(note(nm), d, 6, 0.008, 0.2)
        lead = (square(f, d, 6) * 0.6 + saw(f, d, 6) * 0.4) * adsr(d, 0.005, 0.05, 0.75, min(0.3, d * 0.5))
        parts.append((t0, lp(lead, 5000), 0.3))
    # harmony chord under final note
    for nm in ["C4", "E4", "G4", "C5"]:
        d = 0.9
        parts.append((0.78, tri(note(nm), d) * adsr(d, 0.01, 0.1, 0.7, 0.5), 0.18))
    # drum hits
    kick = sine(np.geomspace(160, 45, int(0.2 * SR)), 0.2) * env(0.2, 0.001, curve=7)
    snare = (bp(noise(0.15), 1500, 8000) * env(0.15, 0.001, curve=8))
    for t0 in (0.0, 0.39, 0.78):
        parts.append((t0, kick, 0.5))
    parts.append((0.78, snare, 0.25))
    for k in range(14):
        f = note("C7") * 2 ** (RNG.choice([0, 4, 7, 12]) / 12)
        parts.append((0.78 + k * 0.045, bell(f, 0.25, 0.05, 0.2), 0.12))
    x = mix(2.0, *parts)
    return finalize(reverb(x, 1.0, 0.22))


def s_lose():
    parts = []
    seq = [("G4", 0.0, 0.3), ("F#4", 0.33, 0.3), ("F4", 0.66, 0.3), ("E4", 0.99, 1.0)]
    for i, (nm, t0, d) in enumerate(seq):
        rate, depth = (5.5, 0.025) if i == 3 else (5, 0.004)
        f = vibrato(note(nm), d, rate, depth, 0.1)
        if i == 3:
            f = f * np.linspace(1.0, 0.94, len(f))
        tone = saw(f, d, 10) * adsr(d, 0.02, 0.05, 0.8, 0.15 if i < 3 else 0.5)
        # "wah" mute: filter opens and closes
        tone = sweep_filter(tone, 400, 2200 if i < 3 else 1200, "low", 16)
        parts.append((t0, tone, 0.6))
    x = mix(2.1, *parts)
    return finalize(reverb(x, 0.8, 0.15))


def s_accept():
    a = square(note("C6"), 0.08, 4) * env(0.08, 0.002, curve=5)
    b = square(note("G6"), 0.18, 4) * env(0.18, 0.002, curve=5)
    x = mix(0.3, (0, a, 0.5), (0.07, b, 0.6),
            (0, tri(note("C7"), 0.08) * env(0.08, 0.002, curve=6), 0.2),
            (0.07, tri(note("G7"), 0.18) * env(0.18, 0.002, curve=6), 0.2))
    return finalize(reverb(lp(x, 7000), 0.4, 0.12), peak_db=-3)


def s_confetti():
    pop_noise = bp(noise(0.08), 300, 6000) * env(0.08, 0.0008, curve=12)
    pop_low = sine(np.geomspace(220, 60, int(0.1 * SR)), 0.1) * env(0.1, 0.001, curve=9)
    parts = [(0, pop_noise, 1.0), (0, pop_low, 0.8)]
    for _ in range(70):
        t0 = 0.04 + RNG.exponential(0.25)
        if t0 > 1.3:
            continue
        f = RNG.uniform(3000, 9000)
        d = RNG.uniform(0.01, 0.03)
        crackle = (sine(f, d) * 0.5 + hp(noise(d), 4000)) * env(d, 0.0005, curve=8)
        parts.append((t0, crackle, RNG.uniform(0.05, 0.2) * np.exp(-t0 * 1.5)))
    for k in range(8):
        f = note("C7") * 2 ** (RNG.choice([0, 4, 7, 12, 16]) / 12)
        parts.append((0.05 + k * 0.06, bell(f, 0.3, 0.07, 0.3), 0.12))
    x = mix(1.5, *parts)
    return finalize(reverb(x, 0.6, 0.15))


def tick(variant=1):
    """Plastic/wood wheel-peg tick. Variants differ in pitch/body."""
    cfg = {1: (2400, 900, 0.035), 2: (2900, 1100, 0.03), 3: (2000, 750, 0.04), 4: (3400, 1300, 0.025)}
    hi, body, d = cfg[variant]
    snap = bp(noise(d), hi * 0.7, hi * 1.6) * env(d, 0.0003, curve=14)
    tone = sine(body, d) * env(d, 0.0005, curve=10)
    return snap * 0.9 + tone * 0.5


def s_wheel_tick(v):
    return finalize(mix(0.06, (0, tick(v), 1.0)), peak_db=-3)


def s_wheel_spin():
    dur = 4.5
    parts = []
    t0, interval = 0.0, 0.035
    i = 0
    while t0 < dur - 0.3:
        parts.append((t0, tick(1 + i % 4), 0.8))
        i += 1
        t0 += interval
        interval *= 1.045  # decelerate
    whoosh = bp(noise(dur), 300, 2500) * np.exp(-tt(dur) / 1.2) * (0.5 + 0.5 * np.sin(2 * np.pi * np.geomspace(8, 0.5, int(dur * SR)) * tt(dur)))
    parts.append((0, whoosh, 0.15))
    x = mix(dur, *parts)
    return finalize(reverb(x, 0.3, 0.08))


def s_wheel_start():
    dur = 1.1
    thump = sine(np.geomspace(120, 45, int(0.25 * SR)), 0.25) * env(0.25, 0.002, curve=7)
    clunk = bp(noise(0.06), 200, 1500) * env(0.06, 0.001, curve=10)
    w = noise(dur) * np.sin(np.pi * np.clip(tt(dur) / dur, 0, 1)) ** 2
    whoosh = sweep_filter(w, 400, 4000, "low", 32)
    parts = [(0, thump, 0.9), (0, clunk, 0.6), (0.05, whoosh, 0.35)]
    t0, interval = 0.12, 0.16
    i = 0
    while t0 < dur - 0.05:
        parts.append((t0, tick(1 + i % 4), 0.7))
        i += 1
        t0 += interval
        interval = max(0.035, interval * 0.8)  # accelerate
    x = mix(dur, *parts)
    return finalize(reverb(x, 0.3, 0.08))


def s_unboxing_1():
    """Cardboard rip + lid pop + reveal chime."""
    dur = 0.45
    rip = bp(noise(dur), 600, 5000)
    grain = (RNG.random(int(dur * SR)) > 0.6).astype(float)
    grain = lp(grain, 300) * 3
    rip = rip * grain * adsr(dur, 0.02, 0.05, 0.9, 0.08)
    pop = sine(np.geomspace(300, 90, int(0.08 * SR)), 0.08) * env(0.08, 0.001, curve=9)
    parts = [(0, rip, 0.6), (0.47, pop, 0.8), (0.47, bp(noise(0.05), 500, 3000) * env(0.05, 0.001, curve=9), 0.4)]
    for i, nm in enumerate(["C6", "E6", "G6", "C7"]):
        parts.append((0.52 + i * 0.05, bell(note(nm), 0.8, 0.25, 0.4), 0.45))
    x = mix(1.6, *parts)
    return finalize(reverb(x, 0.8, 0.2))


def s_unboxing_2():
    """Magical build-up then burst reveal."""
    build = 0.8
    f = np.geomspace(300, 1200, int(build * SR))
    shimmer = (tri(f, build) + 0.5 * tri(f * 1.5, build)) * np.linspace(0, 1, int(build * SR)) ** 2
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(np.linspace(6, 22, int(build * SR))) / SR)
    noise_rise = sweep_filter(noise(build), 500, 8000, "low", 24) * np.linspace(0, 1, int(build * SR)) ** 3
    parts = [(0, shimmer * trem, 0.25), (0, noise_rise, 0.25)]
    boom = sine(np.geomspace(150, 40, int(0.5 * SR)), 0.5) * env(0.5, 0.002, curve=6)
    crash = hp(noise(0.8), 3000) * env(0.8, 0.001, curve=6)
    parts += [(build, boom, 0.9), (build, crash, 0.3)]
    for nm in ["C5", "G5", "C6", "E6", "G6", "C7"]:
        parts.append((build, bell(note(nm), 1.2, 0.5, 0.3), 0.3))
    for k in range(16):
        fk = note("C7") * 2 ** (RNG.choice([0, 4, 7, 12, 16, 19]) / 12)
        parts.append((build + 0.03 + k * 0.04, bell(fk, 0.3, 0.06, 0.2), 0.12))
    x = mix(2.4, *parts)
    return finalize(reverb(x, 1.2, 0.25))


def s_riser():
    dur = 3.0
    n = int(dur * SR)
    ramp = np.linspace(0, 1, n)
    f = 150 * (1200 / 150) ** ramp
    tone = saw(f, dur, 10) * 0.5 + saw(f * 1.007, dur, 10) * 0.5
    tone = lp(tone, 6000)
    trem_rate = np.cumsum(2 + 18 * ramp ** 2) / SR
    trem = 0.65 + 0.35 * np.sin(2 * np.pi * trem_rate)
    nz = sweep_filter(noise(dur), 300, 12000, "low", 48)
    x = tone * trem * ramp ** 1.6 * 0.6 + nz * ramp ** 2.2 * 0.45
    fade = int(0.03 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    return finalize(reverb(x, 0.6, 0.15), trim=False)


def s_error():
    a = square(note("E4"), 0.1, 5) * env(0.1, 0.002, curve=3)
    b = square(note("C4"), 0.22, 5) * adsr(0.22, 0.002, 0.03, 0.7, 0.08)
    x = mix(0.4, (0, a, 0.5), (0.11, b, 0.6))
    return finalize(reverb(lp(x, 3500), 0.3, 0.1), peak_db=-3)


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
    os.makedirs(f"{out}/wav", exist_ok=True)
    have_ffmpeg = shutil.which("ffmpeg") is not None
    if have_ffmpeg:
        os.makedirs(f"{out}/ogg", exist_ok=True)
        os.makedirs(f"{out}/mp3", exist_ok=True)
    for name, fn in SOUNDS:
        x = fn()
        path = f"{out}/wav/{name}.wav"
        wavfile.write(path, SR, (x * 32767).astype(np.int16))
        if have_ffmpeg:
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-q:a", "6", f"{out}/ogg/{name}.ogg"], check=True)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-b:a", "192k", f"{out}/mp3/{name}.mp3"], check=True)
        print(f"{name:24s} {len(x) / SR:5.2f}s")


if __name__ == "__main__":
    main()
