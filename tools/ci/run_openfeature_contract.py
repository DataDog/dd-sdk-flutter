#!/usr/bin/env python3
"""Run the upstream contract against the hosted SDK and record both identities."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import subprocess

from check_openfeature_dependency import (
    CONTRACT_REF, SDK_ARCHIVE_SHA256, SDK_VERSION, check_manifests,
    package_root, verify_hosted_sdk,
)

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / 'packages/datadog_flags'


def runtime_files(root):
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted((root / 'lib').rglob('*')) if path.is_file()}


def verify_runtime(sdk_path, checkout):
    actual = runtime_files(sdk_path)
    if not actual or actual != runtime_files(checkout / 'packages/openfeature_dart_client_sdk'):
        raise ValueError('Resolved SDK runtime differs from the beta.2 release source')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['vm', 'chrome'], required=True)
    args = parser.parse_args()
    check_manifests()
    config_path = PACKAGE / '.dart_tool/package_config.json'
    dependencies_text = subprocess.check_output(
        ['dart', 'pub', 'deps', '--json'], cwd=PACKAGE, encoding='utf-8')
    sdk_path = verify_hosted_sdk(config_path, json.loads(dependencies_text),
                                 (PACKAGE / 'pubspec.lock').read_text())
    contract = package_root(config_path, 'openfeature_client_provider_contract')
    checkout = contract.parents[1]
    if contract != checkout / 'conformance/client_provider_contract':
        raise ValueError('Unexpected contract package path')
    revision = subprocess.check_output(
        ['git', '-C', str(checkout), 'rev-parse', 'HEAD'], encoding='utf-8').strip()
    if revision != CONTRACT_REF:
        raise ValueError('Contract checkout is not pinned to the beta.2 release commit')
    if subprocess.check_output(
            ['git', '-C', str(checkout), 'status', '--porcelain'], encoding='utf-8').strip():
        raise ValueError('Contract checkout must be clean')

    # Reuse the upstream scenario accounting, not its source-only SDK identity.
    spec = importlib.util.spec_from_file_location(
        'upstream_evidence', checkout / 'tool/client_provider_evidence.py')
    upstream = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(upstream)
    contract_identity = upstream.identity(checkout)
    if contract_identity['dirty']:
        raise ValueError('Contract checkout must be clean')
    verify_runtime(sdk_path, checkout)
    out = ROOT / '.build/openfeature-evidence' / args.platform
    out.mkdir(parents=True, exist_ok=True)
    command = ['dart', 'test', '--reporter=json', '--platform', args.platform,
               'test/shared_contract_test.dart']
    result = subprocess.run(command, cwd=PACKAGE, encoding='utf-8', capture_output=True)
    (out / 'tests.jsonl').write_text(result.stdout)
    (out / 'stderr.log').write_text(result.stderr)
    (out / 'dependencies.json').write_text(dependencies_text)
    summary = upstream.summarize(result.stdout)
    passed = (result.returncode == 0 and summary['all_scenarios_passed']
              and summary['platforms'] == [args.platform])
    receipt = {
        **summary, 'all_scenarios_passed': passed,
        'contract_version': upstream.CONTRACT_VERSION,
        'contract_checkout': contract_identity,
        'sdk_package': {'source': 'hosted', 'url': 'https://pub.dev',
                        'version': SDK_VERSION, 'archive_sha256': SDK_ARCHIVE_SHA256,
                        'resolved_path': str(sdk_path), 'runtime_matches_release': True},
        'provider_checkout': upstream.identity(ROOT),
        'classification': 'external',
        'canonical_repository': 'https://github.com/DataDog/dd-sdk-flutter',
        'dart': subprocess.check_output(['dart', '--version'], encoding='utf-8').strip(),
        'command': command, 'process_exit_code': result.returncode,
        'native_mobile_runtime_tested': False,
        'independent_provider_gate_satisfied': False,
        'remaining_review': 'Hosted SDK verification and controlled-transport contract '
                            'results are not live-service or native-platform acceptance.',
    }
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
    if not passed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
