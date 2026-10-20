#!/usr/bin/env python3
"""Generates ICQuel's own artwork and sounds (everything is drawn / synthesised here; nothing is derived from third-party files).
Run:  python3 tools/gen_assets.py     ->  assets-own/img/*.png, assets-own/sounds/*.wav, assets-own/icon.png"""
import math, os, wave, struct
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets-own')
IMG = os.path.join(ROOT, 'img'); SND = os.path.join(ROOT, 'sounds')
os.makedirs(IMG, exist_ok=True); os.makedirs(SND, exist_ok=True)

NAVY = (14, 42, 74); TEAL = (25, 181, 196); CYAN = (94, 224, 232); WHITE = (255, 255, 255); YELLOW = (255, 210, 74)
GREEN = (47, 191, 113); AMBER = (240, 180, 41); ORANGE = (232, 119, 46); RED = (224, 69, 58); GRAY = (150, 162, 173); LGRAY = (190, 198, 206)
SS = 8  # supersampling

def font(size, bold=True):
    for path, idx in (('/System/Library/Fonts/Helvetica.ttc', 1 if bold else 0), ('/System/Library/Fonts/HelveticaNeue.ttc', 1 if bold else 0), ('/Library/Fonts/Arial.ttf', 0)):
        try: return ImageFont.truetype(path, int(size), index=idx)
        except Exception: continue
    return ImageFont.load_default()

class Canvas:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.im = Image.new('RGBA', (w * SS, h * SS), bg); self.d = ImageDraw.Draw(self.im)
    def s(self, v): return v * SS
    def poly(self, pts, fill=None, outline=None, width=1):
        self.d.polygon([(self.s(x), self.s(y)) for x, y in pts], fill=fill, outline=outline)
    def ellipse(self, box, fill=None, outline=None, width=1):
        self.d.ellipse([self.s(v) for v in box], fill=fill, outline=outline, width=int(width * SS))
    def rect(self, box, fill=None, outline=None, width=1, r=0):
        b = [self.s(v) for v in box]
        if r: self.d.rounded_rectangle(b, radius=self.s(r), fill=fill, outline=outline, width=int(width * SS))
        else: self.d.rectangle(b, fill=fill, outline=outline, width=int(width * SS))
    def line(self, pts, fill, width=1):
        self.d.line([(self.s(x), self.s(y)) for x, y in pts], fill=fill, width=int(width * SS), joint='curve')
    def text(self, xy, t, size, fill, bold=True, anchor='la'):
        self.d.text((self.s(xy[0]), self.s(xy[1])), t, font=font(size * SS, bold), fill=fill, anchor=anchor)
    def out(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)

def save(name, im): im.save(os.path.join(IMG, name + '.png'))

def drop_pts(cx, cy, R, steps=64):
    """Teardrop: round body with a tip on top."""
    r = R * 0.72; ccy = cy + R * 0.22; tip = (cx, cy - R); d = ccy - tip[1]
    phi = math.acos(r / d)
    pts = [tip, (cx + r * math.sin(phi), ccy - r * math.cos(phi))]
    for i in range(steps + 1):
        a = phi + (2 * math.pi - 2 * phi) * i / steps
        pts.append((cx + r * math.sin(a), ccy - r * math.cos(a)))
    return pts

def droplet(c, cx, cy, R, fill, outline=None, shine=True):
    c.poly(drop_pts(cx, cy, R), fill=fill, outline=outline)
    if shine:
        c.ellipse((cx - R * 0.42, cy + R * 0.02, cx - R * 0.14, cy + R * 0.42), fill=(255, 255, 255, 120))

def mascot(c, cx, cy, R, body=TEAL, face=True):
    droplet(c, cx, cy, R, body, outline=NAVY, shine=False)
    c.poly(drop_pts(cx, cy, R), outline=NAVY)
    ccy = cy + R * 0.22
    c.ellipse((cx - R * 0.42, ccy - R * 0.10, cx - R * 0.18, ccy + R * 0.16), fill=WHITE)
    c.ellipse((cx + R * 0.18, ccy - R * 0.10, cx + R * 0.42, ccy + R * 0.16), fill=WHITE)
    c.ellipse((cx - R * 0.34, ccy - R * 0.02, cx - R * 0.24, ccy + R * 0.10), fill=NAVY)
    c.ellipse((cx + R * 0.24, ccy - R * 0.02, cx + R * 0.34, ccy + R * 0.10), fill=NAVY)
    c.d.arc([c.s(cx - R * 0.28), c.s(ccy + R * 0.05), c.s(cx + R * 0.28), c.s(ccy + R * 0.42)], 20, 160, fill=NAVY, width=int(max(1, R * 0.07) * SS))

# ---------------------------------------------------------------- app icon / logo
def icon(size=1024):
    S = size
    c = Canvas(S // SS * 1, S // SS * 1) if False else None
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    pad = int(S * 0.06); box = (pad, pad, S - pad, S - pad)
    grad = Image.new('RGBA', (S, S))
    gp = grad.load()
    for y in range(S):
        t = y / (S - 1)
        col = tuple(int(NAVY[i] * (1 - t) + TEAL[i] * t) for i in range(3)) + (255,)
        for x in range(S): gp[x, y] = col
    mask = Image.new('L', (S, S), 0); ImageDraw.Draw(mask).rounded_rectangle(box, radius=int(S * 0.22), fill=255)
    im.paste(grad, (0, 0), mask)
    big = Canvas(S // 2, S // 2)  # drawn at (S/2)*8 = 4S px, then reduced to S
    cx, cy, R = S / 4, S / 4 + S * 0.012, S * 0.17
    droplet(big, cx, cy, R, WHITE, shine=False)
    r = R * 0.72; ccy = cy + R * 0.22
    big.ellipse((cx - r * 0.78, ccy - r * 0.62, cx + r * 0.78, ccy + r * 0.62), fill=CYAN)
    big.poly([(cx - r * 0.2, ccy + r * 0.55), (cx - r * 0.5, ccy + r * 0.98), (cx + r * 0.12, ccy + r * 0.58)], fill=CYAN)
    for k, dx in enumerate((-0.38, 0, 0.38)):
        big.ellipse((cx + r * dx - r * 0.1, ccy - r * 0.1, cx + r * dx + r * 0.1, ccy + r * 0.1), fill=WHITE)
    # small sparkle
    sx, sy, sr = cx + R * 1.02, cy - R * 0.72, R * 0.2
    big.poly([(sx, sy - sr), (sx + sr * 0.28, sy - sr * 0.28), (sx + sr, sy), (sx + sr * 0.28, sy + sr * 0.28), (sx, sy + sr), (sx - sr * 0.28, sy + sr * 0.28), (sx - sr, sy), (sx - sr * 0.28, sy - sr * 0.28)], fill=YELLOW)
    art = big.out().resize((S, S), Image.LANCZOS)
    im.alpha_composite(art)
    return im

def logo_mascot(size):
    c = Canvas(size, size); mascot(c, size / 2, size / 2 + size * 0.02, size * 0.42)
    return c.out()

# ---------------------------------------------------------------- 16px status bubbles & small glyph icons
def bubble(fill, glyph=None, ring=False):
    c = Canvas(16, 16)
    if ring:
        c.ellipse((2, 2, 14, 14), outline=fill, width=1.6)
    else:
        c.ellipse((1.5, 1.5, 14.5, 14.5), fill=fill, outline=tuple(int(v * 0.65) for v in fill), width=1)
        c.ellipse((4, 3, 8, 7), fill=(255, 255, 255, 90))
    if glyph == 'clock': c.line([(8, 4.5), (8, 8), (10.5, 9.5)], WHITE, 1.5)
    if glyph == 'bar': c.rect((4.5, 7, 11.5, 9), fill=WHITE)
    if glyph == 'excl': c.rect((7.2, 4, 8.8, 9), fill=WHITE); c.ellipse((7, 10.2, 9, 12.2), fill=WHITE)
    if glyph == 'dots':
        for x in (4.8, 8, 11.2): c.ellipse((x - 0.9, 7.1, x + 0.9, 8.9), fill=WHITE)
    if glyph == 'smile':
        c.ellipse((5, 5.2, 6.6, 6.8), fill=WHITE); c.ellipse((9.4, 5.2, 11, 6.8), fill=WHITE)
        c.d.arc([c.s(5), c.s(6.2), c.s(11), c.s(12)], 20, 160, fill=WHITE, width=int(1.2 * SS))
    return c.out()

def person(color=NAVY, bg=None):
    c = Canvas(16, 16)
    if bg: c.rect((0.5, 0.5, 15.5, 15.5), fill=bg, outline=(0, 0, 0, 40), r=3)
    c.ellipse((5.2, 2.5, 10.8, 8.1), fill=color)
    c.d.pieslice([c.s(2.8), c.s(8.6), c.s(13.2), c.s(19.8)], 180, 360, fill=color)
    return c.out()

def envelope(size=16, fill=(255, 235, 150), line=NAVY):
    c = Canvas(size, size); k = size / 16
    c.rect((1 * k, 3.5 * k, 15 * k, 12.5 * k), fill=fill, outline=line, width=1 * k, r=1.2 * k)
    c.line([(1.6 * k, 4.4 * k), (8 * k, 9 * k), (14.4 * k, 4.4 * k)], line, 1 * k)
    return c.out()

def note_icon():
    c = Canvas(16, 16)
    c.poly([(3, 1.5), (11, 1.5), (14, 4.5), (14, 14.5), (3, 14.5)], fill=(255, 255, 255), outline=NAVY)
    c.poly([(11, 1.5), (11, 4.5), (14, 4.5)], fill=LGRAY, outline=NAVY)
    for y in (7, 9.5, 12): c.line([(5, y), (12, y)], TEAL, 1)
    return c.out()

def glyph_icon(kind):
    c = Canvas(16, 16)
    if kind == 'page':   # house
        c.poly([(8, 1.8), (14.6, 7.6), (1.4, 7.6)], fill=RED, outline=NAVY); c.rect((3.4, 7.6, 12.6, 14.2), fill=(255, 235, 150), outline=NAVY); c.rect((6.8, 9.6, 9.4, 14.2), fill=TEAL)
    elif kind == 'reminder':
        c.ellipse((1.8, 1.8, 14.2, 14.2), fill=WHITE, outline=NAVY, width=1.3); c.line([(8, 4.2), (8, 8), (10.8, 9.6)], NAVY, 1.4)
    elif kind == 'notes': return note_icon()
    elif kind == 'todo':
        c.rect((2, 2, 14, 14), fill=WHITE, outline=NAVY, r=1.5); c.line([(4.4, 8.2), (6.8, 10.8), (11.6, 4.8)], GREEN, 1.8)
    elif kind == 'email': return envelope()
    elif kind == 'phone':
        c.d.arc([c.s(2), c.s(2), c.s(14), c.s(14)], 200, 340, fill=NAVY, width=int(2.2 * SS)); c.rect((1.6, 6.4, 4.8, 11.4), fill=NAVY, r=1); c.rect((11.2, 6.4, 14.4, 11.4), fill=NAVY, r=1)
    elif kind == 'archive':
        c.rect((2, 2.5, 14, 7), fill=(255, 235, 150), outline=NAVY, r=1); c.rect((2.8, 7, 13.2, 14), fill=(255, 235, 150), outline=NAVY); c.rect((6, 9, 10, 10.6), fill=NAVY)
    elif kind == 'white':
        c.rect((2.5, 1.8, 13.5, 14.2), fill=TEAL, outline=NAVY, r=1); c.line([(5, 5), (11, 5)], WHITE, 1.2); c.line([(5, 8), (11, 8)], WHITE, 1.2); c.line([(5, 11), (9, 11)], WHITE, 1.2)
    elif kind == 'active':
        c.rect((1.5, 1.5, 14.5, 14.5), fill=ORANGE, outline=NAVY, r=3); c.text((8, 8.3), 'A', 10, WHITE, anchor='mm')
    elif kind == 'eicq':
        c.rect((1.5, 1.5, 14.5, 14.5), fill=RED, outline=NAVY, r=3); c.text((8, 8.3), 'E', 10, WHITE, anchor='mm')
    elif kind == 'random':
        c.rect((2, 2, 14, 14), fill=WHITE, outline=NAVY, r=2.5)
        for x, y in ((5, 5), (11, 5), (8, 8), (5, 11), (11, 11)): c.ellipse((x - 1.1, y - 1.1, x + 1.1, y + 1.1), fill=NAVY)
    elif kind == 'phone16':
        return glyph_icon('phone')
    elif kind == 'speaker':
        c.poly([(2, 6), (5.5, 6), (9, 3), (9, 13), (5.5, 10), (2, 10)], fill=NAVY); c.d.arc([c.s(8), c.s(4.5), c.s(13), c.s(11.5)], 300, 60, fill=NAVY, width=int(1.2 * SS))
    elif kind == 'muted':
        c.poly([(2, 6), (5.5, 6), (9, 3), (9, 13), (5.5, 10), (2, 10)], fill=NAVY); c.line([(10.5, 5), (14.5, 11)], RED, 1.6); c.line([(14.5, 5), (10.5, 11)], RED, 1.6)
    elif kind == 'fontA':
        c.text((3.5, 13.5), 'A', 8, NAVY, anchor='ls'); c.text((8, 13.5), 'A', 12, TEAL, anchor='ls')
    elif kind == 'colors':
        for (x, y, col) in ((2, 2, RED), (8, 2, YELLOW), (2, 8, TEAL), (8, 8, GREEN)): c.rect((x, y, x + 6, y + 6), fill=col, outline=NAVY, width=0.7)
    elif kind == 'lines':
        c.text((2.5, 12.5), 'F', 11, NAVY, anchor='ls')
        for y, col in ((5, RED), (8, TEAL), (11, NAVY)): c.line([(8, y), (14, y)], col, 1.4)
    elif kind == 'circle':
        c.ellipse((2.5, 2.5, 13.5, 13.5), outline=RED, width=1.6); c.line([(4.5, 11.5), (11.5, 4.5)], RED, 1.6)
    elif kind == 'grid':
        for x in (3, 7, 11):
            for y in (3, 7, 11): c.rect((x, y, x + 3, y + 3), fill=NAVY)
    return c.out()

def tabs_all():
    c = Canvas(16, 16)
    for x, col in ((1.5, GREEN), (5.5, TEAL), (9.5, CYAN)): droplet(c, x + 2.5, 7.4, 5.5, col, outline=NAVY, shine=False)
    return c.out()

# ---------------------------------------------------------------- composite / text images
def labelled(w, h, text, icon_draw=None, bg=None, fg=NAVY, size=None, pad_left=0):
    c = Canvas(w, h, (0, 0, 0, 0) if bg is None else bg + (255,))
    if icon_draw: icon_draw(c)
    c.text((pad_left + (w - pad_left) / 2, h / 2 + 0.3), text, size or h * 0.62, fg, anchor='mm')
    return c.out()

def build_images():
    for name, (fill, glyph, ring) in {
        'online': (GREEN, None, False), 'away': (AMBER, 'clock', False), 'na': (ORANGE, 'dots', False), 'occupied': (RED, 'excl', False),
        'dnd': (RED, 'bar', False), 'ffc': ((44, 198, 217), 'smile', False), 'invisible': (GRAY, None, True), 'offline': (LGRAY, None, True)}.items():
        save(name, bubble(fill, glyph, ring))
    save('tab_online', bubble(GREEN))
    save('contact', person(NAVY, (232, 240, 247))); save('usertab', person(NAVY)); save('alltab', tabs_all())
    save('msg', envelope()); save('note', note_icon())
    for n, k in (('m_page', 'page'), ('m_reminder', 'reminder'), ('m_notes', 'notes'), ('m_todo', 'todo'), ('m_email', 'email'), ('m_phone', 'phone'), ('m_archive', 'archive'),
                 ('m_white', 'white'), ('m_active', 'active'), ('m_eicq', 'eicq'), ('random', 'random'), ('phone16', 'phone16')):
        save(n, glyph_icon(k))
    for i, k in enumerate(('speaker', 'muted', 'fontA', 'fontA', 'colors', 'lines', 'circle', 'grid')): save(f'tool_{i}', glyph_icon(k))
    # arrows strip: 9 tiles of 11x11 (right, down, corner) in three colours; tile 0 = collapsed, tile 1 = expanded
    c = Canvas(99, 11)
    for t, col in enumerate((TEAL, RED, AMBER)):
        for k in range(3):
            x0 = (t * 3 + k) * 11
            if k == 0: c.poly([(x0 + 3, 1.5), (x0 + 3, 9.5), (x0 + 8.5, 5.5)], fill=col)
            if k == 1: c.poly([(x0 + 1.5, 3), (x0 + 9.5, 3), (x0 + 5.5, 8.5)], fill=col)
            if k == 2: c.poly([(x0 + 9, 2), (x0 + 9, 9), (x0 + 2, 9)], fill=col)
    save('arrows', c.out())
    # grip: two 10x20 halves of vertical dots
    c = Canvas(20, 20)
    for half in (0, 10):
        for y in (4, 8, 12, 16): c.ellipse((half + 4, y - 1.2, half + 6.4, y + 1.2), fill=GRAY)
    save('grip', c.out())
    c = Canvas(11, 11); c.poly([(2.5, 1.5), (2.5, 9.5), (9, 5.5)], fill=GREEN); save('go', c.out())
    c = Canvas(5, 9); c.poly([(1, 1), (1, 8), (4.2, 4.5)], fill=NAVY); save('arrowr', c.out())
    # "More" button face (two frames of 48x16)
    c = Canvas(96, 16)
    for fx in (0, 48):
        c.rect((fx + 2, 2.5, fx + 12, 13.5), fill=WHITE, outline=NAVY, width=1.2); c.rect((fx + 2, 2.5, fx + 12, 5), fill=NAVY)
        c.text((fx + 16, 8.4), 'More', 9.5, NAVY, anchor='lm')
    save('more', c.out())
    # bitmaps with text
    def person_plus(c): c.ellipse((4, 3.5, 9, 8.5), fill=NAVY); c.d.pieslice([c.s(2), c.s(8.2), c.s(11), c.s(17.5)], 180, 360, fill=NAVY); c.line([(12.5, 5), (12.5, 11)], GREEN, 1.7); c.line([(9.7, 8), (15.3, 8)], GREEN, 1.7)
    save('addusers', labelled(71, 18, 'Add Users', person_plus, size=11.5, pad_left=17))
    def target(c): c.ellipse((3, 3.5, 14, 14.5), outline=RED, width=1.4); c.ellipse((6.4, 6.9, 10.6, 11.1), fill=RED)
    save('icqnow', labelled(69, 19, 'Now!', target, size=12, pad_left=15))
    c = Canvas(44, 16, YELLOW + (255,)); c.rect((0.5, 0.5, 43.5, 15.5), outline=NAVY, width=1); c.text((22, 8.6), 'Services', 9.5, NAVY, anchor='mm'); save('services', c.out())
    c = Canvas(57, 19); droplet(c, 9, 9.4, 7.5, TEAL, outline=NAVY, shine=False); c.text((17.5, 9.8), 'ICQuel', 11, NAVY, anchor='lm'); save('icqlogo', c.out())
    # vertical banner 22x192
    ban = Canvas(22, 192, NAVY + (255,))
    txt = Image.new('RGBA', (192 * SS, 22 * SS), (0, 0, 0, 0)); ImageDraw.Draw(txt).text((8 * SS, 11 * SS), 'ICQuel  -  spring of chats', font=font(12 * SS), fill=CYAN, anchor='lm')
    ban.im.alpha_composite(txt.rotate(90, expand=True), (0, 0)); droplet(ban, 11, 12, 7, TEAL, outline=WHITE, shine=False)
    save('banner', ban.out())
    # larger art
    c = Canvas(120, 120, (240, 250, 252, 255)); mascot(c, 60, 56, 40, TEAL); c.text((60, 108), App_NAME, 11, NAVY, anchor='mm'); save('splash', c.out())
    wiz = Canvas(100, 240, (232, 246, 250, 255))
    for i in range(24): wiz.rect((0, i * 10, 100, i * 10 + 10), fill=tuple(int(a * (1 - i / 24) + b * (i / 24)) for a, b in zip((232, 246, 250), (150, 215, 225))) + (255,))
    mascot(wiz, 50, 100, 34, TEAL); wiz.text((50, 150), App_NAME, 13, NAVY, anchor='mm'); save('wizard', wiz.out())
    save('flower32', logo_mascot(32)); save('logo', logo_mascot(128)); save('prefsicon', logo_mascot(16))
    for n, col in (('ico_1001', TEAL), ('ico_1002', GREEN), ('ico_1006', TEAL), ('ico_1018', RED), ('ico_1019', (44, 120, 220)), ('ico_1020', AMBER), ('ico_2058', ORANGE)):
        c = Canvas(32, 32); mascot(c, 16, 16.5, 13, col); save(n, c.out())
    def msgicon(sym, col):
        c = Canvas(32, 32); c.ellipse((2.5, 2.5, 29.5, 29.5), fill=col, outline=NAVY, width=1.2); c.text((16, 16.8), sym, 20, WHITE, anchor='mm'); return c.out()
    save('info32', msgicon('i', (44, 120, 220))); save('question32', msgicon('?', TEAL)); save('face32', logo_mascot(32))

# ---------------------------------------------------------------- sounds
RATE = 22050
def tone(freq, dur, vol=0.5, harmonics=((1, 1.0), (2, 0.25), (3, 0.08)), attack=0.004, decay=6.0):
    t = np.arange(int(RATE * dur)) / RATE
    w = sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in harmonics)
    env = np.minimum(1, t / attack) * np.exp(-decay * t)
    return vol * w * env / max(1e-9, sum(a for _, a in harmonics))
def seq(parts, gap=0.0):
    out = []; pos = 0
    for start, sig in parts:
        s = int(start * RATE); out.append((s, sig)); pos = max(pos, s + len(sig))
    buf = np.zeros(pos + int(RATE * 0.05))
    for s, sig in out: buf[s:s + len(sig)] += sig
    return buf
def write(name, sig):
    sig = np.clip(sig / max(1e-9, np.abs(sig).max()) * 0.85, -1, 1)
    with wave.open(os.path.join(SND, name + '.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes((sig * 32767).astype('<i2').tobytes())
def noise_click(dur=0.03, vol=0.6, tone_hz=1800):
    t = np.arange(int(RATE * dur)) / RATE
    return vol * (np.random.RandomState(1).randn(len(t)) * 0.35 + np.sin(2 * np.pi * tone_hz * t)) * np.exp(-90 * t)

def build_sounds():
    write('chime', seq([(0, tone(880, 0.32, decay=7)), (0.13, tone(1318.5, 0.5, decay=6))]))          # incoming message: rising two-note chime
    write('hello', seq([(0, tone(523.25, 0.25, decay=8)), (0.1, tone(659.25, 0.25, decay=8)), (0.2, tone(783.99, 0.5, decay=6))]))
    write('pop', seq([(0, tone(660, 0.18, decay=14)), (0.07, tone(990, 0.2, decay=12))]))
    write('ping', tone(1568, 0.7, decay=5, harmonics=((1, 1.0), (2.7, 0.3))))
    write('drop', seq([(0, tone(1200, 0.12, decay=25)), (0.1, tone(600, 0.3, decay=12))]))
    write('bell', tone(1046.5, 1.0, decay=3.5, harmonics=((1, 1.0), (2.76, 0.5), (5.4, 0.25))))
    write('ring', seq([(i * 0.18, tone(1000 if i % 2 == 0 else 800, 0.14, decay=10)) for i in range(6)]))
    write('tick', noise_click(0.05, 0.5, 2200))
    write('startup', seq([(0, tone(392, 0.4, decay=5)), (0.12, tone(523.25, 0.4, decay=5)), (0.24, tone(659.25, 0.4, decay=5)), (0.36, tone(1046.5, 0.8, decay=3.5))]))
    write('msgsent', seq([(0, tone(740, 0.12, decay=22)), (0.06, tone(1108, 0.16, decay=18))]))
    write('msgtype', noise_click(0.035, 0.5, 1500))
    write('msgback', noise_click(0.05, 0.45, 900))
    write('alert', seq([(0, tone(988, 0.2, decay=9)), (0.2, tone(988, 0.2, decay=9)), (0.4, tone(740, 0.5, decay=6))]))

App_NAME = 'ICQuel'
if __name__ == '__main__':
    icon(1024).save(os.path.join(ROOT, 'icon.png'))
    build_images(); build_sounds()
    print('own assets written to', os.path.normpath(ROOT), '-', len(os.listdir(IMG)), 'images,', len(os.listdir(SND)), 'sounds')

import sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_orange; gen_orange.apply()
