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

## Further Reading

{{< partial name="whats-next/whats-next.html" >}}

[1]: https://github.com/flutter/flutter/wiki/Developing-with-Flutter-on-Apple-Silicon