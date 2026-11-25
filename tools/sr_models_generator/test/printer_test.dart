// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:sr_models_generator/src/naming.dart';
import 'package:test/test.dart';

import 'support/package_root.dart';

void main() {
  late String fixtures;

  /// [definitions] printed and formatted, as the generator writes them.
  Future<String> printed(
    Iterable<Definition> definitions, {
    List<String> header = const [],
  }) => formatDart(
    DartPrinter(
      part: 'models.g.dart',
      header: header,
    ).printLibrary(definitions),
    destination: 'models.dart',
  );

  /// The definitions of the resolver fixtures [files].
  List<Definition> definitionsOf(List<String> files) =>
      (ModelResolver(SchemaLoader(fixtures))..resolveRoots(files)).definitions;

  setUpAll(() async {
    fixtures = p.join(await packageRoot(), 'test', 'fixtures', 'resolver');
  });

  group('the library', () {
    late String library;
    setUpAll(
      () async => library = await printed(
        definitionsOf(['primitives-schema.json']),
        header: ['Generated.', '', 'Do not edit.'],
      ),
    );

    test('starts with the header, as comments', () {
      expect(library.split('\n').take(3), [
        '// Generated.',
        '//',
        '// Do not edit.',
      ]);
    });

    test('imports what the annotations need', () {
      expect(
        library,
        contains(
          "import 'package:json_annotation/json_annotation.dart';\n"
          "import 'package:meta/meta.dart';",
        ),
      );
    });

    test('includes the part json_serializable generates', () {
      expect(library, contains("part 'models.g.dart';"));
    });
  });

  group('enums', () {
    // Values that must be escaped in a Dart string literal.
    final quirky = EnumDefinition(
      name: 'SRQuirky',
      location: 'quirky.json',
      description: null,
      values: {
        "it's": 'itS',
        r'$price': 'price',
        r'back\slash': 'backSlash',
        'line\nbreak': 'lineBreak',
      },
    );
    late String library;
    setUpAll(
      () async => library = await printed([
        ...definitionsOf(['text-schema.json']).whereType<EnumDefinition>(),
        quirky,
      ]),
    );

    // The annotated case -> what is special about its value.
    final cases = {
      "@JsonValue('ios')\n  ios,": 'a value',
      "@JsonValue('react-native')\n  reactNative,": 'a value with a dash',
      "@JsonValue('values')\n  valuesValue,": 'a value named like a member',
      "@JsonValue('it\\'s')\n  itS,": 'a value with a quote',
      "@JsonValue('\\\$price')\n  price,": 'a value with a dollar',
    };
    for (final MapEntry(key: code, value: what) in cases.entries) {
      test('annotates the case of $what with its JSON value', () {
        expect(library, contains(code));
      });
    }

    test('prints plain enums', () {
      expect(library, contains('enum SRPlatform {'));
      expect(library, isNot(contains('fromJson')));
    });
  });

  group('classes', () {
    late String library;
    setUpAll(
      () async => library = await printed(
        definitionsOf([
          'primitives-schema.json',
          'shapes-schema.json',
          'text-schema.json',
        ]),
      ),
    );

    test('prints immutable final classes that json_serializable converts', () {
      expect(
        library,
        contains(
          '@immutable\n'
          '@JsonSerializable(explicitToJson: true, includeIfNull: false, '
          'checked: true)\n'
          'final class SRPoint {\n'
          '  const SRPoint({required this.x, required this.y});\n'
          '\n'
          '  factory SRPoint.fromJson(Map<String, dynamic> json) =>\n'
          '      _\$SRPointFromJson(json);',
        ),
      );
      expect(
        library,
        contains('  Map<String, dynamic> toJson() => _\$SRPointToJson(this);'),
      );
    });

    test('makes optional fields nullable and not required', () {
      expect(library, contains('  final double? ratio;'));
      expect(library, contains('    this.ratio,'));
      expect(library, contains('    required this.count,'));
    });

    test('names a field after its JSON key only when they differ', () {
      expect(
        library,
        contains("  @JsonKey(name: 'is_visible')\n  final bool? isVisible;"),
      );
      expect(library, contains('  final int count;'));
      expect(library, isNot(contains("JsonKey(name: 'count')")));
    });

    test('writes const fields to JSON without reading them', () {
      expect(
        library,
        contains(
          '  @JsonKey(includeFromJson: false, includeToJson: true)\n'
          "  final String type = 'text';",
        ),
      );
      expect(
        library,
        contains(
          '  @JsonKey(includeFromJson: false, includeToJson: true)\n'
          '  final int version = 0;',
        ),
      );
      expect(library, isNot(contains('this.type')));
      expect(library, isNot(contains('this.version')));
    });

    group('==', () {
      test('compares every field but the const ones', () {
        expect(
          library,
          contains(
            '      other is SRPrimitives &&\n'
            '          other.count == count &&\n'
            '          other.ratio == ratio &&\n'
            '          other.text == text &&\n'
            '          other.isVisible == isVisible;',
          ),
        );
        expect(library, isNot(contains('other.type')));
        expect(library, isNot(contains('other.version')));
      });

      test('hashes the same fields', () {
        expect(
          library,
          contains(
            '  int get hashCode => Object.hashAll([count, ratio, text, '
            'isVisible]);',
          ),
        );
      });

      test('compares and hashes lists item by item', () {
        expect(library, contains('_equals(other.grid, grid)'));
        expect(library, contains('_hash(grid)'));
        expect(library, contains('bool _equals(Object? a, Object? b) {'));
        expect(library, contains('int _hash(Object? value) =>'));
      });

      test('declares the list helpers only when a class has lists', () async {
        final primitives = await printed(
          definitionsOf(['primitives-schema.json']),
        );
        expect(primitives, isNot(contains('_equals')));
        expect(primitives, isNot(contains('_hash')));
      });
    });
  });

  group('unions', () {
    late String library;
    setUpAll(
      () async => library = await printed(
        definitionsOf(['drawing-schema.json', 'tree-node-schema.json']),
      ),
    );

    test('prints a sealed class that its variants implement', () {
      expect(library, contains('@immutable\nsealed class SRShape {'));
      expect(library, contains('final class SRCircle implements SRShape {'));
      expect(library, contains('final class SRTapEvent implements SREvent {'));
    });

    test('picks the variant from the discriminator', () {
      expect(
        library,
        contains(
          '  factory SRShape.fromJson(Map<String, dynamic> json) => '
          "switch (json['type']) {\n"
          "    'circle' => SRCircle.fromJson(json),\n"
          "    'square' => SRSquare.fromJson(json),\n"
          '    final other => throw FormatException(\n'
          "      'Unknown SRShape type: '\n"
          "      '\$other',\n"
          '    ),\n'
          '  };',
        ),
      );
    });

    test('picks the variant from an integer discriminator', () {
      expect(library, contains("switch (json['source']) {"));
      expect(library, contains('        2 => SRTapEvent.fromJson(json),'));
    });

    test('exposes the fields every variant shares', () {
      final union = RegExp(
        r'sealed class SRShape \{.*?\n\}',
        dotAll: true,
      ).firstMatch(library)?[0];
      expect(union, isNotNull);
      expect(union, contains('  int get id;'));
      expect(union, contains('  SRPoint? get clip;'));
      expect(union, contains('  String get type;'));
      expect(union, contains('  Map<String, dynamic> toJson();'));
      // `label` has another type in each variant.
      expect(union, isNot(contains('label')));
    });

    test('marks the shared fields of a variant as overrides', () {
      expect(library, contains('  @override\n  final int id;'));
      expect(
        library,
        contains(
          '  @override\n'
          '  @JsonKey(includeFromJson: false, includeToJson: true)\n'
          "  final String type = 'circle';",
        ),
      );
      expect(
        library,
        contains(
          '  @override\n'
          '  Map<String, dynamic> toJson() => _\$SRCircleToJson(this);',
        ),
      );
    });
  });

  group('documentation', () {
    late String library;
    setUpAll(
      () async => library = await printed(
        definitionsOf([
          'primitives-schema.json',
          'text-schema.json',
          'drawing-schema.json',
        ]),
      ),
    );

    // Description in the fixtures -> where it must be printed.
    final comments = {
      'a class':
          '/// One property of each primitive type.\n'
          '@immutable\n@JsonSerializable(',
      'a field': '  /// An integer.\n  final int count;',
      'an enum': '/// The platform.\nenum SRPlatform {',
      'a field of an enum type':
          '  /// How text is truncated.\n'
          "  @JsonKey(name: 'truncation_mode')\n"
          '  final SRTextTruncationMode truncationMode;',
      'a const field':
          '  /// The kind of element.\n'
          '  @JsonKey(includeFromJson: false, includeToJson: true)\n'
          "  final String type = 'text';",
      'a union': '/// A shape.\n@immutable\nsealed class SRShape {',
      'a shared field, in the union': '  /// The identifier.\n  int get id;',
      'a shared field, in a variant':
          '  /// The identifier.\n  @override\n  final int id;',
    };
    for (final MapEntry(key: what, value: comment) in comments.entries) {
      test('documents $what', () {
        expect(library, contains(comment));
      });
    }

    test('writes no comment without a description', () {
      expect(library, contains('  final int count;\n\n  final double? ratio;'));
    });

    Future<String> documented(String description) => printed([
      ClassDefinition(
          name: 'SRNote',
          location: 'note.json',
          description: description,
        )
        ..fields.add(
          Field(
            jsonKey: 'text',
            dartName: 'text',
            type: const PrimitiveType(Primitive.string),
            isRequired: true,
            description: description,
          ),
        ),
    ]);

    test('wraps long descriptions to 80 columns, keeping every word', () async {
      final description = List.generate(30, (i) => 'word$i').join(' ');
      final comments = [
        for (final line in (await documented(description)).split('\n'))
          if (line.startsWith('/// ')) line,
      ];
      expect(comments.length, greaterThan(2));
      expect(comments.every((line) => line.length <= 80), isTrue);
      expect([
        for (final line in comments) ...line.substring(4).split(' '),
      ], description.split(' '));
    });

    test('keeps paragraphs', () async {
      expect(
        await documented('First.\n\nSecond.'),
        contains('/// First.\n///\n/// Second.\n@immutable'),
      );
    });

    test('keeps text that is not ASCII', () async {
      expect(
        await documented('Café, “quoted”, 1–2 €.'),
        contains('/// Café, “quoted”, 1–2 €.'),
      );
    });

    test('escapes what dartdoc would read as a reference or HTML', () async {
      expect(
        await documented('Entries [0] to [3], or <none>.'),
        contains(r'/// Entries \[0\] to \[3\], or \<none>.'),
      );
    });
  });

  group('names that could clash with the generated code', () {
    Field field(String key, TypeRef type, {Object? constValue}) => Field(
      jsonKey: key,
      dartName: fieldName(key),
      type: type,
      isRequired: true,
      description: null,
      constValue: constValue,
    );
    const string = PrimitiveType(Primitive.string);
    late String library;

    setUpAll(() async {
      // A field named `other`, like the parameter of ==, and one that would
      // be named `identical`, like the function == calls.
      final holder =
          ClassDefinition(
              name: 'SRHolder',
              location: 'holder.json',
              description: null,
            )
            ..fields.addAll([
              field('other', string),
              field('items', const ListType(string)),
              field('identical', string),
            ]);
      // A discriminator key with characters to escape in a string literal.
      final quoted = ClassDefinition(
        name: 'SRQuoted',
        location: 'quoted.json',
        description: null,
      )..fields.add(field("kind's", string, constValue: 'q'));
      final union = UnionDefinition(
        name: 'SRTagged',
        location: 'tagged.json',
        description: null,
      )..discriminatorKey = "kind's";
      union.variants['q'] = quoted;
      quoted.unions.add(union);
      library = await printed([holder, quoted, union]);
    });

    test('a field named other is compared to the other field', () {
      expect(library, contains('other.other == this.other'));
      expect(library, contains('_equals(other.items, items)'));
    });

    test('a field is not named identical', () {
      expect(
        library,
        contains(
          "  @JsonKey(name: 'identical')\n  final String identicalValue;",
        ),
      );
    });

    test('a discriminator key with a quote is escaped', () {
      expect(library, contains(r"switch (json['kind\'s'])"));
      expect(library, contains(r"@JsonKey(name: 'kind\'s'"));
    });
  });

  group('dartString', () {
    final literals = {
      'plain': "'plain'",
      "it's": r"'it\'s'",
      r'$price': r"'\$price'",
      r'back\slash': r"'back\\slash'",
      'line\nbreak': r"'line\nbreak'",
      'bell\u0007': r"'bell\u{7}'",
      'naïve': "'naïve'",
    };
    for (final MapEntry(key: value, value: literal) in literals.entries) {
      test('writes $literal', () {
        expect(dartString(value), literal);
      });
    }
  });
}
