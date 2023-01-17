# Datadog SDK Stress Test

This app is meant to be used to stress test the Datadog Flutter SDK.

It divides these tests into three areas:
* Large payloads - adding large amounts of data to any Log `attributes` or `context` variables
* High frequency - sending a lot of logs or RUM events
* Mapping - adding mapping functions

You can enable / disable the mapping functions in `main.dart`, and any of the tests.

# Findings

## iOS

```
TODO
```

## Android

```
TODO
```

## A Note About Mapping Functions

Mapping functions are meant to be used to quickly discard unwanted events or modify events to remove any data you do not want sent to Datadog. If these functions take too long (say if you are debugging them, or if they are too complex) they will send the **unmodified** version to Datadog. 

These stress tests were used to determine the reasonable values for that wait. We checked the timing for large payloads in debug versions of both iOS
and Android on devices and simulators to determine that delay.
