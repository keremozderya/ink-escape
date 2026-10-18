"""Original synthetic foley and a quiet, original 58 BPM score. No sampled music."""
from pathlib import Path
import wave, subprocess
import numpy as np
from scipy.signal import butter, sosfilt
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
SR = 22050
rng = np.random.default_rng(1987)
def tone(f,t):
    return np.sin(2*np.pi*f*t) + .26*np.sin(2*np.pi*f*2.01*t)+.08*np.sin(2*np.pi*f*3.98*t)
def save(name,a):
    a=np.clip(a,-.94,.94)
    with wave.open(str(ROOT / (name+'.wav')),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((a*32767).astype('<i2').tobytes())
# Sixteen 4/4 bars, resolving gently into the first chord. All pitches and arrangement original.
beat=60/58; duration=64*beat
score=np.zeros(int(SR*duration))
chords=[(60,64,67),(57,60,64),(53,57,60),(55,59,62)]*4
for bar,chord in enumerate(chords):
    for j,n in enumerate([chord[0]-12,chord[1],chord[2],chord[1]]):
        start=int((bar*4+j)*beat*SR); length=min(int(SR*5),len(score)-start)
        t=np.arange(length)/SR; f=440*2**((n-69)/12)
        note=.06*tone(f,t)*(1-np.exp(-t*45))*np.exp(-t*1.15)
        score[start:start+length]+=note
    if bar%2==0:
        n=chord[2]+12; start=int((bar*4+2.5)*beat*SR); length=min(int(SR*4),len(score)-start)
        t=np.arange(length)/SR;score[start:start+length]+=.025*tone(440*2**((n-69)/12),t)*(1-np.exp(-t*30))*np.exp(-t*.95)
# Quiet room tail; wrap delay for a continuous loop.
score+=np.roll(score,int(.23*SR))*.13+np.roll(score,int(.41*SR))*.08
save('paper_evening',score)
subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(ROOT/'paper_evening.wav'),'-codec:a','libmp3lame','-b:a','96k',str(ROOT/'paper_evening.mp3')],check=True)
(ROOT/'paper_evening.wav').unlink()
print('Original score:',round(duration,2),'seconds; foley assets:',len(list(ROOT.glob('*'))))
