# Releasing Salvage Station

Releases are built and uploaded automatically by the [BigWigs packager](https://github.com/BigWigsMods/packager):

1. Update `## Version:` in `SalvageStation.toc`, `ns.VERSION` in `Core.lua`, and add the new entry at the top of `CHANGELOG.md`.
2. Commit, then push a tag with the version number (e.g. `1.0.1`). The `## v1.0.1` section of `CHANGELOG.md` becomes the CurseForge changelog for that upload.
3. GitHub Actions packages the addon and uploads it to CurseForge (and Wago, if `WAGO_API_TOKEN` is set), plus a GitHub release.

Repository secrets used: `CF_API_KEY` (required for CurseForge), `WAGO_API_TOKEN` (optional).

## First-time setup
1. Create the project on CurseForge (World of Warcraft → Addons) and copy its **Project ID** from the project page sidebar.
2. Add `## X-Curse-Project-ID: <id>` to `SalvageStation.toc` (and `## X-Wago-ID: <id>` if it's on Wago).
3. Add the `CF_API_KEY` secret under Settings → Secrets and variables → Actions (the same key your other addons use works).

## Publish button (no chat needed)
Actions tab → **Package and release** → **Run workflow**. Enter the version (it must match `## Version:` in the .toc and have a `## vX.Y.Z` section in `CHANGELOG.md`). Untick **Upload to CurseForge** to release to Wago only.
