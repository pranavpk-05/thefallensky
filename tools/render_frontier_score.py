"""Render the six original Dark Frontier cues. Requires NumPy and FFmpeg."""

from pathlib import Path
import subprocess
import wave

import numpy as np


RATE = 32000
OUT = Path(__file__).resolve().parents[1] / "assets" / "score"
TRACKS = (
    ("black-signal", 54, [(38, 45, 50, 53), (34, 41, 48, 52), (35, 42, 47, 54), (33, 40, 46, 52)],
     [(0, 62), (2.75, 69), (6.5, 65), (10, 64), (13.5, 58), (20, 62), (24.75, 69), (29, 56)], 0.04, 0.13),
    ("forgotten-valley", 63, [(38, 45, 52, 57), (36, 43, 50, 55), (34, 41, 48, 53), (33, 45, 52, 58)],
     [(1, 69), (3, 74), (6.5, 72), (11, 67), (17, 65), (20, 69), (24, 64), (29, 57)], 0, 0),
    ("evidence-of-the-dead", 74, [(38, 45, 51, 56), (38, 43, 50, 54), (35, 42, 47, 53), (37, 44, 50, 55)],
     [(0, 63), (1.5, 62), (6, 66), (9, 60), (14, 58), (17.5, 61), (21, 66), (27, 63)], 0.21, 0.21),
    ("someone-is-following", 124, [(38, 45, 50, 51), (38, 44, 49, 55), (35, 42, 47, 53), (37, 43, 50, 56)],
     [(3, 74), (7, 73), (14, 68), (19, 70), (24, 74), (27, 75)], 0.38, 0.48),
    ("above-the-storm", 76, [(38, 45, 52, 57), (34, 41, 48, 53), (41, 48, 55, 64), (36, 43, 50, 57)],
     [(1, 62), (4, 65), (8, 69), (12, 72), (17, 74), (19, 77), (23, 76), (26, 69)], 0.18, 0.05),
    ("the-truth-below", 51, [(38, 45, 50, 53), (33, 45, 52, 58), (34, 41, 53, 57), (38, 45, 51, 56)],
     [(1, 69), (4, 65), (7, 62), (10, 58), (11.5, 60), (17, 65), (20, 69), (22.5, 68), (28, 62)], 0, 0.05),
)


def hz(note):
    return 440.0 * 2 ** ((note - 69.0) / 12.0)


def stereo(mono, pan):
    return mono[:, None] * np.sqrt([0.5 - pan * 0.5, 0.5 + pan * 0.5])


def add(score, start, voice, pan, level):
    at = round(start * RATE)
    span = min(len(voice), len(score) - at)
    if span > 0:
        score[at:at + span] += stereo(voice[:span] * level, pan)


def render(spec, folder):
    name, bpm, harmony, melody, pulse, drums = spec
    beat = 60 / bpm
    span = 32 * beat
    t = np.arange(round(span * RATE)) / RATE
    mix = np.zeros((len(t), 2))
    rng = np.random.default_rng(1906 + bpm)
    air = rng.normal(0, 1, len(t))
    slow_air = np.convolve(air, np.hanning(73) / 34, mode="same")
    mix += stereo(slow_air * (0.032 + 0.021 * np.sin(t * 0.48)), 0.27)
    for bar, chord in enumerate(harmony):
        length = beat * 8 + 2.5
        q = np.arange(round(length * RATE)) / RATE
        envelope = np.minimum(1.0, q / 1.8) * np.minimum(1.0, (length - q) / 2.25)
        for part, note in enumerate(chord):
            pitch = hz(note)
            for detune, pan in [(-0.0017, -0.65), (0.0019, 0.65)]:
                phase = 2 * np.pi * pitch * (1 + detune) * q + np.sin(q * 1.8 + part) * 0.27
                bow = np.sin(phase) + np.sin(phase * 2) * 0.35 + np.sin(phase * 3) * 0.11
                if name in ("black-signal", "above-the-storm"):
                    bow += np.sin(phase * 4 + np.sin(q * 3)) * (0.14 if part > 0 else 0.30)
                add(mix, bar * beat * 8, bow * envelope * (0.75 + 0.25 * np.sin(q * 0.8 + part)),
                    pan, 0.053 if part == 0 else 0.039)
        if pulse:
            for tick in range(16):
                q = np.arange(round(beat * 0.55 * RATE)) / RATE
                tone = hz(chord[0] - 12 + (7 if tick % 7 == 5 else 0))
                strike = np.sin(2 * np.pi * tone * q) + np.sin(4 * np.pi * tone * q) * 0.23
                strike *= np.minimum(q * 85, 1.0) * np.exp(-q * 8) * np.minimum(1.0, (q[-1] - q) * 90)
                add(mix, beat * (bar * 8 + tick * 0.5), strike, 0, pulse * (0.72 if tick % 4 else 1.0))
    for index, (when, note) in enumerate(melody):
        q = np.arange(RATE * 4) / RATE
        phase = 2 * np.pi * hz(note) * q
        piano = np.sin(phase) * np.exp(-q * 1.09)
        piano += 0.44 * np.sin(2.002 * phase) * np.exp(-q * 2.65)
        piano += 0.18 * np.sin(3.01 * phase) * np.exp(-q * 5.8)
        piano *= np.minimum(1.0, q * 185) * np.minimum(1.0, (4.0 - q) * 8)
        direction = -0.20 if index % 2 else 0.31
        add(mix, beat * when, piano, direction, 0.125)
        for delay, pan, gain in [(0.119, -0.63, 0.025), (0.253, 0.72, 0.015), (0.473, -0.3, 0.009)]:
            add(mix, beat * when + delay, piano, pan, gain)
    if drums:
        q = np.arange(RATE // 2) / RATE
        drum = np.sin(2 * np.pi * (32 * q + 4.6 * (1 - np.exp(-q * 13))))
        drum += 0.13 * rng.normal(0, 1, len(q)) * np.exp(-q * 42)
        drum *= np.minimum(q * 180, 1.0) * np.exp(-q * 12) * np.minimum(1.0, (q[-1] - q) * 65)
        for n in range(32):
            if n % 8 in (0, 3, 6) or (drums > 0.3 and n >= 16):
                add(mix, n * beat, drum, 0, drums * 0.71)
    # Mask the loop seam with a brief fade and keep sufficient mix headroom.
    fade = np.minimum(np.minimum(t / 0.28, (span - t) / 0.36), 1.0)
    mix = np.tanh(mix * 1.38) * fade[:, None]
    mix *= 0.77 / max(0.12, float(np.max(np.abs(mix))))
    wav = folder / f"{name}.wav"
    with wave.open(str(wav), "wb") as file:
        file.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        file.writeframes((mix * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
                    "-c:a", "libvorbis", "-q:a", "5", str(OUT / f"{name}.ogg")], check=True)


if __name__ == "__main__":
    from tempfile import TemporaryDirectory

    OUT.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory() as temporary:
        for track in TRACKS:
            render(track, Path(temporary))
