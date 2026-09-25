"""Render all SHIFT//WING audio: python3 tools/audio/build.py [names...]"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

from synth import write_wav  # noqa: E402
from tracks import TRACKS  # noqa: E402
from nes import NES_SFX, NES_TRACKS  # noqa: E402
from sfx_hq import SFX_HQ, SFX_HQ_VARIANTS, write_stereo  # noqa: E402

TRACKS = {**TRACKS, **NES_TRACKS}

# Tracks supplied as produced audio files: never overwrite them with the synth versions.
USER_TRACKS = {"stage1", "boss1", "stage2", "stage3"}

SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
only = set(sys.argv[1:])
for name, fn in TRACKS.items():
    if name in USER_TRACKS:
        continue
    if not only or name in only:
        write_wav(os.path.join(ROOT, "assets", "audio", "music", name + ".wav"), fn())
# 8-bit Stage 4 effects stay lo-fi on purpose (32 kHz mono).
for name, fn in NES_SFX.items():
    if not only or name in only:
        write_wav(os.path.join(SFX_DIR, name + ".wav"), fn())
# Studio effects: 48 kHz stereo, with variants for frequent sounds.
for name, fn in SFX_HQ.items():
    if not only or name in only:
        write_stereo(os.path.join(SFX_DIR, name + ".wav"), fn())
for name, (fn, count) in SFX_HQ_VARIANTS.items():
    if not only or name in only:
        for v in range(count):
            suffix = "" if v == 0 else "_%d" % (v + 1)
            write_stereo(os.path.join(SFX_DIR, name + suffix + ".wav"), fn(v))
