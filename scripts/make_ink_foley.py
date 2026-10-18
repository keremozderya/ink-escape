"""Deterministic original viscous-ink foley. No dry taps or repeating pitched beeps."""
from pathlib import Path
import wave
import numpy as np
from scipy.signal import butter, sosfilt
ROOT=Path(__file__).resolve().parents[1]
SR=44100
AUDIO=ROOT/'assets/audio'
def save(name,a):
    a=np.tanh(a*1.15)/1.15
    # Every sample starts/ends at zero; no buffer-edge click.
    fade=min(int(SR*.005),len(a)//4)
    a[:fade]*=np.linspace(0,1,fade);a[-fade:]*=np.linspace(1,0,fade)
    with wave.open(str(AUDIO/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((np.clip(a,-.97,.97)*32767).astype('<i2').tobytes())
    return a
def band(rng,n,lo,hi):
    return sosfilt(butter(2,[lo,hi],fs=SR,btype='bandpass',output='sos'),rng.normal(0,1,n))
def envelope(t,start,rise,decay):
    q=np.maximum(t-start,0)
    return (t>=start)*(1-np.exp(-q/rise))*np.exp(-q/decay)
def ink(seed,duration=.28,weight=1):
    r=np.random.default_rng(seed);n=int(SR*duration);t=np.arange(n)/SR
    # Soft, thick compression, then wet adhesion/release: two distinct textures.
    low=band(r,n,100,760);mid=band(r,n,500,2700);air=band(r,n,1700,5200)
    impact=envelope(t,.007,.002,.028)
    squeeze=envelope(t,.022,.012,.065)
    release=envelope(t,.095+r.uniform(-.012,.012),.004,.035)
    a=.63*low*impact+.35*mid*squeeze+.19*air*release+.45*low*release
    # Small damped bubbles with random size/lifetime, not a musical note.
    for j in range(r.integers(8,14)):
        start=r.uniform(.018,.19);life=r.uniform(.009,.028);tt=np.maximum(t-start,0)
        f=r.uniform(450,1550)/weight
        phase=2*np.pi*(f*tt-f*.55*tt*tt/life)
        bubble=np.sin(phase)*(tt>0)*(1-np.exp(-tt/.0012))*np.exp(-tt/life)
        a+=r.uniform(.018,.06)*bubble
    # Tiny dispersed droplets make the tail organic, keeping harsh highs quiet.
    for _ in range(3):
        start=r.uniform(.07,.17);a+=.12*mid*envelope(t,start,.0015,.009)
    a=sosfilt(butter(2,4700,fs=SR,output='sos'),a)
    return a/(np.max(np.abs(a))+1e-9)*r.uniform(.70,.82)
steps=[]
for i in range(6):steps.append(save('step'+str(i),ink(88231+i*173,weight=1+(i%2)*.08)))
save('land',ink(1239,.34,1.25)*1.05)
save('capture',ink(1241,.43,1.1)*.8)
save('pickup',ink(1261,.32,.85)*.70)
save('ballRelease',ink(1271,.16,.75)*.42)
for name,seed,duration in [('commit',32,.2),('invalid',33,.14),('dissolve',34,.48),('gate',35,.62),('start',36,.36),('crumb',37,.12),('death',38,.65)]:
    r=np.random.default_rng(seed);n=int(SR*duration);t=np.arange(n)/SR
    paper=band(r,n,700,4200);dark=band(r,n,100,1200)
    if name=='commit':a=.27*paper*envelope(t,.005,.002,.02)+.2*dark*envelope(t,.025,.004,.045)
    elif name=='invalid':a=.18*paper*envelope(t,.002,.008,.032)
    elif name=='crumb':a=.26*paper*envelope(t,.003,.001,.014)
    elif name=='dissolve':a=.18*dark*np.sin(np.pi*np.minimum(t/duration,1))**2+.08*paper*envelope(t,.02,.04,.11)
    elif name=='gate':a=.22*paper*np.sin(np.pi*t/duration)**1.8*(.6+.4*np.sin(2*np.pi*9*t)**2)+.13*dark*envelope(t,.03,.02,.2)
    elif name=='death':a=.3*dark*envelope(t,.01,.016,.12)+.09*paper*envelope(t,.09,.025,.16)
    else:a=.17*paper*np.sin(np.pi*t/duration)**2*(.6+.4*np.sin(2*np.pi*6*t)**2)
    save(name,a)
# Soft graphite on fibrous paper; loop ends meet without a click.
r=np.random.default_rng(91);t=np.arange(SR*2)/SR
pencil=band(r,len(t),1100,5800)*(.075+.025*np.sin(2*np.pi*11*t)+.015*np.sin(2*np.pi*37*t))
save('pencil',pencil)
preview=np.zeros(int(SR*4.2))
for i in range(8):
    sample=steps[[0,3,1,4,2,5,0,4][i]]*.65;start=int((.12+i*.4375)*SR);preview[start:start+len(sample)]+=sample
out=ROOT/'docs/ink_footsteps_preview.wav';out.parent.mkdir(exist_ok=True)
with wave.open(str(out),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((preview*32767).astype('<i2').tobytes())
print('6 viscous-ink footsteps, 9 material foley effects, pencil loop and preview created.')
