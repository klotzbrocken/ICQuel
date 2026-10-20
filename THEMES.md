# Themes (import)
Preferences > My Details > Theme > **Import Theme…** takes a folder or .zip with a `theme.json`. Only data files
(png, wav, json, txt, md) are copied to `~/Library/Application Support/ICQuel/Themes/<id>/`; no code is ever run. Max 80 MB.

```
theme.json   {"id":"my-theme","name":"My Theme","base":"classic|modern","author":"…","version":"1",
              "sounds":{"message":"mysound","online":"…","chat":"…","url":"…","file":"…","external":"…","phone":"…","contact":"…"}}
img/*.png    replaces built-in images of the same name (see assets-own/img for the names)
sounds/*.wav replaces/adds sounds (startup, msgsent, msgtype, msgback + event sounds)
dialogs.json optional dialog layouts for the classic style (overrides the built-in ones)
icon.png     optional Dock icon
```
Missing files fall back to the built-in set. The app ships only its own artwork and sounds (`assets-own/`, made by `tools/gen_assets.py`).
