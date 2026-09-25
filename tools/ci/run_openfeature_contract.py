#!/usr/bin/env python3
"""Run the upstream receipt tool from the SDK checkout actually used by Dart."""
from pathlib import Path
from urllib.parse import urljoin, urlparse, unquote
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / 'packages/datadog_flags'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['vm', 'chrome'], required=True)
    args = parser.parse_args()
    config_path = PACKAGE / '.dart_tool/package_config.json'
    config = json.loads(config_path.read_text())
    sdk = next(p for p in config['packages'] if p['name'] == 'openfeature_dart_client_sdk')
    sdk_path = Path(unquote(urlparse(urljoin(config_path.as_uri(), sdk['rootUri'])).path))
    checkout = sdk_path.resolve().parents[1]
    subprocess.run([
        'python3', str(checkout / 'tool/client_provider_evidence.py'),
        '--classification', 'external',
        '--canonical-repository', 'https://github.com/DataDog/dd-sdk-flutter',
        '--provider-repo', str(ROOT), '--working-directory', str(PACKAGE),
        '--test-target', 'test/shared_contract_test.dart',
        '--platform', args.platform,
        '--output', str(ROOT / '.build/openfeature-evidence' / args.platform),
    ], check=True)


if __name__ == '__main__':
    main()
