"""Focused historical-requirement regression suite; every process has private saves."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
TESTS = [
    'integration/test_open_polish', 'integration/test_resource_integration',
    'integration/test_production_ui', 'integration/test_reference_paper_ui',
    'integration/test_handmade_life', 'integration/test_dialogue_presentation',
    'integration/test_five_day_flow', 'integration/test_architecture_alignment',
    'integration/test_five_day_identity_mechanics', 'integration/test_daily_life',
    'integration/test_pocket_roles', 'integration/test_save_failure_recovery',
    'integration/test_transaction_boundaries', 'integration/test_shop_work_routes',
    'integration/test_starting_budgets', 'integration/test_midnight_rollover',
    'integration/test_night_and_interaction', 'integration/test_atmosphere_transition',
    'integration/test_scene_atlas', 'integration/test_home_interiors',
    'integration/test_resident_spaces', 'integration/test_street_motion',
    'integration/test_coastal_composition', 'integration/test_supplied_home_and_owner',
    'integration/test_crisp_street', 'integration/test_late_night_people',
    'integration/test_linear_dialogue', 'integration/test_life_feedback',
    'integration/test_cooking_rhythm', 'integration/test_native_modules',
    'integration/test_collage_viewport', 'integration/test_letter_workshop',
    'integration/test_feedback_systems', 'integration/test_nebula_telescope',
    'town_sound/test_audio_settings', 'town_sound/test_world_capture',
    'town_sound/test_recorder', 'town_sound/test_pocket_media',
    'town_sound/test_visual_composition', 'integration/test_recording_retry',
]


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument('--godot', required=True)
    cli.add_argument('--tests', nargs='*')
    cli.add_argument('--run-name', default='current')
    args = cli.parse_args()
    target = ROOT / '.runtime/open-source-polish/qa' / args.run_name
    target.mkdir(parents=True, exist_ok=True)
    # Hash approved art from the tracked file list; no synthetic screenshot oracle.
    tracked = subprocess.check_output(['git', 'ls-files', '-z', 'art'], cwd=ROOT).decode().split('\0')
    baseline = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in tracked if p and (ROOT/p).is_file()}
    (target/'art-baseline.json').write_text(json.dumps(baseline, indent=2), encoding='utf-8')
    rows = []
    for name in args.tests or TESTS:
        script = ROOT / 'tests' / (name + '.gd')
        if not script.is_file():
            rows.append({'test': name, 'result': 'MISSING'})
            continue
        env = os.environ.copy()
        profile = target / 'profiles' / script.stem
        for key, directory in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
            path = profile / directory
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        started = time.monotonic()
        try:
            # RenderingServer.frame_post_draw and real covers need an actual renderer.
            mode = ['--windowed', '--resolution', '1280x720']
            process = subprocess.Popen([args.godot, *mode, '--audio-driver', 'WASAPI', '--path', str(ROOT), '--script', str(script), '--', '--isolated-save'], cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            timer = threading.Timer(360 if script.stem=='test_five_day_flow' else 120, process.kill)
            timer.start()
            lines = []
            for line in process.stdout:
                lines.append(line)
                # Parser/runtime errors abandon the coroutine, so fail promptly.
                if b'SCRIPT ERROR:' in line:
                    process.kill()
            process.wait()
            timer.cancel()
            output = b''.join(lines).decode('utf-8', errors='replace')
            code = process.returncode
        except subprocess.TimeoutExpired as error:
            output = ((error.stdout or b'')+(error.stderr or b'')).decode('utf-8', errors='replace')
            code = -999
        (target/(script.stem+'.log')).write_text(output, encoding='utf-8')
        errors = [line for line in output.splitlines() if re.match(r'(SCRIPT ERROR|ERROR):', line) and 'root certificate store' not in line]
        expected_errors = [line for line in errors if name=='integration/test_nebula_telescope' and line=="ERROR: Could not create directory: 'res://project.godot/not-a-directory'."]
        errors = [line for line in errors if line not in expected_errors]
        row = {'expected_errors': expected_errors, 'test': name, 'exit_code': code, 'seconds': round(time.monotonic()-started, 2), 'errors': errors, 'result': 'PASS' if code==0 and not errors else 'REVIEW'}
        rows.append(row)
        (target/'results.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
        print(f"{row['result']:6} {name} ({row['seconds']}s)", flush=True)
    changed = [p for p, digest in baseline.items() if not (ROOT/p).is_file() or hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=digest]
    print(f'ART INTEGRITY: {len(baseline)} tracked files, {len(changed)} changes', flush=True)
    (target/'art-integrity.json').write_text(json.dumps({'files': len(baseline), 'changed': changed}, indent=2), encoding='utf-8')
    return int(bool(changed) or any(r['result']!='PASS' for r in rows))


if __name__ == '__main__':
    raise SystemExit(main())
