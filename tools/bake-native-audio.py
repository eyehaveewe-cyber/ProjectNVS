"""Bake MBean1-derived reed harmonics, ADSR and seeded air to native PCM.
Development only; Godot plays the included bank directly with AudioStreamWAV.
Provenance: MBean1 ecd441f reed-audio.js and chip-audio.js, adapted in src/audio.js.
"""
import math, struct, base64, gzip, json
from pathlib import Path
rate=22050
tones={}
sustains={}
for pitch in range(36,97):
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
    # A cycle-aligned harmonic reed loop for held keyboard notes. The loop is
    # periodic by construction, so there is no click at a repeated sample edge.
    # Godot applies the attack/release envelope at playback, independently for
    # each held voice. One loop has eight complete fundamental periods.
    frames=max(32,round(rate/frequency*8))
    actual_frequency=rate/frames*8
    loop=[]
    for i in range(frames):
        phase=2*math.pi*i/frames*8
        # Same reed partial weights as the finite note; a smooth frequency
        # response approximates the finite bank's low-pass without filter state.
        cutoff=min(2200,frequency*4.8)
        body=sum(math.sin(phase*h)*(1 if h%2 else .22)/h**2.15
                 /math.sqrt(1+(actual_frequency*h/cutoff)**2) for h in range(1,17))
        loop.append(struct.pack('<h',int(max(-1,min(1,body*.19*.76))*32767)))
    sustains[str(pitch)]={'data':base64.b64encode(b''.join(loop)).decode(),
                          'frames':frames,'frequency':actual_frequency}
target=Path(__file__).resolve().parent.parent/'assets/pipe_bank.nvs.gz'
target.write_bytes(gzip.compress(json.dumps({'sample_rate':rate,'tones':tones,'sustains':sustains},separators=(',',':')).encode(),compresslevel=9,mtime=0))
print(f'Native pipe bank: {target.stat().st_size} bytes, {len(tones)} pitches')
