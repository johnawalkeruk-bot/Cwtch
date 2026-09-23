"""Generate original, deterministic environmental sound effects. Run with Python 3."""
import math
import random
import wave
from array import array
from pathlib import Path

RATE = 22050
OUT = Path(__file__).parent / 'audio' / 'ambience'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(4719)

def save(name, samples, loop=False):
    if loop:
        # Crossfade the last second into the first; no abrupt noise seam.
        n = RATE
        for i in range(n):
            a = i / n
            samples[i] = samples[-n+i] * (1-a) + samples[i] * a
        samples = samples[:-n]
    pcm = array('h', (int(max(-.95, min(.95, v)) * 32767) for v in samples))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(pcm.tobytes())

for name in ('wind', 'rain', 'thunder', 'stream'):
    duration = 25 if name != 'thunder' else 9
    low = deep = 0.0
    samples = []
    for i in range(RATE * duration):
        t = i / RATE
        white = rng.uniform(-1, 1)
        low += .035 * (white-low)
        deep += .006 * (white-deep)
        if name == 'wind':
            value = (low * 1.7 + white * .025) * (.55 + .2*math.sin(t*.73) + .13*math.sin(t*1.3))
        elif name == 'rain':
            value = (white*.23 + low*.5) * (.85+.1*math.sin(t*.4))
        elif name == 'stream':
            value = (low*1.5 + white*.12) * (.75+.15*math.sin(t*2.3)) + .025*math.sin(math.tau*(420*t+18*math.sin(t*3)))
        else:
            envelope = min(1, t*12) * math.exp(-t*.48) * min(1, (duration-t)*2)
            value = (deep*6 + low*.7 + white*.045) * envelope
        samples.append(value)
    save(name, samples, name != 'thunder')

for name in ('birds', 'crickets'):
    samples = [0.0] * (RATE*25)
    count = 32 if name == 'birds' else 130
    for _ in range(count):
        start = rng.uniform(.3, 24)
        length = rng.uniform(.09, .3) if name == 'birds' else .065
        frequency = rng.uniform(1800, 3300) if name == 'birds' else 4200
        phase = 0.0
        for j in range(int(length*RATE)):
            index = int(start*RATE)+j
            if index >= len(samples):
                break
            t = j/RATE
            phase += math.tau*(frequency + 650*math.sin(t*18))/RATE
            samples[index] += .13*math.sin(phase)*math.sin(math.pi*t/length)**2
    save(name, samples, True)
print('Generated wind, rain, thunder, birds and crickets.')
