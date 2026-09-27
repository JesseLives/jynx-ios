# Jynx for iPhone

Native SwiftUI app for signals.justsal.xyz. Built unsigned on GitHub Actions; testers sign it themselves.

## Install a build

1. GitHub > this repo > Actions > the newest green run > download **Jynx-ipa** and unzip it to get `Jynx.ipa`.
2. On a Windows PC or Mac, install Sideloadly (https://sideloadly.io) and iTunes (Windows).
3. Plug in the iPhone, open Sideloadly, drag `Jynx.ipa` in, enter your Apple ID, press Start.
4. On the iPhone: Settings > General > VPN & Device Management > trust your Apple ID.
   If iOS asks, turn on Settings > Privacy & Security > Developer Mode and restart.

A free Apple ID signs the app for 7 days. After that it will not open: install the build again.

## Develop

- `Packages/JynxKit`: everything that is not a view. Tests run anywhere Swift runs: `cd Packages/JynxKit && swift test`.
- `App/`: SwiftUI views. Compiled only on the macOS runner (`.github/workflows/build.yml`).
- Test fixtures are real server bodies, refreshed from the server repo:
  `IOS_FIXTURES_DIR=<this repo>/Packages/JynxKit/Tests/JynxKitTests/Fixtures PGDATABASE=signals_test pnpm exec vitest run --pool=forks test/ios-fixtures.spec.ts`
