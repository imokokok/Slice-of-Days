"""Original layered procedural Foley. Python stdlib only; no downloaded recordings.
Regenerate with: python tools/generate_kitchen_audio.py
Replace WAVs with recorded Foley later without changing game logic.
"""
from pathlib import Path
import math, random, struct, wave

DEST = Path(__file__).resolve().parents[1] / 'modules/restaurant/assets/audio'
DEST.mkdir(parents=True, exist_ok=True)
RATE = 22050
LOOPS = {'flame', 'sizzle', 'boil', 'water', 'squeeze', 'pour', 'powder'}
names = sorted(LOOPS) + ['ignite', 'tap', 'pan', 'chop', 'stir', 'stir_wet', 'stir_meat', 'stir_dry', 'stir_hard', 'drop', 'drain', 'wipe', 'paper', 'serve']
for index, name in enumerate(names):
    rng = random.Random(7301 + index)
    duration = 2.4 if name in LOOPS else (0.7 if name in ['drain','serve','ignite'] else 0.28)
    size = int(RATE * duration)
    samples, low, mid = [], 0., 0.
    phase = 0.
    for i in range(size):
        t = i / RATE
        n = rng.uniform(-1, 1)
        low += .025 * (n - low)
        mid += .22 * (n - mid)
        high = n - mid
        bubble = math.sin(2*math.pi*(210*t + 28*math.sin(t*17))) * math.exp(-((t*9)%1)*9)
        if name == 'flame': v = low * 1.7 + mid * .22
        elif name == 'sizzle': v = high * .10 + mid*.35 + (rng.random() < .003) * rng.uniform(-.65,.65)
        elif name == 'boil': v = low*.75 + mid*.19 + bubble*.12
        elif name == 'water': v = mid*.52 + high*.12 + bubble*.07
        elif name == 'pour': v = mid*.30 + bubble*.26
        elif name == 'squeeze': v = low*.50 + bubble*.38 + mid*.2*max(0,math.sin(t*16))
        elif name == 'powder': v = high*.23*(.2+.8*abs(math.sin(t*15)))
        elif name == 'ignite': v = (high*.7*math.exp(-(t%.12)*150) if t<.48 else mid*.5*math.exp(-(t-.48)*12))
        elif name == 'chop': v = (mid*.9 + math.sin(t*2*math.pi*170)*.35 + high*.25)*math.exp(-t*32)
        elif name == 'stir_wet':
            # Soft wet fold: damp pan scrape, vegetable moisture and one quiet slap.
            scrape = mid*.23*(.35+.65*abs(math.sin(t*math.pi*24)))
            slap = low*1.1*math.exp(-((t-.055)/.028)**2)
            v = (scrape+slap+high*.035)*math.exp(-t*5.5)
        elif name == 'stir_meat':
            # Heavier oily contact with a low, short body and restrained crackle.
            thud = low*1.45*math.exp(-((t-.045)/.032)**2)
            oil = high*.075*(rng.random()<.17)*math.exp(-t*4)
            v = thud+mid*.17*math.exp(-t*8)+oil
        elif name == 'stir_dry':
            # Several light grains or crisp pieces brushing a pan.
            ticks = sum(math.sin(t*2*math.pi*f)*a for f,a in [(760,.07),(1210,.045),(1780,.025)])
            v = (ticks+high*.12)*math.exp(-t*17)
        elif name == 'stir_hard':
            # A quiet hard-object knock; deliberately lower than food and pan Foley.
            v = (math.sin(t*2*math.pi*420)*.16+math.sin(t*2*math.pi*910)*.055+high*.07)*math.exp(-t*25)
        elif name in ['pan','stir']:
            v = (sum(math.sin(t*2*math.pi*f)*a for f,a in [(480,.24),(1130,.13),(1960,.05)])+high*.24)*math.exp(-t*(12 if name=='pan' else 20))
        elif name == 'tap': v = (math.sin(t*2*math.pi*1300)*.16+high*.6)*math.exp(-t*70)
        # A short damped food-on-wood thud, without a ringing pitched tone.
        elif name == 'drop': v = (low*1.5*math.exp(-t*48)+mid*.24*math.exp(-t*85)+high*.025*math.exp(-t*170))
        elif name == 'drain': v = (bubble*.32+mid*.25)*(1-t/duration)
        elif name == 'wipe': v = mid*.5*math.sin(math.pi*t/duration)
        elif name == 'paper': v = (high*.25+mid*.20)*math.sin(math.pi*t/duration)**2
        else: v = (math.sin(t*2*math.pi*1320)*.32+math.sin(t*2*math.pi*2112)*.12)*math.exp(-t*7)
        if name not in LOOPS: v *= min(1, t/.003) * min(1, (duration-t)/.018)
        samples.append(v)
    if name in LOOPS:
        fade = int(.05*RATE)
        # Overlap tail into the start, then remove the duplicated tail.
        for i in range(fade):
            a=i/fade
            samples[i]=samples[-fade+i]*(1-a)+samples[i]*a
        samples=samples[:-fade]
    peak=max(abs(x) for x in samples)
    gain=min(1., .78/max(peak, .001))
    pcm=b''.join(struct.pack('<h',round(max(-1,min(1,x*gain))*32767)) for x in samples)
    with wave.open(str(DEST/(name+'.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm)
    print(name, len(samples), 'peak', round(peak*gain,3))
