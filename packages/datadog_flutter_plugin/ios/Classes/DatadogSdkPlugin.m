// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

#import "DatadogSdkPlugin.h"
#if __has_include(<datadog_flutter_plugin/datadog_flutter_plugin-Swift.h>)
#import <datadog_flutter_plugin/datadog_flutter_plugin-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "datadog_flutter_plugin-Swift.h"
#endif

@implementation DatadogSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftDatadogSdkPlugin registerWithRegistrar:registrar];
}
@end
