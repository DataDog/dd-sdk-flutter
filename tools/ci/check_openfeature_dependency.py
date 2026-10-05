#!/usr/bin/env python3
"""Check hosted OpenFeature dependencies and the release-tagged test harness."""
from pathlib import Path
import json
import re
import sys
from urllib.parse import urljoin, urlparse, unquote

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / 'packages/datadog_flags/pubspec.yaml'
SDK_VERSION = '0.0.1-beta.2'
SDK_ARCHIVE_SHA256 = '42503e804c1ef4b34e1ed5551330886a40d72037a069817743e7fd7ebcf13eee'
CONTRACT_REF = 'bd1ed8ae6a8560bd36360f913b363264d5306930'
SDK_NAME = 'openfeature_dart_client_sdk'


def section(text, name):
    match = re.search(rf'^{re.escape(name)}:\s*\n((?:[ \t].*\n|\n)*)', text, re.M)
    return match.group(1) if match else ''


def package_root(config_path, name):
    config = json.loads(config_path.read_text())
    package = next(p for p in config['packages'] if p['name'] == name)
    uri = urlparse(urljoin(config_path.as_uri(), package['rootUri']))
    if uri.scheme != 'file' or uri.netloc not in ('', 'localhost'):
        raise ValueError(f'{name} must resolve to a local package')
    path = unquote(uri.path)
    if re.match(r'^/[A-Za-z]:/', path):
        path = path[1:]
    return Path(path).resolve()


def verify_hosted_sdk(config_path, dependencies, lock_text):
    sdk = next(p for p in dependencies['packages'] if p['name'] == SDK_NAME)
    if sdk.get('source') != 'hosted' or sdk['version'] != SDK_VERSION:
        raise ValueError(f'Tests must use hosted {SDK_NAME} {SDK_VERSION}')
    block = re.search(rf'^  {SDK_NAME}:\n((?:    .*\n)+)', lock_text, re.M)
    if not block or not re.search(
            rf'^      sha256: "?{SDK_ARCHIVE_SHA256}"?$', block.group(1), re.M):
        raise ValueError('OpenFeature lockfile must identify the published beta.2 archive')
    if not re.search(r'^    source: hosted$', block.group(1), re.M):
        raise ValueError('OpenFeature lockfile must use the hosted source')
    if not re.search(r'^      url: "?https://pub.dev"?$', block.group(1), re.M):
        raise ValueError('OpenFeature must come from pub.dev')
    return package_root(config_path, SDK_NAME)


def check_manifests(root=ROOT):
    paths = ['packages/datadog_flags/pubspec.yaml',
             'packages/datadog_flags_flutter/pubspec.yaml',
             'packages/datadog_flags/example/pubspec.yaml',
             'packages/datadog_flags_flutter/example/pubspec.yaml',
             'examples/simple_example/pubspec.yaml']
    for relative in paths:
        path = root / relative
        source = path.read_text()
        if not re.search(rf'^  {SDK_NAME}: \^{re.escape(SDK_VERSION)}$',
                         section(source, 'dependencies'), re.M):
            raise ValueError(f'{relative} must depend on hosted {SDK_VERSION}')
        overrides = section(source, 'dependency_overrides')
        sdk_overrides = re.findall(rf'^  {SDK_NAME}:.*$', overrides, re.M)
        expected = f'  {SDK_NAME}: {SDK_VERSION}'
        if sdk_overrides and (relative != paths[0] or sdk_overrides != [expected]):
            raise ValueError(f'Unexpected OpenFeature override in {relative}')
        local_overrides = path.with_name('pubspec_overrides.yaml')
        if local_overrides.exists():
            local_sdk_overrides = re.findall(
                rf'^  {SDK_NAME}:.*$',
                section(local_overrides.read_text(), 'dependency_overrides'), re.M)
            if local_sdk_overrides and (
                    relative != paths[0] or local_sdk_overrides != [expected]):
                raise ValueError(f'Local override must not replace hosted OpenFeature: {relative}')
    core = (root / paths[0]).read_text()
    if re.findall(r'^      ref: (.+)$', core, re.M) != [CONTRACT_REF]:
        raise ValueError('Pin the development-only contract to the beta.2 release commit')


def main():
    check_manifests()
    if '--require-hosted' in sys.argv:
        for package in ['datadog_flags', 'datadog_flags_flutter']:
            source = (ROOT / f'packages/{package}/pubspec.yaml').read_text()
            if re.search(r'^publish_to: none$', source, re.M):
                raise SystemExit(f'Release preparation has not enabled publishing for {package}.')
    print(f'Hosted OpenFeature {SDK_VERSION} declarations and contract pin verified.')


if __name__ == '__main__':
    main()
