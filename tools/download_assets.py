#!/usr/bin/env python3
"""Download game assets from Sketchfab and Poly Haven into the repo.

Runs inside GitHub Actions (see .github/workflows/download-assets.yml).

  assets/sketchfab_list.txt  - one Sketchfab model URL per line (needs the SKETCHFAB_TOKEN secret)
  assets/polyhaven_list.txt  - one Poly Haven asset per line: "<type> <id-or-keyword>"
                               type = texture | hdri | model

Already-downloaded assets are skipped, so the workflow can be re-run safely.
CREDITS.md is updated automatically for every Sketchfab model.
"""
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
UA = "IronVanguardAssetFetcher/1.0 (github.com/muhammadhammadabbasi/iron-vanguard)"
TEX_RES = os.environ.get("TEX_RES", "2k")
MAX_FILE = 95 * 1024 * 1024  # stay under GitHub's 100 MB file limit


def get(url, headers=None, raw=False):
    h = {"User-Agent": UA}
    h.update(headers or {})
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=180) as r:
        data = r.read()
    return data if raw else json.loads(data)


def save(path, data):
    if len(data) > MAX_FILE:
        print(f"  ! skipped {os.path.basename(path)}: {len(data) // 1048576} MB is over GitHub's file limit")
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return True


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")[:60] or "model"


def read_list(name):
    p = os.path.join(ASSETS, name)
    if not os.path.exists(p):
        return []
    out = []
    for line in open(p, encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if line:
            out.append(line)
    return out


# ------------------------------------------------------------------ Sketchfab

def sketchfab():
    urls = read_list("sketchfab_list.txt")
    if not urls:
        print("Sketchfab: list is empty")
        return
    token = os.environ.get("SKETCHFAB_TOKEN", "").strip()
    if not token:
        print("Sketchfab: SKETCHFAB_TOKEN secret is not set - skipping")
        return
    credits_path = os.path.join(ROOT, "CREDITS.md")
    credits = open(credits_path, encoding="utf-8").read() if os.path.exists(credits_path) else "# Credits\n\n"
    for url in urls:
        m = re.search(r"([0-9a-f]{32})", url)
        if not m:
            print(f"Sketchfab: no model id in '{url}'")
            continue
        uid = m.group(1)
        try:
            info = get(f"https://api.sketchfab.com/v3/models/{uid}")
            name = info.get("name", uid)
            folder = os.path.join(ASSETS, "sketchfab", f"{slug(name)}_{uid[:6]}")
            if os.path.isdir(folder) and os.listdir(folder):
                print(f"Sketchfab: already have '{name}'")
                continue
            lic = (info.get("license") or {}).get("label", "unknown licence")
            author = (info.get("user") or {}).get("displayName", "unknown")
            print(f"Sketchfab: downloading '{name}' by {author} ({lic})")
            dl = get(f"https://api.sketchfab.com/v3/models/{uid}/download", {"Authorization": f"Token {token}"})
            if "glb" in dl:
                data = get(dl["glb"]["url"], raw=True)
                if save(os.path.join(folder, f"{slug(name)}.glb"), data):
                    print(f"  saved glb ({len(data) // 1024} KB)")
            elif "gltf" in dl:
                data = get(dl["gltf"]["url"], raw=True)
                zf = zipfile.ZipFile(io.BytesIO(data))
                for zi in zf.infolist():
                    if not zi.is_dir():
                        save(os.path.join(folder, zi.filename), zf.read(zi))
                print(f"  saved gltf ({len(data) // 1024} KB zip)")
            else:
                print("  ! no glb/gltf download offered for this model")
                continue
            line = f"- **{name}** by {author} - {lic} - https://sketchfab.com/3d-models/{uid}\n"
            if uid not in credits:
                credits += line
        except Exception as e:  # keep going with the rest of the list
            print(f"  ! failed: {e}")
    with open(credits_path, "w", encoding="utf-8") as f:
        f.write(credits)


# ------------------------------------------------------------------ Poly Haven

_ph_cache = {}


def ph_assets(kind):
    if kind not in _ph_cache:
        _ph_cache[kind] = get(f"https://api.polyhaven.com/assets?t={kind}")
    return _ph_cache[kind]


def ph_resolve(kind, key):
    """Exact id, or the most-downloaded asset whose id/name contains all keyword words."""
    assets = ph_assets(kind)
    if key in assets:
        return key
    words = key.lower().replace("_", " ").split()
    hits = []
    for aid, a in assets.items():
        text = (aid + " " + a.get("name", "") + " " + " ".join(a.get("tags", []))).lower()
        if all(w in text for w in words):
            hits.append((a.get("download_count", 0), aid))
    hits.sort(reverse=True)
    return hits[0][1] if hits else None


def ph_pick(files_for_map):
    res = files_for_map.get(TEX_RES) or files_for_map.get("2k") or next(iter(files_for_map.values()))
    for fmt in ("jpg", "png", "hdr", "exr"):
        if fmt in res:
            return res[fmt]["url"]
    return None


def polyhaven():
    entries = read_list("polyhaven_list.txt")
    kinds = {"texture": "textures", "hdri": "hdris", "model": "models"}
    for e in entries:
        parts = e.split(None, 1)
        if len(parts) != 2 or parts[0] not in kinds:
            print(f"Poly Haven: bad line '{e}' (use: texture|hdri|model <id or keywords>)")
            continue
        kind, key = parts
        try:
            aid = ph_resolve(kinds[kind], key)
            if not aid:
                print(f"Poly Haven: nothing found for {kind} '{key}'")
                continue
            folder = os.path.join(ASSETS, "polyhaven", kinds[kind], aid)
            if os.path.isdir(folder) and os.listdir(folder):
                print(f"Poly Haven: already have {aid}")
                continue
            files = get(f"https://api.polyhaven.com/files/{aid}")
            print(f"Poly Haven: {kind} '{key}' -> {aid}")
            if kind == "texture":
                for mapname, out in (("Diffuse", "albedo"), ("nor_gl", "normal"), ("Rough", "roughness"), ("AO", "ao")):
                    if mapname in files:
                        url = ph_pick(files[mapname])
                        if url:
                            save(os.path.join(folder, f"{aid}_{out}{os.path.splitext(url)[1]}"), get(url, raw=True))
            elif kind == "hdri":
                url = ph_pick(files["hdri"])
                save(os.path.join(folder, f"{aid}{os.path.splitext(url)[1]}"), get(url, raw=True))
            elif kind == "model":
                g = files["gltf"].get(TEX_RES) or files["gltf"]["2k"]
                g = g["gltf"]
                save(os.path.join(folder, f"{aid}.gltf"), get(g["url"], raw=True))
                for rel, inc in g.get("include", {}).items():
                    save(os.path.join(folder, rel), get(inc["url"], raw=True))
        except Exception as ex:
            print(f"  ! failed: {ex}")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "polyhaven"):
        polyhaven()
    if which in ("all", "sketchfab"):
        sketchfab()
