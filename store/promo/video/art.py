"""Prepare the promo's art from the repo's own art (stdlib + Pillow + numpy).

- art/promo/chimp_sign.png (neon tubes on black, made with Codex / ChatGPT image generation) -> assets/art/chimp_sign.webp:
  the black is turned into transparency ("unscreen": alpha = brightest channel, colour divided by it), so the tubes and
  their glow sit on any background the way light would.
- art/promo/chimp_3d.png (transparent, Codex / ChatGPT) -> assets/art/chimp_3d.webp, cropped to its visible pixels.
- art/app_icon_neon.png -> assets/art/icon.webp (512 px).

    python3 art.py
"""
import pathlib

import numpy as np
from PIL import Image

here = pathlib.Path(__file__).parent
repo = here.parents[2]
out = here / 'assets' / 'art'


def unscreen(src):
    rgb = np.asarray(Image.open(src).convert('RGB')).astype(np.float32) / 255
    a = rgb.max(axis=2)
    a = np.clip((a - 0.03) / 0.97, 0, 1)  # the "black" background is not quite 0: lift it to fully clear
    col = np.where(a[..., None] > 1e-4, rgb / np.maximum(rgb.max(axis=2, keepdims=True), 1e-4), 0)
    rgba = np.dstack([col, a]) * 255
    return Image.fromarray(rgba.round().astype(np.uint8), 'RGBA')


def crop_visible(im, pad=8):
    bbox = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    l, t, r, b = bbox
    return im.crop((max(0, l - pad), max(0, t - pad), min(im.width, r + pad), min(im.height, b)))


if __name__ == '__main__':
    out.mkdir(parents=True, exist_ok=True)
    sign = crop_visible(unscreen(repo / 'art' / 'promo' / 'chimp_sign.png'), 24)
    sign.save(out / 'chimp_sign.webp', quality=92, method=6)
    chimp = crop_visible(Image.open(repo / 'art' / 'promo' / 'chimp_3d.png').convert('RGBA'))
    chimp.save(out / 'chimp_3d.webp', quality=92, method=6)
    Image.open(repo / 'art' / 'app_icon_neon.png').convert('RGB').resize((512, 512), Image.LANCZOS).save(out / 'icon.webp', quality=92, method=6)
    for p in sorted(out.iterdir()):
        im = Image.open(p)
        print(f'{p.name}: {im.size[0]}x{im.size[1]}, {p.stat().st_size // 1024} KB')
