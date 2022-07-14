# Overview

> *NOTICE* These instructions are for early adopters looking to symbolicate iOS and Android native crashes. These instructions and temporary and will change as Datadog adds more support for Flutter error tracking in the future.
> 
> Note that Dart stack traces for Flutter applications using the `--split-debug-info` and `--obfuscate` flags are currently not supported.
>

Enable Crash Reporting and Error Tracking to get comprehensive crash reports and error trends with Real User Monitoring. 

Your crash reports appear in [**Error Tracking**][8].

## Setup

If you have not set up the Fluter SDK yet, the the instructions in the [documentation][2].

### Add Crash Reporting

Update your initialization configuration to set `nativeCrashReportEnabled` to `true`

```dart
final configuration = DdSdkConfiguration(
  clientToken: 'DD_CLIENT_TOKEN'
  env: 'DD_ENV'
  site: DatadogSite.us1,
  trackingConsent: TrackingConsent.granted,
  nativeCrashReportEnabled: true, // Set this flag
  loggingConfiguration: LoggingConfiguration(),
  rumConfiguration: 'DD_APP_ID',
);
DatadogSdk.instance.initialize(configuration);
```

This will enable native crash reporting for iOS and Android.

## Manually uploading iOS dSYMs to Datadog

Crash reports on iOS are collected in a raw format and mostly contain memory addresses. To map these addresses into legible symbol information, Datadog requires .dSYM files, which are generated in your application's build process.

Every iOS application produces .dSYM files for each application module. These files minimize an application's binary size and enable faster download speed. Each application version contains a set of .dSYM files. 

### Upload your dSYM file

By uploading your .dSYM file to Datadog, you gain access to the file path and line number of each frame in an error's related stack trace.

Once your application crashes and you restart the application, the iOS SDK uploads a crash report to Datadog. 

You can use the command line tool [@datadog/datadog-ci][5] to upload your dSYM file. By default, Flutter will put these dSYMs in `./build/ios/archive/Runner.xcarchive/dSYMs`. After building your application with `flutter build ipa`, run the following shell command to upload your dSYMs to Datadog:

```sh
export DATADOG_API_KEY="<API KEY>"

npx @datadog/datadog-ci dsyms upload ./build/ios/archive/Runner.xcarchive/dSYMs
```

**Note**: To configure the tool using the EU endpoint, set the `DATADOG_SITE` environment variable to `datadoghq.eu`. To override the full URL for the intake endpoint, define the `DATADOG_DSYM_INTAKE_URL` environment variable. 


## Manually uploading Android Proguard Mapping Files to Datadog

If you are using the `--obfuscate` parameter on Android builds, you will need to upload your Proguard mapping file to Datadog in order to deobfuscate your stack traces. The [Gradle Plugin for datadog Android SDK][1] supports uploading your mapping file directly to Datadog.

You can configure the plugin by adding the following to you `./android/app/build.gradle` file:

```
plugins {
    id("com.datadoghq.dd-sdk-android-gradle-plugin") version "x.y.z"
}
```

In addition, if you need to configure the upload, you can add the following block to the end of you `./android/app/build.gradle` file:

```
datadog {
    // versionName is optional, by default it is read from your Android plugin configuration's version name,
    // which is set from you pubspec.yaml at build time
    versionName = "1.3.0" 
    serviceName = "my-service" // Optional, by default it is read from your Android plugin configuration's package name
    site = "US" // Optional, can be "US", "EU" or "GOV". Default is "US"
}
```

After building your Flutter application with `flutter build apk` or `flutter build appbundle`, use the following shell commands to upload your Mapping file to Datadog:

```sh
export DD_API_KEY="<API KEY>"

cd android
./gradlew uploadMappingRelease
```

[1]: https://github.com/DataDog/dd-sdk-android-gradle-plugin
[2]: https://docs.datadoghq.com/real_user_monitoring/flutter/#setup
[5]: https://www.npmjs.com/package/@datadog/datadog-ci
[8]: https://app.datadoghq.com/rum/error-tracking
