#!/usr/bin/env python3
"""Check the temporary SDK pin and prevent accidental package publication."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / 'packages/datadog_flags/pubspec.yaml'


def main():
    source = CORE.read_text()
    refs = re.findall(r'^      ref: ([0-9a-f]{40})$', source, re.M)
    if '--require-hosted' in sys.argv:
        sdk = re.search(r'^  openfeature_dart_client_sdk:.*(?:\n {4,}.*)*', source, re.M).group()
        overrides = CORE.with_name('pubspec_overrides.yaml')
        overridden = overrides.exists() and 'openfeature_dart_client_sdk:' in overrides.read_text()
        if 'git:' in sdk or overridden or re.search(r'^publish_to: none$', source, re.M):
            raise SystemExit('Release blocked: validate a hosted Dart 3.10-compatible '
                             'OpenFeature release and remove the publication block first.')
        return
    if len(refs) != 2 or len(set(refs)) != 1:
        raise SystemExit('Pin the OpenFeature SDK and contract to the same full commit.')
    for package in ['datadog_flags', 'datadog_flags_flutter']:
        text = (ROOT / f'packages/{package}/pubspec.yaml').read_text()
        if not re.search(r'^publish_to: none$', text, re.M):
            raise SystemExit(f'{package} must remain unpublished while using the Git SDK.')
    for path in [ROOT / 'packages/datadog_flags_flutter/pubspec.yaml',
                 ROOT / 'packages/datadog_flags/example/pubspec.yaml',
                 ROOT / 'packages/datadog_flags_flutter/example/pubspec.yaml',
                 ROOT / 'examples/simple_example/pubspec.yaml']:
        if re.findall(r'^      ref: (.+)$', path.read_text(), re.M) != [refs[0]]:
            raise SystemExit(f'OpenFeature pin differs in {path.relative_to(ROOT)}')
    print(f'OpenFeature development pin {refs[0]} verified; publication remains blocked.')


if __name__ == '__main__':
    main()
