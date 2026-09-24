"""Offline provenance/PCM audit. This is not human listening approval."""
import array
import hashlib
import json
import math
import wave
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / "modules/restaurant/assets/audio/recorded"
manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
banks = json.loads((root / "modules/restaurant/data/audio_bank.json").read_text(encoding="utf-8"))
sources = {item["id"]: item for item in manifest["sources"]}
expected = {path for paths in banks.values() for path in paths}
assert expected == {item["file"] for item in manifest["clips"]}
assert not list(folder.parent.glob("*.wav")), "Old generated WAVs still present"
assert not (root / "tools/generate_kitchen_audio.py").exists()
report = []
for item in manifest["clips"]:
    path = root / item["file"].removeprefix("res://")
    source = sources[item["source_id"]]
    assert source["license"] == "CC0-1.0" and not source["attribution_required"]
    assert source["license_url"] == "https://creativecommons.org/publicdomain/zero/1.0/"
    assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"], path
    with wave.open(str(path)) as stream:
        assert stream.getsampwidth() == 2 and stream.getnchannels() == 1
        assert stream.getnframes() == item["frames"]
        values = array.array("h", stream.readframes(stream.getnframes()))
        peak = max(abs(v) for v in values) / 32768
        rms = math.sqrt(sum(v*v for v in values)/len(values)) / 32768
        assert 0.0005 < rms and peak < 0.65, (path, peak, rms)
        if item["loop"]:
            assert abs(values[0] - values[-1]) / 32768 < .15, (path, "loop discontinuity")
        report.append({"file": path.name, "seconds": round(len(values)/stream.getframerate(), 3), "peak_dbfs": round(20*math.log10(peak), 2), "rms_dbfs": round(20*math.log10(rms), 2)})
print(json.dumps({"status": "PASS", "recordings": len(sources), "clips": len(report), "banks": len(banks), "human_audition": "not completed", "measurements": report}, indent=2))
