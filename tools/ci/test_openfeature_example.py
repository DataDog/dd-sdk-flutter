#!/usr/bin/env python3
"""Run the OpenFeature example test on an already booted native simulator."""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EXAMPLE = ROOT / 'examples/simple_example'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['android', 'ios'], required=True)
    parser.add_argument('--device')
    args = parser.parse_args()
    device = args.device
    if device is None:
        devices = json.loads(subprocess.check_output(
            ['flutter', 'devices', '--machine'], text=True))
        candidates = [d for d in devices if d.get('emulator') and
                      d.get('targetPlatform', '').startswith(args.platform)]
        if len(candidates) != 1:
            raise SystemExit('Boot one simulator for the platform or specify --device.')
        device = candidates[0]['id']
    # Flutter bundles this asset even though the test injects its own environment.
    env_file = EXAMPLE / '.env'
    created_env = not env_file.exists()
    if created_env:
        env_file.touch()
    output = ROOT / '.build' / f'openfeature-example-{args.platform}.log'
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        subprocess.run(['flutter', 'pub', 'get'], cwd=EXAMPLE, check=True)
        with output.open('w') as log:
            result = subprocess.run([
                'flutter', 'test', 'integration_test/openfeature_test.dart',
                '-d', device, '--reporter', 'expanded',
            ], cwd=EXAMPLE, stdout=log, stderr=subprocess.STDOUT)
        print(output.read_text())
        raise SystemExit(result.returncode)
    finally:
        if created_env:
            env_file.unlink()


if __name__ == '__main__':
    main()
