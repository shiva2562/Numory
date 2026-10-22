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
            elif kind == 'synth':  # two detuned saws, the synthwave lead
                for det in (0.994, 1.006):
                    v += 0.5 * sum(math.sin(ph * det * k) / k for k in range(1, 8))
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


def sweep(f0, f1, dur, vol=0.35):
    """A pitch glide (the 'zap' of a tube lighting)."""
    n, ph, out = int(RATE * dur), 0.0, []
    for i in range(n):
        t = i / n
        ph += 2 * math.pi * (f0 + (f1 - f0) * t * t) / RATE
        env = min(1.0, i / 200) * (1 - t) ** 1.5
        out.append(vol * env * (math.sin(ph) + 0.4 * math.sin(2 * ph)))
    return out


def glitch(dur, vol=0.35):
    """Bit-crushed noise over a low buzz."""
    import random
    rnd = random.Random(7)
    n, out, hold = int(RATE * dur), [], 0.0
    for i in range(n):
        t = i / RATE
        if i % 180 == 0:
            hold = rnd.uniform(-1, 1)
        env = math.exp(-t / (dur / 3))
        buzz = math.tanh(4 * math.sin(2 * math.pi * 98 * t))
        out.append(vol * env * (0.55 * hold + 0.6 * buzz))
    return out


# Minor pentatonic up from A3: every number a step higher, never a sour note.
PENTA = [0, 3, 5, 7, 10]
A = 220.0
for k in range(15):
    semi = 12 * (k // 5) + PENTA[k % 5]
    write(f'note_{k + 1:02d}.wav', tone([A * 2 ** (semi / 12)], 0.18, kind='synth', decay=0.15, vol=0.28))
write('start.wav', sweep(300, 1800, 0.22))
write('wrong.wav', glitch(0.38))
arp = lambda notes, gap, dur: seq([tone([220 * 2 ** (s / 12)], dur, kind='synth', vol=0.3) for s in notes], gap)
write('done.wav', arp((12, 15, 19, 24), 0.075, 0.35))
write('best.wav', arp((12, 15, 19, 24, 27, 31, 36), 0.065, 0.45))
write('tap.wav', tone([880], 0.05, kind='synth', decay=0.04, vol=0.18))
