// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_session_replay/src/processor/diff.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SRWireframe text(int id, {String value = 'text'}) => SRTextWireframe(
    id: id,
    x: 0,
    y: 0,
    width: 10,
    height: 10,
    text: value,
    textStyle: SRTextStyle(color: '#000000FF', family: '', size: 10),
  );

  SRWireframe image(int id) => SRImageWireframe(
    id: id,
    x: 0,
    y: 0,
    width: 10,
    height: 10,
    resourceId: 'resource',
  );

  SRWireframe placeholder(int id) => SRPlaceholderWireframe(
    id: id,
    x: 0,
    y: 0,
    width: 10,
    height: 10,
    label: 'Image',
  );

  for (final (description, before, after) in [
    ('image replaced by text', image(1), text(1)),
    ('text replaced by image', text(1), image(1)),
    ('image replaced by placeholder', image(1), placeholder(1)),
  ]) {
    test('$description is removed and added again', () {
      final diff = computeDiff([text(0), before], [text(0), after]);

      expect(diff.removes.map((remove) => remove.id), [1]);
      expect(diff.adds.single.wireframe, after);
      expect(diff.adds.single.previousId, 0);
      expect(diff.updates, isEmpty);
    });
  }

  test('changed wireframe of the same type is updated', () {
    final diff = computeDiff([text(1)], [text(1, value: 'changed')]);

    expect(diff.updates.length, 1);
    expect(diff.adds, isEmpty);
    expect(diff.removes, isEmpty);
  });

  test('unchanged wireframes produce no diff', () {
    final diff = computeDiff([text(0), image(1)], [text(0), image(1)]);

    expect(diff.isEmpty, isTrue);
  });
}
