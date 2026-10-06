"""Regression checks for the hosted OpenFeature validation boundary."""
import json
from pathlib import Path
import tempfile
import unittest

from check_openfeature_dependency import (
    CONTRACT_REF, SDK_ARCHIVE_SHA256, SDK_NAME, SDK_VERSION, check_manifests, package_root, section,
    verify_hosted_sdk,
)
from run_openfeature_contract import verify_runtime


class HostedSdkTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sdk = self.root / 'hosted-sdk'
        self.config = self.root / 'package_config.json'
        self.config.write_text(json.dumps({'packages': [
            {'name': SDK_NAME, 'rootUri': self.sdk.as_uri() + '/'}]}))
        self.dependencies = {'packages': [
            {'name': SDK_NAME, 'version': SDK_VERSION, 'source': 'hosted'}]}
        self.lock = (f'packages:\n  {SDK_NAME}:\n'
                     f'    description:\n      sha256: {SDK_ARCHIVE_SHA256}\n'
                     f'      url: "https://pub.dev"\n'
                     f'    source: hosted\n    version: "{SDK_VERSION}"\n')

    def test_accepts_hosted_archive(self):
        self.assertEqual(verify_hosted_sdk(self.config, self.dependencies, self.lock),
                         self.sdk.resolve())

    def test_rejects_non_hosted_sources(self):
        for source in ['git', 'path']:
            with self.subTest(source=source):
                self.dependencies['packages'][0]['source'] = source
                with self.assertRaises(ValueError):
                    verify_hosted_sdk(self.config, self.dependencies, self.lock)

    def test_rejects_other_version(self):
        for version in ['0.0.1-beta.1', '0.0.1-beta.2']:
            with self.subTest(version=version):
                self.dependencies['packages'][0]['version'] = version
                with self.assertRaises(ValueError):
                    verify_hosted_sdk(self.config, self.dependencies, self.lock)

    def test_rejects_wrong_archive(self):
        with self.assertRaises(ValueError):
            verify_hosted_sdk(self.config, self.dependencies,
                              self.lock.replace(SDK_ARCHIVE_SHA256, '0' * 64))

    def test_rejects_lockfile_source_override(self):
        with self.assertRaises(ValueError):
            verify_hosted_sdk(self.config, self.dependencies,
                              self.lock.replace('source: hosted', 'source: path'))

    def test_rejects_different_host(self):
        with self.assertRaises(ValueError):
            verify_hosted_sdk(self.config, self.dependencies,
                              self.lock.replace('https://pub.dev', 'https://example.org'))

    def test_rejects_remote_package_uri(self):
        self.config.write_text(json.dumps({'packages': [
            {'name': SDK_NAME, 'rootUri': 'https://example.org/sdk'}]}))
        with self.assertRaises(ValueError):
            package_root(self.config, SDK_NAME)

    def test_runtime_must_match_release(self):
        release = self.root / 'checkout'
        expected = release / 'packages/openfeature_dart_client_sdk/lib'
        actual = self.sdk / 'lib'
        expected.mkdir(parents=True)
        actual.mkdir(parents=True)
        (expected / 'api.dart').write_text('release code')
        (actual / 'api.dart').write_text('release code')
        verify_runtime(self.sdk, release)
        (actual / 'api.dart').write_text('modified code')
        with self.assertRaises(ValueError):
            verify_runtime(self.sdk, release)

    def test_sections_do_not_mix_dependency_and_override(self):
        text = ('dependencies:\n  sdk: ^1.0.0\n\n'
                '# Test-only override.\ndependency_overrides:\n  sdk: 1.0.0\n')
        self.assertIn('sdk: ^1.0.0', section(text, 'dependencies'))
        self.assertNotIn('sdk: 1.0.0', section(text, 'dependencies'))

    def test_melos_core_override_must_preserve_hosted_release(self):
        manifests = ['packages/datadog_flags', 'packages/datadog_flags_flutter',
                     'packages/datadog_flags/example', 'packages/datadog_flags_flutter/example',
                     'examples/simple_example']
        for relative in manifests:
            path = self.root / relative / 'pubspec.yaml'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'dependencies:\n  {SDK_NAME}: ^{SDK_VERSION}\n')
        core = self.root / manifests[0] / 'pubspec.yaml'
        core.write_text(core.read_text() +
                        f'dev_dependencies:\n  contract:\n    git:\n      ref: {CONTRACT_REF}\n'
                        f'dependency_overrides:\n  {SDK_NAME}: {SDK_VERSION}\n')
        override = core.with_name('pubspec_overrides.yaml')
        prefix = f'# melos_managed_dependency_overrides: {SDK_NAME}\ndependency_overrides:\n'
        override.write_text(prefix + f'  {SDK_NAME}: {SDK_VERSION}\n')
        check_manifests(self.root)
        for value in ['0.0.1-beta.1', '0.0.1-beta.2', '\n    path: ../sdk', '\n    git: https://example.org/sdk']:
            with self.subTest(value=value):
                override.write_text(prefix + f'  {SDK_NAME}: {value}\n')
                with self.assertRaises(ValueError):
                    check_manifests(self.root)


if __name__ == '__main__':
    unittest.main()
