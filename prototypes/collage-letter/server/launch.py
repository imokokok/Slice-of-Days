"""Portable Windows launcher; starts a loopback post office when needed."""
import argparse
import configparser
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import time
from urllib.request import urlopen

ROOT=Path(__file__).resolve().parent.parent
STATE=Path(os.environ.get('LOCALAPPDATA',str(Path.home())))/'CollageLetterServer'
STATE.mkdir(parents=True,exist_ok=True)
FLAGS=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0


def ensure_local_server():
    try:
        with urlopen('http://127.0.0.1:8787/health',timeout=1) as response:
            if json.load(response).get('service')=='collage-letter':
                return
    except (OSError,ValueError):
        pass
    log=(STATE/'server.log').open('a',encoding='utf-8')
    subprocess.Popen([sys.executable,str(ROOT/'server/app.py')],cwd=ROOT,
                     stdout=log,stderr=log,creationflags=FLAGS)
    log.close()
    for _ in range(30):
        try:
            with urlopen('http://127.0.0.1:8787/health',timeout=.3) as response:
                if json.load(response).get('service')=='collage-letter':
                    return
        except (OSError,ValueError):
            time.sleep(.1)


def launch(profile=None):
    config=configparser.ConfigParser()
    config.read(ROOT/'network.cfg',encoding='utf-8')
    url=config.get('server','url',fallback='http://127.0.0.1:8787').strip('"')
    if url.rstrip('/')=='http://127.0.0.1:8787':
        ensure_local_server()
    bundled=ROOT/'runtime/Godot.exe'
    engine=str(bundled) if bundled.exists() else os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot4')
    if not engine:
        raise SystemExit('Install Godot 4.5.1+ and add godot/godot4 to PATH, or set GODOT_BIN to its executable.')
    # A source ZIP has no editor cache: import its real image/audio files once.
    marker=ROOT/'.godot/open-pack-import-v3'
    if not marker.exists():
        with (STATE/'import.log').open('w',encoding='utf-8') as log:
            command=[engine,'--headless','--editor','--path',str(ROOT),'--import','--quit']
            # Godot 4.5 can fail while shutting down its first parallel import.
            # Retry the cached import once; only a successful run may launch.
            for attempt in range(2):
                result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=log,creationflags=FLAGS)
                if result.returncode==0:
                    break
                if attempt==1:
                    raise subprocess.CalledProcessError(result.returncode,command)
        marker.write_text('Imported open-pack image and audio resources.\n',encoding='utf-8')
    command=[engine,'--path',str(ROOT)]
    if profile:
        command+=['--',f'--profile={profile}']
    with (STATE/f'game-{profile or "default"}.log').open('w',encoding='utf-8') as log:
        subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=log)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--demo',action='store_true')
    parser.add_argument('--server-only',action='store_true')
    args=parser.parse_args()
    if args.server_only:
        ensure_local_server()
    elif args.demo:
        launch('Player-A'); launch('Player-B')
    else:
        launch()
