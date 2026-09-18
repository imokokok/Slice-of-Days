#!/usr/bin/env python3
"""Extract player-facing Chinese source strings for the runtime catalog.

The Chinese source text is intentionally used as the Godot message id. This lets
existing scenes, JSON content, and dynamically-created Controls participate in
translation without a risky all-at-once rewrite of gameplay identifiers.
"""

from __future__ import annotations

import json
import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT_ROOT / "localization" / "source_strings.json"
SCAN_ROOTS = ("scripts", "data", "extensions", "scenes")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres"}
CHINESE = re.compile(r"[\u3400-\u9fff]")
DOUBLE_QUOTED = re.compile(r'"(?:\\.|[^"\\])*"', re.DOTALL)


def excluded(path: Path) -> bool:
    relative = path.relative_to(PROJECT_ROOT)
    parts = relative.parts
    return (
        "tests" in parts
        or "test" in parts
        or path.name.endswith("_test.gd")
        or path.name == "translation_probe.swift"
    )


def add_string(catalog: dict[str, set[str]], value: str, path: Path) -> None:
    if not CHINESE.search(value):
        return
    # These strings are machine-facing protocol data, not player-facing copy.
    # Translating either would break rule parsing or the local AI response schema.
    if value.startswith("([0-9一二三四五六七八九十]+)"):
        return
    if value.startswith("只返回JSON对象，字段为reply"):
        return
    location = str(path.relative_to(PROJECT_ROOT))
    catalog.setdefault(value, set()).add(location)


def walk_json(catalog: dict[str, set[str]], value: object, path: Path) -> None:
    if isinstance(value, str):
        add_string(catalog, value, path)
    elif isinstance(value, list):
        for item in value:
            walk_json(catalog, item, path)
    elif isinstance(value, dict):
        for item in value.values():
            walk_json(catalog, item, path)


def extract_resource(catalog: dict[str, set[str]], path: Path) -> None:
    source = path.read_text(encoding="utf-8", errors="replace")
    for match in DOUBLE_QUOTED.finditer(source):
        try:
            value = json.loads(match.group(0))
        except json.JSONDecodeError:
            continue
        add_string(catalog, value, path)


def main() -> None:
    catalog: dict[str, set[str]] = {}
    for root_name in SCAN_ROOTS:
        root = PROJECT_ROOT / root_name
        if not root.exists():
            continue
        for path in sorted(root.rglob("*")):
            if not path.is_file() or excluded(path):
                continue
            if path.suffix == ".json":
                try:
                    walk_json(catalog, json.loads(path.read_text(encoding="utf-8")), path)
                except json.JSONDecodeError as error:
                    raise SystemExit(f"Invalid JSON in {path}: {error}") from error
            elif path.suffix in TEXT_SUFFIXES:
                extract_resource(catalog, path)

    payload = {
        source: sorted(locations)
        for source, locations in sorted(catalog.items(), key=lambda item: item[0])
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    character_count = sum(len(CHINESE.findall(source)) for source in payload)
    print(f"wrote {len(payload)} source strings ({character_count} Chinese characters) to {OUTPUT}")


if __name__ == "__main__":
    main()
