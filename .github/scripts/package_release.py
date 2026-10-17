#!/usr/bin/env python3
"""Synchronize release versions and optionally build the RuneScape plugin ZIP."""

import argparse
import json
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[2]
VERSION_LINE = re.compile(r'^PrettyUI\.version = "([^"\r\n]*)"$', re.MULTILINE)
TAG_VERSION = re.compile(r"v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\Z")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="Release tag (1.2.3 or v1.2.3)")
    parser.add_argument("--output", type=Path, help="Build a flat plugin ZIP at this path")
    args = parser.parse_args()

    match = TAG_VERSION.fullmatch(args.tag)
    if not match:
        parser.error("release tag must be a version such as 1.2.3 or v1.2.3")
    version = match.group(1)

    manifest_path = ROOT / "plugin.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    lua_path = ROOT / "main.lua"
    lua = lua_path.read_text(encoding="utf-8")
    if len(VERSION_LINE.findall(lua)) != 1:
        raise ValueError("main.lua must contain exactly one PrettyUI.version assignment")
    updated = VERSION_LINE.sub(lambda _: f'PrettyUI.version = "{version}"', lua)
    if manifest["version"] != version:
        manifest["version"] = version
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if updated != lua:
        lua_path.write_text(updated, encoding="utf-8")

    if args.output:
        with ZipFile(args.output, "w", ZIP_DEFLATED) as archive:
            for filename in ("plugin.json", "main.lua"):
                archive.write(ROOT / filename, filename)
            for directory in ("resources", "src"):
                archive.writestr(f"{directory}/", "")
                for path in sorted((ROOT / directory).rglob("*")):
                    if path.is_file():
                        archive.write(path, path.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
