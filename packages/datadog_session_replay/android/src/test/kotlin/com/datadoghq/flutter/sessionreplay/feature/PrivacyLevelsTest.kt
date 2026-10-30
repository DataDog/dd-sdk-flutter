/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */
package com.datadoghq.flutter.sessionreplay.feature

import assertk.assertThat
import assertk.assertions.isEqualTo
import org.junit.jupiter.api.Test

internal class PrivacyLevelsTest {
    @Test
    fun `M map to the native names W fromDartNames`() {
        // When
        val levels = PrivacyLevels.fromDartNames(
            textAndInput = "maskSensitiveInputs",
            image = "maskNone",
            touch = "show"
        )

        // Then
        assertThat(levels).isEqualTo(
            PrivacyLevels(textAndInput = "mask_sensitive_inputs", image = "mask_none", touch = "show")
        )
    }

    @Test
    fun `M map every text and input level W fromDartNames`() {
        assertThat(PrivacyLevels.fromDartNames("maskAllInputs", null, null).textAndInput)
            .isEqualTo("mask_all_inputs")
        assertThat(PrivacyLevels.fromDartNames("maskAll", null, null).textAndInput)
            .isEqualTo("mask_all")
    }

    @Test
    fun `M map maskNonAssetsOnly to its closest native level W fromDartNames`() {
        assertThat(PrivacyLevels.fromDartNames(null, "maskNonAssetsOnly", null).image)
            .isEqualTo("mask_large_only")
    }

    @Test
    fun `M fall back to the most restrictive levels W fromDartNames {missing or unknown}`() {
        assertThat(PrivacyLevels.fromDartNames(null, null, null))
            .isEqualTo(PrivacyLevels.MOST_RESTRICTIVE)
        assertThat(PrivacyLevels.fromDartNames("unknown", "unknown", "unknown"))
            .isEqualTo(PrivacyLevels.MOST_RESTRICTIVE)
    }
}
