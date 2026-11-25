#!/usr/bin/env python3
"""Generate voice-over with Piper neural TTS (runs in GitHub Actions).

Reads tools/voice/lines.json, writes assets/voice/<id>.ogg.
Only lines whose text/voice changed since last run are regenerated (tools/voice/manifest.json).
Radio voices get a band-pass "radio" filter and a little static.
"""
import hashlib
import json
import os
import subprocess
import urllib.request
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "voice", "lines.json")
MANIFEST = os.path.join(ROOT, "tools", "voice", "manifest.json")
OUT = os.path.join(ROOT, "assets", "voice")
CACHE = os.path.join(os.path.expanduser("~"), ".cache", "piper-voices")
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main"


def model_path(name):
    lang, rest = name.split("-", 1)
    speaker, quality = rest.rsplit("-", 1)
    family = lang.split("_")[0]
    os.makedirs(CACHE, exist_ok=True)
    onnx = os.path.join(CACHE, name + ".onnx")
    for ext in (".onnx", ".onnx.json"):
        dst = os.path.join(CACHE, name + ext)
        if not os.path.exists(dst):
            url = f"{HF}/{family}/{lang}/{speaker}/{quality}/{name}{ext}"
            print("downloading", url)
            urllib.request.urlretrieve(url, dst)
    return onnx


_voices = {}


def synth(model, text, wav_path, length_scale):
    from piper import PiperVoice
    if model not in _voices:
        _voices[model] = PiperVoice.load(model_path(model))
    v = _voices[model]
    with wave.open(wav_path, "wb") as wf:
        if hasattr(v, "synthesize_wav"):
            try:
                from piper import SynthesisConfig
                v.synthesize_wav(text, wf, syn_config=SynthesisConfig(length_scale=length_scale))
            except ImportError:
                v.synthesize_wav(text, wf)
        else:
            v.synthesize(text, wf, length_scale=length_scale)


def post(wav_in, ogg_out, radio, pitch):
    filters = ["silenceremove=start_periods=1:start_threshold=-50dB", "apad=pad_dur=0.15"]
    if pitch and abs(pitch - 1.0) > 0.01:
        filters.insert(0, f"asetrate=22050*{pitch},aresample=22050,atempo={1.0 / pitch:.4f}")
    if radio:
        filters += ["highpass=f=320", "lowpass=f=3300", "acompressor=threshold=-18dB:ratio=4", "volume=1.6"]
    else:
        filters += ["acompressor=threshold=-20dB:ratio=3", "volume=1.3"]
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_in]
    if radio:
        # mix in faint radio static
        cmd += ["-f", "lavfi", "-i", "anoisesrc=color=white:amplitude=0.012",
                "-filter_complex", f"[0:a]{','.join(filters)}[v];[1:a]highpass=f=1500,lowpass=f=4000[n];"
                                   "[v][n]amix=inputs=2:duration=first:weights=1 1[out]", "-map", "[out]"]
    else:
        cmd += ["-af", ",".join(filters)]
    cmd += ["-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", ogg_out]
    subprocess.run(cmd, check=True)


def main():
    data = json.load(open(SRC, encoding="utf-8"))
    voices = data["voices"]
    manifest = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for line in data["lines"]:
        v = voices[line["speaker"]]
        key = hashlib.sha1(json.dumps([line["text"], v], sort_keys=True).encode()).hexdigest()
        ogg = os.path.join(OUT, line["id"] + ".ogg")
        if manifest.get(line["id"]) == key and os.path.exists(ogg):
            continue
        tmp = "/tmp/_line.wav"
        synth(v["model"], line["text"], tmp, v.get("length_scale", 1.0))
        post(tmp, ogg, v.get("radio", False), v.get("pitch", 1.0))
        manifest[line["id"]] = key
        made += 1
        print(f"voice: {line['id']} ({line['speaker']})")
    json.dump(manifest, open(MANIFEST, "w"), indent=1, sort_keys=True)
    # subtitles file for the game
    subs = {l["id"]: {"speaker": l["speaker"], "text": l["text"]} for l in data["lines"]}
    json.dump(subs, open(os.path.join(OUT, "subtitles.json"), "w"), indent=1)
    print(f"generated {made} new lines, {len(data['lines'])} total")


if __name__ == "__main__":
    main()
