"""Verify selected files and distinguish code references from installed reserves.

This is a source audit, not evidence that every referenced branch was played.
Pair its report with the actual GUI/audio/save tests named in the QA report.
"""
from pathlib import Path
import hashlib, json, re, zipfile

ROOT = Path(__file__).resolve().parents[1]

def audit():
    manifest = json.loads((ROOT/'data/presentation/resource_manifest.json').read_text(encoding='utf-8'))
    scripts = {p.relative_to(ROOT).as_posix(): p.read_text(encoding='utf-8-sig')
               for p in (ROOT/'scripts').rglob('*.gd') if 'tests' not in p.parts}
    rows = []
    archives = {}
    for pack, metadata in manifest['packs'].items():
        archive=ROOT/'.runtime/third_party_sources'/(pack+'.zip')
        if archive.exists():
            assert hashlib.sha256(archive.read_bytes()).hexdigest()==metadata['archive_sha256'], pack
            archives[pack]=zipfile.ZipFile(archive)
    for key, item in manifest['assets'].items():
        path = ROOT/item['path'].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], key
        if item['pack'] in archives:
            assert hashlib.sha256(archives[item['pack']].read(item['source'])).hexdigest()==item['source_sha256'], key+' source'
        references = []
        for name, source in scripts.items():
            for line, text in enumerate(source.splitlines(), 1):
                if re.search(r'["\']'+re.escape(key)+r'["\']', text):
                    references.append(f'{name}:{line}')
        dynamic = ''
        if key.startswith(('step_', 'foley_', 'bird_')):
            dynamic = 'scripts/town_sound/audio/WorldSound.gd: location/surface/index routing'
        status = 'source_referenced' if references or dynamic else 'installed_reserve'
        if key in ['pot_body','pot_hot']: status = 'adaptation_source_or_reserve'
        if key in ['ui_drag','ui_snap']:
            status = 'cue_registered_no_gameplay_caller'
        rows.append(dict(key=key, path=item['path'], source=item['source'], pack=item['pack'],
                         installed_sha256=item['sha256'], source_sha256=item['source_sha256'],
                         status=status, direct_references=references, dynamic_consumer=dynamic))
    output=ROOT/'docs/qa/third_party_usage_20260924.json'
    output.write_text(json.dumps({'method':'Static references plus SHA-256 verification; not a runtime coverage claim',
        'verified_source_archives':sorted(archives),
        'assets':rows},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for archive in archives.values(): archive.close()
    groups={s:sum(r['status']==s for r in rows) for s in sorted({r['status'] for r in rows})}
    print(json.dumps({'verified':len(rows),'status_counts':groups,'report':str(output)},ensure_ascii=False))

if __name__=='__main__': audit()
