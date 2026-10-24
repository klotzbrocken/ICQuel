#!/usr/bin/env python3
"""Writes a made-up ICQuel store (random nicknames, random first names for the iMessage contacts, short chats) to <dir>/store.json.
Used by tools/demo.sh so screenshots never show real data.  Usage: make_dummy_store.py <dir>"""
import json, os, random, struct, sys, time, zlib

NICKS = ["PixelPanda", "NightOwl99", "Sk8erGal", "ByteBandit", "MoonWalker", "Pretzel_X", "NeoTrinity", "RetroRita", "CyberCat42", "SunnyDay_", "LazerLemon", "TurboToast", "Glitter_Fox", "Zero_Cool_", "WaveRider", "Dr_Modem", "Cool_Breeze", "Matrix_Mia"]
FIRST = ["Lena", "Jonas", "Mara", "Felix", "Nora", "Ben", "Ida", "Theo", "Mia", "Paul", "Clara", "Emil", "Hanna", "Leon", "Sofia", "Luca", "Anna", "Max"]
CHAT = [("in", "hey, wassup?"), ("out", "not much, just downloaded the new Winamp :-)"), ("in", "nice! a/s/l? lol, kidding"), ("out", "haha, 25/m/couch"), ("in", "r u coming to the LAN party on saturday?")]
IM_CHAT = [("in", "Are we still on for tonight?"), ("out", "Yes! 8 o'clock?"), ("in", "Perfect. I'll bring snacks"), ("out", "Great, see you then"), ("in", "See you! 🙂")]
REF = 978307200  # Swift Date reference: 2001-01-01

def png(path, w=180, h=110):
    """A small gradient picture (stdlib only) so the demo shows an inline attachment."""
    rows = b"".join(b"\x00" + bytes(c for x in range(w) for c in (int(40 + 200 * x / w), int(120 + 100 * y / h), 220)) for y in range(h))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))

def date(offset): return time.time() - REF - offset

random.seed()
nicks, firsts = random.sample(NICKS, len(NICKS)), random.sample(FIRST, len(FIRST))
uin = lambda: str(random.randint(10_000_000, 99_999_999))
contacts, history = [], {}
def add(c, chat=None):
    contacts.append(c)
    if chat: history[c["uin"]] = [dict({"dir": m[0], "text": m[1], "t": date(300 + (len(chat) - i) * 70)}, **({"files": m[2]} if len(m) > 2 else {})) for i, m in enumerate(chat)]
d0 = sys.argv[1]; os.makedirs(os.path.join(d0, "media"), exist_ok=True)
pic = os.path.join(d0, "media", "demo-picture.png"); png(pic)
note = os.path.join(d0, "media", "Holiday-plans.txt"); open(note, "w").write("Day 1: beach. Day 2: more beach.\n")
for i in range(7): add({"name": nicks.pop(), "uin": uin()}, CHAT if i < 3 else None)
for i in range(4): add({"name": firsts.pop(), "uin": uin(), "bridge": "+4915" + str(random.randint(10_000_000, 99_999_999))}, (IM_CHAT[:3] + [("in", "", [pic])] + IM_CHAT[3:]) if i < 3 else None)
add({"name": "Weekend Crew", "uin": uin(), "bridge": "group:iMessage;+;chatDEMO"}, [("in", "Mia: who is up for the lake on Saturday?"), ("out", "me! I bring the speaker"), ("in", "Ben: 🙌")])
for i in range(3): add({"name": firsts.pop(), "uin": uin(), "bridge": "wa:4915" + str(random.randint(10_000_000, 99_999_999)) + "@s.whatsapp.net"},
                       [("in", "Did you see the photos?"), ("out", "Yes, great shots!"), ("in", "", [pic]), ("in", "Here is the plan", [note]), ("out", "Thanks, looks good")] if i < 2 else [("in", "Call me when you can"), ("out", "On my way home, 10 min")])
add({"name": "Family Group", "uin": uin(), "bridge": "wa:123456789-1600000000@g.us"}, [("in", "Mum: dinner on Sunday at 6?"), ("out", "I'll be there"), ("in", "Dad: bringing dessert")])
add({"name": "Pixel", "uin": uin(), "persona": "A friendly chat buddy from the early 2000s.", "preset": "friend", "initiative": True},
    [("in", "hey! long time no see, how r u?"), ("out", "good, you?"), ("in", "bored lol. wanna chat later tonight?")])
store = {"uin": uin(), "nick": nicks.pop(), "status": "online", "sounds": True, "contacts": contacts, "freqEnabled": True, "freqMode": "hour", "minutes": 15,
         "demoFirst": False, "aiEnabled": False, "history": history, "simpleMode": False, "botInit": True, "bridgeEnabled": False, "bridgeLast": 0, "appName": "ICQuel", "showGroups": True, "waEnabled": False}
d = d0
json.dump(store, open(os.path.join(d, "store.json"), "w"), indent=1)
print("dummy store:", d, "-", len(contacts), "contacts")
