// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

/// The official mobile samples of rum-events-format
/// (`samples/session-replay/mobile`), at the commit the models are generated
/// from: sample path -> its JSON.
const srSamples = {
  'record/full-snapshot-record-with-composition-tree.json': r'''
{
  "timestamp": 1657618587157,
  "type": 10,
  "data": {
    "wireframes": [
      {
        "id": 42,
        "x": 20,
        "y": 100,
        "width": 240,
        "height": 80,
        "type": "shape"
      },
      {
        "id": 43,
        "x": 44,
        "y": 124,
        "width": 160,
        "height": 24,
        "type": "text",
        "text": "Hello",
        "textStyle": {
          "family": "Arial",
          "size": 16,
          "type": "sans-serif",
          "color": "#000000FF"
        }
      }
    ],
    "compositionTree": {
      "root": {
        "id": 1,
        "x": 0,
        "y": 0,
        "width": 390,
        "height": 844,
        "children": [{ "type": "layer", "id": 2 }]
      },
      "layers": [
        {
          "id": 2,
          "x": 20,
          "y": 100,
          "width": 240,
          "height": 80,
          "modifiers": [
            {
              "type": "clip",
              "path": "M 0 24 Q 0 0 24 0 H 216 Q 240 0 240 24 V 80 H 0 Z",
              "fillRule": "nonzero"
            },
            {
              "type": "shadow",
              "color": "#00000040",
              "offsetX": 0,
              "offsetY": 2,
              "radius": 8,
              "path": "M 0 24 Q 0 0 24 0 H 216 Q 240 0 240 24 V 80 H 0 Z"
            },
            {
              "type": "opacity",
              "value": 0.9
            },
            {
              "type": "maskImage",
              "resourceId": "maskResourceIdMock"
            }
          ],
          "children": [
            { "type": "wireframe", "id": 42 },
            { "type": "wireframe", "id": 43 }
          ],
          "compositeOperation": "destinationOut"
        }
      ]
    }
  }
}
''',
  'record/full-snapshot-record.json': r'''
{
  "timestamp": 1657618587157,
  "type": 10,
  "data": {
    "wireframes": [
      {
        "id": 1,
        "x": 10,
        "y": 10,
        "width": 20,
        "height": 30,
        "type": "text",
        "text": "Test",
        "textStyle": {
          "family": "Arial",
          "size": 20,
          "type": "sans-serif",
          "color": "#FF000000"
        }
      },
      {
        "id": 2,
        "x": 10,
        "y": 10,
        "width": 20,
        "height": 30,
        "type": "image",
        "base64": "base64Mock",
        "resourceId": "resourceIdMock",
        "mimeType": "image/jpeg"
      },
      {
        "id": 3,
        "x": 10,
        "y": 10,
        "width": 20,
        "height": 30,
        "type": "image"
      },
      {
        "id": 4,
        "x": 10,
        "y": 10,
        "width": 20,
        "height": 30,
        "type": "image",
        "isEmpty": true
      },
      {
        "id": 5,
        "x": 20,
        "y": 30,
        "width": 100,
        "height": 50,
        "type": "shape",
        "shapeStyle": {
          "backgroundGradient": {
            "type": "linear",
            "stops": [
              {
                "color": "#FF0000FF",
                "position": 0
              },
              {
                "color": "#0000FFFF",
                "position": 1
              }
            ],
            "startPoint": {
              "x": 0,
              "y": 0.5
            },
            "endPoint": {
              "x": 1,
              "y": 0.5
            }
          },
          "cornerRadius": 8
        }
      }
    ]
  }
}
''',
  'record/has-focus-record.json': r'''
{
  "timestamp": 1657629228278,
  "type": 6,
  "data": {
    "has_focus": true
  }
}
''',
  'record/incremental-snapshot-record-composition-tree-mutation.json': r'''
{
  "timestamp": 1657620232337,
  "type": 11,
  "data": {
    "source": 10,
    "root": {
      "id": 1,
      "x": 0,
      "y": 0,
      "width": 390,
      "height": 844,
      "children": [
        { "type": "layer", "id": 2 },
        { "type": "layer", "id": 3 }
      ]
    },
    "adds": [
      {
        "id": 3,
        "x": 10,
        "y": 200,
        "width": 100,
        "height": 50,
        "children": [],
        "modifiers": [
          {
            "type": "gaussianBlur",
            "radius": 8
          }
        ],
        "compositeOperation": "sourceOver"
      }
    ],
    "removes": [4],
    "updates": [
      {
        "id": 2,
        "modifiers": [
          {
            "type": "clip",
            "path": "M 0 16 Q 0 0 16 0 H 224 Q 240 0 240 16 V 80 H 0 Z"
          }
        ],
        "children": [
          { "type": "wireframe", "id": 42 },
          { "type": "wireframe", "id": 43 }
        ],
        "compositeOperation": "destinationOut"
      }
    ]
  }
}
''',
  'record/incremental-snapshot-record.json': r'''
{
  "timestamp": 1657620232337,
  "type": 11,
  "data": {
    "source": 0,
    "adds": [
      {
        "previousId": 10,
        "wireframe": {
          "id": 11,
          "x": 10,
          "y": 10,
          "width": 20,
          "height": 30,
          "type": "text",
          "text": "Test",
          "textStyle": {
            "family": "Arial",
            "size": 20,
            "type": "sans-serif",
            "color": "#FF000000"
          }
        }
      },
      {
        "previousId": 11,
        "wireframe": {
          "id": 14,
          "x": 10,
          "y": 10,
          "width": 20,
          "height": 30,
          "type": "image"
        }
      }
    ],
    "removes": [
      {
        "id": 9
      }
    ],
    "updates": [
      {
        "id": 3,
        "text": "New text",
        "type": "text",
        "textStyle": {
          "family": "Arial",
          "size": 20,
          "type": "sans-serif",
          "color": "#FF0000"
        }
      },
      {
        "id": 4,
        "type": "shape",
        "x": 0,
        "y": 10
      },
      {
        "id": 12,
        "type": "image",
        "base64": "base64Mock",
        "resourceId": "resourceIdMock",
        "mimeType": "image/jpeg"
      },
      {
        "id": 12,
        "type": "image",
        "isEmpty": true
      }
    ]
  }
}
''',
  'record/metadata-record.json': r'''
{
  "timestamp": 1657629228274,
  "type": 4,
  "data": {
    "width": 600,
    "height": 800
  }
}
''',
  'record/view-end-record.json': r'''
{
  "timestamp": 1657629228280,
  "type": 7
}
''',
  'segment/segment.json': r'''
{
  "application": {
    "id": "c8b3b434-0a55-413f-a391-8e3b7e7131a8"
  },
  "session": {
    "id": "c09e525c-5971-49c4-8b51-531ba99765cf"
  },
  "view": {
    "id": "b27c7927-bf1e-4168-8d56-d5f191741ba4"
  },
  "source": "android",
  "start": 1657629228285,
  "end": 1657629238285,
  "has_full_snapshot_record": true,
  "records_count": 2,
  "creation_reason": "init",
  "index_in_view": 1,
  "records": [
    {
      "timestamp": 1657629228218,
      "type": 10,
      "data": {
        "wireframes": [
          {
            "id": 1,
            "x": 10,
            "y": 10,
            "width": 20,
            "height": 30,
            "type": "shape"
          },
          {
            "id": 2,
            "x": 10,
            "y": 10,
            "width": 20,
            "height": 30,
            "type": "text",
            "text": "Test",
            "textStyle": {
              "family": "Arial",
              "size": 20,
              "type": "sans-serif",
              "color": "#FF000000"
            }
          },
          {
            "id": 3,
            "x": 40,
            "y": 50,
            "width": 20,
            "height": 30,
            "type": "shape"
          }
        ]
      }
    },
    {
      "timestamp": 1657629228273,
      "type": 11,
      "data": {
        "source": 0,
        "adds": [
          {
            "previousId": 2,
            "wireframe": {
              "id": 12,
              "x": 10,
              "y": 10,
              "width": 20,
              "height": 30,
              "type": "text",
              "text": "Test",
              "textStyle": {
                "family": "Arial",
                "size": 20,
                "type": "sans-serif",
                "color": "#FF000000"
              }
            }
          }
        ],
        "removes": [
          {
            "id": 3
          }
        ],
        "updates": [
          {
            "id": 2,
            "text": "New text",
            "type": "text",
            "textStyle": {
              "family": "Arial",
              "size": 20,
              "type": "sans-serif",
              "color": "#FF0000"
            }
          },
          {
            "id": 1,
            "type": "shape",
            "x": 0,
            "y": 10
          }
        ]
      }
    }
  ]
}
''',
};
