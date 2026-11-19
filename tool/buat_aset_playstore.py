"""Membuat ikon launcher dan aset listing Google Play dari LOGO_PAPB.png.

Pemakaian (dari folder proyek):  python tool/buat_aset_playstore.py [folder_screenshot]

Hasil:
  android/app/src/main/res/mipmap-*/ic_launcher.png      ikon lama (Android < 8)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png + mipmap-anydpi-v26/ic_launcher.xml
  store/icon-512.png               ikon Play Store (512×512)
  store/feature-graphic.png        feature graphic (1024×500)
  store/screenshots/*.png          screenshot HP (dipotong: tanpa status bar, pita DEBUG, tombol navigasi)
  web/favicon.png, web/icons/*     ikon versi web (tab browser, PWA, ikon layar utama iPhone)

Screenshot riwayat sengaja tidak dipakai karena memuat foto wajah orang.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'android/app/src/main/res'
STORE = ROOT / 'store'
WEB = ROOT / 'web'
GREEN_DARK = (23, 84, 55)
GREEN = (38, 112, 74)


def load_logo() -> Image.Image:
    src = Image.open(ROOT / 'LOGO_PAPB.png').convert('RGBA')
    return src.crop(src.getchannel('A').getbbox())  # buang ruang transparan


def launcher_icons(logo: Image.Image) -> None:
    # Ikon lama: logo utuh (sudah berbentuk kotak membulat).
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for density, px in legacy.items():
        out = RES / f'mipmap-{density}'
        out.mkdir(parents=True, exist_ok=True)
        logo.resize((px, px), Image.LANCZOS).save(out / 'ic_launcher.png', optimize=True)

    # Ikon adaptif: lapisan 108 dp, yang terlihat hanya ±72 dp di tengah dan
    # dipotong bentuk (lingkaran/kotak membulat) oleh launcher. Logo dibuat 54 dp
    # supaya sudutnya tidak terpotong.
    adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
    for density, px in adaptive.items():
        canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        size = round(px * 54 / 108)
        scaled = logo.resize((size, size), Image.LANCZOS)
        canvas.paste(scaled, ((px - size) // 2, (px - size) // 2), scaled)
        canvas.save(RES / f'mipmap-{density}' / 'ic_launcher_foreground.png', optimize=True)

    anydpi = RES / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding='utf-8',
    )
    colors = RES / 'values/ic_launcher_background.xml'
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n',
        encoding='utf-8',
    )


def square(logo: Image.Image) -> Image.Image:
    """Logo dijadikan persegi dengan menambah ruang transparan (tanpa melar)."""
    side = max(logo.size)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(logo, ((side - logo.width) // 2, (side - logo.height) // 2), logo)
    return canvas


def full_bleed(logo: Image.Image, px: int, scale: float) -> Image.Image:
    """Kotak penuh tanpa bagian transparan: latar gradasi hijau dari tepi logo,
    lalu logo di tengah. Dipakai untuk ikon iPhone (iOS mengisi bagian
    transparan dengan hitam) dan ikon maskable Android."""
    w, h = logo.size
    top = logo.getpixel((w // 2, int(h * 0.03)))[:3]
    bottom = logo.getpixel((w // 2, int(h * 0.97)))[:3]
    canvas = Image.new('RGBA', (px, px))
    draw = ImageDraw.Draw(canvas)
    for y in range(px):
        t = y / max(px - 1, 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        draw.line([(0, y), (px, y)], fill=color + (255,))
    size = round(px * scale)
    scaled = square(logo).resize((size, size), Image.LANCZOS)
    canvas.alpha_composite(scaled, ((px - size) // 2, (px - size) // 2))
    return canvas.convert('RGB')


def web_icons(logo: Image.Image) -> None:
    """Ikon versi web. Sebelumnya masih ikon bawaan Flutter."""
    icons = WEB / 'icons'
    icons.mkdir(parents=True, exist_ok=True)
    sq = square(logo)
    sq.resize((32, 32), Image.LANCZOS).save(WEB / 'favicon.png', optimize=True)
    for px in (192, 512):
        sq.resize((px, px), Image.LANCZOS).save(icons / f'Icon-{px}.png', optimize=True)
        # Maskable: konten penting harus di dalam lingkaran 80% di tengah.
        full_bleed(logo, px, 0.8).save(icons / f'Icon-maskable-{px}.png', optimize=True)
    full_bleed(logo, 180, 1.0).save(icons / 'apple-touch-icon.png', optimize=True)


def store_icon(logo: Image.Image) -> None:
    # Play Store memotong sudut sendiri, jadi ikon dibuat penuh tanpa transparan.
    icon = Image.new('RGB', (512, 512), (255, 255, 255))
    size = 440
    scaled = logo.resize((size, size), Image.LANCZOS)
    icon.paste(scaled, ((512 - size) // 2, (512 - size) // 2), scaled)
    icon.save(STORE / 'icon-512.png', optimize=True)


def font(names: list[str], size: int) -> ImageFont.FreeTypeFont:
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def feature_graphic(logo: Image.Image) -> None:
    w, h = 1024, 500
    img = Image.new('RGB', (w, h), GREEN_DARK)
    draw = ImageDraw.Draw(img)
    for x in range(w):  # gradasi hijau tua → hijau
        t = x / (w - 1)
        color = tuple(round(GREEN_DARK[i] + (GREEN[i] - GREEN_DARK[i]) * t) for i in range(3))
        draw.line([(x, 0), (x, h)], fill=color)
    size = 330
    scaled = logo.resize((size, size), Image.LANCZOS)
    img.paste(scaled, (70, (h - size) // 2), scaled)
    title = font(['C:/Windows/Fonts/segoeuib.ttf', 'DejaVuSans-Bold.ttf'], 96)
    body = font(['C:/Windows/Fonts/segoeui.ttf', 'DejaVuSans.ttf'], 38)
    draw.text((450, 140), 'Racik', font=title, fill='white')
    draw.text((452, 265), 'Pindai makanan,', font=body, fill=(230, 244, 235))
    draw.text((452, 312), 'kenali gizi dan skor sehatnya', font=body, fill=(230, 244, 235))
    img.save(STORE / 'feature-graphic.png', optimize=True)


def screenshots(folder: Path) -> None:
    # (nama file WhatsApp, nama hasil) — urutan = urutan tampil di Play Store
    chosen = [
        ('17.36.09', '1-hasil-pindai'),
        ('17.36.10', '2-skor-dan-nutrisi'),
        ('17.36.02', '3-cari-resep'),
        ('17.36.03', '4-detail-resep'),
        ('17.36.10 (1)', '5-pindai-makanan'),
    ]
    out = STORE / 'screenshots'
    out.mkdir(parents=True, exist_ok=True)
    for stamp, name in chosen:
        src = folder / f'WhatsApp Image 2026-09-29 at {stamp}.jpeg'
        im = Image.open(src).convert('RGB')
        # Buang status bar + pita DEBUG (atas) dan tombol navigasi (bawah).
        # Hasil 738×1432 memenuhi syarat Play: sisi panjang ≤ 2× sisi pendek.
        im = im.crop((0, 84, im.width, im.height - 86))
        # Sisa ujung pita DEBUG di pojok kanan atas ditutup warna app bar.
        bar = im.getpixel((640, 4))
        w = im.width
        ImageDraw.Draw(im).polygon(
          [(w - 46, 0), (w, 0), (w, 42), (w - 6, 42)],
          fill=bar,
        )
        im.save(out / f'{name}.png', optimize=True)


if __name__ == '__main__':
    STORE.mkdir(exist_ok=True)
    logo = load_logo()
    launcher_icons(logo)
    store_icon(logo)
    feature_graphic(logo)
    web_icons(logo)
    if len(sys.argv) > 1:
        screenshots(Path(sys.argv[1]))
    print('Selesai:', STORE)
