# Validation: original layout, open materials and reliable mail

- Godot 4.5.1 rendered smoke: save/load, polygon UVs, rotation, flipping, scale, rectangle/free crop, tape, folds, envelope, wax, stamp, delivery: PASS.
- Godot 4.7.2 host: 67 distinct rendered source pages and crop operations; three viewport sizes; actual scaled input into the dialogue; fold capture; isolated host save path: PASS.
- Recorded audio: all streams have duration; fixed 10-player pool; event playback and immediate mute: PASS.
- Python service unit/integration suite: 8/8 PASS, including concurrent send, debt, idempotency, pagination and restart persistence.
- Godot two-player network flow against an isolated Waitress server: publish, debt block, reply, inbox, saved reply draft, repay debt, artwork display: PASS.
- Godot client fault injection against Waitress: first publish commits then returns 503, second response replays same letter; one row stored; bounded retries; signup and business conflicts not retried: PASS.
- Source package imports with Godot; all asset SHA-256 values match provenance. Final native-window interaction was not completed. The rendered screenshot in docs/preview.png comes from the tested game.
- Public hosting and Docker execution were not performed. The server can be deployed using server/README.md.

Reproduce from the prototype directory:

```
python -m unittest discover -s server -p test_service.py
# GODOT_BIN must point to the console engine executable.
python server/test_client_retry.py
godot --path . -- --smoke-test --fresh
```

Host test from repository root (Godot 4.7.2):

```
godot --path . --script res://tests/integration/test_collage_viewport.gd -- --isolated-save --fresh
```
