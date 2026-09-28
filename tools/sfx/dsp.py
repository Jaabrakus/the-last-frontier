"""Shared DSP helpers for Frontier's procedural sound effects (numpy + stdlib only).

Every family script in tools/sfx/ imports from here. Coordination rule: only ADD
functions; never rename or change the signature of an existing one (other family
scripts rely on them). Family-specific synthesis belongs in the family script.

Conventions
- Signals are float64 numpy arrays at SR (44.1 kHz), mono shape (n,), stereo (n, 2).
- Times are in seconds, frequencies in Hz, levels in dB unless a name says "lin".
- Random generators are numpy Generators (see `rng`) so every variant is seeded.
"""
from __future__ import annotations

import math
import os
import wave

import numpy as np

SR = 44100


# --------------------------------------------------------------------------- basics

def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def nsamp(dur: float, sr: int = SR) -> int:
    return max(int(round(dur * sr)), 0)


def taxis(n: int, sr: int = SR) -> np.ndarray:
    return np.arange(n) / sr


def db2lin(db: float) -> float:
    return 10.0 ** (db / 20.0)


def lin2db(x: float) -> float:
    return 20.0 * math.log10(max(abs(x), 1e-12))


def white(n: int, r: np.random.Generator) -> np.ndarray:
    return r.standard_normal(n)


def peak_norm(x: np.ndarray, peak: float = 1.0) -> np.ndarray:
    """Scale to a linear peak (1.0 by default). Silent input is returned as is."""
    m = np.max(np.abs(x)) if len(x) else 0.0
    return x * (peak / m) if m > 0 else x


def place(dst: np.ndarray, src: np.ndarray, t: float, gain: float = 1.0, sr: int = SR) -> np.ndarray:
    """Mix `src` into `dst` in place, starting at time t (s). Overhang is dropped."""
    i = nsamp(t, sr)
    if i >= len(dst) or len(src) == 0:
        return dst
    if i < 0:
        src = src[-i:]
        i = 0
    k = min(len(src), len(dst) - i)
    dst[i:i + k] += gain * src[:k]
    return dst


# --------------------------------------------------------------------------- envelopes

def exp_env(n: int, tau: float, sr: int = SR) -> np.ndarray:
    return np.exp(-taxis(n, sr) / tau)


def ar_env(n: int, attack: float, tau: float, sr: int = SR) -> np.ndarray:
    """Raised-cosine attack of `attack` s, then exponential decay with time constant tau."""
    t = taxis(n, sr)
    env = np.exp(-np.maximum(t - attack, 0.0) / tau)
    if attack > 0:
        a = t < attack
        env[a] = 0.5 - 0.5 * np.cos(np.pi * t[a] / attack)
    return env


def fade_in(x: np.ndarray, dur: float, sr: int = SR) -> np.ndarray:
    k = min(nsamp(dur, sr), len(x))
    if k > 0:
        w = 0.5 - 0.5 * np.cos(np.pi * np.arange(k) / k)
        x[:k] *= w if x.ndim == 1 else w[:, None]
    return x


def fade_out(x: np.ndarray, dur: float, sr: int = SR) -> np.ndarray:
    k = min(nsamp(dur, sr), len(x))
    if k > 0:
        w = 0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k)
        x[-k:] *= w if x.ndim == 1 else w[:, None]
    return x


def smooth_noise(n: int, rate: float, r: np.random.Generator, sr: int = SR) -> np.ndarray:
    """Band-limited random control signal in [-1, 1] that wanders at about `rate` Hz."""
    k = max(int(n * rate / sr) + 4, 4)
    pts = r.uniform(-1.0, 1.0, k)
    xp = np.linspace(0, n, k)
    y = np.interp(np.arange(n), xp, pts)
    # one cheap smoothing pass (moving average of one control period)
    w = max(int(sr / rate / 2), 1)
    if w > 1 and n > w:
        y = np.convolve(y, np.ones(w) / w, mode="same")
    return y


# --------------------------------------------------------------------------- FFT tools

def _nfft(n: int) -> int:
    return 1 << max(int(n - 1).bit_length(), 1)


def fftconvolve(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Linear (causal) convolution, full length len(a)+len(b)-1."""
    n = len(a) + len(b) - 1
    nf = _nfft(n)
    return np.fft.irfft(np.fft.rfft(a, nf) * np.fft.rfft(b, nf), nf)[:n]


def convolve_same(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """Causal convolution truncated to len(x)."""
    return fftconvolve(x, ir)[:len(x)]


def fft_band(x: np.ndarray, lo: float | None = None, hi: float | None = None,
             order: int = 2, sr: int = SR) -> np.ndarray:
    """Zero-phase Butterworth-magnitude band shaping (use on noise before enveloping)."""
    n = len(x)
    nf = _nfft(2 * n)
    f = np.fft.rfftfreq(nf, 1.0 / sr)
    h = np.ones_like(f)
    if hi is not None:
        h /= np.sqrt(1.0 + (f / hi) ** (2 * order))
    if lo is not None:
        h /= np.sqrt(1.0 + (lo / np.maximum(f, 1e-6)) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x, nf) * h, nf)[:n]


def pink(n: int, r: np.random.Generator, sr: int = SR) -> np.ndarray:
    """1/f noise via spectral shaping, unit RMS."""
    nf = _nfft(n)
    f = np.fft.rfftfreq(nf, 1.0 / sr)
    X = np.fft.rfft(r.standard_normal(nf))
    X /= np.sqrt(np.maximum(f, 20.0))
    y = np.fft.irfft(X, nf)[:n]
    return y / (np.std(y) + 1e-12)


# --------------------------------------------------------------------------- IIR filters (causal)

def biquad_coeffs(kind: str, f0: float, q: float = 0.7071, gain_db: float = 0.0, sr: int = SR):
    """RBJ cookbook biquad. kind: lp, hp, bp (0 dB peak), peak, lowshelf, highshelf."""
    f0 = min(max(f0, 1.0), sr * 0.49)
    w0 = 2.0 * math.pi * f0 / sr
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * q)
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind in ("lowshelf", "highshelf"):
        s = 2 * math.sqrt(A) * alpha
        if kind == "lowshelf":
            b = [A * ((A + 1) - (A - 1) * cw + s), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - s)]
            a = [(A + 1) + (A - 1) * cw + s, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - s]
        else:
            b = [A * ((A + 1) + (A - 1) * cw + s), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - s)]
            a = [(A + 1) - (A - 1) * cw + s, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - s]
    else:
        raise ValueError(kind)
    a0 = a[0]
    return [v / a0 for v in b], [1.0, a[1] / a0, a[2] / a0]


def biquad(x: np.ndarray, b, a) -> np.ndarray:
    """Direct form II transposed biquad (per-sample loop; fine for short SFX)."""
    b0, b1, b2 = b
    _, a1, a2 = a
    z1 = z2 = 0.0
    out = [0.0] * len(x)
    for i, xi in enumerate(x.tolist()):
        yi = b0 * xi + z1
        z1 = b1 * xi - a1 * yi + z2
        z2 = b2 * xi - a2 * yi
        out[i] = yi
    return np.asarray(out)


def _butter_qs(order: int):
    return [1.0 / (2.0 * math.sin((2 * k - 1) * math.pi / (2 * order))) for k in range(1, order // 2 + 1)]


def lowpass(x: np.ndarray, fc: float, order: int = 2, sr: int = SR) -> np.ndarray:
    """Causal Butterworth lowpass (even order, cascaded biquads)."""
    for q in _butter_qs(max(order, 2)):
        x = biquad(x, *biquad_coeffs("lp", fc, q, sr=sr))
    return x


def highpass(x: np.ndarray, fc: float, order: int = 2, sr: int = SR) -> np.ndarray:
    """Causal Butterworth highpass (even order, cascaded biquads)."""
    for q in _butter_qs(max(order, 2)):
        x = biquad(x, *biquad_coeffs("hp", fc, q, sr=sr))
    return x


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2, sr: int = SR) -> np.ndarray:
    """Causal band limit: highpass at lo then lowpass at hi."""
    return lowpass(highpass(x, lo, order, sr), hi, order, sr)


def resonator(x: np.ndarray, f0: float, q: float, sr: int = SR) -> np.ndarray:
    """Constant-peak-gain two-pole bandpass resonance."""
    return biquad(x, *biquad_coeffs("bp", f0, q, sr=sr))


def svf(x: np.ndarray, fc, q: float = 0.7071, mode: str = "lp", sr: int = SR) -> np.ndarray:
    """Topology-preserving state-variable filter with per-sample cutoff.

    fc: scalar or array (len(x)). mode: lp, bp, hp.
    """
    n = len(x)
    fc = np.broadcast_to(np.clip(np.asarray(fc, dtype=float), 5.0, sr * 0.45), (n,))
    g = np.tan(np.pi * fc / sr)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1 = ic2 = 0.0
    out = [0.0] * n
    sel = {"lp": 0, "bp": 1, "hp": 2}[mode]
    for i, (xi, c1, c2, c3) in enumerate(zip(x.tolist(), a1.tolist(), a2.tolist(), a3.tolist())):
        v3 = xi - ic2
        v1 = c1 * ic1 + c2 * v3
        v2 = ic2 + c2 * ic1 + c3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        out[i] = v2 if sel == 0 else (v1 if sel == 1 else xi - k * v1 - v2)
    return np.asarray(out)


# --------------------------------------------------------------------------- oscillators / modal

def sine_sweep(n: int, f, phase: float = 0.0, sr: int = SR) -> np.ndarray:
    """Sine with instantaneous frequency f (scalar or array of len n)."""
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    ph = phase + 2.0 * np.pi * np.cumsum(f) / sr
    return np.sin(ph)


def damped_sine(dur: float, f, tau: float, attack: float = 0.001, phase: float = 0.0,
                sr: int = SR) -> np.ndarray:
    n = nsamp(dur, sr)
    return sine_sweep(n, f, phase, sr) * ar_env(n, attack, tau, sr)


def modal_ir(freqs, taus, amps, dur: float, r: np.random.Generator | None = None,
             sr: int = SR) -> np.ndarray:
    """Sum of exponentially decaying sinusoids (impulse response of a modal body)."""
    n = nsamp(dur, sr)
    t = taxis(n, sr)
    y = np.zeros(n)
    for i, (f, tau, a) in enumerate(zip(freqs, taus, amps)):
        ph = r.uniform(0, 2 * np.pi) if r is not None else 0.0
        y += a * np.sin(2 * np.pi * f * t + ph) * np.exp(-t / tau)
    return y


def mallet(width: float, sr: int = SR) -> np.ndarray:
    """Half-sine contact pulse; a wider pulse is a softer strike (fewer highs)."""
    k = max(nsamp(width, sr), 2)
    return np.sin(np.pi * (np.arange(k) + 0.5) / k)


def strike(freqs, taus, amps, dur: float, contact: float = 0.001,
           r: np.random.Generator | None = None, noise: float = 0.0, sr: int = SR) -> np.ndarray:
    """Modal body excited by a mallet pulse (optionally roughened with noise)."""
    ex = mallet(contact, sr)
    if noise > 0 and r is not None:
        ex = ex * (1.0 + noise * r.standard_normal(len(ex)))
    return convolve_same(np.concatenate([ex, np.zeros(nsamp(dur, sr))]), modal_ir(freqs, taus, amps, dur, r, sr))[:nsamp(dur, sr)]


# --------------------------------------------------------------------------- friction

def stick_slip_train(dur: float, rate, r: np.random.Generator, jitter: float = 0.15,
                     amp=None, amp_jitter: float = 0.3, sr: int = SR) -> np.ndarray:
    """Impulse train of slip events for creaks/groans.

    rate: slips per second, scalar or callable rate(t). amp: None, scalar or callable amp(t).
    Each period is jittered by +-jitter (relative), each impulse by +-amp_jitter.
    Filter/convolve the result with resonators to get a creak.
    """
    n = nsamp(dur, sr)
    y = np.zeros(n)
    t = 0.0
    rf = rate if callable(rate) else (lambda _t, _r=rate: _r)
    af = amp if callable(amp) else (lambda _t, _a=(1.0 if amp is None else amp): _a)
    while True:
        rt = max(rf(t), 1.0)
        t += (1.0 / rt) * (1.0 + jitter * r.uniform(-1, 1))
        i = int(t * sr)
        if i >= n:
            break
        y[i] += af(t) * (1.0 + amp_jitter * r.uniform(-1, 1))
    return y


# --------------------------------------------------------------------------- finishing / IO

def dc_block(x: np.ndarray, fc: float = 20.0, sr: int = SR) -> np.ndarray:
    """Remove DC / subsonic rumble with a gentle causal highpass."""
    if x.ndim == 2:
        return np.stack([dc_block(x[:, c], fc, sr) for c in range(x.shape[1])], axis=1)
    return highpass(x, fc, 2, sr)


def trim(x: np.ndarray, thresh_db: float = -60.0, lead: bool = True, tail: bool = True,
         pad: float = 0.002, sr: int = SR) -> np.ndarray:
    """Trim leading/trailing samples quieter than thresh_db relative to the peak."""
    mono = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    pk = mono.max() if len(mono) else 0.0
    if pk <= 0:
        return x
    idx = np.nonzero(mono > pk * db2lin(thresh_db))[0]
    p = nsamp(pad, sr)
    a = max(idx[0] - p, 0) if lead else 0
    b = min(idx[-1] + p + 1, len(x)) if tail else len(x)
    return x[a:b]


def finalize(x: np.ndarray, peak_db: float = -1.0, fade: float = 0.02, lead_trim: bool = True,
             thresh_db: float = -60.0, hp: float | None = 20.0, sr: int = SR) -> np.ndarray:
    """DC-block, trim silence, short fade-out, peak-normalize to peak_db dBFS."""
    x = np.asarray(x, dtype=float)
    if hp:
        x = dc_block(x, hp, sr)
    x = trim(x, thresh_db, lead=lead_trim, tail=True, sr=sr)
    x = fade_out(x.copy(), fade, sr)
    if lead_trim:
        x = fade_in(x, 0.0005, sr)
    return peak_norm(x, db2lin(peak_db))


def write_wav(path: str, x: np.ndarray, sr: int = SR, dither: bool = True, seed: int = 0) -> str:
    """Write 16-bit PCM WAV (mono (n,) or stereo (n, 2)) with TPDF dither; never clips."""
    x = np.asarray(x, dtype=float)
    ch = 1 if x.ndim == 1 else x.shape[1]
    s = x * 32767.0
    if dither:
        g = np.random.default_rng(seed)
        s = s + g.uniform(-0.5, 0.5, s.shape) + g.uniform(-0.5, 0.5, s.shape)
    s = np.clip(np.round(s), -32768, 32767).astype("<i2")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(s.tobytes())
    return path


def read_wav(path: str):
    """Read a 16-bit PCM WAV -> (float array (n,) or (n, ch), sr)."""
    with wave.open(path, "rb") as w:
        ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
        d = np.frombuffer(w.readframes(n), dtype="<i2").astype(float) / 32768.0
    return (d.reshape(-1, ch) if ch > 1 else d), sr


# --------------------------------------------------------------------------- strings / loops (added by bow.py)

def karplus_strong(f0: float, dur: float, t60: float, damp: float = 0.5, excite=None,
                   fmul=None, r: np.random.Generator | None = None, sr: int = SR) -> np.ndarray:
    """Karplus-Strong plucked string with a fractional (linear-interpolated) delay.

    f0: fundamental (Hz). t60: time for the fundamental to fall 60 dB (s).
    damp: 0..0.95 one-pole loop lowpass (higher = darker, highs die faster).
    excite: signal fed into the loop (default: one period of uniform noise).
    fmul: optional pitch multiplier, scalar or per-sample array (held at its last value),
          e.g. 1 + 0.03 * exp(-t / 0.012) for a pitch that settles after the pluck.
    """
    n = nsamp(dur, sr)
    if excite is None:
        g = r if r is not None else np.random.default_rng(0)
        excite = g.uniform(-1.0, 1.0, max(int(sr / f0), 2))
    ex = np.zeros(n)
    k = min(len(excite), n)
    ex[:k] = np.asarray(excite, dtype=float)[:k]
    fm = np.ones(n)
    if fmul is not None:
        fa = np.atleast_1d(np.asarray(fmul, dtype=float))
        m = min(len(fa), n)
        fm[:m] = fa[:m]
        fm[m:] = fa[m - 1]
    b = min(max(damp, 0.0), 0.95)
    period = sr / (f0 * fm)                               # samples per loop pass
    dly = np.maximum(period - b / (1.0 - b), 1.01)        # minus the lowpass phase delay
    gain = 10.0 ** (-3.0 * (period / sr) / max(t60, 1e-4))
    y = [0.0] * n
    s = 0.0
    for i, (e, d, gi) in enumerate(zip(ex.tolist(), dly.tolist(), gain.tolist())):
        pos = i - d
        v = 0.0
        if pos >= 0.0:
            j = int(pos)
            fr = pos - j
            v = y[j] * (1.0 - fr) + y[j + 1] * fr
        s = (1.0 - b) * v + b * s
        y[i] = e + gi * s
    return np.asarray(y)


def loop_xfade(x: np.ndarray, xfade: float, sr: int = SR) -> np.ndarray:
    """Seamless loop: equal-power crossfade the last `xfade` s into the start.

    Returns len(x) - nsamp(xfade) samples; the wrap from the last sample to the
    first continues the original signal, so there is no click at the loop point.
    """
    k = nsamp(xfade, sr)
    n = len(x) - k
    th = (np.arange(k) / k) * (np.pi / 2.0)
    fi, fo = np.sin(th), np.cos(th)
    if x.ndim == 2:
        fi, fo = fi[:, None], fo[:, None]
    y = np.array(x[:n], dtype=float, copy=True)
    y[:k] = x[:k] * fi + x[n:n + k] * fo
    return y


def write_wav_loop(path: str, x: np.ndarray, loop_start: int = 0, loop_end: int | None = None,
                   sr: int = SR, dither: bool = True, seed: int = 0) -> str:
    """write_wav plus a RIFF 'smpl' chunk holding one forward loop.

    loop_start/loop_end are sample frames; loop_end is inclusive per the smpl spec
    (default: last frame). Godot's importer reads it with loop mode "Detect From WAV";
    game code should still set AudioStreamWAV.loop_mode/loop_end (= frame count).
    """
    import struct
    write_wav(path, x, sr, dither, seed)
    end = (len(x) - 1) if loop_end is None else int(loop_end)
    body = struct.pack("<9I", 0, 0, int(round(1e9 / sr)), 60, 0, 0, 0, 1, 0)
    body += struct.pack("<6I", 0, 0, int(loop_start), end, 0, 0)   # id, forward, start, end, frac, infinite
    with open(path, "r+b") as f:
        f.seek(0, 2)
        f.write(b"smpl" + struct.pack("<I", len(body)) + body)
        riff = f.tell() - 8
        f.seek(4)
        f.write(struct.pack("<I", riff))
    return path


# --------------------------------------------------------------------------- spectral tools (added by ambience.py)

def colored_noise(n: int, r: np.random.Generator, exponent: float = 1.0, fmin: float = 10.0,
                  sr: int = SR) -> np.ndarray:
    """Gaussian noise with power ~ 1/f**exponent (1 = pink, 2 = brown), flat below fmin, unit RMS."""
    nf = _nfft(n)
    f = np.fft.rfftfreq(nf, 1.0 / sr)
    X = np.fft.rfft(r.standard_normal(nf)) * (np.maximum(f, fmin) / fmin) ** (-exponent / 2.0)
    X[0] = 0.0
    y = np.fft.irfft(X, nf)[:n]
    return y / (np.sqrt(np.mean(y * y)) + 1e-20)


def brown(n: int, r: np.random.Generator, sr: int = SR) -> np.ndarray:
    """Brown (1/f^2) noise, flat below 10 Hz, unit RMS."""
    return colored_noise(n, r, 2.0, 10.0, sr)


def mag_lowpass(f, fc: float, order: int = 2):
    """Butterworth lowpass magnitude at frequencies f (Hz)."""
    return 1.0 / np.sqrt(1.0 + (np.asarray(f, dtype=float) / fc) ** (2 * order))


def mag_highpass(f, fc: float, order: int = 2):
    """Butterworth highpass magnitude at frequencies f (Hz)."""
    return 1.0 / np.sqrt(1.0 + (fc / np.maximum(np.asarray(f, dtype=float), 1e-9)) ** (2 * order))


def mag_bandpass(f, lo: float, hi: float, order: int = 2):
    return mag_highpass(f, lo, order) * mag_lowpass(f, hi, order)


def mag_resonance(f, fc, q: float):
    """Two-pole resonant bandpass magnitude, peak gain 1 at fc (fc may broadcast against f)."""
    f = np.maximum(np.asarray(f, dtype=float), 1e-9)
    return 1.0 / np.sqrt(1.0 + q * q * (f / fc - fc / f) ** 2)


def minimum_phase(mag: np.ndarray, m: int) -> np.ndarray:
    """Minimum-phase complex response on an rfft grid of length m from its magnitude (folded cepstrum)."""
    c = np.fft.irfft(np.log(np.maximum(mag, 1e-9)), m)
    fold = np.zeros(m)
    fold[0] = 1.0
    if m % 2 == 0:
        fold[1:m // 2] = 2.0
        fold[m // 2] = 1.0
    else:
        fold[1:(m + 1) // 2] = 2.0
    return np.exp(np.fft.rfft(c * fold, m))


def fft_filter(x: np.ndarray, mag_fn, sr: int = SR, minphase: bool = True, tail: float = 0.0,
               circular: bool = False) -> np.ndarray:
    """Filter x (mono (n,) or (n, ch)) by the magnitude response mag_fn(freqs_hz) via FFT.

    minphase=True gives a causal, analog-like minimum-phase filter (no pre-ringing), fast even
    for minute-long signals; minphase=False is zero-phase. `tail` (s) extends the output to keep
    ringing. circular=True filters periodically over exactly len(x) (for loops).

    The minimum-phase IR is designed on a grid 4x the output length (1.5 s .. 47 s), then
    truncated to a quarter of that grid with a short taper and applied by linear convolution:
    the folded-cepstrum method leaves an aliasing spike near half the design grid, which would
    otherwise come back as a faint (-45 dB) ghost echo of the signal ~m/2 samples later.
    """
    x = np.asarray(x, dtype=float)
    n = len(x)
    keep = n if circular else n + nsamp(tail, sr)
    if not minphase:
        m = n if circular else _nfft(keep + nsamp(0.1, sr))
        H = np.asarray(mag_fn(np.fft.rfftfreq(m, 1.0 / sr)), dtype=float)
        y = np.fft.irfft(np.fft.rfft(x, m, axis=0) * (H[:, None] if x.ndim == 2 else H), m, axis=0)
        return y[:keep]
    D = min(max(_nfft(4 * keep), 1 << 16), 1 << 21)
    L = D // 4
    mag = np.asarray(mag_fn(np.fft.rfftfreq(D, 1.0 / sr)), dtype=float)
    h = np.fft.irfft(minimum_phase(mag, D), D)[:L]
    k = max(L // 16, 1)
    h[L - k:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(1, k + 1) / k)
    if circular:
        if L > n:
            h = np.bincount(np.arange(L) % n, weights=h, minlength=n)
        m = n
    else:
        m = _nfft(n + L)
    Hf = np.fft.rfft(h, m)
    y = np.fft.irfft(np.fft.rfft(x, m, axis=0) * (Hf[:, None] if x.ndim == 2 else Hf), m, axis=0)
    return y[:keep]


def _hann_periodic(n: int) -> np.ndarray:
    return 0.5 - 0.5 * np.cos(2.0 * np.pi * np.arange(n) / n)


def stft(x: np.ndarray, n_fft: int = 2048, hop: int = 512) -> np.ndarray:
    """Mono STFT (periodic Hann), frame i centred on sample i*hop. Shape (frames, n_fft//2+1)."""
    x = np.asarray(x, dtype=float)
    pad = n_fft // 2
    frames_n = int(np.ceil(len(x) / hop)) + 1
    xp = np.zeros((frames_n - 1) * hop + n_fft)
    xp[pad:pad + len(x)] = x
    frames = np.lib.stride_tricks.sliding_window_view(xp, n_fft)[::hop][:frames_n]
    return np.fft.rfft(frames * _hann_periodic(n_fft), axis=1)


def istft(X: np.ndarray, n_fft: int = 2048, hop: int = 512, length: int | None = None) -> np.ndarray:
    """Weighted overlap-add inverse of stft()."""
    w = _hann_periodic(n_fft)
    frames = np.fft.irfft(X, n_fft, axis=1) * w
    total = (frames.shape[0] - 1) * hop + n_fft
    out = np.zeros(total)
    wsum = np.zeros(total)
    for i in range(frames.shape[0]):
        out[i * hop:i * hop + n_fft] += frames[i]
        wsum[i * hop:i * hop + n_fft] += w * w
    pad = n_fft // 2
    length = total - n_fft if length is None else length
    return (out / np.maximum(wsum, 1e-6))[pad:pad + length]


def tv_filter(x: np.ndarray, gain_fn, n_fft: int = 2048, hop: int = 512, sr: int = SR) -> np.ndarray:
    """Time-varying spectral filter: gain_fn(t[:, None], f[None, :]) -> (frames, bins) magnitude.

    t = frame centre times (s), f = bin frequencies (Hz). Use for filter sweeps, closing lowpasses,
    and frequency-dependent decays. Mono or stereo input; output has the input length.
    """
    x = np.asarray(x, dtype=float)
    if x.ndim == 2:
        return np.stack([tv_filter(x[:, c], gain_fn, n_fft, hop, sr) for c in range(x.shape[1])], axis=1)
    X = stft(x, n_fft, hop)
    t = (np.arange(X.shape[0]) * hop / sr)[:, None]
    f = np.fft.rfftfreq(n_fft, 1.0 / sr)[None, :]
    return istft(X * np.broadcast_to(gain_fn(t, f), X.shape), n_fft, hop, len(x))


def read_wav_loop(path: str):
    """Loop points of a WAV's 'smpl' chunk as (start, end_inclusive), or None."""
    import struct
    with open(path, "rb") as fh:
        buf = fh.read()
    pos = 12
    while pos + 8 <= len(buf):
        cid, size = buf[pos:pos + 4], struct.unpack("<I", buf[pos + 4:pos + 8])[0]
        if cid == b"smpl" and size >= 60 and struct.unpack("<I", buf[pos + 36:pos + 40])[0]:
            return struct.unpack("<2I", buf[pos + 52:pos + 60])
        pos += 8 + size + (size & 1)
    return None


def analyze(x: np.ndarray, sr: int = SR) -> dict:
    """duration_s, channels, peak_dbfs, rms_dbfs, crest_db, centroid_hz (magnitude-weighted,
    whole file), attack_ms (10% -> 90% of the max of a 5 ms RMS envelope)."""
    x = np.asarray(x, dtype=float)
    mono = x if x.ndim == 1 else x.mean(axis=1)
    pk = float(np.max(np.abs(x)))
    r = float(np.sqrt(np.mean(x * x)))
    out = {"duration_s": len(x) / sr, "channels": 1 if x.ndim == 1 else x.shape[1],
           "peak_dbfs": lin2db(pk), "rms_dbfs": lin2db(r), "crest_db": lin2db(pk) - lin2db(r)}
    n_fft = 4096
    f = np.fft.rfftfreq(n_fft, 1.0 / sr)
    spec = np.abs(stft(mono, n_fft, n_fft // 2)).sum(axis=0) if len(mono) >= n_fft \
        else np.abs(np.fft.rfft(mono, n_fft))
    out["centroid_hz"] = float(np.sum(f * spec) / (np.sum(spec) + 1e-20))
    w, hop = nsamp(0.005, sr), nsamp(0.001, sr)
    env = np.sqrt(np.maximum(np.convolve(mono * mono, np.ones(w) / w, mode="same")[::hop], 0.0))
    m = env.max() + 1e-20
    out["attack_ms"] = (int(np.argmax(env >= 0.9 * m)) - int(np.argmax(env >= 0.1 * m))) * hop / sr * 1e3
    return out


_SPEC_CMAP = np.array([[0, 0, 4], [31, 12, 72], [85, 15, 109], [136, 34, 106], [186, 54, 85],
                       [227, 89, 51], [249, 140, 10], [249, 201, 50], [252, 255, 164]], dtype=float)


def spectrogram_png(x: np.ndarray, path: str, sr: int = SR, n_fft: int = 1024, hop: int | None = None,
                    fmax: float | None = None, width: int = 1000, height: int = 360,
                    db_range: float = 90.0, title: str = "") -> str:
    """Save a log-magnitude spectrogram (linear frequency axis, kHz ticks) plus a peak-envelope
    strip to PNG (needs Pillow). Stereo input is shown as the L+R power sum."""
    from PIL import Image, ImageDraw
    x = np.asarray(x, dtype=float)
    chans = [x] if x.ndim == 1 else [x[:, c] for c in range(x.shape[1])]
    hop = hop or max(64, n_fft // 4)
    S = sum(np.abs(stft(c, n_fft, hop)) ** 2 for c in chans)
    f = np.fft.rfftfreq(n_fft, 1.0 / sr)
    fmax = fmax or sr / 2
    S = S[:, f <= fmax]
    e = np.linspace(0, S.shape[0], width + 1).astype(int)
    img = np.stack([S[e[i]:max(e[i] + 1, e[i + 1])].mean(axis=0) for i in range(width)])
    d = 10 * np.log10(img + 1e-20)
    v = np.clip((d - (d.max() - db_range)) / db_range, 0, 1).T[::-1]
    v = v[np.linspace(0, v.shape[0] - 1, height).astype(int)]
    p = v * (len(_SPEC_CMAP) - 1)
    i0 = np.floor(p).astype(int)
    i1 = np.minimum(i0 + 1, len(_SPEC_CMAP) - 1)
    fr = (p - i0)[..., None]
    rgb = (_SPEC_CMAP[i0] * (1 - fr) + _SPEC_CMAP[i1] * fr).astype(np.uint8)
    lab, strip = 18, 70
    im = Image.new("RGB", (width + 44, lab + height + strip + 22), (18, 18, 22))
    im.paste(Image.fromarray(rgb, "RGB"), (40, lab))
    dr = ImageDraw.Draw(im)
    mono = x if x.ndim == 1 else x.mean(axis=1)
    dur = len(mono) / sr
    dr.text((40, 3), "%s  %.2f s  0-%.1f kHz  %d dB" % (title, dur, fmax / 1000, db_range), fill=(230, 230, 230))
    step = 1000 if fmax <= 8000 else (2000 if fmax <= 16000 else 5000)
    for fk in np.arange(step, fmax, step):
        yy = lab + int(height * (1 - fk / fmax))
        dr.line([(33, yy), (39, yy)], fill=(200, 200, 200))
        dr.text((2, yy - 6), "%gk" % (fk / 1000), fill=(200, 200, 200))
    y0 = lab + height + 4
    e2 = np.linspace(0, len(mono), width + 1).astype(int)
    for i in range(width):
        h = int(np.max(np.abs(mono[e2[i]:max(e2[i] + 1, e2[i + 1])])) * (strip // 2 - 2))
        dr.line([(40 + i, y0 + strip // 2 - h), (40 + i, y0 + strip // 2 + h)], fill=(120, 190, 255))
    tstep = 0.1 if dur <= 2.5 else (0.5 if dur <= 10 else 5.0)
    for tk in np.arange(0, dur, tstep):
        xx = 40 + int(width * tk / dur)
        dr.line([(xx, y0 + strip), (xx, y0 + strip + 4)], fill=(200, 200, 200))
    dr.text((40, y0 + strip + 6), "time ticks every %gs" % tstep, fill=(160, 160, 160))
    im.save(path)
    return path
