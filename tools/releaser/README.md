# Releaser

This is a simple Dart tool for taking all the necessary steps to prep a version
for release. Usage:

```bash
dart ./bin/releaser.dart datadog_flutter_plugin --version 1.0.0
```

It performs the following actions:

* Validates that you are on a releasable branch
* Validates that there are unreleased changes in the CHANGELOG.md for the
  package
* Creates a branch for the release chore (chore/[package]/release-[version])
* Updates packages/[package]/lib/src/version.dart with the proper version
* Updates packages/[package]/pubspec.yaml with the proper version
* Updates packages/[package]/CHANGELOG.md to modify the unreleased version to
  the specified version
* Stages and commits these changes to your current branch with the message "🚀
  Preparing for release of [package] [version]"
* Creates a release branch (release/[package]/[version])
* Removes "dependency_overrides" from releasing pubspec.yaml
* Commits these changes to the release branch
* Validates that `dart pub publish --dry-run` runs without errors
* Switches to the chore branch
* Bump the version in the library to the next possible release
* Commit these changes to the chore branch to be merged back into develop

Still TODO:
* Opens a PR on your behalf into `develop` (or branch specified with `--branch`)

## Post review

After the release branch is finished building, you can deploy it with:

```bash
dart ./bin/deployer.dart datadog_flutter_plugin
```

which perform the following tasks:

* Checks that you are on a `release` branch and that your working tree is
  clean and up to date with the origin
* Tags main with the package / version number and pushes the changes
* Creates a github release for that tag / version number (marked as a
  pre-release as needed)

## Post CI

Unfortunately, [pub.dev](https://pub.dev/) does not yet support automated
deployment from CIs. (See [this
issue](https://github.com/dart-lang/pub-dev/issues/5388)) So, someone with
upload access will need to run `dart pub publish` for the selected package
manually


## TODO

* Support deploying multiple packages from one run of `releaser`

# License

[Apache License, v2.0](LICENSE)