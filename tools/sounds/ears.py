"""Our "ears": measures sound files so sounds are picked and levelled by numbers.

For a file (or a segment of it: start, length) it gives:
  dur       seconds
  I         integrated loudness (LUFS, of the mono mix: a 3D sound plays in mono)
  Mmax      loudest momentary loudness (400 ms, LUFS): how loud a one-shot feels
  truePeak  dBFS of the file itself (above 0 = it clips)
  onset     first point within 30 dB of the peak (the leading blank to cut)
  peak      time of the loudest 20 ms
  attack    peak - onset
  end40     where it falls 40 dB under the peak
  centroid  spectral centroid (Hz): brightness
  harsh     share of energy in 2-5 kHz (the "bite")
  sub       share under 150 Hz (inaudible on phones / laptops)
Over 8 s (loops) it also gives the level stability (std of 400 ms windows),
the seam (end -> start level step and spectral distance) and crackles/s.

Needs ffmpeg and numpy.   python3 tools/sounds/ears.py file.ogg [...]
"""

import json
import os
import re
import subprocess
import sys

import numpy as np

SR = 48000


def decode(path, start=0.0, length=None):
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start), "-i", path]
    if length:
        cmd += ["-t", str(length)]
    cmd += ["-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def loudness(x):
    """EBU R128 through ffmpeg, on raw samples."""
    proc = subprocess.run(
        ["ffmpeg", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
         "-filter_complex", "ebur128=peak=true", "-f", "null", "-"],
        input=x.tobytes(), capture_output=True,
    )
    err = proc.stderr.decode(errors="ignore")
    i = re.findall(r"I:\s+(-?[\d.]+|-inf) LUFS", err)
    p = re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", err)
    m = [float(v) for v in re.findall(r" M:\s*(-?[\d.]+)", err) if float(v) > -120]
    num = lambda s: None if not s or s[-1] == "-inf" else float(s[-1])
    return num(i), num(p), (max(m) if m else None)


def true_peak(path, start=0.0, length=None):
    """True peak of the file itself (all its channels), dBFS."""
    cmd = ["ffmpeg", "-nostats", "-ss", str(start), "-i", path]
    if length:
        cmd += ["-t", str(length)]
    cmd += ["-filter_complex", "ebur128=peak=true", "-f", "null", "-"]
    err = subprocess.run(cmd, capture_output=True).stderr.decode(errors="ignore")
    p = re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", err)
    return None if not p or p[-1] == "-inf" else float(p[-1])


def db(v):
    return 20 * np.log10(max(v, 1e-9))


def analyse(path, start=0.0, length=None):
    x = decode(path, start, length)
    if len(x) < SR * 0.45:  # (ebur128 needs 400 ms: pad short files with silence)
        x = np.concatenate([x, np.zeros(int(SR * 0.45) - len(x), dtype=np.float32)])
    n = len(x)
    dur = n / SR
    # (loudness on the mono mix: Roblox plays a sound placed in the world in mono)
    i, _, mmax = loudness(x)
    tp = true_peak(path, start, length)
    hop, win = int(SR * 0.01), int(SR * 0.02)
    frames = np.array([np.sqrt(np.mean(x[k:k + win] ** 2) + 1e-12) for k in range(0, max(1, n - win), hop)])
    fdb = 20 * np.log10(frames)
    pk = fdb.max()
    onset = np.argmax(fdb > pk - 30) * 0.01
    peak = np.argmax(fdb) * 0.01
    active = fdb > pk - 40
    tail = (len(fdb) - np.argmax(active[::-1])) * 0.01
    m = min(n, SR * 10)
    spec = np.abs(np.fft.rfft(x[:m] * np.hanning(m))) ** 2
    f = np.fft.rfftfreq(m, 1 / SR)
    out = dict(
        dur=round(dur, 2), I=i, Mmax=mmax, truePeak=tp, onset=round(onset, 2), peak=round(peak, 2),
        attack=round(peak - onset, 2), end40=round(tail, 2),
        centroid=int((f * spec).sum() / spec.sum()),
        harsh=round(float(spec[(f > 2000) & (f < 5000)].sum() / spec.sum()), 3),
        sub=round(float(spec[f < 150].sum() / spec.sum()), 3),
    )
    if dur > 8:
        w = int(SR * 0.4)
        levels = [db(np.sqrt(np.mean(x[k:k + w] ** 2))) for k in range(0, n - w, w)]
        out["stability"] = round(float(np.std(levels)), 2)
        a, b = x[-int(SR * 0.2):], x[: int(SR * 0.2)]
        out["seam_dB"] = round(float(db(np.sqrt(np.mean(a ** 2))) - db(np.sqrt(np.mean(b ** 2)))), 2)
        sa, sb = np.abs(np.fft.rfft(a)), np.abs(np.fft.rfft(b))
        out["seam_spec"] = round(float(np.linalg.norm(np.log(sa + 1e-6) - np.log(sb + 1e-6)) / np.sqrt(len(sa))), 2)
        out["crackles_s"] = round(float((np.diff(fdb) > 6).sum() / dur), 1)
    return out


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(json.dumps(dict(file=os.path.basename(p), **analyse(p)), default=float))
