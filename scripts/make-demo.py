#!/usr/bin/env python3
"""Generate the original, silent geometric demo. No system voices or online media."""
import argparse
import pathlib
import shutil
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=pathlib.Path, default=root / 'Samples/demo.mp4')
args = parser.parse_args()
ffmpeg = shutil.which('ffmpeg')
if not ffmpeg:
    raise SystemExit('This optional generator requires a locally installed FFmpeg.')
if args.output.exists():
    raise SystemExit('Output already exists. Choose a new --output path; existing files are never replaced.')
args.output.parent.mkdir(parents=True, exist_ok=True)
filters = (
    'drawgrid=w=80:h=80:t=1:c=0x152c35,'
    'drawbox=x=80:y=80:w=1120:h=560:color=0x28444f:t=2,'
    'drawbox=x=140:y=135:w=85:h=8:color=0x63e0b8:t=fill,'
    'drawbox=x=140:y=535:w=1000:h=3:color=0x25434d:t=fill,'
    'drawbox=x=535:y=260:w=8:h=160:color=0x63e0b8:t=fill,'
    'drawbox=x=575:y=220:w=8:h=240:color=0x63e0b8:t=fill,'
    'drawbox=x=615:y=185:w=8:h=310:color=0x98a3ff:t=fill,'
    'drawbox=x=655:y=235:w=8:h=210:color=0x63e0b8:t=fill,'
    'drawbox=x=695:y=275:w=8:h=130:color=0x63e0b8:t=fill,'
    'format=yuv420p'
)
subprocess.run([
    ffmpeg, '-v', 'error', '-nostdin', '-f', 'lavfi', '-i',
    'color=c=0x0c1822:s=1280x720:r=24:d=24', '-vf', filters,
    '-an', '-t', '24', '-c:v', 'libx264', '-preset', 'fast', '-crf', '24',
    '-movflags', '+faststart', '-n', str(args.output)
], check=True)
print(args.output)
