"""Crop/normalize imagegen output only; never draw replacement artwork."""
from pathlib import Path
from PIL import Image
import argparse
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('generated', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / 'art/ui/handmade/workshop'
walk = root / 'art/characters/temporary_walk'
out.mkdir(parents=True, exist_ok=True)
walk.mkdir(parents=True, exist_ok=True)

def trim(image):
    box = image.getchannel('A').point(lambda a: 255 if a > 20 else 0).getbbox()
    assert box, 'Empty generated cutout'
    return image.crop(box)

sheet = Image.open(args.generated / 'exec-9067af46-6826-459e-a88f-2ba3f069d799.png').convert('RGBA')
regions = {
    'scissors': (0, 0, 410, 409), 'knife': (415, 0, 715, 410),
    'tape': (720, 0, 1080, 410), 'mat': (1081, 0, 1448, 410),
    'pen': (0, 410, 360, 783), 'envelope': (365, 410, 715, 739),
    'wax-tray': (720, 410, 1080, 748), 'candle': (1081, 410, 1448, 748),
    'spoon': (0, 792, 418, 1086), 'stamp': (420, 746, 715, 1086),
    'matchbox': (720, 755, 1080, 1086), 'tape-strip': (1081, 765, 1448, 1086),
}
for name, box in regions.items():
    trim(sheet.crop(box)).save(out / (name + '.png'))
typewriter = Image.open(args.generated / 'exec-27a586d1-de35-4342-a96b-e0225832c35e.png').convert('RGBA')
trim(typewriter).save(out / 'typewriter.png')
shutil.copy2(args.generated / 'exec-30d54814-17a3-49e2-895c-9c9c64cf9a78.png', out / 'desk.png')

sheet = Image.open(args.generated / 'exec-24a45c6f-3053-443e-a58c-ab3f00a0789a.png').convert('RGBA')
for i in range(4):
    x, y = (i % 2) * 627, (i // 2) * 627
    frame = trim(sheet.crop((x, y, x + 627, y + 627)))
    ratio = 600 / frame.height
    frame = frame.resize((round(frame.width * ratio), 600), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (448, 616))
    canvas.alpha_composite(frame, ((448 - frame.width) // 2, 8))
    canvas.save(walk / ('step_%02d.png' % i))
print('Prepared 14 workshop assets and four foot-aligned temporary walking frames.')
