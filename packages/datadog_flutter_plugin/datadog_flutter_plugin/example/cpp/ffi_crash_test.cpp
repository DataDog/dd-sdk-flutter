// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

#include <stdint.h>

void internal_function(int32_t attribute, int32_t* assignee) {
    *assignee = attribute;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int32_t ffi_callback_test(int32_t attribute, int32_t (*callback)(int32_t attribute)) {
    attribute *= 5;
    int32_t value = callback(attribute);

    return value;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void ffi_crash_test(int32_t attribute) {
    int32_t* assignee = nullptr;

    internal_function(attribute, assignee);
}