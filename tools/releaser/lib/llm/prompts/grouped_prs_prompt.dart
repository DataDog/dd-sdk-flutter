// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// == LLM Pass 1: Collect related PRs into groups with a common label

import '../../pr_resolution.dart' show PrDetails;
import '../prompt.dart';

class GroupedPr {
  final int number;
  final String title;

  const GroupedPr({required this.number, required this.title});

  factory GroupedPr.fromJson(Map<String, dynamic> json) =>
      GroupedPr(number: json['number'] as int, title: json['title'] as String);
}

class PrGroup {
  final String label;
  final List<GroupedPr> prs;

  const PrGroup({required this.label, required this.prs});

  factory PrGroup.fromJson(Map<String, dynamic> json) => PrGroup(
    label: json['label'] as String,
    prs: (json['prs'] as List)
        .map((e) => GroupedPr.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class GroupedPrs {
  final List<PrGroup> groups;

  const GroupedPrs({required this.groups});

  factory GroupedPrs.fromJson(Map<String, dynamic> json) => GroupedPrs(
    groups: (json['groups'] as List)
        .map((e) => PrGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

final _schema = {
  'type': 'object',
  'properties': {
    'groups': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'label': {
            'type': 'string',
            'description':
                'Short string describing the purpose of this group of PRs. '
                'Infer from the titles of constituent PRs.',
          },
          'prs': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'number': {
                  'type': 'integer',
                  'description':
                      'Integer PR number. Use the original PR number exactly.',
                },
                'title': {
                  'type': 'string',
                  'description':
                      'Single-line string describing the PR. Use the '
                      'original text exactly.',
                },
              },
              'required': ['number', 'title'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['label', 'prs'],
        'additionalProperties': false,
      },
    },
  },
  'required': ['groups'],
  'additionalProperties': false,
};

String _text(List<PrDetails> prs) {
  final prText = prs
      .map((pr) => '${pr.number.toString().padLeft(5)} ${pr.title}')
      .join('\n');
  return '''
You are preparing to write a customer-facing changelog for an SDK. Below is a list of PRs that have been merged since the last release.

Your task: group these PRs so that closely-related PRs can be considered together. A group should capture a coherent user-visible change: for example, several PRs that together implement one feature, or a fix that directly relates to a feature in the same release. PRs with no clear relationship to others should each be their own group.

Your response will be a JSON array where each element is an object representing a related group of one or more PRs. This JSON value will adhere to the provided schema. Your response will include no prose or formatting.

Use only the data provided below. Do not consult external sources.

<prs>
$prText
</prs>''';
}

/// Groups [prs] so closely-related PRs are considered together in the next
/// pass -- see `changelog.dart`'s `runGroupedPrsPrompt` for the validation
/// layered on top of this raw call.
Prompt<GroupedPrs> groupedPrsPrompt(List<PrDetails> prs) =>
    Prompt(text: _text(prs), schema: _schema, fromJson: GroupedPrs.fromJson);
