"""Extract Godot Movie Maker MJPEG frames and PCM audio for macOS H.264 export.

Usage: python3 tools/extract_godot_avi.py recording.avi /private/tmp/frames
The source is Godot's RIFF AVI output; no image conversion or fabricated frames.
"""
import argparse
import struct
import wave
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
frames = 0
samples = 0
with args.source.open("rb") as source:
    if source.read(4) != b"RIFF":
        raise SystemExit("Not a RIFF file")
    source.read(4)
    if source.read(4) != b"AVI ":
        raise SystemExit("Not AVI")
    # Godot writes 48 kHz, stereo, 16-bit little-endian PCM in stream 01.
    with wave.open(str(args.output / "audio.wav"), "wb") as audio:
        audio.setnchannels(2)
        audio.setsampwidth(2)
        audio.setframerate(48000)
        while True:
            header = source.read(8)
            if len(header) < 8:
                break
            tag, size = struct.unpack("<4sI", header)
            if tag == b"LIST":
                kind = source.read(4)
                if kind == b"movi":
                    remaining = size - 4
                    while remaining >= 8:
                        chunk = source.read(8)
                        if len(chunk) < 8:
                            raise SystemExit("Truncated AVI chunk")
                        stream, length = struct.unpack("<4sI", chunk)
                        payload = source.read(length)
                        if len(payload) != length:
                            raise SystemExit("Truncated AVI payload")
                        if stream in (b"00db", b"00dc"):
                            if not payload.startswith(b"\xff\xd8") or not payload.endswith(b"\xff\xd9"):
                                raise SystemExit("Invalid MJPEG frame")
                            (args.output / f"frame_{frames:05d}.jpg").write_bytes(payload)
                            frames += 1
                        elif stream == b"01wb":
                            audio.writeframesraw(payload)
                            samples += length // 4
                        padding = length & 1
                        if padding:
                            source.read(1)
                        remaining -= 8 + length + padding
                    break
                source.seek(size - 4 + (size & 1), 1)
            else:
                source.seek(size + (size & 1), 1)
if frames == 0 or samples == 0:
    raise SystemExit(f"Missing media: {frames} frames, {samples} samples")
print(f"Extracted {frames} JPEG frames and {samples / 48000:.3f}s PCM audio")
