"""Numory promo soundtrack: a 28-second synthwave cue in A minor at 120 BPM, synthesized (no samples, no copyrighted audio),
with the game's own sound effects (assets/audio/*.wav: the rising note per number, start, wrong, best, tap) placed on the
edit in assets/edit.js, so every tap sounds on the frame it lands.

    python3 score.py      -> assets/gen/soundtrack.wav (48 kHz stereo, -14 LUFS, peaks under -2 dBTP)

Needs numpy, scipy and pyloudnorm. The chords are the game's own loop (tools/make_music.py): Am, F, C, G.

| Time | Music |
|---|---|
| 0-2 | Intro: the clock. Filtered Am pad, a tick-tock on eighths, a sub pulse, a reverse swell into the drop |
| 2-6 | The drop on "tap 1": kick, gated snare, octave bass, pad. Am, F. The taps play the game's notes; the finish lands on 4.0 |
| 6-8 | Title: crash, C, the arpeggio, the hum of the sign lighting |
| 8-10.5 | The Hard round over G, then Am. On the wrong tap (10.5) the music tape-stops |
| 10.5-12 | Silence, the game's buzz, then a riser and a snare roll |
| 12-16 | Modes: Am, F. The three boards fill one sixteenth per number with the game's notes |
| 16-20 | The world: C, G, arpeggio. The rank counter ticks down and lands on 18.0 |
| 20-22 | Breakdown for the chimp sign: no kick, claps, the sign's hum |
| 22-26 | F, G, C, G: the chimp, then the end card |
| 26 | The last hit: kick, snare, crash and an Am stab, ringing out to 28 |
"""
import json
import pathlib
import re
import wave

import numpy as np
import pyloudnorm
from scipy import signal

here = pathlib.Path(__file__).parent
repo = here.parents[2]
EDIT = json.loads(re.search(r'\{.*\}', (here / 'assets' / 'edit.js').read_text(), re.S).group(0))
RATE = 48000
BPM = EDIT['bpm']
BEAT = 60 / BPM
BAR = 4 * BEAT
DUR = EDIT['duration']
N = int(RATE * DUR)
CUT = EDIT['cuts']
rng = np.random.default_rng(20261101)

# MIDI chord tones (root, third, fifth), the game's voicings
CH = {'Am': (57, 60, 64), 'F': (53, 57, 60), 'C': (48, 52, 55), 'G': (55, 59, 62)}
# (start, end, chord); the harmony of the whole cue
HARMONY = [(0, 4, 'Am'), (4, 6, 'F'), (6, 8, 'C'), (8, 10, 'G'), (10, 10.5, 'Am'),
           (12, 14, 'Am'), (14, 16, 'F'), (16, 18, 'C'), (18, 20, 'G'), (20, 22, 'Am'),
           (22, 23, 'F'), (23, 24, 'G'), (24, 25, 'C'), (25, 26, 'G'), (26, 28, 'Am')]
# where the drums play: (start, end, kick?)
DRUMS = [(2, CUT['stop'], True), (CUT['modes'], CUT['chimp'], True), (CUT['chimp'], CUT['chimpDrop'], False), (CUT['chimpDrop'], CUT['final'], True)]


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def t_of(n):
    return np.arange(n) / RATE


def sec(s):
    return int(round(s * RATE))


def saw(f, n, detune=(0.994, 1.0, 1.006), phase=0.0):
    t = t_of(n)
    return sum(2 * ((t * f * d + phase * k) % 1) - 1 for k, d in enumerate(detune)) / len(detune)


def env(n, a, r, hold=None):
    e = np.ones(n)
    ai, ri = sec(a), sec(r)
    if ai:
        e[:ai] = np.linspace(0, 1, ai)
    if ri:
        e[-ri:] *= np.linspace(1, 0, ri) ** 2
    return e


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, 'low', fs=RATE, output='sos'), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, 'high', fs=RATE, output='sos'), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], 'band', fs=RATE, output='sos'), x)


def sweep_lp(x, f0, f1, block=256):
    """A low-pass whose cutoff glides from f0 to f1 (exponentially) over x."""
    y = np.zeros_like(x)
    zi = None
    nb = (len(x) + block - 1) // block
    for b in range(nb):
        f = f0 * (f1 / f0) ** (b / max(1, nb - 1))
        sos = signal.butter(2, min(f, RATE / 2 - 100), 'low', fs=RATE, output='sos')
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        y[b * block:(b + 1) * block], zi = signal.sosfilt(sos, x[b * block:(b + 1) * block], zi=zi)
    return y


class Track:
    def __init__(self):
        self.x = np.zeros((N + RATE * 2, 2))

    def add(self, sound, at, gain=1.0, pan=0.0):
        i = sec(at)
        if i < 0:
            sound, i = sound[-i:], 0
        if sound.ndim == 1:
            l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
            sound = np.stack([sound * l * 1.414, sound * r * 1.414], axis=1)
        end = min(len(self.x), i + len(sound))
        self.x[i:end] += sound[:end - i] * gain


def load_sfx(name):
    with wave.open(str(repo / 'assets' / 'audio' / name)) as w:
        sr, n = w.getframerate(), w.getnframes()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    if sr != RATE:
        g = np.gcd(sr, RATE)
        x = signal.resample_poly(x, RATE // g, sr // g)
    return x


def chord_at(t):
    for a, b, c in HARMONY:
        if a <= t < b:
            return c
    return None


def drums_at(t):
    for a, b, k in DRUMS:
        if a <= t < b - 1e-9:
            return k
    return None


# ---------------------------------------------------------------- sounds
def kick_hit():
    n = sec(0.42)
    t = t_of(n)
    body = np.sin(2 * np.pi * np.cumsum(46 + 110 * np.exp(-t * 32)) / RATE) * np.exp(-t * 7.5)
    click = hp(rng.standard_normal(n), 2500) * np.exp(-t * 300) * 0.35
    return np.tanh(1.6 * (body + click)) * 0.9


def snare_hit():
    n = sec(0.6)
    t = t_of(n)
    noise = bp(rng.standard_normal(n), 900, 9000) * np.exp(-t * 18) * 0.7
    tone = (np.sin(2 * np.pi * 190 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t * 22) * 0.6
    dry = noise + tone
    # 80s gated reverb: a dense 0.22 s tail that stops dead
    ir_n = sec(0.22)
    ir = rng.standard_normal(ir_n) * np.linspace(1, 0.55, ir_n)
    ir[-sec(0.01):] *= np.linspace(1, 0, sec(0.01))
    wet = signal.fftconvolve(dry, ir)[:n] * 0.05
    return dry + lp(wet, 6000)


def clap_hit():
    n = sec(0.3)
    t = t_of(n)
    x = np.zeros(n)
    for k, d in enumerate((0, 0.011, 0.022, 0.034)):
        i = sec(d)
        m = n - i
        x[i:] += bp(rng.standard_normal(m), 1000, 5000) * np.exp(-t_of(m) * (60 if k < 3 else 16))
    return x * 0.6


def hat(open_=False):
    n = sec(0.3 if open_ else 0.06)
    t = t_of(n)
    return hp(rng.standard_normal(n), 7500) * np.exp(-t * (14 if open_ else 80)) * (0.35 if open_ else 0.3)


def crash():
    n = sec(2.6)
    t = t_of(n)
    x = hp(rng.standard_normal(n), 3500) * np.exp(-t * 1.6) * 0.45
    return np.stack([x, np.roll(hp(rng.standard_normal(n), 3500) * np.exp(-t * 1.6) * 0.45, 7)], axis=1)


def boom():
    n = sec(1.6)
    t = t_of(n)
    return np.sin(2 * np.pi * np.cumsum(34 + 60 * np.exp(-t * 9)) / RATE) * np.exp(-t * 2.6) * 0.9


def reverse_swell(length):
    n = sec(length)
    x = hp(rng.standard_normal(n), 2500) * np.linspace(0, 1, n) ** 3 * 0.35
    return sweep_lp(x, 1500, 14000)


def riser(length, f0=200, f1=1600):
    n = sec(length)
    t = t_of(n)
    f = f0 * (f1 / f0) ** (t / length)
    ph = np.cumsum(f) / RATE
    tone = (2 * (ph % 1) - 1) * 0.5 + (2 * ((ph * 1.005) % 1) - 1) * 0.5
    noise = hp(rng.standard_normal(n), 1200)
    x = lp(tone, 4000) * 0.22 + sweep_lp(noise, 800, 12000) * 0.3
    return x * np.linspace(0, 1, n) ** 2


def tick(high):
    n = sec(0.05)
    t = t_of(n)
    f = 2600 if high else 1900
    return (np.sin(2 * np.pi * f * t) + 0.4 * hp(rng.standard_normal(n), 4000)) * np.exp(-t * 120) * 0.28


def hum(length, gate):
    """The buzz of a neon tube: 100 Hz mains hum with harmonics, switched by gate(t) (0 or 1 per sample)."""
    n = sec(length)
    t = t_of(n)
    x = sum(np.sin(2 * np.pi * 100 * k * t) / k for k in range(1, 9)) * 0.5
    x = np.tanh(2 * x) * 0.16
    g = gate(t)
    g = lp(g.astype(float), 400)  # no clicks
    zap = np.zeros(n)
    edges = np.flatnonzero(np.diff((gate(t) > 0.5).astype(int)) > 0)
    for e in edges:
        m = min(n - e, sec(0.04))
        zap[e:e + m] += hp(rng.standard_normal(m), 3000) * np.exp(-t_of(m) * 90) * 0.5
    return x * g + zap


def flicker_gate(dark):
    """dark = [(start, end)] in seconds where the tube is off; on the rest of the time."""
    def g(t):
        on = np.ones_like(t)
        for a, b in dark:
            on[(t >= a) & (t < b)] = 0
        return on
    return g


def pluck(m, length=0.22):
    n = sec(length)
    t = t_of(n)
    f = hz(m)
    x = np.tanh(2.2 * np.sin(2 * np.pi * f * t) + 0.6 * np.sin(4 * np.pi * f * t)) * np.exp(-t * 13)
    return x


# ---------------------------------------------------------------- arrangement
kick_t, snare_t, hats_t, perc_t, bass_t, pad_t, arp_t, fx_t, game_t = (Track() for _ in range(9))
duck = np.ones(len(kick_t.x))
K, S, CL = kick_hit(), snare_hit(), clap_hit()
HC, HO = hat(), hat(True)
d_n = sec(BEAT * 0.9)
duck_shape = 1 - 0.6 * np.exp(-t_of(d_n) * 10)

steps = int(DUR / (BEAT / 4))
for s in range(steps):
    t = s * BEAT / 4
    d = drums_at(t)
    if d is None:
        continue
    beat_pos = s % 16  # sixteenth in the bar
    if d and s % 4 == 0:
        kick_t.add(K, t)
        i = sec(t)
        duck[i:i + d_n] = np.minimum(duck[i:i + d_n], duck_shape[:len(duck[i:i + d_n])])
    if beat_pos in (4, 12):
        (snare_t if d else perc_t).add(S if d else CL, t, 0.9 if d else 0.8)
        if d:
            perc_t.add(CL, t, 0.35)
    if s % 2 == 1:
        hats_t.add(HO if s % 4 == 2 else HC, t, 0.5, pan=0.25)
    if d:
        hats_t.add(HC, t, 0.28 if s % 2 else 0.18, pan=-0.2)

# the intro (0-2): the clock ticking, a sub pulse on the beats
for k in range(8):
    fx_t.add(tick(k % 2 == 0), k * BEAT / 2, 0.9, pan=0.3 if k % 2 else -0.3)
for k in range(4):
    n = sec(0.35)
    tt = t_of(n)
    fx_t.add(np.sin(2 * np.pi * 55 * tt) * np.exp(-tt * 7) * 0.7, k * BEAT)
fx_t.add(reverse_swell(1.5), 2.0 - 1.5, 0.9)

# bass: octave saws on the eighths, where the drums play (and a held note in the intro)
for s in range(int(DUR / (BEAT / 2))):
    t = s * BEAT / 2
    c = chord_at(t)
    if c is None or drums_at(t) is None:
        continue
    root = CH[c][0]
    while root > 45:
        root -= 12
    note = root + (12 if s % 2 else 0)
    n = sec(BEAT / 2)
    bass_t.add(saw(hz(note), n, (0.997, 1.003)) * env(n, 0.004, 0.06), t, 0.55)
n = sec(2.0)
bass_t.add(lp(saw(hz(33), n, (1.0,)), 300) * env(n, 0.5, 0.3), 0, 0.35)

# pad: the chord, every chord span, slow in and out, wide
for a, b, c in HARMONY:
    n = sec(b - a + 0.25)
    root, third, fifth = CH[c]
    notes = (root - 12, third, fifth, root + 12)
    left = sum(saw(hz(m), n, (0.991, 1.0, 1.004), 0.13) for m in notes) / 4
    right = sum(saw(hz(m), n, (0.996, 1.0, 1.009), 0.37) for m in notes) / 4
    e = env(n, 0.03 if a > 0 else 1.6, 0.25)
    pad_t.add(np.stack([left * e, right * e], axis=1), a, 0.5)

# arpeggio: chord tones up an octave on sixteenths, with a dotted-eighth echo, in the title, the world and the end
for a, b in [(6, 8), (16, 20), (22, CUT['final'])]:
    for s in range(int((b - a) / (BEAT / 4))):
        t = a + s * BEAT / 4
        root, third, fifth = CH[chord_at(t)]
        tones = [root + 12, third + 12, fifth + 12, root + 24]
        m = tones[[0, 1, 2, 3, 2, 1, 2, 3][s % 8]]
        p = pluck(m)
        arp_t.add(p, t, 0.32, pan=-0.35)
        arp_t.add(p, t + BEAT * 0.75, 0.13, pan=0.45)

# impacts and swells
for t in (2.0, CUT['title'], CUT['modes'], CUT['chimpDrop'], CUT['end']):
    fx_t.add(crash(), t, 0.8)
for t in (2.0, CUT['title'], CUT['modes'], CUT['chimpDrop']):
    fx_t.add(boom(), t, 0.5)
fx_t.add(reverse_swell(1.0), CUT['title'] - 1.0, 0.8)
fx_t.add(reverse_swell(1.0), CUT['end'] - 1.0, 0.8)
fx_t.add(reverse_swell(0.5), CUT['world'] - 0.5, 0.7)
fx_t.add(riser(0.75), CUT['modes'] - 0.75, 0.9)
fx_t.add(riser(0.5, 300, 1800), CUT['chimpDrop'] - 0.5, 0.7)
# the last hit: the whole band on 26.0, then an Am stab rings out over the end card
FIN = CUT['final']
kick_t.add(K, FIN, 1.15)
snare_t.add(S, FIN, 0.9)
perc_t.add(CL, FIN, 0.5)
fx_t.add(crash(), FIN, 1.0)
fx_t.add(boom(), FIN, 0.9)
n = sec(DUR - FIN + 0.5)
tt = t_of(n)
stab = sum(saw(hz(m), n, (0.992, 1.0, 1.008)) for m in (45, 57, 60, 64, 69, 72, 76)) / 7
stab = sweep_lp(stab, 7000, 500) * np.exp(-tt * 1.4) * np.minimum(1, tt / 0.004)
fx_t.add(np.stack([stab, np.roll(stab, 90)], axis=1), FIN, 0.9)
for k, m in enumerate((69, 72, 76, 81)):
    arp_t.add(pluck(m, 0.6), FIN + k * BEAT / 4, 0.35, pan=(-0.4, 0.4)[k % 2])

# the snare roll into the modes: sixteenths, then thirty-seconds, climbing
roll0 = CUT['modes'] - 0.75
for k in range(10):
    t = roll0 + k * 0.0625 if k < 6 else roll0 + 0.375 + (k - 6) * 0.09375
    perc_t.add(S, t, 0.25 + 0.06 * k)

# the neon signs lighting (the app's Wordmark launch flicker, dark beats in ms: 0-120, 260-330, 480-520, 700-740)
WORDMARK_DARK = [(0, 0.12), (0.26, 0.33), (0.48, 0.52), (0.70, 0.74)]
SIGN_DARK = [(0, 0.06), (0.1, 0.16), (0.24, 0.36), (0.45, 0.5)]
fx_t.add(hum(1.4, flicker_gate(WORDMARK_DARK)), CUT['title'], 0.55)
fx_t.add(hum(2.0, flicker_gate(SIGN_DARK)), CUT['chimp'], 0.6)
fx_t.add(hum(1.2, flicker_gate(WORDMARK_DARK)), CUT['end'], 0.5)

# ---------------------------------------------------------------- the game's own sounds
NOTES = [load_sfx(f'note_{k:02d}.wav') for k in range(1, 16)]
START, WRONG, DONE, BEST, TAP = (load_sfx(f) for f in ('start.wav', 'wrong.wav', 'done.wav', 'best.wav', 'tap.wav'))
for r in (EDIT['hook'], EDIT['fail']):
    game_t.add(START, r['appear'], 0.5)
    for num, t in r['taps']:
        game_t.add(NOTES[num - 1], t, 0.95)
game_t.add(BEST, EDIT['hook']['taps'][-1][1], 0.9)
game_t.add(WRONG, EDIT['fail']['wrong'][1], 1.0)
for b in EDIT['modes']['boards']:
    for k in range(b['count']):
        game_t.add(NOTES[k], b['start'] + k * EDIT['modes']['step'], 0.8, pan=[-0.3, 0, 0.3][EDIT['modes']['boards'].index(b)])
rk = EDIT['rank']
for k in range(rk['ticks']):
    # the counter steps on every sixteenth (the picture does the same), so each tick is a visible jump
    t = rk['start'] + k * (rk['land'] - rk['start']) / rk['ticks']
    game_t.add(TAP, t, 0.8)
game_t.add(DONE, rk['land'], 0.9)
game_t.add(BEST, CUT['final'], 0.8)

# ---------------------------------------------------------------- mix
def stem(tr, lpf=None, hpf=None, ducked=False, gain=1.0):
    x = tr.x.copy()
    if hpf:
        x = hp(x.T, hpf).T
    if lpf:
        x = lp(x.T, lpf).T
    if ducked:
        x *= duck[:, None]
    return x * gain


pad = pad_t.x.copy()
# the intro pad opens up as the drop nears
cut_i = sec(2.0)
pad[:cut_i] = np.stack([sweep_lp(pad[:cut_i, 0], 300, 2500), sweep_lp(pad[:cut_i, 1], 300, 2500)], axis=1)
pad[cut_i:] = lp(pad[cut_i:].T, 1800).T
pad *= duck[:, None]

mix = (stem(kick_t, gain=0.95) + stem(snare_t, gain=0.55) + stem(perc_t, gain=0.5) + stem(hats_t, gain=0.45)
       + stem(bass_t, lpf=420, ducked=True, gain=0.8) + pad * 0.42 + stem(arp_t, lpf=5000, ducked=True, gain=0.5)
       + stem(fx_t, gain=0.7))

# the wrong tap: everything but the game's sounds tape-stops over 0.35 s, then silence until the riser
stop = sec(CUT['stop'])
slow = sec(0.35)
rate = np.linspace(1, 0, slow) ** 1.4
pos = stop + np.cumsum(rate)
tail = np.stack([np.interp(pos, np.arange(len(mix)), mix[:, c]) for c in (0, 1)], axis=1) * np.linspace(1, 0, slow)[:, None]
quiet_end = sec(CUT['modes'] - 0.75)
fx_keep = fx_t.x[stop:quiet_end] * 0.7 + perc_t.x[stop:quiet_end] * 0.5  # the riser and the roll start inside the gap
mix[stop:stop + slow] = tail
mix[stop + slow:quiet_end] = 0
mix[stop:quiet_end] += fx_keep * (np.arange(quiet_end - stop) >= slow)[:, None]

mix += game_t.x * 0.75
# a little glue: soft saturation, then loudness and a peak ceiling
mix = mix[:N + sec(0.0)]
mix = np.tanh(mix * 0.9) / 0.9
fade = sec(0.6)
mix[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2

meter = pyloudnorm.Meter(RATE)
mix = pyloudnorm.normalize.loudness(mix, meter.integrated_loudness(mix), -14.0)


def true_peak(x):
    return np.abs(signal.resample_poly(x, 4, 1, axis=0)).max()


ceiling = 10 ** (-2.0 / 20)
for _ in range(6):
    tp = true_peak(mix)
    if tp <= ceiling:
        break
    # a soft knee limiter on the loudest samples, then re-level
    thr = ceiling * 0.8
    over = np.abs(mix) > thr
    mix[over] = np.sign(mix[over]) * (thr + (ceiling - thr) * np.tanh((np.abs(mix[over]) - thr) / (ceiling - thr)))
    mix = pyloudnorm.normalize.loudness(mix, meter.integrated_loudness(mix), -14.0)
mix *= min(1.0, ceiling / true_peak(mix))

out = here / 'assets' / 'gen' / 'soundtrack.wav'
out.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(out), 'w') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((np.clip(mix, -1, 1) * 32767).astype('<i2').tobytes())
print(f'{out.relative_to(here)}: {len(mix) / RATE:.2f} s, {meter.integrated_loudness(mix):.1f} LUFS, '
      f'true peak {20 * np.log10(true_peak(mix)):.1f} dBTP')
