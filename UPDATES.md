# Updates (Sparkle via GitHub)

The app checks `https://github.com/<GITHUB_REPO>/releases/latest/download/appcast.xml` once a day and via
**app menu → Check for Updates…**. Updates are verified with an EdDSA signature (Sparkle 2.10.0, MIT licence).

## One-time setup
1. Create a GitHub repository for the releases and put `owner/repo` into `update.conf` (`GITHUB_REPO=`).
   While it is still `OWNER/REPO`, the menu item only shows "Updates are not set up yet" and no network request is made.
2. The signing key already exists in your login keychain (account `icq99b`). Back it up once:
   `Vendor/Sparkle/bin/generate_keys --account icq99b -x icq99b-sparkle-private.key` (store it safely, never commit it).
   Without this key no future update can be signed.

## Releasing
1. Raise `BUILD` (and `SHORT`) in `VERSION`: Sparkle only offers builds with a higher `BUILD`.
2. Run `./release.sh`. It builds, zips `ICQuel.app`, signs it and writes `release/appcast.xml`. It publishes nothing.
3. Upload manually (the script prints the exact `gh release create …` command): the zip and `appcast.xml` must be
   assets of the same release, tagged `v<SHORT>`.

## Notes
- The app is ad-hoc signed, not notarised. Other Macs show the Gatekeeper warning on first launch (right-click → Open).
  For public distribution use a Developer ID certificate and notarisation; Sparkle works with both.
- Personal data (contacts, bots, history) lives in `~/Library/Application Support/ICQuel/store.json` and survives updates.
