"""Applies the orange-slice artwork (tools/icon-source.jpeg) over the generated assets: app icon, logo, status icons, dialog icons, banners.
Called at the end of gen_assets.py (python3 tools/gen_assets.py)."""
import os
from PIL import Image, ImageDraw, ImageOps, ImageFilter, ImageChops, ImageFont
H = os.path.dirname(os.path.abspath(__file__)); IMG = os.path.join(H, '..', 'assets-own', 'img'); ROOT = os.path.join(H, '..', 'assets-own')
NAVY = (14, 42, 74)

def load_orange():
    src = Image.open(os.path.join(H, 'icon-source.jpeg')).convert('RGB')
    rgb = Image.merge('RGB', [c.point(lambda v: 255 if v > 235 else 0) for c in src.split()])
    white = ImageChops.multiply(ImageChops.multiply(rgb.split()[0], rgb.split()[1]), rgb.split()[2])   # 255 where near-white
    flood = white.copy(); W, Hh = flood.size
    for pt in [(0, 0), (W - 1, 0), (0, Hh - 1), (W - 1, Hh - 1)]:   # the circle touches the edges: four separate corner regions
        if flood.getpixel(pt) == 255: ImageDraw.floodfill(flood, pt, 128, thresh=0)
    bg = flood.point(lambda v: 255 if v == 128 else 0)
    alpha = ImageOps.invert(bg.filter(ImageFilter.MaxFilter(5))).filter(ImageFilter.GaussianBlur(1.0))   # grow the cut-out by 2px to drop the white fringe
    o = src.convert('RGBA'); o.putalpha(alpha)
    return o.crop(alpha.point(lambda v: 255 if v > 8 else 0).getbbox())

def font(size):
    for path, idx in (('/System/Library/Fonts/Helvetica.ttc', 1), ('/System/Library/Fonts/HelveticaNeue.ttc', 1)):
        try: return ImageFont.truetype(path, int(size), index=idx)
        except Exception: continue
    return ImageFont.load_default()

def apply():
    orange = load_orange()
    def fit(size, margin=0.0):
        c = Image.new('RGBA', (size, size), (0, 0, 0, 0)); s = max(1, int(size * (1 - margin)))
        o = orange.resize((s, s), Image.LANCZOS); c.paste(o, ((size - s) // 2, (size - s) // 2), o); return c
    def grey(im, a=0.6): g = ImageOps.grayscale(im.convert('RGB')).convert('RGBA'); g.putalpha(im.split()[3].point(lambda v: int(v * a))); return g
    def save(n, im): im.save(os.path.join(IMG, n + '.png'))
    fit(1024, 0.04).save(os.path.join(ROOT, 'icon.png'))
    # 16px status icons: the slice, plus a small badge in the corner (drawn at 8x, then reduced)
    def status(kind):
        B = 128; base = fit(B, 0.02)
        if kind in ('offline',): base = grey(base, 0.7)
        if kind == 'invisible': base = grey(base, 0.35)
        if kind == 'online': return base.resize((16, 16), Image.LANCZOS)
        d = ImageDraw.Draw(base); cx, cy, r = 98, 98, 30
        col = {'away': (240, 180, 41), 'na': (232, 119, 46), 'occupied': (224, 69, 58), 'dnd': (224, 69, 58), 'ffc': (47, 191, 113)}.get(kind)
        if col:
            d.ellipse((cx - r - 4, cy - r - 4, cx + r + 4, cy + r + 4), fill=(255, 255, 255, 255)); d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col)
            w = (255, 255, 255, 255)
            if kind == 'away': d.line([(cx, cy - 16), (cx, cy), (cx + 12, cy + 8)], fill=w, width=8)
            if kind == 'dnd': d.rectangle((cx - 16, cy - 5, cx + 16, cy + 5), fill=w)
            if kind == 'occupied': d.rectangle((cx - 4, cy - 17, cx + 4, cy + 4), fill=w); d.ellipse((cx - 5, cy + 9, cx + 5, cy + 19), fill=w)
            if kind == 'na':
                for x in (-14, 0, 14): d.ellipse((cx + x - 5, cy - 5, cx + x + 5, cy + 5), fill=w)
            if kind == 'ffc': d.line([(cx - 14, cy), (cx + 14, cy)], fill=w, width=9); d.line([(cx, cy - 14), (cx, cy + 14)], fill=w, width=9)
        return base.resize((16, 16), Image.LANCZOS)
    for k in ('online', 'away', 'na', 'occupied', 'dnd', 'ffc', 'invisible', 'offline'): save(k, status(k))
    save('tab_online', status('online'))
    fit(128).save(os.path.join(IMG, 'logo.png'))
    for n, s in (('flower32', 32), ('face32', 32), ('prefsicon', 16), ('ico_1001', 32), ('ico_1002', 32), ('ico_1006', 32), ('ico_1018', 32), ('ico_1019', 32), ('ico_1020', 32), ('ico_2058', 32), ('question32', 32)): save(n, fit(s))
    sp = Image.new('RGBA', (120, 120), (255, 244, 230, 255)); o = orange.resize((84, 84), Image.LANCZOS); sp.paste(o, (18, 10), o)
    ImageDraw.Draw(sp).text((60, 108), 'ICQuel', font=font(13), fill=NAVY, anchor='mm'); save('splash', sp)
    # small logo with text (57x19), vertical banner (22x192), wizard side image (100x240)
    S = 8; lg = Image.new('RGBA', (57 * S, 19 * S), (0, 0, 0, 0)); o = orange.resize((16 * S, 16 * S), Image.LANCZOS); lg.paste(o, (1 * S, 1 * S + S // 2), o)
    ImageDraw.Draw(lg).text((19 * S, 10 * S), 'ICQuel', font=font(11 * S), fill=NAVY, anchor='lm'); save('icqlogo', lg.resize((57, 19), Image.LANCZOS))
    ban = Image.new('RGBA', (22 * S, 192 * S), (232, 119, 46, 255)); o = orange.resize((18 * S, 18 * S), Image.LANCZOS); ban.paste(o, (2 * S, 4 * S), o)
    txt = Image.new('RGBA', (192 * S, 22 * S), (0, 0, 0, 0)); ImageDraw.Draw(txt).text((30 * S, 11 * S), 'ICQuel', font=font(13 * S), fill=(255, 255, 255, 255), anchor='lm')
    ban.alpha_composite(txt.rotate(90, expand=True), (0, 0)); save('banner', ban.resize((22, 192), Image.LANCZOS))
    wz = Image.new('RGBA', (100, 240))
    px = wz.load()
    for y in range(240):
        t = y / 239
        for x in range(100): px[x, y] = tuple(int(a * (1 - t) + b * t) for a, b in zip((255, 244, 230), (250, 190, 130))) + (255,)
    o = orange.resize((76, 76), Image.LANCZOS); wz.alpha_composite(o, (12, 70)); ImageDraw.Draw(wz).text((50, 168), 'ICQuel', font=font(15), fill=NAVY, anchor='mm'); save('wizard', wz)
    print('orange artwork applied')

if __name__ == '__main__': apply()
