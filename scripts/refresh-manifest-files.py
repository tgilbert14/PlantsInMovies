"""Refresh runtime file checksums without changing existing deployment package pins.

Use this for a source/asset-only change. For package changes, use write_manifest.R
with rsconnect in the project's deployment environment instead.
"""
from pathlib import Path
import hashlib
import json
import sys

root = Path(__file__).resolve().parents[1]
manifest_path = root / 'manifest.json'
manifest = json.loads(manifest_path.read_text())
paths = ['app.R', 'R/biomes.R', 'R/charts.R', 'R/cinema.R',
         'www/cinema-v1.scss', 'www/cinema-v1.js',
         'www/cinema/arrakis-v1.svg', 'www/cinema/middleearth-v1.svg',
         'www/cinema/islanublar-v1.svg',
         'data/biome_tally.rds', 'data/biome_totals.rds',
         'data/state_biome_family.rds', 'data/state_richness.rds',
         'data/state_pairs.rds', 'data/meta.rds']
files = {p: {'checksum': hashlib.md5((root / p).read_bytes()).hexdigest()}
         for p in sorted(paths)}
if '--check' in sys.argv:
    if manifest['files'] != files:
        raise SystemExit('Manifest file inventory/checksums are stale.')
    print(f'PASS: {len(files)} runtime file checksums; existing package pins retained')
else:
    manifest['files'] = files
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    print(f'Refreshed {len(files)} runtime files; existing package pins retained')
