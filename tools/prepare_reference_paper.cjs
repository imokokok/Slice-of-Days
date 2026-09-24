// Post-generation cutout only: keep the generated drawing and remove its backdrop.
// Usage: node prepare_reference_paper.cjs GENERATED_IMAGE_DIRECTORY
const sharp = require('sharp');
const fs = require('node:fs');
const path = require('node:path');
const source = process.argv[2];
const output = path.resolve(__dirname, '../art/ui/reference_paper');
fs.mkdirSync(output, { recursive: true });
(async () => {
  const { data, info } = await sharp(path.join(source, 'exec-8f91e830-679c-4e1f-85f2-05be361ffcce.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let p = 0; p < data.length; p += 4) {
    const r = data[p], g = data[p + 1], b = data[p + 2];
    const a = Math.max(0, 1 - Math.max(0, Math.min(r, b) - g - 12) / 243);
    if (a < .08) { data[p + 3] = 0; continue; }
    if (a < 1) {
      data[p] = Math.max(0, Math.min(255, (r - 255 * (1 - a)) / a));
      data[p + 1] = Math.min(255, g / a);
      data[p + 2] = Math.max(0, Math.min(255, (b - 255 * (1 - a)) / a));
      data[p + 3] = Math.round(255 * a);
    }
  }
  await sharp(data, { raw: info }).png().toFile(path.join(output, 'clipboard.png'));
  const outline = '64,218 64,180 78,152 108,140 609,186 635,208 650,203 678,210 709,190 1462,164 1487,175 1497,207 1499,793 1482,818 1455,827 722,834 691,827 678,816 654,827 631,817 87,803 63,790 50,762 55,271 63,241';
  const mask = Buffer.from(`<svg width="1536" height="1024"><polygon points="${outline}" fill="white"/></svg>`);
  await sharp(path.join(source, 'exec-2cc120cd-c85d-4401-a561-8f8b494bde33.png')).ensureAlpha().composite([{ input: mask, blend: 'dest-in' }]).png().toFile(path.join(output, 'cassette.png'));
  console.log(JSON.stringify({ output, images: ['clipboard.png', 'cassette.png'] }));
})();
