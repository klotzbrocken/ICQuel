# wa-bridge

Headless WhatsApp Web (Baileys, multi-device) helper for ICQuel. `node bridge.js <dataDir>`; JSON Lines on stdin/stdout, logs on stderr.
Session lives in `<dataDir>/auth`, downloaded media in `<dataDir>/media`.

Helper -> app: `qr{data}`, `ready{me}`, `closed{reason,loggedOut}` (final only; transient drops reconnect silently),
`message{id,jid,from,name,text,group,ts,fromMe,files[]}`, `chats{chats[{jid,name,group,last,ts}]}`, `sent{id,ok,error?}`.
App -> helper: `send{id,jid,text}`, `sendFile{id,jid,path,caption}`, `chats`, `logout`, `quit`.

`node bridge.js --selftest` runs offline with fake events.
Build: `tools/build_wa_bridge.sh <outDir>` -> `<outDir>/bridge.js` (single esbuild bundle) + universal `<outDir>/node`.
Signing: node needs entitlements `com.apple.security.cs.allow-jit` and `com.apple.security.cs.allow-unsigned-executable-memory` under hardened runtime.
