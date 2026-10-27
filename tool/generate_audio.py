#!/usr/bin/env python3
"""Original synthesized music and effects for Revolt Cabino."""

import math
import os
import subprocess
import wave

import numpy as np
from scipy.signal import lfilter

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
MUSIC = os.path.join(ROOT, "music")
SFX = os.path.join(ROOT, "sfx")


def soft_clip(x, drive=1.15):
    return np.tanh(x * drive) / np.tanh(drive)


def lowpass(x, cutoff):
    coeff = math.exp(-2.0 * math.pi * cutoff / SR)
    return lfilter([1.0 - coeff], [1.0, -coeff], x)


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def normalize(x, peak=0.89):
    max_abs = float(np.max(np.abs(x))) if x.size else 1.0
    if max_abs < 1e-8:
        return x
    return x * (peak / max_abs)


def seamless(x, fade_seconds=2.4):
    fade_n = int(fade_seconds * SR)
    fade_in = np.linspace(0.0, 1.0, fade_n)
    mixed = x.copy()
    mixed[:fade_n] = x[:fade_n] * fade_in + x[-fade_n:] * (1.0 - fade_in)
    return mixed[:-fade_n]


def write_wav(path, audio, stereo=False):
    audio = np.clip(audio, -1.0, 1.0)
    if stereo:
        frames = audio.reshape(-1, 2)
    else:
        frames = audio.reshape(-1, 1)
    pcm = (frames * 32767.0).astype(np.int16)
    with wave.open(path, "w") as handle:
        handle.setnchannels(2 if stereo else 1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def to_m4a(wav_path, m4a_path):
    subprocess.check_call(
        [
            "afconvert",
            "-f",
            "m4af",
            "-d",
            "aac",
            "-b",
            "192000",
            wav_path,
            m4a_path,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    os.remove(wav_path)


def music_bed(duration, seed, pulse=0.0, brightness=0.0):
    count = int(SR * duration)
    t = np.arange(count) / SR
    rng = np.random.default_rng(seed)
    left = np.zeros(count)
    right = np.zeros(count)
    roots = (55.0, 82.5, 110.0, 164.8)
    amps = (0.16, 0.09, 0.045, 0.02 + brightness)
    for freq, amp in zip(roots, amps):
        left += amp * np.sin(2 * math.pi * freq * t)
        right += amp * np.sin(2 * math.pi * freq * 1.002 * t + 0.4)
        left += amp * 0.35 * np.sin(2 * math.pi * freq * 1.005 * t)
        right += amp * 0.35 * np.sin(2 * math.pi * freq * 0.997 * t)
    lfo = 0.86 + 0.14 * np.sin(2 * math.pi * (0.045 + pulse) * t)
    left *= lfo
    right *= lfo
    if pulse:
        beat = 0.5 + 0.5 * np.sin(2 * math.pi * 0.55 * t)
        thump = pulse * 0.08 * np.sin(2 * math.pi * 55.0 * t) * beat
        left += thump
        right += thump * 0.9
    noise_l = lowpass(rng.standard_normal(count), 900) * (0.018 + brightness * 0.2)
    noise_r = lowpass(rng.standard_normal(count), 900) * (0.018 + brightness * 0.2)
    left += highpass(noise_l, 180)
    right += highpass(noise_r, 180)
    scale = np.array([293.66, 329.63, 349.23, 392.0, 440.0, 523.25])
    step = 4.2 if pulse == 0 else 3.6
    start = 1.5
    index = 0
    while start < duration - 3:
        freq = scale[index % len(scale)]
        if brightness:
            freq *= 1 if index % 5 else 1.5
        env = np.exp(-np.maximum(t - start, 0) / (1.7 + brightness))
        env[t < start] = 0
        tone_l = (0.045 + brightness * 0.02) * np.sin(2 * math.pi * freq * t) * env
        tone_r = (0.04 + brightness * 0.02) * np.sin(2 * math.pi * freq * t + 0.3) * env
        left += tone_l
        right += tone_r + tone_l * 0.15
        start += step
        index += 1
    stereo = np.column_stack((left, right))
    stereo = soft_clip(stereo, 1.05)
    stereo = seamless(stereo.reshape(-1), 2.6).reshape(-1, 2)
    return normalize(stereo, 0.42 if pulse == 0 else 0.48)


def env_adsr(n, attack, decay, sustain=0.0):
    t = np.arange(n) / SR
    attack_n = max(1, int(attack * SR))
    curve = np.ones(n)
    curve[:attack_n] = np.linspace(0, 1, attack_n)
    curve *= np.exp(-t / max(decay, 0.001))
    if sustain:
        curve = np.maximum(curve, sustain * np.exp(-t / (decay * 3)))
    return curve


def tone(freq, seconds, decay, harmonics=(1.0, 0.35, 0.12)):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    wave_sum = np.zeros(n)
    for index, amp in enumerate(harmonics, start=1):
        wave_sum += amp * np.sin(2 * math.pi * freq * index * t)
    return wave_sum * env_adsr(n, 0.008, decay)


def noise(seconds, decay, cutoff=1800):
    n = int(SR * seconds)
    raw = np.random.default_rng(int(seconds * 1000 + cutoff)).standard_normal(n)
    return lowpass(raw, cutoff) * env_adsr(n, 0.004, decay)


def mix(*parts):
    length = max(len(part) for part in parts)
    out = np.zeros(length)
    for part in parts:
        out[: len(part)] += part
    return normalize(soft_clip(out, 1.2), 0.82)


def save_sfx(name, audio):
    write_wav(os.path.join(SFX, name), audio, stereo=False)


def build_sfx():
    save_sfx("sfx_ui_tap.wav", mix(tone(1400, 0.07, 0.03, (1, 0.2)), noise(0.05, 0.02, 2500) * 0.15))
    save_sfx(
        "sfx_ui_back.wav",
        mix(tone(880, 0.09, 0.04), tone(520, 0.14, 0.06) * 0.8),
    )
    save_sfx(
        "sfx_ui_unavailable.wav",
        mix(tone(220, 0.16, 0.07, (1, 0.2)), tone(180, 0.18, 0.08) * 0.7),
    )
    whoosh = highpass(noise(0.22, 0.12, 1600), 240) * 0.55
    save_sfx(
        "sfx_gravity_change.wav",
        mix(whoosh, tone(160, 0.32, 0.14, (1, 0.4, 0.15)), tone(740, 0.08, 0.03) * 0.35),
    )
    save_sfx("sfx_player_slide.wav", mix(highpass(noise(0.32, 0.16, 2200), 500) * 0.45, tone(420, 0.28, 0.12, (1, 0.15))))
    save_sfx("sfx_cargo_slide.wav", mix(lowpass(noise(0.42, 0.2, 700), 500) * 0.9, tone(110, 0.4, 0.16, (1, 0.3))))
    save_sfx("sfx_object_settle.wav", mix(tone(240, 0.14, 0.05, (1, 0.45, 0.1)), noise(0.08, 0.03, 900) * 0.2))
    save_sfx("sfx_plate_activate.wav", mix(tone(360, 0.16, 0.06, (1, 0.3)), tone(980, 0.12, 0.05) * 0.45))
    save_sfx("sfx_plate_release.wav", mix(tone(300, 0.16, 0.07, (1, 0.25)), tone(620, 0.14, 0.08) * 0.4))
    save_sfx("sfx_gate_open.wav", mix(lowpass(noise(0.36, 0.16, 600), 500), tone(180, 0.34, 0.12, (1, 0.2))))
    save_sfx("sfx_gate_close.wav", mix(lowpass(noise(0.32, 0.14, 550), 480), tone(140, 0.28, 0.08, (1, 0.35))))
    save_sfx("sfx_magnet_on.wav", mix(tone(190, 0.28, 0.1, (1, 0.2, 0.5)), tone(760, 0.08, 0.03) * 0.3))
    save_sfx("sfx_magnet_off.wav", mix(tone(240, 0.24, 0.1, (1, 0.15)), tone(120, 0.22, 0.1)))
    save_sfx(
        "sfx_fragment_collect.wav",
        mix(tone(880, 0.5, 0.22, (1, 0.2)), tone(1174, 0.46, 0.2) * 0.7, tone(1568, 0.4, 0.18) * 0.45),
    )
    snap = noise(0.08, 0.02, 4000) * 0.55
    save_sfx("sfx_laser_failure.wav", mix(snap, tone(640, 0.18, 0.06), tone(220, 0.42, 0.16, (1, 0.25))))
    save_sfx("sfx_undo.wav", mix(tone(700, 0.16, 0.06), tone(360, 0.22, 0.09)))
    save_sfx("sfx_hint_reveal.wav", mix(tone(660, 0.22, 0.08), tone(990, 0.2, 0.08) * 0.6, tone(1800, 0.06, 0.02) * 0.25))
    save_sfx(
        "sfx_level_complete.wav",
        mix(tone(392, 0.7, 0.28), tone(494, 0.8, 0.3) * 0.85, tone(587, 0.9, 0.32) * 0.7, tone(160, 0.5, 0.2) * 0.35),
    )
    save_sfx(
        "sfx_chapter_complete.wav",
        mix(
            tone(329, 1.1, 0.4),
            tone(415, 1.2, 0.42) * 0.8,
            tone(494, 1.4, 0.45) * 0.75,
            tone(659, 1.3, 0.4) * 0.45,
            tone(98, 1.6, 0.5) * 0.3,
        ),
    )
    save_sfx(
        "sfx_campaign_complete.wav",
        mix(
            tone(196, 2.2, 0.8, (1, 0.2)),
            tone(392, 3.4, 1.1) * 0.7,
            tone(494, 3.6, 1.2) * 0.55,
            tone(587, 3.8, 1.3) * 0.4,
            tone(784, 3.2, 1.0) * 0.22,
        ),
    )


def build_music():
    tracks = {
        "music_menu_ambient.m4a": music_bed(78, seed=11, pulse=0.0, brightness=0.0),
        "music_gameplay_ambient.m4a": music_bed(104, seed=29, pulse=0.08, brightness=0.04),
        "music_final_sector.m4a": music_bed(104, seed=47, pulse=0.16, brightness=0.08),
    }
    for name, audio in tracks.items():
        wav_path = os.path.join(MUSIC, name.replace(".m4a", ".wav"))
        write_wav(wav_path, audio, stereo=True)
        to_m4a(wav_path, os.path.join(MUSIC, name))
        print(name, "seconds", round(len(audio) / SR, 2))


if __name__ == "__main__":
    os.makedirs(MUSIC, exist_ok=True)
    os.makedirs(SFX, exist_ok=True)
    build_sfx()
    build_music()
    print("audio ready")
