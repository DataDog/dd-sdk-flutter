## Overview

Enable Crash Reporting and Error Tracking to get comprehensive crash reports and error trends with Real User Monitoring. 

<div class="alert alert-info">
Dart stack traces on Flutter applications with `--split-debug-info` and `--obfuscate` flags are not supported.
</div>

Your crash reports appear in [**Error Tracking**][1].

## Setup

If you have not set up the Datadog Flutter SDK for RUM yet, follow the [in-app setup instructions][2] or see the [Flutter setup documentation][3].

### Add Crash Reporting

Update your initialization snippet to enable native crash reporting for iOS and Android by setting `nativeCrashReportEnabled` to `true`.

For example:

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

## Manually upload iOS dSYMs to Datadog

Crash reports on iOS are collected in a raw format and mostly contain memory addresses. To map these addresses into legible symbol information, Datadog requires .dSYM files, which are generated in your application's build process.

### Find your dYSM file

Every iOS application produces .dSYM files for each application module. These files minimize an application's binary size and enable faster download speed. Each application version contains a set of .dSYM files. 

### Upload your dSYM file

By uploading your .dSYM file to Datadog, you gain access to the file path and line number of each frame in an error's related stack trace.

Once your application crashes and you restart the application, the Datadog iOS SDK uploads a crash report to Datadog. 

You can use the [@datadog/datadog-ci][4] command line tool to upload your dSYM file. By default, Flutter adds these dSYM files in `./build/ios/archive/Runner.xcarchive/dSYMs`. After building your application with `flutter build ipa`, run the following shell command to upload your dSYMs to Datadog:

```sh
export DATADOG_API_KEY="<API KEY>"

npx @datadog/datadog-ci dsyms upload ./build/ios/archive/Runner.xcarchive/dSYMs
```

To configure the tool using an EU endpoint, set the `DATADOG_SITE` environment variable to `datadoghq.eu`. To override the full URL for the intake endpoint, define the `DATADOG_DSYM_INTAKE_URL` environment variable. 

## Manually upload Android ProGuard mapping files to Datadog

If you are using the `--obfuscate` parameter on Android builds, and you wish to deobfuscate your traces, you need to upload your ProGuard mapping file to Datadog. The [Datadog Android SDK Gradle plugin][5] supports uploading your mapping file directly to Datadog.

You can configure the plugin by adding the following lines to your `./android/app/build.gradle` file:

```
plugins {
    id("com.datadoghq.dd-sdk-android-gradle-plugin") version "x.y.z"
}
```

Additionally, if you need to configure the upload, add the following to the end of your `./android/app/build.gradle` file:

```
datadog {
    // versionName is optional, by default it is read from your Android plugin configuration's version name,
    // which is set from you pubspec.yaml at build time
    versionName = "1.3.0" 
    serviceName = "my-service" // Optional, by default it is read from your Android plugin configuration's package name
    site = "US" // Optional, can be "US", "EU" or "GOV". Default is "US"
}
```

After building your Flutter application with `flutter build apk` or `flutter build appbundle`, use the following shell commands to upload your mapping file to Datadog:

```sh
export DD_API_KEY="<API KEY>"

cd android
./gradlew uploadMappingRelease
```

## Further reading

{{< partial name="whats-next/whats-next.html" >}}

[1]: https://app.datadoghq.com/rum/error-tracking
[2]: https://app.datadoghq.com/rum/application/create
[3]: https://docs.datadoghq.com/real_user_monitoring/flutter/#setup
[4]: https://www.npmjs.com/package/@datadog/datadog-ci
[5]: https://github.com/DataDog/dd-sdk-android-gradle-plugin