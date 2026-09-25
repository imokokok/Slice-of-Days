"""Prepare the retained temporary walk cycle. Legacy workshop raster art is retired."""
from pathlib import Path
from PIL import Image
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('generated', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
walk = root / 'art/characters/temporary_walk'
walk.mkdir(parents=True, exist_ok=True)

def trim(image):
    box = image.getchannel('A').point(lambda a: 255 if a > 20 else 0).getbbox()
    assert box, 'Empty generated cutout'
    return image.crop(box)

sheet = Image.open(args.generated / 'exec-24a45c6f-3053-443e-a58c-ab3f00a0789a.png').convert('RGBA')
for i in range(4):
    x, y = (i % 2) * 627, (i // 2) * 627
    frame = trim(sheet.crop((x, y, x + 627, y + 627)))
    ratio = 600 / frame.height
    frame = frame.resize((round(frame.width * ratio), 600), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (448, 616))
    canvas.alpha_composite(frame, ((448 - frame.width) // 2, 8))
    canvas.save(walk / ('step_%02d.png' % i))
print('Prepared four foot-aligned temporary walking frames.')
