/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

internal data class PrivacyLevels(
    val textAndInput: String,
    val image: String,
    val touch: String
) {
    companion object {
        val MOST_RESTRICTIVE = PrivacyLevels(textAndInput = "mask_all", image = "mask_all", touch = "hide")

        fun fromDartNames(textAndInput: String?, image: String?, touch: String?) = PrivacyLevels(
            textAndInput = when (textAndInput) {
                "maskSensitiveInputs" -> "mask_sensitive_inputs"
                "maskAllInputs" -> "mask_all_inputs"
                else -> MOST_RESTRICTIVE.textAndInput
            },
            image = when (image) {
                "maskNone" -> "mask_none"
                else -> MOST_RESTRICTIVE.image
            },
            touch = when (touch) {
                "show" -> "show"
                else -> MOST_RESTRICTIVE.touch
            }
        )
    }
}
