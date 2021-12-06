#import "DatadogSdkPlugin.h"
#if __has_include(<datadog_sdk/datadog_sdk-Swift.h>)
#import <datadog_sdk/datadog_sdk-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "datadog_sdk-Swift.h"
#endif

@implementation DatadogSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftDatadogSdkPlugin registerWithRegistrar:registrar];
}
@end
