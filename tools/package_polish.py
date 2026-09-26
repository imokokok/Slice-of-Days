"""Package an already exported Windows build with verification and external notices."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT.parent / 'SOLMERE_Windows_Polish_20260926'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    assert (BUILD/'Solmere.pck').stat().st_size > 400_000_000, 'Export the current PCK first'
    expected_engine = 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
    assert digest(BUILD/'Solmere.exe') == expected_engine, 'Unexpected Godot runtime'
    results = json.loads((ROOT/'docs/qa/open-polish-20260926/results.json').read_text('utf-8'))
    assert len(results) == 34 and all(item['result']=='PASS' for item in results)
    shutil.copytree(ROOT/'third_party/licenses', BUILD/'licenses', dirs_exist_ok=True)
    for name, source in [('xiaolai', ROOT/'art/ui/fonts/xiaolai'),
                         ('godot_engine', ROOT.parent/'SOLMERE_Windows_AB_Pocket_20260926/licenses/godot_engine')]:
        target = BUILD/'licenses'/name
        target.mkdir(parents=True, exist_ok=True)
        for item in source.iterdir():
            if item.is_file() and item.suffix.lower() in {'.txt','.md'}:
                shutil.copyfile(item, target/item.name)
    for name in ['THIRD_PARTY_LICENSES.md','REFERENCE_LOG.md','README.md']:
        shutil.copyfile(ROOT/name, BUILD/name)
    shutil.copytree(ROOT/'docs/qa/open-polish-20260926', BUILD/'docs/qa/open-polish-20260926', dirs_exist_ok=True)
    shutil.copyfile(ROOT/'docs/qa/open_source_polish_20260926.md', BUILD/'docs/qa/open_source_polish_20260926.md')
    shutil.copyfile(ROOT/'docs/DAILY_LIFE_SYSTEM.md', BUILD/'docs/DAILY_LIFE_SYSTEM.md')
    for source, target in [
        ('extensions/observatory/assets/nebulae/SOURCES.md','astronomy-sources.md'),
        ('extensions/myriorama_tarot/assets/audio/Kenney-License.txt','kenney-casino.txt'),
        ('art/town_sound_cc0/SOURCES.md','town-sounds.md'),
    ]:
        shutil.copyfile(ROOT/source, BUILD/'licenses'/target)
    (BUILD/'阅读我.txt').write_text(
        'SOLMERE · 2026-09-26 开源资源与交互复查版\n\n'
        '解压整个文件夹，双击 Solmere.exe。请把 Solmere.pck 留在同一文件夹。\n'
        '无需安装 Godot、Python 或联网。\n\n'
        'A / D 走动，W 交谈，E 互动，Space 继续对话。\n'
        'A 按 R 使用录音机；B 按 J 打开手写待办；C 相机；Tab 地图；Esc 收起界面。\n'
        'B 在唱片店声音手作桌右侧选择店内声音，再剪辑制作。\n'
        '请勿同时运行两个游戏窗口写同一正式存档。\n\n'
        '检查结果见 docs/qa；素材作者与完整许可见 licenses 和 THIRD_PARTY_LICENSES.md。\n'
        '游戏内致谢按要求留空，不代表免除第三方许可。\n', encoding='utf-8')
    manifest = {
        'version':'open-source-polish-20260926',
        'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip(),
        'godot':'4.7.2.stable', 'current_suites_passed':34,
        'five_day_checks':223, 'cross_process_reload_checks':13,
        'packed_resource_checks':77,
        'files':{str(path.relative_to(BUILD)).replace('\\','/'):{'bytes':path.stat().st_size,'sha256':digest(path)}
                 for path in sorted(BUILD.rglob('*')) if path.is_file() and path.name!='build-manifest.json'},
    }
    (BUILD/'build-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    archive = BUILD.with_suffix('.zip')
    with ZipFile(archive,'w',ZIP_DEFLATED,compresslevel=1) as output:
        for path in sorted(BUILD.rglob('*')):
            if path.is_file(): output.write(path, str(Path(BUILD.name)/path.relative_to(BUILD)))
    with ZipFile(archive) as output:
        assert output.testzip() is None
        assert output.getinfo(BUILD.name+'/Solmere.pck').file_size == (BUILD/'Solmere.pck').stat().st_size
    print(json.dumps({'zip':str(archive),'bytes':archive.stat().st_size,'sha256':digest(archive),'commit':manifest['git_commit']},ensure_ascii=False))


if __name__ == '__main__':
    main()
