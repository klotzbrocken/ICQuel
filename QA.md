# QA

Automatic (run before every release):
- `tools/test.sh`: logic checks against the real code (parsers, chat.db queries on a fixture, AI request building for both providers, Giphy parser, auto-reply guards, search, WhatsApp protocol, the real helper in `--selftest` mode, GIF to MP4). `ICQ_SELFTEST_NET=1 tools/test.sh` also downloads and runs Node.js.
- `tools/qa.sh`: renders every window in all four themes into `/tmp/icquel-qa/<theme>/` and fails on missing or blank pictures. Look at the new windows once (Privacy, Find, ActiveList, GIF picker).

Needs a person (not automatable here). Tick when done on a Mac with Messages:
- [ ] Preferences: change a checkbox, a text field and the theme: each takes effect about a second later, "Restore Defaults" does not get undone by closing the window.
- [ ] Privacy page: Full Disk Access status, "Allow Messages control", both AI services (key accepted, model list loads, a chatbot answers), draft / summary / auto-reply switches show their confirmation.
- [ ] iMessage: send text, a GIF, a Photos picture and a file to yourself; attachments from other people show inline; a group chat (switch "Show group chats" on, import it, send and receive); delivered / read line under your last message.
- [ ] Auto-reply: switch it on, mark one contact, set Away, write from another device: exactly one reply within 6 hours, none to unmarked contacts or groups.
- [ ] Focus: Shortcuts automation "Open URL icquel://status/dnd" changes the status.
- [ ] WhatsApp (use a second number): enable, download, scan the QR code, import a chat, receive, send text / picture / GIF, unlink.
- [ ] Update from the previous release through Sparkle.
