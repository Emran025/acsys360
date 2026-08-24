from pathlib import Path
import yaml

files = [
    Path('.github/workflows/ci.yml'),
    Path('.github/workflows/container.yml'),
    Path('.github/workflows/release.yml'),
    Path('.github/ISSUE_TEMPLATE/feature.yml'),
]
for path in files:
    with path.open(encoding='utf-8') as handle:
        yaml.safe_load(handle)
    print(f'valid: {path}')
