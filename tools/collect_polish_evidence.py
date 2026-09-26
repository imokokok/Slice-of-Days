"""Collect the latest result for every current check, retaining failed historical checks."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
from qa_open_polish import TESTS

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / '.runtime/open-source-polish/qa'
OUT = ROOT / 'docs/qa/open-polish-20260926'
RUNS = ['merged', 'merged-final', 'final-regression', 'sound-box-final', 'role-shop-final']


def main():
    rows = {}
    for run in RUNS:
        for item in json.loads((QA/run/'results.json').read_text('utf-8')):
            rows[item['test']] = dict(item, run=run)
    current = [rows[name] for name in TESTS]
    assert all(row['result'] == 'PASS' for row in current), 'A current test still fails'
    OUT.mkdir(parents=True, exist_ok=True)
    for item in current:
        name = item['test'].split('/')[-1]
        shutil.copyfile(QA/item['run']/(name+'.log'), OUT/(name+'.txt'))
        item['log'] = name+'.txt'
    (OUT/'results.json').write_text(json.dumps(current, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    shutil.copyfile(QA/'historical-scan.json', OUT/'historical-scan.json')
    shutil.copyfile(QA/'merged/five-day-reload.log', OUT/'five-day-reload.txt')
    shutil.copyfile(QA/'final-regression/art-integrity.json', OUT/'art-integrity.json')
    # Compare approved existing raster/audio source blobs to the merged main base.
    candidates = subprocess.check_output(['git','ls-tree','-r','000bf3a','art'], cwd=ROOT).decode().splitlines()
    unchanged, changed = 0, []
    for entry in candidates:
        metadata, name = entry.split('\t', 1)
        previous = metadata.split()[2]
        path = ROOT/name
        if path.suffix.lower() not in {'.png','.jpg','.jpeg','.webp','.wav','.ogg','.ttf','.otf'}:
            continue
        if not path.exists():
            changed.append(name); continue
        current_blob = hashlib.sha1(b'blob '+str(path.stat().st_size).encode()+b'\0'+path.read_bytes()).hexdigest()
        if previous != current_blob: changed.append(name)
        else: unchanged += 1
    assert not changed, changed
    (OUT/'approved-source-integrity.json').write_text(json.dumps({'baseline':'000bf3a','unchanged_source_files':unchanged,'changed':changed}, indent=2)+'\n', encoding='utf-8')
    for name in ['05-map','07-settings','08-live-recording','10-b-handwritten-agenda','12-checkout','15-record-shop','16-b-sound-materials']:
        shutil.copyfile(ROOT/'.runtime/open-source-polish/captures'/(name+'.png'), OUT/(name+'.png'))
    # Windows pipe logs may contain CRCRLF; preserve text while normalizing lines.
    for path in OUT.glob('*.txt'):
        text = path.read_bytes().decode('utf-8').replace('\r','')
        path.write_text('\n'.join(line.rstrip() for line in text.splitlines())+'\n', encoding='utf-8', newline='\n')
    print(f'{len(current)} current tests passed; {unchanged} approved source files unchanged.')


if __name__ == '__main__':
    main()
