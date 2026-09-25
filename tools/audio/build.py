"""Render all SHIFT//WING audio: python3 tools/audio/build.py [names...]"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

from synth import write_wav  # noqa: E402
from tracks import TRACKS  # noqa: E402
from sfx import SFX  # noqa: E402
from nes import NES_SFX, NES_TRACKS  # noqa: E402

TRACKS = {**TRACKS, **NES_TRACKS}
SFX = {**SFX, **NES_SFX}

only = set(sys.argv[1:])
for name, fn in TRACKS.items():
    if not only or name in only:
        write_wav(os.path.join(ROOT, "assets", "audio", "music", name + ".wav"), fn())
for name, fn in SFX.items():
    if not only or name in only:
        write_wav(os.path.join(ROOT, "assets", "audio", "sfx", name + ".wav"), fn())
