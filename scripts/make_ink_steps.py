"""Rebuild only the six wet ink footsteps, leaving all other game audio intact.

Original procedural foley: soft pressure, a close wet slap and a short sticky
release. All variants use fixed seeds and a short fade to avoid buffer clicks.
Requires NumPy and SciPy, as does make_ink_foley.py.
"""
from pathlib import Path
import wave

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
SR = 44100


def filtered(rng, n, low, high):
    return sosfilt(butter(2, [low, high], btype="bandpass", fs=SR,
                          output="sos"), rng.normal(0, 1, n))


def pulse(t, start, attack, decay):
    q = np.maximum(t - start, 0)
    return (t >= start) * (1 - np.exp(-q / attack)) * np.exp(-q / decay)


def step(seed):
    rng = np.random.default_rng(seed)
    duration = rng.uniform(.19, .225)
    t = np.arange(int(SR * duration)) / SR
    low = filtered(rng, len(t), 100, 580)
    wet = filtered(rng, len(t), 650, 3300)
    fine = filtered(rng, len(t), 1900, 5200)
    pressure = low * pulse(t, .001, .0018, .018) * .65
    slap = wet * pulse(t, .004, .0009, .024) * .95
    release_at = rng.uniform(.048, .065)
    release = wet * pulse(t, release_at, .0016, .022) * .55
    drops = np.zeros_like(t)
    for _ in range(4):
        drops += fine * pulse(t, rng.uniform(.018, .095), .0007, .005) * .24
    # A quiet, quickly damped liquid cavity, beneath the broad wet texture.
    q = np.maximum(t - release_at, 0)
    cavity = np.sin(2 * np.pi * rng.uniform(210, 320) * q) * \
        pulse(t, release_at, .002, .009) * .06
    result = pressure + slap + release + drops + cavity
    result = sosfilt(butter(2, 5100, fs=SR, output="sos"), result)
    result *= rng.uniform(.69, .79) / max(np.max(np.abs(result)), 1e-9)
    result[:110] *= np.linspace(0, 1, 110)
    result[-440:] *= np.linspace(1, 0, 440)
    return result


def write(path, samples):
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SR)
        output.writeframes((np.clip(samples, -.95, .95) * 32767)
                           .astype("<i2").tobytes())


if __name__ == "__main__":
    steps = [step(781024 + i * 197) for i in range(6)]
    for i, samples in enumerate(steps):
        write(ROOT / f"assets/audio/step{i}.wav", samples)
    preview = np.zeros(SR * 4)
    for i, variant in enumerate([0, 3, 1, 4, 2, 5, 0, 4]):
        start = int((.1 + i * .4375) * SR)
        preview[start:start + len(steps[variant])] += steps[variant] * .65
    write(ROOT / "docs/ink_footsteps_preview.wav", preview)
    print("Created six short wet ink steps and preview.")
