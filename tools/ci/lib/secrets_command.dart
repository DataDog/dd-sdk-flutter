// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

/// A Vault location holding a copy of every [CiSecretGroup].
enum SecretStore {
  /// Read by macOS (Tart) runners, which log in with the AWS auth method.
  aws('kv/aws/arn:aws:iam::486234852809:role/ci-dd-sdk-flutter'),

  /// Read by Linux runners through the CI Identity of jobs on protected
  /// branches. People can write to it but not read it.
  ci('kv/ci/datadog/dd-sdk-flutter/trusted-jobs');

  const SecretStore(this._prefix);

  final String _prefix;

  String pathFor(CiSecretGroup group) => '$_prefix/${group.name}';
}

/// Fields stored together at one Vault path, each with a description. Keep in
/// sync with the "Flutter CI Secrets" Confluence page.
enum CiSecretGroup {
  e2e({
    'client_token':
        'Client token for the E2E test app, bound to the mobile-integration environment',
    'application_id': 'RUM application id for the E2E test app',
  });

  const CiSecretGroup(this.fields);

  final Map<String, String> fields;
}

class VaultException implements Exception {
  VaultException(this.message);

  final String message;

  @override
  String toString() => 'VaultException: $message';
}

/// Runs the `vault` CLI.
class Vault {
  final _environment = {
    'VAULT_ADDR':
        Platform.environment['VAULT_ADDR'] ?? 'https://vault.us1.ddbuild.io',
  };

  Future<void> ensureLoggedIn() async {
    final lookup = await Process.run('vault', [
      'token',
      'lookup',
    ], environment: _environment);
    if (lookup.exitCode == 0) return;

    stderr.writeln('Logging in to Vault with OIDC.');
    final login = await Process.start(
      'vault',
      ['login', '-method=oidc', '-no-print'],
      environment: _environment,
      mode: ProcessStartMode.inheritStdio,
    );
    if (await login.exitCode != 0) throw VaultException('vault login failed.');
  }

  Future<String> read(String path, String field) async {
    final result = await Process.run('vault', [
      'kv',
      'get',
      '-field=$field',
      path,
    ], environment: _environment);
    if (result.exitCode != 0) {
      throw VaultException('Reading $path failed: ${result.stderr}'.trim());
    }
    return (result.stdout as String).trim();
  }

  /// Replaces every field at [path]. The data is sent to `vault` as JSON on
  /// stdin so it never appears in the process list.
  Future<void> write(String path, Map<String, String> fields) async {
    final process = await Process.start('vault', [
      'kv',
      'put',
      path,
      '-',
    ], environment: _environment);
    process.stdin.write(jsonEncode(fields));
    final (_, error, exitCode) = await (
      process.stdin.close(),
      process.stderr.transform(utf8.decoder).join(),
      process.exitCode,
    ).wait;
    process.stdout.drain<void>();
    if (exitCode != 0) {
      throw VaultException('Writing $path failed: $error'.trim());
    }
  }
}

/// The `secrets` command: reads and writes the Vault secrets used by CI.
class SecretsCommand extends Command<void> {
  SecretsCommand() {
    final vault = Vault();
    addSubcommand(_GetCommand(vault));
    addSubcommand(_SetCommand(vault));
  }

  @override
  String get name => 'secrets';

  @override
  String get description => 'Read and write the Vault secrets used by CI.';

  @override
  String get usageFooter => [
    '',
    'Secrets:',
    for (final group in CiSecretGroup.values)
      for (final MapEntry(:key, :value) in group.fields.entries)
        '  ${group.name}/$key\n      $value',
  ].join('\n');
}

class _GetCommand extends Command<void> {
  _GetCommand(this._vault);

  final Vault _vault;

  @override
  String get name => 'get';

  @override
  String get invocation => '${super.invocation} <group>/<field>';

  @override
  String get description =>
      'Print a secret from the ${SecretStore.aws.name} store.';

  @override
  Future<void> run() async {
    final [id] = argResults!.rest.length == 1
        ? argResults!.rest
        : usageException('Expected one secret, like e2e/client_token.');
    final [groupName, field] = id.split('/').length == 2
        ? id.split('/')
        : usageException('Unknown secret "$id".');
    final group = CiSecretGroup.values.asNameMap()[groupName];
    if (group == null || !group.fields.containsKey(field)) {
      usageException('Unknown secret "$id".');
    }

    await _vault.ensureLoggedIn();
    stdout.writeln(await _vault.read(SecretStore.aws.pathFor(group), field));
  }
}

class _SetCommand extends Command<void> {
  _SetCommand(this._vault);

  final Vault _vault;

  @override
  String get name => 'set';

  @override
  String get invocation => '${super.invocation} <group>';

  @override
  String get description =>
      'Prompt for every field of a group and write it to all stores.';

  @override
  Future<void> run() async {
    final group = argResults!.rest.length == 1
        ? CiSecretGroup.values.asNameMap()[argResults!.rest.single]
        : null;
    if (group == null) {
      usageException(
        'Expected one group: ${CiSecretGroup.values.map((g) => g.name).join(', ')}.',
      );
    }

    final values = {
      for (final field in group.fields.keys) field: _prompt('$field: '),
    };
    if (values.values.any((v) => v.isEmpty)) usageException('Empty value.');

    await _vault.ensureLoggedIn();
    for (final store in SecretStore.values) {
      await _vault.write(store.pathFor(group), values);
      stdout.writeln('Set ${group.name} in ${store.name}.');
    }
  }
}

/// Reads a line from stdin, hiding it when stdin is a terminal.
String _prompt(String label) {
  stderr.write(label);
  if (!stdin.hasTerminal) return stdin.readLineSync()?.trim() ?? '';

  stdin.echoMode = false;
  try {
    return stdin.readLineSync()?.trim() ?? '';
  } finally {
    stdin.echoMode = true;
    stderr.writeln();
  }
}
