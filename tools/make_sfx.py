#!/usr/bin/env python3
"""Synthesizes Numory's sound effects (no samples, no copyrighted audio).

Usage: python3 tools/make_sfx.py   (writes assets/audio/*.wav)
"""
import math, os, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def tone(freqs, dur, kind='sine', attack=0.004, decay=None, vol=0.5):
    n = int(RATE * dur)
    decay = decay or dur
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-t / (decay / 4))
        v = 0.0
        for f in freqs:
            ph = 2 * math.pi * f * t
            if kind == 'sine':
                v += math.sin(ph) + 0.25 * math.sin(2 * ph)
            else:  # soft square
                v += math.tanh(3 * math.sin(ph))
        out.append(vol * env * v / len(freqs))
    return out


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32000)) for s in samples))


def seq(parts, gap):
    out = []
    for k, p in enumerate(parts):
        start = int(k * gap * RATE)
        out.extend([0.0] * max(0, start + len(p) - len(out)))
        for i, s in enumerate(p):
            out[start + i] += s
    return [s * 0.7 for s in out]


A = 392.0  # G4; one semitone up per number
for k in range(15):
    write(f'note_{k + 1:02d}.wav', tone([A * 2 ** (k / 12)], 0.16, decay=0.14))
write('start.wav', tone([880, 1320], 0.18, decay=0.12, vol=0.35))
write('wrong.wav', tone([110, 116], 0.32, kind='square', decay=0.3, vol=0.35))
write('done.wav', seq([tone([523.25 * 2 ** (s / 12)], 0.4) for s in (0, 4, 7, 12)], 0.08))
write('best.wav', seq([tone([523.25 * 2 ** (s / 12), 1046.5 * 2 ** (s / 12)], 0.5) for s in (0, 4, 7, 12, 16, 19)], 0.07))
write('tap.wav', tone([660], 0.06, decay=0.05, vol=0.3))
