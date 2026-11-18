// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

/// Dart reserved words, and contextual keywords that would be confusing as
/// member names.
const _reservedWords = {
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', //
  'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
  'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
  'external', 'factory', 'false', 'final', 'finally', 'for', 'Function',
  'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
  'late', 'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part',
  'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
  'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'typedef',
  'var', 'void', 'when', 'while', 'with', 'yield',
};

/// Members every generated class declares or inherits; a field with one of
/// these names would clash with them.
const _classMembers = {
  'fromJson', 'toJson', 'hashCode', 'runtimeType', 'toString', //
  'noSuchMethod',
};

/// Members every generated enum declares or inherits; a case with one of
/// these names would clash with them.
const _enumMembers = {..._classMembers, 'values', 'index', 'value'};

/// Splits [input] on anything that is not a letter or a digit and
/// capitalizes each part: `records_count` -> `RecordsCount`
String pascalCase(String input) => input
    .split(RegExp(r'[^A-Za-z0-9]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join();

/// [pascalCase] with a lowercase first letter: `records_count` ->
/// `recordsCount`.
String camelCase(String input) {
  final pascal = pascalCase(input);
  if (pascal.isEmpty) return pascal;
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// The Dart field name for the JSON key [key]: `records_count` ->
/// `recordsCount`, `default` -> `defaultValue`.
String fieldName(String key) => _memberName(key, _classMembers);

/// The Dart enum case name for the JSON value [value]: `react-native` ->
/// `reactNative`, `values` -> `valuesValue`.
String enumCaseName(String value) => _memberName(value, _enumMembers);

/// A valid Dart member name for [input] that does not clash with
/// [reservedMembers]
String _memberName(String input, Set<String> reservedMembers) {
  var name = camelCase(input);
  if (name.isEmpty || name.startsWith(RegExp('[0-9]'))) {
    name = 'v$name';
  }
  if (_reservedWords.contains(name) || reservedMembers.contains(name)) {
    name = '${name}Value';
  }
  return name;
}
