import pathlib,json,math,wave,struct,random
P=pathlib.Path(__file__).resolve().parents[2];out=P/'art/memories';out.mkdir(parents=True,exist_ok=True)
rooms=json.loads((P/'data/meta/memories.json').read_text(encoding='utf-8'))['rooms']
for r in rooms:
 n=r['day'];role=r['role'];color='#'+r['accent']
 parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1000" viewBox="0 0 1400 1000">','<rect width="1400" height="1000" fill="#e8dec5"/>','<rect x="36" y="36" width="1328" height="928" fill="none" stroke="#a8a493" stroke-width="3"/>']
 if role=='A':
  # Different visual layers on the same translucent paper format.
  parts += [f'<rect x="140" y="120" width="1120" height="670" fill="{color}" opacity=".7"/>', '<path d="M140 630 L450 320 L660 550 L880 240 L1260 570 L1260 790 L140 790Z" fill="#354f54" opacity=".7"/>']
  for i in range(n+1):parts.append(f'<rect x="{230+i*113}" y="{200+i%3*135}" width="160" height="275" fill="#e8dcc3" opacity=".5" transform="rotate({-7+i*2} 700 500)"/>')
  parts.append(f'<circle cx="1020" cy="270" r="{70+n*4}" fill="#d9b16d" opacity=".7"/>')
 else:
  for j in range(7):
   y=160+j*89
   parts.append(f'<path d="M110 {y} H1290" stroke="#acae9a" stroke-width="2"/>')
   pts=' '.join(f'{x},{y+math.sin(x*.023+n+j)*14*math.sin(x*.006+j)**2}' for x in range(130,1280,4))
   parts.append(f'<polyline points="{pts}" fill="none" stroke="{color if j!=n-1 else "#324c52"}" stroke-width="{3 if j!=n-1 else 7}"/>')
 parts += [f'<text x="110" y="887" font-family="serif" font-size="36" fill="#3c5256">{role} / {n:02d}</text>',f'<text x="1090" y="887" font-family="serif" font-size="28" fill="#596963">SOLMERE</text>','</svg>']
 (out/f'{r["id"]}.svg').write_text(''.join(parts),encoding='utf-8')
 # Original synthesized environmental placeholders, deliberately quiet; no cloned dialogue.
 rng=random.Random(role+str(n));rate=22050;duration=8;pcm=[]
 for i in range(rate*duration):
  t=i/rate;noise=rng.uniform(-1,1);env=min(t*3,1,(duration-t)*3)
  if role=='A':
   if n==1:v=math.sin(t*2*math.pi*700)*(.10 if t%2<.13 else 0)+noise*.008
   elif n==2:v=noise*.03+(math.sin(t*2*math.pi*110)*.025)
   elif n==3:v=noise*(.03+.015*math.sin(t*3))
   elif n==4:v=noise*(.035+.025*math.sin(t*.8))
   elif n==5:v=noise*(.08 if t%1<.013 else .002)
   elif n==6:v=noise*(.04 if t%.27<.012 else .007)+math.sin(t*2*math.pi*70)*.01
   else:v=noise*.004
  else:
   beat=t%(0.4+n*.031);v=math.sin(t*2*math.pi*(240+n*95))*math.exp(-beat*38)*.07+noise*.004
  pcm.append(struct.pack('<h',int(max(-1,min(1,v*env))*32767)))
 with wave.open(str(out/f'{r["id"]}.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(pcm))
print('14 paper layers and 14 original environmental stems created')
