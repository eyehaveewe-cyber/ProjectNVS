"""Bake MBean1-derived reed harmonics, ADSR and seeded air to native PCM.
Development only; Godot plays the included bank directly with AudioStreamWAV.
Provenance: MBean1 ecd441f reed-audio.js and chip-audio.js, adapted in src/audio.js.
"""
import math, struct, base64, gzip, json
from pathlib import Path
rate=22050
tones={}
for pitch in [38,43,50,53,57,60,62,64,67,69,72,74,76,81]:
    frequency=440*2**((pitch-69)/12)
    gate=.48
    release=.2
    phase=0.0
    filtered=0.0
    seed=2166136261
    for ch in f'{pitch}:reed-air':
        seed=((seed^ord(ch))*16777619)&0xffffffff
    alpha=1-math.exp(-2*math.pi*min(2200,frequency*4.8)/rate)
    output=[]
    for i in range(int((gate+release+.025)*rate)):
        t=i/rate
        env=t/.035 if t<.035 else 1-(1-.76)*min(1,(t-.035)/.09) if t<gate else .76*max(0,1-(t-gate)/release)
        vibrato=math.sin(2*math.pi*4.7*t)*7*min(1,t/.18)
        phase+=2*math.pi*frequency*2**(vibrato/1200)/rate
        body=sum(math.sin(phase*h)*(1 if h%2 else .22)/h**2.15 for h in range(1,17))
        filtered+=alpha*(body-filtered)
        seed^=(seed<<13)&0xffffffff;seed^=seed>>17;seed^=(seed<<5)&0xffffffff;seed&=0xffffffff
        noise=seed/2147483648-1
        value=max(-1,min(1,(filtered+noise*.025)*env*.19))
        output.append(struct.pack('<h',int(value*32767)))
    tones[str(pitch)]=base64.b64encode(b''.join(output)).decode()
target=Path(__file__).resolve().parent.parent/'assets/pipe_bank.nvs.gz'
target.write_bytes(gzip.compress(json.dumps({'sample_rate':rate,'tones':tones},separators=(',',':')).encode(),compresslevel=9,mtime=0))
print(f'Native pipe bank: {target.stat().st_size} bytes, {len(tones)} pitches')
