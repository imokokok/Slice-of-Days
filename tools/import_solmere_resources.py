"""Install selected licensed assets from their official, free itch.io downloads.

Raw packs and downloaded personal session URLs stay outside version control.
No payment or account creation. Re-run to restore an offline development copy.
Python 3.10+, standard library only. Run from the project root.
"""
from pathlib import Path
import argparse, concurrent.futures, hashlib, http.cookiejar, io, json, re
import shutil, struct, urllib.parse, urllib.request, wave, zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'little_chef': ('hello erika', 'https://hello-erika.itch.io/cute-cozy-cooking-game-assest'),
    'cila': ('Cila', 'https://nacila.itch.io/paper-stylized-ui-ready-for-development'),
    'cute_ui': ('R4orce', 'https://r4orce.itch.io/cute-ui-sound-pack'),
    'cozy_sfx': ('HuntSounds', 'https://huntsounds.itch.io/cosy-sfx-volume-1'),
}
SELECTION = {}
def select(key, pack, source, category, loop=False):
    SELECTION[key] = dict(pack=pack, source=source, category=category, loop=loop)

for key, path in {
    'paper_wide':'paper/paper 02.png', 'paper_tall':'paper/paper 03.png',
    'paper_large':'paper/paper 07.png', 'paper_dialogue':'paper/dialog box 08.png',
    'paper_label':'others/title 1 01.png', 'paper_tab':'others/title 2 01.png',
    'paper_square':'others/square 01.png', 'paper_focus':'others/Marker 01.png',
    'icon_check':'icon/Check.png', 'icon_close':'icon/Exit.png',
    'icon_play':'icon/Play.png', 'icon_pause':'icon/Pause.png',
    'icon_stop':'icon/Stop.png', 'icon_music':'icon/Music.png',
    'icon_info':'icon/Info.png', 'icon_arrow_left':'icon/arrow L.png',
    'icon_arrow_right':'icon/arrow R.png', 'icon_heart':'icon/Heart.png',
}.items(): select(key,'cila','Cila - Paper UI stylized Free/'+path,'ui')
for key,path in {
    'food_bread':'Environment/Shelf/bread.png', 'food_cheese':'Environment/Shelf/cheese.png',
    'kitchen_salt':'Environment/Counter/salt.png', 'kitchen_spoon':'Environment/Wall/spoon.png',
    'kitchen_ladle':'Environment/Wall/sooup_spoon.png', 'pot_back':'Environment/Pot/pot_back.png',
    'pot_body':'Environment/Pot/pot_base.png', 'pot_hot':'Environment/Pot/pot_base_hot.png',
    'pot_lid':'Environment/Pot/pot_lid.png', 'serving_bowl':'Environment/Shelf/Bowl_Stack/Bowl_0.png',
}.items(): select(key,'little_chef','Sprites/Sprites/'+path,'kitchen')
for key,path in {
    'ui_click':'02_click_soft.wav', 'ui_focus':'09_tap_feather.wav',
    'ui_success':'11_success.wav', 'ui_error':'39_fail_soft.wav',
    'ui_slide':'13_swipe.wav', 'ui_open':'14_menu_open.wav',
    'ui_close':'15_menu_close.wav', 'ui_notice':'16_notification.wav',
    'ui_record_start':'19_toggle_on.wav', 'ui_record_stop':'20_toggle_off.wav',
    'ui_check':'24_checkbox.wav', 'ui_drag':'31_drag.wav',
    'ui_drop':'32_drop.wav', 'ui_snap':'33_snap.wav',
}.items(): select(key,'cute_ui','Cute - UI Sound Pack/WAV_48kHz_24bit/'+path,'audio')
for key,path in {
    'ambience_rain':'RAIN_AMBIENCE.wav', 'ambience_indoor_rain':'INDOOR_RAIN_AMBIENCE.wav',
    'ambience_night':'NIGHTTIME_AMBIENCE.wav', 'ambience_day':'OUTDOOR_GENERIC_AMBIENCE.wav',
    'ambience_room':'ROOM_TONE.wav', 'ambience_wind':'WIND_AMBIENCE.wav',
}.items(): select(key,'cozy_sfx','Cozy SFX Volume 1/BACKGROUND_AMBIENCE/'+path,'audio',True)
for surface in ['grass','gravel','stone','wood']:
    for i in range(1,6):
        select(f'step_{surface}_{i}','cozy_sfx',f'Cozy SFX Volume 1/FOOTSTEPS/{surface.upper()}/{surface.upper()}_FOOTSTEP_{i}.wav','audio')
for kind,upper in [('paper','FABRIC'),('water','WATER'),('wood','WOOD'),('leaf','LEAFS')]:
    for i in range(1,4): select(f'foley_{kind}_{i}','cozy_sfx',f'Cozy SFX Volume 1/INTERACTIONS/{upper}_{i}.wav','audio')
for i in range(1,5): select(f'bird_{i}','cozy_sfx',f'Cozy SFX Volume 1/NATURE_ONESHOTS/BIRD_CHIRP_{i}.wav','audio')

def sha(data): return hashlib.sha256(data).hexdigest()
def download(pack, cache):
    archive=cache/(pack+'.zip')
    if archive.exists(): return archive
    url=SOURCES[pack][1]
    jar=http.cookiejar.CookieJar()
    session=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    session.addheaders=[('User-Agent','Mozilla/5.0')]
    page=session.open(url,timeout=45).read().decode()
    token=re.search(r'name="csrf_token" value="([^"]+)"',page).group(1)
    req=urllib.request.Request(url+'/download_url',data=urllib.parse.urlencode({'csrf_token':token}).encode(),headers={'Referer':url,'X-Requested-With':'XMLHttpRequest'})
    result=json.loads(session.open(req,timeout=45).read())
    if 'url' not in result: raise RuntimeError(f'{pack}: free download unavailable: {result.get("errors",[])}')
    page_url=result['url'];page=session.open(page_url,timeout=45).read().decode()
    token=re.search(r'name="csrf_token" value="([^"]+)"',page).group(1)
    # The first file on each free download page is the asset ZIP, not the preview video.
    upload=re.search(r'data-upload_id="(\d+)"',page).group(1)
    req=urllib.request.Request(url+'/file/'+upload+'?source=game_download',data=urllib.parse.urlencode({'csrf_token':token}).encode(),headers={'Referer':page_url,'X-Requested-With':'XMLHttpRequest'})
    result=json.loads(session.open(req,timeout=45).read())
    if 'url' not in result: raise RuntimeError(f'{pack}: download not granted')
    raw=session.open(result['url'],timeout=120).read()
    if not zipfile.is_zipfile(io.BytesIO(raw)): raise RuntimeError(f'{pack}: response was not a ZIP')
    archive.write_bytes(raw)
    return archive

def pcm16(raw):
    with wave.open(io.BytesIO(raw),'rb') as wav:
        channels, width, rate, count=wav.getnchannels(),wav.getsampwidth(),wav.getframerate(),wav.getnframes()
        frames=wav.readframes(count)
    if width==3:
        frames=b''.join(frames[i+1:i+3] for i in range(0,len(frames),3))
    elif width==4:
        frames=b''.join(struct.pack('<h',max(-32768,min(32767,struct.unpack_from('<i',frames,i)[0]>>16))) for i in range(0,len(frames),4))
    elif width!=2: raise RuntimeError(f'Unsupported PCM width {width}')
    out=io.BytesIO()
    with wave.open(out,'wb') as wav:
        wav.setnchannels(channels);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes(frames)
    return out.getvalue(),dict(sample_rate=rate,channels=channels,frames=count,duration=round(count/rate,4),conversion=f'PCM {width*8} to PCM 16; original rate and channels retained')

def run():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache',type=Path,default=ROOT/'.runtime/third_party_sources')
    parser.add_argument('--verify-only',action='store_true')
    args=parser.parse_args();cache=args.cache.resolve();cache.mkdir(parents=True,exist_ok=True)
    manifest_path=ROOT/'data/presentation/resource_manifest.json'
    if args.verify_only:
        manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
        for key,item in manifest['assets'].items():
            raw=(ROOT/item['path'].removeprefix('res://')).read_bytes()
            assert sha(raw)==item['sha256'],f'Changed or incomplete resource: {key}'
        print(f'PASS: {len(manifest["assets"])} installed assets verified.');return
    with concurrent.futures.ThreadPoolExecutor(4) as pool: archives=dict(zip(SOURCES,pool.map(lambda pack:download(pack,cache),SOURCES)))
    # A fresh clone restores the reviewed revision, not an unreviewed upstream change.
    expected=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    for pack,path in archives.items():
        pinned=expected.get('packs',{}).get(pack,{}).get('archive_sha256')
        if pinned and sha(path.read_bytes())!=pinned:
            raise RuntimeError(f'{pack}: official archive changed since the reviewed manifest; review the new license/files before updating the pin')
    target=ROOT/'art/licensed';target.mkdir(parents=True,exist_ok=True)
    manifest={'version':1,'installed_on':'2026-09-24','assets':{},'packs':{}}
    for pack,path in archives.items():
        manifest['packs'][pack]={'author':SOURCES[pack][0],'url':SOURCES[pack][1],'archive_sha256':sha(path.read_bytes()),'raw_archive_committed':False}
        with zipfile.ZipFile(path) as z:
            for key,item in SELECTION.items():
                if item['pack']!=pack:continue
                raw=z.read(item['source']);original_sha=sha(raw);extra={}
                ext=Path(item['source']).suffix.lower()
                if ext=='.wav':raw,extra=pcm16(raw)
                dest=target/item['category']/(key+ext);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
                manifest['assets'][key]={**item,'path':'res://'+dest.relative_to(ROOT).as_posix(),'source_sha256':original_sha,'sha256':sha(raw),**extra}
            license_dir=ROOT/'third_party/licenses'/pack;license_dir.mkdir(parents=True,exist_ok=True)
            for filename in z.namelist():
                if Path(filename).name.lower() in ['license.txt','readme.txt']:
                    (license_dir/Path(filename).name).write_bytes(z.read(filename))
    manifest_path.parent.mkdir(parents=True,exist_ok=True);manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Installed {len(manifest["assets"])} production assets from {len(archives)} official packs into {target}.')
    print('Open the Godot project once to import textures and audio. Original archives stay local.')

if __name__=='__main__':run()
