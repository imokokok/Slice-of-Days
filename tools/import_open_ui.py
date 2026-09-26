"""Install selected, unmodified CC0 UI resources; record every byte's provenance.

Downloads stay in .runtime. This script only extracts explicitly selected members.
Runtime tinting and sizing happen in Godot, leaving source images untouched.
"""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.runtime/open-source-polish'
MANIFEST = ROOT / 'data/presentation/open_ui_manifest.json'
DOWNLOADS = {
    'skymon': 'https://opengameart.org/sites/default/files/skymon-icons-free-v250329.zip',
    'interface': 'https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip',
    'rpg': 'https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip',
}
ICON_NAMES = {
    'book': 'reading-book', 'personal': 'user', 'star': 'star-alt',
    'mail': 'inbox', 'photo': 'image-square', 'life': 'image-square',
    'requirements': 'quest', 'add': 'plus', 'text': 'paper',
    'draw': 'pencil', 'pause': 'pause', 'back': 'left-arrow',
    'close': 'close-x', 'settings': 'settings', 'sound': 'volume-medium',
    'mute': 'volume-mute', 'clock': 'wall-clock', 'sun': 'sun',
    'moon': 'moon', 'rain': 'umbrella', 'cloud': 'cloud',
    'coin': 'coin', 'check': 'check-mark', 'notice': 'bell',
    'error': 'info-round', 'map': 'map1', 'place': 'map-marker',
    'bag': 'pouch', 'heart': 'plain-heart', 'camera': 'camera',
    'move': 'footprint', 'zoom_in': 'zoom-plus', 'zoom_out': 'zoom-minus',
    'coffee': 'coffee', 'water': 'water-drop', 'fire': 'fire',
    'lock': 'padlock-locked', 'expand': 'arrows-expand', 'home': 'home',
}

# Cue names match actual runtime interactions, not filenames guessed by callers.
SOUNDS = {
    'click': ('interface', ['click_003'], -23),
    'focus': ('interface', ['select_001'], -30),
    'dialogue': ('interface', ['click_001'], -27),
    'error': ('interface', ['error_004'], -23),
    'notification': ('interface', ['confirmation_002'], -23),
    'check': ('interface', ['confirmation_001'], -23),
    'record_start': ('interface', ['switch_002'], -23),
    'record_stop': ('interface', ['switch_003'], -23),
    'slider': ('interface', ['scroll_001'], -29),
    'tab': ('interface', ['back_001'], -25),
    'snap': ('interface', ['click_005'], -26),
    'open': ('rpg', ['bookOpen'], -24),
    'close': ('rpg', ['bookClose'], -26),
    'paper': ('rpg', ['bookFlip1', 'bookFlip2', 'bookFlip3'], -24),
    'coin': ('rpg', ['handleCoins', 'handleCoins2'], -22),
    'drag': ('rpg', ['cloth1'], -28),
    'drop': ('rpg', ['cloth2'], -26),
    'cut': ('rpg', ['chop'], -23),
    'pot': ('rpg', ['metalPot1', 'metalPot2'], -26),
    'door_open': ('rpg', ['doorOpen_1'], -24),
    'door_close': ('rpg', ['doorClose_1'], -26),
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    manifest = json.loads(MANIFEST.read_text('utf-8')) if MANIFEST.exists() else {'packs': {}, 'icons': {}, 'sounds': {}}
    # Existing manifest pins each archive, preventing silent upstream replacement.
    import urllib.request
    CACHE.mkdir(parents=True, exist_ok=True)
    for pack, url in DOWNLOADS.items():
        path = CACHE / f'{pack}.zip'
        if not path.exists():
            request = urllib.request.Request(url, headers={'User-Agent': 'Solmere-resource-installer/1.0'})
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read()
            expected = manifest.get('packs', {}).get(pack, {}).get('archive_sha256')
            if expected and digest(payload) != expected:
                raise ValueError(f'{pack}: upstream archive differs from audited version')
            path.write_bytes(payload)
        expected = manifest.get('packs', {}).get(pack, {}).get('archive_sha256')
        if expected and digest(path.read_bytes()) != expected:
            raise ValueError(f'{pack}: cached archive differs from audited version')
    archive_path = CACHE / 'skymon.zip'
    archive_bytes = archive_path.read_bytes()
    manifest['packs']['skymon'] = {
        'author': 'Deface Games / Amanz', 'license': 'CC0-1.0', 'version': 'v250329',
        'page': 'https://defacegames.com/product/skymon-icon-pack-free/',
        'license_page': 'https://opengameart.org/content/skymon-icon-pack-free',
        'download': 'https://opengameart.org/sites/default/files/skymon-icons-free-v250329.zip',
        'archive_sha256': digest(archive_bytes), 'modification': 'None; only runtime tint and scale.',
    }
    with ZipFile(archive_path) as archive:
        for key, name in ICON_NAMES.items():
            member = f'skymon-icons-white/{name}.png'
            data = archive.read(member)
            relative = f'art/ui/open_sketch/{name}.png'
            destination = ROOT / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
            manifest['icons'][key] = {'path': 'res://' + relative, 'pack': 'skymon', 'member': member, 'sha256': digest(data)}
        readme = ROOT / 'third_party/licenses/skymon/readme.pdf'
        readme.parent.mkdir(parents=True, exist_ok=True)
        readme.write_bytes(archive.read('readme.pdf'))
    for pack, page in [('interface', 'interface-sounds'), ('rpg', 'rpg-audio')]:
        archive_path = CACHE / f'{pack}.zip'
        manifest['packs'][pack] = {
            'author': 'Kenney', 'license': 'CC0-1.0',
            'page': f'https://kenney.nl/assets/{page}',
            'author': 'Kenney / Kenney Vleugels', 'license': 'CC0-1.0',
            'page': f'https://kenney.nl/assets/{page}',
            'download': DOWNLOADS[pack],
            'archive_sha256': digest(archive_path.read_bytes()),
            'modification': 'Original OGG bytes; runtime volume only.',
        }
        with ZipFile(archive_path) as archive:
            license_path = ROOT / f'third_party/licenses/kenney_{pack}/LICENSE.txt'
            license_path.parent.mkdir(parents=True, exist_ok=True)
            license_path.write_bytes(archive.read('License.txt'))
            for cue, (source_pack, names, volume) in SOUNDS.items():
                if pack != source_pack:
                    continue
                variants = []
                for name in names:
                    member = f'Audio/{name}.ogg'
                    data = archive.read(member)
                    relative = f'audio/open_foley/{pack}/{name}.ogg'
                    destination = ROOT / relative
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(data)
                    variants.append({'path': 'res://' + relative, 'member': member, 'sha256': digest(data)})
                manifest['sounds'][cue] = {'pack': pack, 'volume_db': volume, 'variants': variants}
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    print(f'Installed {len(set(ICON_NAMES.values()))} original icon files, {len(ICON_NAMES)} semantic roles.')
    print(f'Installed {sum(len(v[1]) for v in SOUNDS.values())} OGG files for {len(SOUNDS)} runtime cues.')


if __name__ == '__main__':
    main()
