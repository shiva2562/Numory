#!/usr/bin/env python3
"""Synthesizes Numory's background loop: a calm synthwave bed (no samples,
no copyrighted audio). 16 bars at 96 BPM in A minor, Am-F-C-G; drums,
octave bass and a pad all the way, a soft arpeggio in the second half.
Tails wrap to the start so the loop is seamless.

Usage: python3 tools/make_music.py   (writes assets/audio/music.wav; needs numpy)
"""
import os, wave

import numpy as np

RATE = 32000
BPM = 96
BEAT = 60 / BPM
BARS = 16
N = int(RATE * BEAT * 4 * BARS)
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'music.wav')
rng = np.random.default_rng(7)

# Am, F, C, G as MIDI notes (root, third, fifth), one chord per bar.
CHORDS = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def t_of(n):
    return np.arange(n) / RATE


def saw(f, n, detune=(0.995, 1.0, 1.005)):
    t = t_of(n)
    return sum(2 * ((t * f * d) % 1) - 1 for d in detune) / len(detune)


def lowpass(x, cutoff):
    """Circular FFT filter: the loop wraps, so this keeps it seamless."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    return np.fft.irfft(spec / np.sqrt(1 + (f / cutoff) ** 4), len(x))


def highpass(x, cutoff):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    return np.fft.irfft(spec / np.sqrt(1 + (cutoff / np.maximum(f, 1)) ** 4), len(x))


def add(track, sound, at):
    """Mixes [sound] in at [at] seconds, wrapping past the loop's end."""
    i = int(at * RATE) % N
    end = i + len(sound)
    if end <= N:
        track[i:end] += sound
    else:
        track[i:] += sound[: N - i]
        track[: end - N] += sound[N - i :]


def env(n, attack, release):
    e = np.ones(n)
    a, r = int(attack * RATE), int(release * RATE)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


kick, snare, hats, bass, pad, arp = (np.zeros(N) for _ in range(6))
duck = np.ones(N)  # sidechain: everything melodic dips under the kick

k_n = int(0.35 * RATE)
k_t = t_of(k_n)
kick_hit = np.sin(2 * np.pi * np.cumsum(45 + 75 * np.exp(-k_t * 30)) / RATE) * np.exp(-k_t * 9)
s_n = int(0.3 * RATE)
s_t = t_of(s_n)
snare_hit = (highpass(rng.standard_normal(s_n), 1500) * 0.6 + np.sin(2 * np.pi * 185 * s_t) * 0.5) * np.exp(-s_t * 14)
h_n = int(0.05 * RATE)
hat_hit = highpass(rng.standard_normal(h_n), 7000) * np.exp(-t_of(h_n) * 90)
d_n = int(BEAT * 0.9 * RATE)
duck_shape = 1 - 0.55 * np.exp(-t_of(d_n) * 9)

for bar in range(BARS):
    root, third, fifth = CHORDS[bar % 4]
    b0 = bar * BEAT * 4
    for beat in range(4):
        at = b0 + beat * BEAT
        add(kick, kick_hit, at)
        i = int(at * RATE)
        duck[i : i + d_n] = np.minimum(duck[i : i + d_n], duck_shape[: len(duck[i : i + d_n])])
        if beat in (1, 3):
            add(snare, snare_hit, at)
    for eighth in range(8):
        at = b0 + eighth * BEAT / 2
        add(hats, hat_hit * (0.6 if eighth % 2 else 0.3), at)
        # Octave bass: root low, root an octave up, on every eighth.
        note = root - 24 + (12 if eighth % 2 else 0)
        n = int(BEAT / 2 * RATE)
        add(bass, saw(hz(note), n, (1.0,)) * env(n, 0.005, 0.08), at)
    # Pad: the whole chord, one bar long, slow in and out.
    n = int(BEAT * 4 * RATE)
    chord = sum(saw(hz(m), n) for m in (root - 12, third, fifth, root + 12)) / 4
    add(pad, chord * env(n, 0.4, 0.5), b0)
    # Arpeggio in bars 9-16: chord tones up an octave, sixteenths.
    if bar >= 8:
        tones = [root + 12, third + 12, fifth + 12, root + 24]
        for k in range(16):
            n = int(BEAT / 4 * RATE)
            f = hz(tones[[0, 1, 2, 3, 2, 1, 2, 3][k % 8]])
            t = t_of(n)
            note = np.tanh(2 * np.sin(2 * np.pi * f * t)) * np.exp(-t * 14)
            at = b0 + k * BEAT / 4
            add(arp, note, at)
            add(arp, note * 0.35, at + BEAT * 0.75)  # dotted-eighth echo

bass = lowpass(bass, 380) * duck
pad = lowpass(pad, 1400) * duck
arp = lowpass(arp, 2600) * duck
mix = 0.9 * kick + 0.35 * snare + 0.12 * hats + 0.45 * bass + 0.35 * pad + 0.16 * arp
mix = np.tanh(1.2 * mix)
mix *= 0.8 / np.max(np.abs(mix))

with wave.open(OUT, 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((mix * 32767).astype('<i2').tobytes())
print(f'{OUT}: {N / RATE:.1f} s, {os.path.getsize(OUT) / 1e6:.1f} MB')
