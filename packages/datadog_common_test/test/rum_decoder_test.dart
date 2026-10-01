// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _view(int documentVersion, Map<String, dynamic> view,
    {Map<String, dynamic>? context}) {
  return {
    'type': 'view',
    'date': 1000,
    'service': 'service',
    '_dd': {'document_version': documentVersion},
    'session': {'id': 'session-id'},
    'context': context ?? {},
    'view': {
      'id': 'view-id',
      'name': 'ViewName',
      'url': 'ViewName',
      ...view,
    },
  };
}

Map<String, dynamic> _viewUpdate(int documentVersion, Map<String, dynamic> view,
    {Map<String, dynamic>? context}) {
  return {
    'type': 'view_update',
    'date': 1000,
    '_dd': {'document_version': documentVersion},
    'session': {'id': 'session-id'},
    if (context != null) 'context': context,
    'view': {
      'id': 'view-id',
      'url': 'ViewName',
      ...view,
    },
  };
}

void main() {
  test('view_update events are applied on top of the previous view state', () {
    final events = [
      _viewUpdate(3, {
        'time_spent': 300,
        'error': {'count': 1},
        'is_active': false,
      }),
      _view(1, {
        'time_spent': 100,
        'is_active': true,
        'action': {'count': 0},
        'error': {'count': 0},
        'accessibility': {'bold_text_enabled': false, 'rtl_enabled': false},
      }),
      _viewUpdate(2, {
        'time_spent': 200,
        'action': {'count': 2},
        'accessibility': {'bold_text_enabled': true},
      }),
    ].map(RumEventDecoder.new).toList();

    final session = RumSessionDecoder.fromEvents(events);

    expect(session.visits.length, 1);
    final visit = session.visits[0];
    expect(visit.name, 'ViewName');
    expect(visit.viewEvents.length, 3);

    final last = visit.viewEvents.last;
    expect(last.eventType, 'view');
    expect(last.service, 'service');
    expect(last.view.actionCount, 2);
    expect(last.view.errorCount, 1);
    expect(last.view.isActive, isFalse);
    expect(last.timeSpent, 300);
    expect(last.rumEvent['view']['accessibility'],
        {'bold_text_enabled': true, 'rtl_enabled': false});
  });

  test('view_update replaces non-view fields wholesale', () {
    final events = [
      _view(1, {'time_spent': 100}, context: {'a': 1, 'b': 2}),
      _viewUpdate(2, {'time_spent': 200}, context: {'a': 1}),
    ].map(RumEventDecoder.new).toList();

    final session = RumSessionDecoder.fromEvents(events);

    expect(session.visits[0].viewEvents.last.context, {'a': 1});
  });

  test('view_update without a baseline view is ignored', () {
    final events = [
      _viewUpdate(2, {'time_spent': 200}),
    ].map(RumEventDecoder.new).toList();

    final session = RumSessionDecoder.fromEvents(events);

    expect(session.visits, isEmpty);
  });
}
