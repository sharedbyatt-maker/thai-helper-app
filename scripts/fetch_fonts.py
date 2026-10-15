#!/usr/bin/env python3
"""Fetch pinned, hash-verified fonts before a Flutter build; never runs in the app."""
import hashlib
import tempfile
import urllib.request
from pathlib import Path

COMMIT = '954e256c4277419b5e48bffa51be069b2bd01bde'
ROOT = Path(__file__).resolve().parents[1] / 'flutter_app' / 'assets' / 'fonts'
FONTS = [
    ('NotoSansMyanmar.ttf', 'ofl/notosansmyanmar/NotoSansMyanmar%5Bwdth%2Cwght%5D.ttf',
     '7abbbfbe2514105d7ce94937aee3feb2ba89b73a256c8b77b5866bd9b83e32ec'),
    ('NotoSansSymbols2-Regular.ttf', 'ofl/notosanssymbols2/NotoSansSymbols2-Regular.ttf',
     '7d5fb73b7ca67a6798101741f5d280a3d016a56a197afcd4199dbb57b4b82a21'),
]


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, source, expected in FONTS:
        target = ROOT / name
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
            print(f'{name}: verified cache')
            continue
        url = f'https://raw.githubusercontent.com/google/fonts/{COMMIT}/{source}'
        with urllib.request.urlopen(url, timeout=40) as response:
            data = response.read(5_000_001)
        if len(data) > 5_000_000 or hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError(f'{name}: source hash mismatch; build stopped')
        with tempfile.NamedTemporaryFile(dir=ROOT, delete=False) as output:
            temporary = Path(output.name)
            output.write(data)
        try:
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
        print(f'{name}: downloaded and verified')


if __name__ == '__main__':
    main()
