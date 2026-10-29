"""Render the editable MBean1 Frog Lantern Rag score into the Godot WAV.

MBean1's catalog has no banjo, so its guitar tracks are notation proxies. This
local deterministic Karplus-Strong model is not MBean1's audio renderer and is
not a recording of an acoustic instrument. Only numpy and the Python stdlib are
required. Notes, duration, tempo and velocities come from the validated score.
"""
import json, math, wave
from pathlib import Path
import numpy as np
root = Path(__file__).resolve().parents[1]
project = json.loads((root/'assets/frog-lantern-rag.mbean.json').read_text())
rate = 22050
seconds = project['bars'] * 4 * 60 / project['bpm']
total = math.ceil((seconds + 0.25) * rate)
mix = np.zeros(total, dtype=np.float64)
rng = np.random.default_rng(29031)
notes = 0
for track_index, track in enumerate(project['tracks']):
    for event in track['notes']:
        notes += 1
        pitch, velocity = event['pitch'], event['velocity']
        hz = 440.0 * 2 ** ((pitch - 69) / 12)
        period = max(8, round(rate/hz - 0.5))
        duration = min(1.25 if track_index != 2 else 1.6, event['durationTicks']/480*60/project['bpm'] + 0.45)
        count = int(duration*rate)
        excitation = rng.uniform(-1, 1, period)
        excitation -= excitation.mean()
        ring = excitation.copy()
        out = np.empty(count)
        last = 0.0
        for i in range(count):
            k = i % period
            current = ring[k]
            out[i] = current
            ring[k] = (current + last) * (0.498 if track_index != 2 else 0.499)
            last = current
        # A short banjo-head resonance and a gentle attack smooth discontinuities.
        t = np.arange(count) / rate
        body = np.sin(2*np.pi*(265 if track_index != 2 else 115)*t) * np.exp(-24*t)
        attack = np.minimum(1.0, t*250)
        decay = np.exp(-t*(2.5 if track_index != 2 else 1.6))
        sound = (out*0.82 + body*0.08)*attack*decay
        release = min(int(.06*rate), count)
        sound[-release:] *= np.linspace(1,0,release)
        gain = [0.44,0.22,0.32][track_index] * velocity
        start = round(event['startTick']/480*60/project['bpm']*rate)
        mix[start:start+count] += sound[:min(count,total-start)]*gain
peak = float(np.max(np.abs(mix)))
if peak > 0.88: mix *= 0.88/peak
# Short fade removes discontinuities at the tail, leaving a complete cadence.
fade = int(.12*rate)
mix[-fade:] *= np.linspace(1,0,fade)
pcm = np.asarray(np.clip(mix,-1,1)*32767,dtype='<i2')
with wave.open(str(root/'assets/frog-lantern-rag.wav'),'wb') as output:
    output.setnchannels(1); output.setsampwidth(2); output.setframerate(rate); output.writeframes(pcm.tobytes())
print(json.dumps({'notes':notes,'seconds':round(len(mix)/rate,2),'sample_rate':rate,'peak':round(float(np.max(np.abs(mix))),4),'rms':round(float(np.sqrt(np.mean(mix**2))),4),'render':'local physical string model, not MBean1 renderer'}))
