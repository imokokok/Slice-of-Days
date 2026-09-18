#!/usr/bin/env python3
"""Fail when the English catalog is incomplete or unsafe for formatting."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = PROJECT_ROOT / "localization" / "source_strings.json"
ENGLISH_PATH = PROJECT_ROOT / "localization" / "en.json"
OVERRIDE_PATH = PROJECT_ROOT / "localization" / "en_overrides.json"
CHINESE = re.compile(r"[\u3400-\u9fff]")
PLACEHOLDER = re.compile(r"%[-+0-9.]*[sdif]|\{[A-Za-z_][^}]*\}")


def main() -> int:
    sources: dict[str, list[str]] = json.loads(SOURCE_PATH.read_text(encoding="utf-8"))
    english: dict[str, str] = json.loads(ENGLISH_PATH.read_text(encoding="utf-8"))
    if OVERRIDE_PATH.exists():
        english.update(json.loads(OVERRIDE_PATH.read_text(encoding="utf-8")))

    missing = [source for source in sources if not english.get(source, "").strip()]
    untranslated = [
        source
        for source in sources
        if source in english
        and (english[source].strip() == source.strip() or CHINESE.search(english[source]))
    ]
    placeholder_errors = []
    for source in sources:
        if source not in english:
            continue
        source_tokens = sorted(PLACEHOLDER.findall(source))
        target_tokens = sorted(PLACEHOLDER.findall(english[source]))
        if source_tokens != target_tokens:
            placeholder_errors.append((source, source_tokens, target_tokens))

    print(f"source strings: {len(sources)}")
    print(f"English entries: {len(english)}")
    print(f"missing: {len(missing)}")
    print(f"still Chinese: {len(untranslated)}")
    print(f"placeholder mismatches: {len(placeholder_errors)}")

    for title, rows in (
        ("MISSING", missing[:20]),
        ("STILL_CHINESE", untranslated[:20]),
    ):
        for row in rows:
            print(f"{title}: {row!r}")
    for source, expected, actual in placeholder_errors[:20]:
        print(f"PLACEHOLDER: {source!r} expected={expected!r} actual={actual!r}")

    return 1 if missing or untranslated or placeholder_errors else 0


if __name__ == "__main__":
    sys.exit(main())
