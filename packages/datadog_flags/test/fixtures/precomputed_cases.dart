// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

class PrecomputedFixtureCase {
  final String name;
  final String json;

  const PrecomputedFixtureCase({
    required this.name,
    required this.json,
  });
}

const precomputedFixtureCases = [
  PrecomputedFixtureCase(
    name: 'all-types-success.json',
    json: r'''
{
  "name": "all-types-success",
  "description": "Successful precomputed assignments for all supported Flutter value types.",
  "context": {
    "targetingKey": "precomputed-user",
    "attributes": {
      "plan": "pro",
      "platform": "flutter"
    }
  },
  "response": {
    "data": {
      "attributes": {
        "flags": {
          "flutter.fixture.enabled": {
            "allocationKey": "allocation-success",
            "variationKey": "enabled",
            "variationType": "boolean",
            "variationValue": true,
            "reason": "TARGETING_MATCH",
            "doLog": true
          },
          "flutter.fixture.title": {
            "allocationKey": "allocation-success",
            "variationKey": "copy-a",
            "variationType": "string",
            "variationValue": "Datadog Flags",
            "reason": "TARGETING_MATCH",
            "doLog": true
          },
          "flutter.fixture.limit": {
            "allocationKey": "allocation-success",
            "variationKey": "limit-five",
            "variationType": "integer",
            "variationValue": 5,
            "reason": "TARGETING_MATCH",
            "doLog": true
          },
          "flutter.fixture.ratio": {
            "allocationKey": "allocation-success",
            "variationKey": "half",
            "variationType": "float",
            "variationValue": 0.5,
            "reason": "TARGETING_MATCH",
            "doLog": true
          },
          "flutter.fixture.config": {
            "allocationKey": "allocation-success",
            "variationKey": "object-a",
            "variationType": "object",
            "variationValue": {
              "showBanner": true,
              "colors": [
                "blue",
                "green"
              ]
            },
            "reason": "TARGETING_MATCH",
            "doLog": true
          }
        }
      }
    }
  },
  "evaluations": [
    {
      "flag": "flutter.fixture.enabled",
      "variationType": "boolean",
      "defaultValue": false,
      "result": {
        "value": true,
        "variant": "enabled",
        "reason": "TARGETING_MATCH",
        "error": null
      }
    },
    {
      "flag": "flutter.fixture.title",
      "variationType": "string",
      "defaultValue": "Fallback title",
      "result": {
        "value": "Datadog Flags",
        "variant": "copy-a",
        "reason": "TARGETING_MATCH",
        "error": null
      }
    },
    {
      "flag": "flutter.fixture.limit",
      "variationType": "integer",
      "defaultValue": 0,
      "result": {
        "value": 5,
        "variant": "limit-five",
        "reason": "TARGETING_MATCH",
        "error": null
      }
    },
    {
      "flag": "flutter.fixture.ratio",
      "variationType": "float",
      "defaultValue": 0.0,
      "result": {
        "value": 0.5,
        "variant": "half",
        "reason": "TARGETING_MATCH",
        "error": null
      }
    },
    {
      "flag": "flutter.fixture.config",
      "variationType": "object",
      "defaultValue": {},
      "result": {
        "value": {
          "showBanner": true,
          "colors": [
            "blue",
            "green"
          ]
        },
        "variant": "object-a",
        "reason": "TARGETING_MATCH",
        "error": null
      }
    }
  ],
  "expectedEmissions": {
    "exposures": 5,
    "flagevaluationRequests": 1,
    "flagevaluationEvents": 5
  }
}
''',
  ),
  PrecomputedFixtureCase(
    name: 'defaults-and-emission-gates.json',
    json: r'''
{
  "name": "defaults-and-emission-gates",
  "description": "Precomputed assignments that validate exposure gates, unknown variation isolation, and default/error flagevaluation payloads.",
  "context": {
    "targetingKey": "precomputed-user",
    "attributes": {
      "plan": "free",
      "platform": "flutter"
    }
  },
  "response": {
    "data": {
      "attributes": {
        "flags": {
          "flutter.fixture.silent": {
            "allocationKey": "allocation-silent",
            "variationKey": "silent-on",
            "variationType": "boolean",
            "variationValue": true,
            "reason": "TARGETING_MATCH",
            "doLog": false
          },
          "flutter.fixture.string": {
            "allocationKey": "allocation-string",
            "variationKey": "copy-b",
            "variationType": "string",
            "variationValue": "Actual string",
            "reason": "TARGETING_MATCH",
            "doLog": true
          },
          "flutter.fixture.unknown": {
            "allocationKey": "allocation-unknown",
            "variationKey": "unknown-a",
            "variationType": "unsupported",
            "variationValue": "Ignored",
            "reason": "TARGETING_MATCH",
            "doLog": true
          }
        }
      }
    }
  },
  "evaluations": [
    {
      "flag": "flutter.fixture.silent",
      "variationType": "boolean",
      "defaultValue": false,
      "result": {
        "value": true,
        "variant": "silent-on",
        "reason": "TARGETING_MATCH",
        "error": null
      }
    },
    {
      "flag": "flutter.fixture.string",
      "variationType": "boolean",
      "defaultValue": false,
      "result": {
        "value": false,
        "variant": null,
        "reason": null,
        "error": "typeMismatch"
      }
    },
    {
      "flag": "flutter.fixture.unknown",
      "variationType": "boolean",
      "defaultValue": false,
      "result": {
        "value": false,
        "variant": null,
        "reason": null,
        "error": "flagNotFound"
      }
    },
    {
      "flag": "flutter.fixture.missing",
      "variationType": "string",
      "defaultValue": "fallback",
      "result": {
        "value": "fallback",
        "variant": null,
        "reason": null,
        "error": "flagNotFound"
      }
    }
  ],
  "expectedEmissions": {
    "exposures": 0,
    "flagevaluationRequests": 1,
    "flagevaluationEvents": 4
  }
}
''',
  ),
];
