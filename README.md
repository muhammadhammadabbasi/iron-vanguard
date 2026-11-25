# Iron Vanguard

An IGI-style tactical stealth shooter built with Godot 4.5. Windows first, Android later.

## Folders

| Folder | What goes in it | How it gets there |
| --- | --- | --- |
| `assets/characters/player` | Player character (Mixamo, with skin) | Claude converts and adds it |
| `assets/characters/enemy` | Enemy soldiers (Mixamo, with skin) | Upload here, or send in chat |
| `assets/animations` | Mixamo animations (without skin) | **You upload** (see the README in that folder) |
| `assets/sketchfab` | Weapons, buildings, vehicles | **Automatic** from `assets/sketchfab_list.txt` |
| `assets/polyhaven` | Textures, skies, props | **Automatic** from `assets/polyhaven_list.txt` |
| `assets/weapons`, `buildings`, `props`, `vehicles` | Anything you download by hand | You upload (optional) |

## Uploading files on the GitHub website

1. Open the folder on github.com (for example `assets/animations`).
2. Click **Add file → Upload files**.
3. Drag the files in, then click **Commit changes**.

Each file must be under 25 MB in the browser (GitHub's hard limit is 100 MB).

## Automatic downloads (Sketchfab + Poly Haven)

A GitHub Action (`.github/workflows/download-assets.yml`) downloads assets for you:

- **Poly Haven:** already set up. The list in `assets/polyhaven_list.txt` downloads automatically, no account needed.
- **Sketchfab:** one-time setup:
  1. On sketchfab.com: **Settings → Password & API → API Token**, then copy the token.
  2. In this repo on GitHub: **Settings → Secrets and variables → Actions → New repository secret**.
     Name: `SKETCHFAB_TOKEN`. Value: paste the token. Save.
  3. Paste model links into `assets/sketchfab_list.txt` (edit the file on GitHub with the pencil icon) and commit.
     The Action runs by itself and adds the models plus their credit lines to `CREDITS.md`.

To re-run it manually: **Actions → Download assets → Run workflow**.

Never paste the token into a file or a chat. It only goes into the GitHub secret.
