// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Forward declaration of Flutter's private FlutterBinaryMessengerRelay class.
// Gives Swift compile-time access to .parent without linking private Flutter headers.
// If Flutter renames this class or property, this file must be updated accordingly.
#import <Flutter/Flutter.h>

@interface FlutterBinaryMessengerRelay : NSObject <FlutterBinaryMessenger>
@property(nonatomic, weak) NSObject<FlutterBinaryMessenger> *parent;
@end
