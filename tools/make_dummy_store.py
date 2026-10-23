#!/usr/bin/env python3
"""Writes a made-up ICQuel store (random nicknames, random first names for the iMessage contacts, short chats) to <dir>/store.json.
Used by tools/demo.sh so screenshots never show real data.  Usage: make_dummy_store.py <dir>"""
import json, os, random, sys, time

NICKS = ["PixelPanda", "NightOwl99", "Sk8erGal", "ByteBandit", "MoonWalker", "Pretzel_X", "NeoTrinity", "RetroRita", "CyberCat42", "SunnyDay_", "LazerLemon", "TurboToast", "Glitter_Fox", "Zero_Cool_", "WaveRider", "Dr_Modem", "Cool_Breeze", "Matrix_Mia"]
FIRST = ["Lena", "Jonas", "Mara", "Felix", "Nora", "Ben", "Ida", "Theo", "Mia", "Paul", "Clara", "Emil", "Hanna", "Leon", "Sofia", "Luca", "Anna", "Max"]
CHAT = [("in", "hey, wassup?"), ("out", "not much, just downloaded the new Winamp :-)"), ("in", "nice! a/s/l? lol, kidding"), ("out", "haha, 25/m/couch"), ("in", "r u coming to the LAN party on saturday?")]
IM_CHAT = [("in", "Are we still on for tonight?"), ("out", "Yes! 8 o'clock?"), ("in", "Perfect. I'll bring snacks"), ("out", "Great, see you then"), ("in", "See you! 🙂")]
REF = 978307200  # Swift Date reference: 2001-01-01

def date(offset): return time.time() - REF - offset

random.seed()
nicks, firsts = random.sample(NICKS, len(NICKS)), random.sample(FIRST, len(FIRST))
uin = lambda: str(random.randint(10_000_000, 99_999_999))
contacts, history = [], {}
def add(c, chat=None):
    contacts.append(c)
    if chat: history[c["uin"]] = [{"dir": d, "text": t, "t": date(300 + (len(chat) - i) * 70)} for i, (d, t) in enumerate(chat)]
for _ in range(7): add({"name": nicks.pop(), "uin": uin()}, CHAT if random.random() < 0.4 else None)
for _ in range(4): add({"name": firsts.pop(), "uin": uin(), "bridge": "+4915" + str(random.randint(10_000_000, 99_999_999))}, IM_CHAT if random.random() < 0.7 else None)
add({"name": "Pixel", "uin": uin(), "persona": "A friendly chat buddy from the early 2000s.", "preset": "friend", "initiative": True},
    [("in", "hey! long time no see, how r u?"), ("out", "good, you?"), ("in", "bored lol. wanna chat later tonight?")])
store = {"uin": uin(), "nick": nicks.pop(), "status": "online", "sounds": True, "contacts": contacts, "freqEnabled": True, "freqMode": "hour", "minutes": 15,
         "demoFirst": False, "aiEnabled": False, "history": history, "simpleMode": False, "botInit": True, "bridgeEnabled": False, "bridgeLast": 0, "appName": "ICQuel"}
d = sys.argv[1]; os.makedirs(d, exist_ok=True)
json.dump(store, open(os.path.join(d, "store.json"), "w"), indent=1)
print("dummy store:", d, "-", len(contacts), "contacts")
