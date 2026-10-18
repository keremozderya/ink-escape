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
def ink(seed,duration=.23,weight=1):
    r=np.random.default_rng(seed);n=int(SR*duration);t=np.arange(n)/SR
    # Broad, damped noise bands only: the previous many sine chirps sounded
    # like squeaks. A low compression and short adhesive pull read as liquid.
    low=band(r,n,85,420);wet=band(r,n,280,1250)
    soft=band(r,n,650,2100)
    press=envelope(t,.002,.009,.028)
    squeeze=envelope(t,.014,.016,.045)
    release_at=r.uniform(.068,.092)*weight
    release=envelope(t,release_at,.007,.024)
    a=1.1*low*press+.65*wet*squeeze+.55*low*release+.14*soft*release
    # Irregular noise grains replace pitched "bubbles". Keep the texture
    # sparse, dark, short, and dry enough for a phone speaker at walking pace.
    for _ in range(3):
        start=r.uniform(.025,.125)
        a+=r.uniform(.15,.24)*wet*envelope(t,start,.003,r.uniform(.006,.012))
    a=sosfilt(butter(2,2400,fs=SR,output='sos'),a)
    a-=a.mean()
    a*=.11/(np.sqrt(np.mean(a*a))+1e-9)
    return a
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
