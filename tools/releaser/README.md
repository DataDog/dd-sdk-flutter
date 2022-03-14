# Releaser

This is a simple Dart tool for taking all the necessary steps to prep a version
for release. Usage:

```bash
dart ./bin/releaser.dart datadog_flutter_plugin --version 1.0.0
```

It performs the following actions:

* Validates that you are on a releasable branch
* Validates that there are unreleased changes in the CHANGELOG.md for the package
* Creates a branch for the release chore (chore/[package]/release-[version])
* Updates packages/[package]/lib/src/version.dart with the proper version
* Updates packages/[package]/pubspec.yaml with the proper version
* Updates packages/[package]/CHANGELOG.md to modify the unreleased version to
  the specified version
* Validates that `dart pub publish --dry-run` runs without errors.
* Stages and commits these changes to your current branch with the message
  "🚀 Preparing for release of [package] [version]"

Still TODO:
* Opens a PR on your behalf into `develop` (or branch specified with `--branch`)
* Opens a PR on your behalf into `main` (or not, if `--no-main` is supplied)

# License

[Apache License, v2.0](LICENSE)