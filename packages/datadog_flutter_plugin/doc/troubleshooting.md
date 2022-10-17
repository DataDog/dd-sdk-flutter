# Flutter Troubleshooting

## Cocoapods issues

If you have trouble building your iOS application after adding the Datadog SDK because of errors being thrown by Cocoapods, check which error you are getting. The most common error is an issue getting the most up-to-date native library from Cocoapods, which can be solved by running the following in your `ios` directory:

```bash
pod install --repo-update
```

Another common error is an issue loading the FFI library on Apple Silicon Macs.  If you see an error similar to the following:

```bash
LoadError - dlsym(0x7fbbeb6837d0, Init_ffi_c): symbol not found - /Library/Ruby/Gems/2.6.0/gems/ffi-1.13.1/lib/ffi_c.bundle
/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/ruby/2.6.0/rubygems/core_ext/kernel_require.rb:54:in `require'
/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/ruby/2.6.0/rubygems/core_ext/kernel_require.rb:54:in `require'
/Library/Ruby/Gems/2.6.0/gems/ffi-1.13.1/lib/ffi.rb:6:in `rescue in <top (required)>'
/Library/Ruby/Gems/2.6.0/gems/ffi-1.13.1/lib/ffi.rb:3:in `<top (required)>'
```

Follow the instructions in the [Flutter documentation][1] for working with Flutter on Apple Silicon.

## Set sdkVerbosity

If you're able to run your app, but you are not seeing the data you expect on the Datadog site, try adding the following to your code before calling `DatadogSdk.initialize`:

```dart
DatadogSdk.instance.sdkVerbosity = Verbosity.verbose;
```

This causes the SDK to output additional information about what it's doing and what errors it's encountering, which may help you and Datadog Support narrow down your issue.

## Issues with Automatic Resource Tracking and Distributed Tracing

The [Datadog Tracking Http Client][2] package  works with most common Flutter networking packages that rely on `dart:io`, including [`http`][3] and [`Dio`][4]. This package does not work with the newly announced "native" http clients, [`cupertino_http`][6] and [`cronet_http`][5]

If you are seeing Resources in your RUM Sessions, then the Tracking Http Client is working, but other steps may be required to use Distributed Tracing.

Be default, the Datadog RUM Flutter SDK samples distributed traces at only 20% of resource requests. While determining if there is an issue with your setup, you should set this value to 100% of traces by modifying your initialization with the following lines:
```dart
final configuration = DdSdkConfiguration(
   //
   rumConfiguration: RumConfiguration(
    applicationId: '<RUM_APPLICATION_ID>',
    tracingSamplingRate: 100.0
   ),
);
```

If you are still having issues, check that your `firstPartyHosts` property is set correctly. These should be hosts only, without schemas or paths, and they do not support regular expressions or wildcards. For example:
    
    ✅ Good - 'example.com', 'api.example.com', 'us1.api.sample.com'
    ❌ Bad - 'https://example.com', '*.example.com', 'us1.sample.com/api/*', 'api.sample.com/api'

## Further Reading

{{< partial name="whats-next/whats-next.html" >}}

[1]: https://github.com/flutter/flutter/wiki/Developing-with-Flutter-on-Apple-Silicon
[2]: https://pub.dev/packages/datadog_tracking_http_client
[3]: https://pub.dev/packages/http
[4]: https://pub.dev/packages/dio
[5]: https://pub.dev/packages/cronet_http
[6]: https://pub.dev/packages/cupertino_http