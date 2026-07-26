#!/usr/bin/env python3
"""
gist_spike.py - M1 pipeline spike for Gista.

Proves the whole v1 loop outside Xcode: Wikipedia lead extract -> ElevenLabs -> mp3.
The question this answers: is a stock voice reading a Wikipedia lead actually
pleasant to listen to? If not, nothing downstream matters.

The ElevenLabs key is read from the macOS Keychain at runtime and never printed.

Usage:
    python3 scripts/gist_spike.py "Voyager 1"
    python3 scripts/gist_spike.py "Antikythera mechanism" --voice 21m00Tcm4TlvDq8ikWAM
    python3 scripts/gist_spike.py "Mariana Trench" --script-only   # no TTS spend
"""

from __future__ import annotations  # /usr/bin/python3 is 3.9 — needed for `str | None`

import argparse
import json
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

KEYCHAIN_SERVICE = "elevenlabs-api-key"
ELEVENLABS_BASE = "https://api.elevenlabs.io/v1"
DEFAULT_VOICE = "21m00Tcm4TlvDq8ikWAM"  # Rachel, ElevenLabs stock
DEFAULT_MODEL = "eleven_flash_v2_5"
WIKI_SUMMARY = "https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}"

# Our own cap, not ElevenLabs'. A lead extract fits comfortably.
MAX_TEXT_CHARS = 5000

# Measured against eleven_flash_v2_5: 110 words rendered as 56.3s => ~117 wpm.
# Slower than the ~150 wpm rule of thumb, which matters because the Live Activity
# shows a duration before the audio exists.
WORDS_PER_MINUTE = 117


def read_key() -> str:
    """Read the API key from the login Keychain. Never logged."""
    try:
        out = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True, text=True, check=True,
        )
    except subprocess.CalledProcessError:
        sys.exit(
            f"No Keychain item '{KEYCHAIN_SERVICE}'. Store it with:\n"
            f'  security add-generic-password -a "$USER" -s "{KEYCHAIN_SERVICE}" -U -w'
        )
    key = out.stdout.strip()
    if not key:
        sys.exit(f"Keychain item '{KEYCHAIN_SERVICE}' is empty.")
    return key


def parse_article(arg: str) -> tuple[str, str | None]:
    """
    Accept either a bare title or a full Wikipedia URL, mirroring what the
    share sheet hands the app. Returns (title, lang_from_url_or_None).
    """
    if not arg.startswith(("http://", "https://")):
        return arg, None
    parsed = urllib.parse.urlparse(arg)
    if not parsed.netloc.endswith("wikipedia.org"):
        sys.exit(f"Not a Wikipedia URL: {arg}")
    lang = parsed.netloc.split(".")[0]
    parts = [p for p in parsed.path.split("/") if p]
    if len(parts) < 2 or parts[0] != "wiki":
        sys.exit(f"Unrecognised Wikipedia URL shape: {arg}")
    return urllib.parse.unquote(parts[1]).replace("_", " "), lang


def fetch_lead_extract(article: str, lang: str = "en") -> dict:
    """
    Fetch the hand-written lead section. This is the v1 script source:
    already in summary register, no LLM required.
    """
    title = urllib.parse.quote(article.replace(" ", "_"), safe="")
    url = WIKI_SUMMARY.format(lang=lang, title=title)
    req = urllib.request.Request(url, headers={"User-Agent": "Gista-M1-Spike/0.1"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            sys.exit(f"No Wikipedia article found for {article!r}.")
        raise

    if data.get("type") == "disambiguation":
        sys.exit(f"{article!r} is a disambiguation page - pick a specific article.")

    extract = (data.get("extract") or "").strip()
    if not extract:
        sys.exit(f"{article!r} has no lead extract to read.")

    return {
        "title": data.get("title", article),
        "description": data.get("description", ""),
        "extract": extract,
        "revision": data.get("revision"),
        "canonical": (data.get("content_urls", {})
                          .get("desktop", {})
                          .get("page", "")),
    }


def synthesize(text: str, key: str, voice: str, model: str) -> bytes:
    """POST text to ElevenLabs, return mp3 bytes."""
    if len(text) > MAX_TEXT_CHARS:
        text = text[:MAX_TEXT_CHARS]
    body = json.dumps({
        "text": text,
        "model_id": model,
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
    }).encode()
    req = urllib.request.Request(
        f"{ELEVENLABS_BASE}/text-to-speech/{voice}?output_format=mp3_44100_128",
        data=body,
        headers={"xi-api-key": key, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        sys.exit(f"ElevenLabs failed ({e.code}): {detail}")


def main() -> None:
    p = argparse.ArgumentParser(description="Gista M1 pipeline spike")
    p.add_argument("article", help="Wikipedia article title or full wikipedia.org URL")
    p.add_argument("--lang", default="en")
    p.add_argument("--voice", default=DEFAULT_VOICE)
    p.add_argument("--model", default=DEFAULT_MODEL)
    p.add_argument("--out-dir", default=None,
                   help="where to write the mp3 (default: alongside this script in ../build)")
    p.add_argument("--script-only", action="store_true",
                   help="fetch and print the script without spending TTS quota")
    args = p.parse_args()

    title, url_lang = parse_article(args.article)
    page = fetch_lead_extract(title, url_lang or args.lang)
    text = page["extract"]
    words = len(text.split())

    print(f"title       : {page['title']}")
    if page["description"]:
        print(f"description : {page['description']}")
    print(f"revision    : {page['revision']}")
    print(f"chars/words : {len(text)} / {words}")
    print(f"est. audio  : ~{words / WORDS_PER_MINUTE * 60:.0f}s")
    print(f"cap headroom: {len(text)}/{MAX_TEXT_CHARS}")
    print()
    print("--- script ---")
    print(text)
    print("--- end script ---")

    if args.script_only:
        print("\n(--script-only: no TTS call made)")
        return

    out_dir = Path(args.out_dir) if args.out_dir else Path(__file__).parent.parent / "build"
    out_dir.mkdir(parents=True, exist_ok=True)
    slug = page["title"].lower().replace(" ", "-").replace("/", "-")
    out_path = out_dir / f"{slug}.mp3"

    print(f"\nsynthesizing via {args.model} / voice {args.voice} ...")
    audio = synthesize(text, read_key(), args.voice, args.model)
    out_path.write_bytes(audio)

    print(f"wrote {out_path}  ({len(audio) / 1024:.0f} KB)")
    print(f"play it: afplay '{out_path}'")


if __name__ == "__main__":
    main()
