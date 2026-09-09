#!/usr/bin/env python3
"""
كِتابي — مولّد الأصول البصرية (يُشغَّل مرة واحدة وقت التطوير)
  1) 24 غلاف كتاب مُصمَّم (assets/covers/book_N.png) بعنوان ومؤلف حقيقيين
  2) شعار العلامة (assets/brand/logo.png)
  3) أيقونة إطلاق متكيّفة لأندرويد (mipmap-*/ic_launcher*.png + anydpi-v26 xml)
  4) أيقونات الويب (web/icons/*, web/favicon.png)
المتطلبات: Pillow (مع libraqm), خط Amiri في /home/user/fonts
"""
import os, re, colorsys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_B = '/home/user/fonts/Amiri-Bold.ttf'
FONT_R = '/home/user/fonts/Amiri-Regular.ttf'
GOLD = (212, 175, 55)
NIGHT = (18, 22, 31)
IVORY = (244, 239, 228)

# Pillow مبني مع libraqm → يقوم بالتشكيل والاتجاه تلقائيًا
def ar(t):
    return t

_orig_text = ImageDraw.ImageDraw.text
_orig_len = ImageDraw.ImageDraw.textlength
def _text(self, xy, text, *a, **k):
    k.setdefault('direction', 'rtl'); k.setdefault('features', ['kern', 'liga'])
    return _orig_text(self, xy, text, *a, **k)
def _len(self, text, *a, **k):
    k.setdefault('direction', 'rtl')
    return _orig_len(self, text, *a, **k)
ImageDraw.ImageDraw.text = _text
ImageDraw.ImageDraw.textlength = _len

def font(path, size):
    return ImageFont.truetype(path, size)

# ---------------------------------------------------------------- parse seed.dart
def parse_seed():
    src = open(os.path.join(ROOT, 'lib/data/seed.dart'), encoding='utf-8').read()
    cats = {int(m[0]): (m[1], int(m[2], 16)) for m in re.findall(
        r"\((\d+), '([^']+)', '[^']+', 0x([0-9A-Fa-f]{8})\)", src)}
    books = []
    for m in re.finditer(r"\((\d+), (\d+), '([^']+)', '([^']+)', ([\d.]+), (null|[\d.]+), ([\d.]+), (\d+), (\d+), (\d), *\n?\s*'", src):
        books.append(dict(id=int(m[1]), cat=int(m[2]), title=m[3], author=m[4], year=int(m[9])))
    return cats, books

def shade(rgb, f):
    return tuple(max(0, min(255, int(c * f))) for c in rgb)

def hex_rgb(v):
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255)

def wrap(draw, text, fnt, maxw):
    words = text.split()
    lines, cur = [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(ar(t), font=fnt) <= maxw:
            cur = t
        else:
            if cur: lines.append(cur)
            cur = w
    if cur: lines.append(cur)
    return lines

# ---------------------------------------------------------------- covers
def make_cover(b, cat, out):
    W, H = 600, 900
    base = hex_rgb(cat[1])
    img = Image.new('RGB', (W, H), base)
    d = ImageDraw.Draw(img)
    # تدرّج عمودي
    for y in range(H):
        f = 1.15 - 0.45 * (y / H)
        d.line([(0, y), (W, y)], fill=shade(base, f))
    # نمط هندسي خفيف حسب رقم الكتاب
    pat = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pat)
    style = b['id'] % 4
    for i in range(-H, W + H, 70):
        if style == 0:
            pd.line([(i, 0), (i + H, H)], fill=(255, 255, 255, 14), width=3)
        elif style == 1:
            pd.ellipse([i, (i * 3) % H, i + 220, (i * 3) % H + 220], outline=(255, 255, 255, 16), width=3)
        elif style == 2:
            pd.rectangle([i, i % 300, i + 160, i % 300 + 160], outline=(255, 255, 255, 14), width=3)
        else:
            pd.polygon([(i, H), (i + 120, H - 260), (i + 240, H)], outline=(255, 255, 255, 14), width=3)
    img.paste(pat, (0, 0), pat)
    d = ImageDraw.Draw(img)
    # كعب الكتاب (يسار) + ظل
    d.rectangle([0, 0, 26, H], fill=shade(base, 0.55))
    d.rectangle([26, 0, 34, H], fill=shade(base, 1.35))
    # إطار ذهبي داخلي
    d.rectangle([60, 60, W - 40, H - 60], outline=GOLD, width=3)
    d.rectangle([70, 70, W - 50, H - 70], outline=(*GOLD, ), width=1)
    # شريط تصنيف أعلى
    fcat = font(FONT_R, 26)
    ct = ar(cat[0])
    tw = d.textlength(ct, font=fcat)
    d.rounded_rectangle([(W - 40 - tw - 40), 88, W - 60, 130], radius=20, fill=GOLD)
    d.text((W - 60 - 20 - tw, 90), ct, font=fcat, fill=NIGHT)
    # زخرفة وسطية
    cx, cy = (W + 20) // 2, 330
    d.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], outline=GOLD, width=3)
    d.ellipse([cx - 56, cy - 56, cx + 56, cy + 56], outline=GOLD, width=1)
    ftitle_glyph = font(FONT_B, 64)
    g = ar(b['title'][0])
    gw = d.textlength(g, font=ftitle_glyph)
    d.text((cx - gw / 2, cy - 44), g, font=ftitle_glyph, fill=IVORY)
    # العنوان
    size = 56
    while True:
        ft = font(FONT_B, size)
        lines = wrap(d, b['title'], ft, W - 160)
        if len(lines) <= 3 or size <= 34:
            break
        size -= 4
    y = 450
    for ln in lines:
        t = ar(ln)
        tw = d.textlength(t, font=ft)
        d.text(((W + 20) / 2 - tw / 2 + 2, y + 2), t, font=ft, fill=(0, 0, 0, 90))
        d.text(((W + 20) / 2 - tw / 2, y), t, font=ft, fill=IVORY)
        y += size + 14
    # خط فاصل ذهبي
    d.line([(180, y + 18), (W - 140, y + 18)], fill=GOLD, width=2)
    d.ellipse([(W + 20) / 2 - 6, y + 12, (W + 20) / 2 + 6, y + 24], fill=GOLD)
    # المؤلف
    fa = font(FONT_R, 34)
    t = ar(b['author'])
    tw = d.textlength(t, font=fa)
    d.text(((W + 20) / 2 - tw / 2, y + 40), t, font=fa, fill=GOLD)
    # السنة + العلامة أسفل
    fy = font(FONT_R, 24)
    d.text((W - 60 - d.textlength(str(b['year']), font=fy), H - 118), str(b['year']), font=fy, fill=(*IVORY,))
    brand = ar('كِتابي')
    d.text((80, H - 120), brand, font=font(FONT_B, 26), fill=GOLD)
    # لمعة خفيفة
    gl = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    gd.polygon([(34, 0), (W, 0), (W, 140), (34, 300)], fill=(255, 255, 255, 12))
    img.paste(gl, (0, 0), gl)
    img = img.resize((300, 450), Image.LANCZOS)
    img.save(out, optimize=True)

# ---------------------------------------------------------------- brand / icon
def draw_logo(size, bg=True):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        d.rounded_rectangle([0, 0, size, size], radius=int(size * .22), fill=NIGHT)
    s = size
    # كتاب مفتوح ذهبي
    cx, cy = s / 2, s * 0.56
    w, h = s * 0.62, s * 0.36
    # الصفحتان
    left = [(cx - w / 2, cy - h / 2 + s * .04), (cx - s * .02, cy - h / 2 - s * .02),
            (cx - s * .02, cy + h / 2), (cx - w / 2, cy + h / 2 + s * .04)]
    right = [(cx + w / 2, cy - h / 2 + s * .04), (cx + s * .02, cy - h / 2 - s * .02),
             (cx + s * .02, cy + h / 2), (cx + w / 2, cy + h / 2 + s * .04)]
    d.polygon(left, fill=GOLD)
    d.polygon(right, fill=(232, 200, 90))
    # سطور
    for i in range(3):
        yy = cy - h / 4 + i * h / 4
        d.line([(cx - w / 2 + s * .07, yy + s * .02), (cx - s * .07, yy)], fill=NIGHT, width=max(2, int(s * .018)))
        d.line([(cx + s * .07, yy), (cx + w / 2 - s * .07, yy + s * .02)], fill=NIGHT, width=max(2, int(s * .018)))
    # إشارة مرجعية
    d.rectangle([cx - s * .03, cy - h / 2 - s * .12, cx + s * .03, cy - s * .02], fill=(142, 59, 70))
    # نجمة صغيرة أعلى
    r = s * .05
    sx, sy = cx, cy - h / 2 - s * .2
    pts = []
    for k in range(10):
        ang = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * .45
        pts.append((sx + rr * math.cos(ang), sy + rr * math.sin(ang)))
    d.polygon(pts, fill=GOLD)
    return img

def make_icons():
    res = os.path.join(ROOT, 'android/app/src/main/res')
    dens = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for k, sz in dens.items():
        dd = os.path.join(res, f'mipmap-{k}')
        os.makedirs(dd, exist_ok=True)
        # legacy icon (مستدير الزوايا على خلفية)
        draw_logo(sz).save(os.path.join(dd, 'ic_launcher.png'))
        # طبقات adaptive: 108dp مع منطقة آمنة 72dp
        layer = sz * 108 // 48
        fg = Image.new('RGBA', (layer, layer), (0, 0, 0, 0))
        logo = draw_logo(int(layer * 0.60), bg=False)
        fg.paste(logo, ((layer - logo.width) // 2, (layer - logo.height) // 2), logo)
        fg.save(os.path.join(dd, 'ic_launcher_foreground.png'))
        Image.new('RGBA', (layer, layer), (*NIGHT, 255)).save(os.path.join(dd, 'ic_launcher_background.png'))
    any_ = os.path.join(res, 'mipmap-anydpi-v26')
    os.makedirs(any_, exist_ok=True)
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '</adaptive-icon>\n')
    for n in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        open(os.path.join(any_, n), 'w').write(xml)
    # web
    wi = os.path.join(ROOT, 'web/icons')
    os.makedirs(wi, exist_ok=True)
    draw_logo(192).save(os.path.join(wi, 'Icon-192.png'))
    draw_logo(512).save(os.path.join(wi, 'Icon-512.png'))
    draw_logo(192).save(os.path.join(wi, 'Icon-maskable-192.png'))
    draw_logo(512).save(os.path.join(wi, 'Icon-maskable-512.png'))
    draw_logo(64).save(os.path.join(ROOT, 'web/favicon.png'))
    # brand
    bd = os.path.join(ROOT, 'assets/brand')
    os.makedirs(bd, exist_ok=True)
    draw_logo(512).save(os.path.join(bd, 'logo.png'))
    draw_logo(512, bg=False).save(os.path.join(bd, 'logo_mark.png'))

if __name__ == '__main__':
    cats, books = parse_seed()
    assert len(books) == 24, f'expected 24 books, got {len(books)}'
    out = os.path.join(ROOT, 'assets/covers')
    os.makedirs(out, exist_ok=True)
    for b in books:
        make_cover(b, cats[b['cat']], os.path.join(out, f"book_{b['id']}.png"))
    make_icons()
    print('covers:', len(books), '| icons + brand done')
