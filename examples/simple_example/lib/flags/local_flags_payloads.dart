// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

Map<String, Object?> localPrecomputeResponse() {
  return {
    'data': {
      'attributes': {
        'flags': {
          'flutter.demo.enabled': {
            'allocationKey': 'allocation-mobile-demo',
            'variationKey': 'enabled',
            'variationType': 'boolean',
            'variationValue': true,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'flutter.demo.title': {
            'allocationKey': 'allocation-mobile-demo',
            'variationKey': 'copy-a',
            'variationType': 'string',
            'variationValue': 'Datadog Flags',
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'flutter.demo.limit': {
            'allocationKey': 'allocation-mobile-demo',
            'variationKey': 'limit-five',
            'variationType': 'integer',
            'variationValue': 5,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'flutter.demo.ratio': {
            'allocationKey': 'allocation-mobile-demo',
            'variationKey': 'half',
            'variationType': 'float',
            'variationValue': 0.5,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'flutter.demo.config': {
            'allocationKey': 'allocation-mobile-demo',
            'variationKey': 'object-a',
            'variationType': 'object',
            'variationValue': {
              'showBanner': true,
              'colors': ['blue', 'green'],
            },
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
        },
      },
    },
  };
}

int countExposureBody(String body) {
  return body.split('\n').where((line) => line.trim().isNotEmpty).length;
}

int countEvaluationEvents(String body) {
  final decoded = jsonDecode(body) as Map<String, Object?>;
  final evaluations = decoded['flagEvaluations'] as List<Object?>;
  return evaluations.length;
}
