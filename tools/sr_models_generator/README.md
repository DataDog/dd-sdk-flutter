# sr_models_generator

Generates the Dart Session Replay data models of `datadog_session_replay`
from the JSON schemas in
[rum-events-format](https://github.com/DataDog/rum-events-format), at the
commit pinned in [`sr_models_generator.yaml`](sr_models_generator.yaml).

## Usage

From the repository root:

```sh
melos run generate:sr_models         # generate the models
melos run generate:sr_models:check   # fail if they are not up to date
melos run generate:sr_models:update  # pin the latest rum-events-format master
```

Or from this directory:

```sh
dart run sr_models_generator                # generate the models, without their JSON code
dart run sr_models_generator --check        # fail if they are not up to date, without their JSON code
dart run sr_models_generator --ref master   # pin another rum-events-format commit
dart run sr_models_generator --help
```

To work on the generator, see [CONTRIBUTING.md](CONTRIBUTING.md).
