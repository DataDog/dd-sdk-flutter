# sr_models_generator

Generates the Dart Session Replay data models of `datadog_session_replay`
from the JSON schemas in
[rum-events-format](https://github.com/DataDog/rum-events-format).

> **Status:** work in progress. The command-line entry point exists, but it
> does not generate anything yet.

## Usage

```sh
dart pub get
dart run sr_models_generator --help
```

To work on the generator, see [CONTRIBUTING.md](CONTRIBUTING.md).
