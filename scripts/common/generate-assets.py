#!/usr/bin/env python3
"""
Upfly Code - gerador de assets de marca.

Gera, a partir de branding/symbol.png:
  - branding/icon.png       (1024 px, fundo escuro arredondado)
  - branding/icon-256.png e icon-512.png
  - branding/icon.ico       (Windows, multi-tamanho)
  - branding/icon.icns      (macOS)
e gera o fundo original:
  - branding/background.jpg (3840x2160) e background-1080p.jpg

Uso:
  python3 scripts/common/generate-assets.py [--primary 0080FF] [--seed 7]

Dependências: Pillow, numpy, icnsutil (apenas para o .icns)
  pip install pillow numpy icnsutil
"""
import argparse
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
BRANDING = ROOT / "branding"


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# --------------------------------------------------------------------------- #
# Ícone
# --------------------------------------------------------------------------- #
def make_icon(primary, bg=(10, 15, 28)):
    sym = Image.open(BRANDING / "symbol.png").convert("RGBA")
    a = np.array(sym)
    # texto preto -> branco, para contrastar com o fundo escuro do ícone
    black = (a[..., 3] > 0) & (a[..., 0] < 60) & (a[..., 1] < 60) & (a[..., 2] < 60)
    a[black, 0:3] = 255
    sym = Image.fromarray(a)

    size = 1024
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # quadrado arredondado (estilo "squircle" simples)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((40, 40, size - 40, size - 40), radius=220, fill=255)
    base = Image.new("RGBA", (size, size), bg + (255,))
    # brilho radial sutil na cor primária
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.sqrt((xx - size * 0.5) ** 2 + (yy - size * 0.45) ** 2) / (size * 0.6)
    glow = np.clip(1 - d, 0, 1) ** 2 * 0.35
    arr = np.array(base).astype(np.float32)
    for i, c in enumerate(primary):
        arr[..., i] = arr[..., i] * (1 - glow) + c * glow
    base = Image.fromarray(arr.astype(np.uint8))
    canvas.paste(base, (0, 0), mask)

    target = int(size * 0.74)
    sym.thumbnail((target, target), Image.LANCZOS)
    ox = (size - sym.width) // 2
    oy = (size - sym.height) // 2
    canvas.alpha_composite(sym, (ox, oy))
    return canvas


def save_icons(icon):
    icon.save(BRANDING / "icon.png")
    icon.resize((256, 256), Image.LANCZOS).save(BRANDING / "icon-256.png")
    icon.resize((512, 512), Image.LANCZOS).save(BRANDING / "icon-512.png")
    icon.save(BRANDING / "icon.ico",
              sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    try:
        import icnsutil
        tmp = BRANDING / ".icns-tmp"
        tmp.mkdir(exist_ok=True)
        img = icnsutil.IcnsFile()
        for px, key in [(16, "icp4"), (32, "icp5"), (64, "icp6"), (128, "ic07"),
                        (256, "ic08"), (512, "ic09"), (1024, "ic10")]:
            p = tmp / f"{px}.png"
            icon.resize((px, px), Image.LANCZOS).save(p)
            img.add_media(key, file=str(p))
        img.write(str(BRANDING / "icon.icns"))
        for f in tmp.iterdir():
            f.unlink()
        tmp.rmdir()
    except ImportError:
        print("icnsutil não instalado: icon.icns não foi gerado (pip install icnsutil)")


# --------------------------------------------------------------------------- #
# Fundo original
# --------------------------------------------------------------------------- #
def make_background(primary, seed=7, W=3840, H=2160):
    rng = random.Random(seed)
    np_rng = np.random.default_rng(seed)
    cyan = (0, 212, 255)
    violet = (110, 60, 255)

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # 1) gradiente base: azul-marinho profundo
    top = np.array([4, 7, 18], np.float32)
    bottom = np.array([8, 14, 34], np.float32)
    t = (yy / H)[..., None]
    img = top * (1 - t) + bottom * t

    def add_glow(cx, cy, radius, color, strength):
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
        g = np.exp(-d ** 2) * strength
        return g[..., None] * np.array(color, np.float32)

    # 2) nebulosas suaves
    img += add_glow(W * 0.70, H * 0.42, W * 0.30, primary, 0.22)
    img += add_glow(W * 0.92, H * 0.12, W * 0.22, violet, 0.35)
    img += add_glow(W * 0.50, H * 0.05, W * 0.20, violet, 0.12)
    img += add_glow(W * 0.15, H * 0.95, W * 0.25, cyan, 0.10)
    # brilho do horizonte
    hz = np.exp(-((yy - H * 0.72) / (H * 0.035)) ** 2) * np.exp(-((xx - W * 0.70) / (W * 0.40)) ** 2)
    img += hz[..., None] * np.array(cyan, np.float32) * 0.35

    # 3) grade em perspectiva no chão (estética "synthwave", bem discreta)
    grid = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(grid)
    horizon = int(H * 0.72)
    vx = W * 0.70
    for i in range(-40, 41):
        x_bottom = vx + i * W * 0.06
        gd.line([(vx, horizon), (x_bottom, H)], fill=150, width=3)
    for k in range(1, 28):
        y = horizon + (H - horizon) * (k / 28) ** 2.2
        gd.line([(0, y), (W, y)], fill=150, width=3)
    garr = np.array(grid, np.float32) / 255.0
    fade = np.clip((yy - horizon) / (H - horizon), 0, 1) ** 1.3
    garr *= fade
    img += garr[..., None] * np.array(primary, np.float32) * 0.9

    # 4) círculo de pinceladas (eco do símbolo Upfly), com brilho neon
    ring = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(ring)
    cx, cy, R = W * 0.70, H * 0.42, H * 0.30
    for _ in range(220):
        r = R + rng.gauss(0, R * 0.05)
        start = rng.uniform(60, 160)
        extent = rng.uniform(120, 330)
        width = max(1, int(abs(rng.gauss(2, 3))))
        alpha = rng.randint(40, 230)
        box = (cx - r, cy - r, cx + r, cy + r)
        rd.arc(box, start=start, end=start + extent, fill=alpha, width=width)
    # traço grosso principal no lado esquerdo, como no logo
    for j in range(30):
        r = R * 0.95 + j * 1.8 + rng.gauss(0, 2)
        s0 = 100 + rng.uniform(-10, 10)
        rd.arc((cx - r, cy - r, cx + r, cy + r), start=s0, end=s0 + rng.uniform(130, 170),
               fill=rng.randint(150, 255), width=2)
    rarr = np.array(ring, np.float32) / 255.0
    rblur1 = np.array(ring.filter(ImageFilter.GaussianBlur(12)), np.float32) / 255.0
    rblur2 = np.array(ring.filter(ImageFilter.GaussianBlur(60)), np.float32) / 255.0
    neon = np.array(primary, np.float32)
    img += rblur2[..., None] * (neon * 0.7 + np.array(violet, np.float32) * 0.3) * 1.1
    img += rblur1[..., None] * neon * 0.8
    img += rarr[..., None] * (neon * 0.55 + np.array([200, 235, 255], np.float32) * 0.45) * 0.9

    # 5) seta para cima (abstrata), dentro do círculo
    arrow = Image.new("L", (W, H), 0)
    ad = ImageDraw.Draw(arrow)
    ax, ay, s = cx - R * 0.42, cy - R * 0.30, R * 0.22
    ad.polygon([(ax, ay - s), (ax - s * 0.75, ay + s * 0.15), (ax - s * 0.2, ay + s * 0.15),
                (ax, ay + s * 1.5), (ax + s * 0.2, ay + s * 0.15), (ax + s * 0.75, ay + s * 0.15)],
               fill=255)
    aarr = np.array(arrow, np.float32) / 255.0
    ablur = np.array(arrow.filter(ImageFilter.GaussianBlur(30)), np.float32) / 255.0
    img += ablur[..., None] * neon * 1.0
    img += aarr[..., None] * neon * 0.9

    # 6) linhas de luz diagonais ("velocidade")
    streaks = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(streaks)
    for _ in range(26):
        x0 = rng.uniform(-W * 0.2, W)
        y0 = rng.uniform(0, H)
        length = rng.uniform(W * 0.05, W * 0.25)
        ang = math.radians(-28)
        sd.line([(x0, y0), (x0 + length * math.cos(ang), y0 + length * math.sin(ang))],
                fill=rng.randint(30, 110), width=rng.choice([1, 2, 2, 3]))
    sarr = np.array(streaks.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    img += sarr[..., None] * np.array(cyan, np.float32) * 0.7

    # 7) partículas/estrelas
    n = 1600
    px = np_rng.integers(0, W, n)
    py = np_rng.integers(0, int(H * 0.75), n)
    stars = np.zeros((H, W), np.float32)
    stars[py, px] = np_rng.uniform(0.2, 1.0, n)
    stars_img = Image.fromarray((stars * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1))
    st = np.array(stars_img, np.float32) / 255.0 * 3.0
    img += st[..., None] * np.array([170, 210, 255], np.float32)

    # 8) vinheta para manter o centro-esquerdo (onde fica o texto) mais calmo
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    vign = np.clip(1 - 0.45 * d ** 1.8, 0.35, 1)
    img *= vign[..., None]
    # escurece a faixa esquerda (área de leitura)
    left = np.clip(1 - (1 - xx / (W * 0.45)) * 0.35, 0.65, 1)
    img *= left[..., None]

    # granulação leve
    img += np_rng.normal(0, 2.0, img.shape).astype(np.float32)
    img = np.clip(img, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--primary", default="0080FF", help="cor principal em hex (padrão: azul Upfly)")
    ap.add_argument("--seed", type=int, default=7, help="semente do fundo (mude para variar)")
    ap.add_argument("--skip-background", action="store_true")
    args = ap.parse_args()
    primary = hex_rgb(args.primary)

    save_icons(make_icon(primary))
    print("ícones gerados em", BRANDING)
    if not args.skip_background:
        bg = make_background(primary, seed=args.seed)
        bg.save(BRANDING / "background.jpg", quality=92, subsampling=0)
        bg.resize((1920, 1080), Image.LANCZOS).save(BRANDING / "background-1080p.jpg", quality=92)
        print("fundo gerado em", BRANDING / "background.jpg")


if __name__ == "__main__":
    main()
