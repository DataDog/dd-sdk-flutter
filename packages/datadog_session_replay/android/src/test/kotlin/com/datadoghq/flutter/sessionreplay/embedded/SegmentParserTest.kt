/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.embedded

import assertk.assertThat
import assertk.assertions.containsExactly
import assertk.assertions.hasSize
import assertk.assertions.isEqualTo
import assertk.assertions.isInstanceOf
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import kotlin.test.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

/**
 * Tests unpacking a Dart-produced segment for the native embedded-content API.
 *
 * This has no iOS counterpart: iOS hands the records over already decoded, while Gson collapses
 * every JSON number into one `Number` type and so needs the integral ones recovered by hand.
 */
internal class SegmentParserTest {
    @Test
    fun `M return the records and view id W parse`() {
        // Given
        val segment = """
            {
              "records": [{"type": 1}, {"type": 2}],
              "viewID": "view-id"
            }
        """.trimIndent()

        // When
        val parsed = SegmentParser.parse(segment)

        // Then
        assertThat(parsed).isNotNull()
        assertThat(parsed!!.viewId).isEqualTo("view-id")
        assertThat(parsed.records.map { it["type"] }).containsExactly(1L, 2L)
    }

    @Test
    fun `M keep integral numbers as Long W parse`() {
        // Given - a record timestamp, which is milliseconds since the epoch
        val timestamp = 1_757_000_000_123L
        val segment = """{"records":[{"timestamp":$timestamp}],"viewID":"view-id"}"""

        // When
        val parsed = SegmentParser.parse(segment)

        // Then - read as a Double this would re-serialize in exponent form and lose precision past
        // 2^53; the player reads record timestamps as integers
        val value = parsed?.records?.first()?.get("timestamp")
        assertThat(value).isNotNull().isInstanceOf<Long>()
        assertThat(value).isEqualTo(timestamp)
    }

    @Test
    fun `M keep fractional numbers as Double W parse`() {
        // Given - wireframe geometry, which is not integral
        val segment = """{"records":[{"x":12.5,"y":1e3}],"viewID":"view-id"}"""

        // When
        val record = SegmentParser.parse(segment)?.records?.first()

        // Then
        assertThat(record?.get("x")).isEqualTo(12.5)
        assertThat(record?.get("y")).isEqualTo(1000.0)
    }

    @Test
    fun `M preserve nested structure W parse`() {
        // Given - records are deeply nested: a snapshot wraps a wireframe list
        val segment = """
            {
              "records": [{
                "data": {"wireframes": [{"id": 7, "text": "hi", "visible": true}]}
              }],
              "viewID": "view-id"
            }
        """.trimIndent()

        // When
        val record = SegmentParser.parse(segment)?.records?.first()

        // Then
        @Suppress("UNCHECKED_CAST")
        val wireframes = (record?.get("data") as? Map<String, Any?>)
            ?.get("wireframes") as? List<Map<String, Any?>>
        assertThat(wireframes).isNotNull()
        assertThat(wireframes!!).hasSize(1)
        assertThat(wireframes[0]["id"]).isEqualTo(7L)
        assertThat(wireframes[0]["text"]).isEqualTo("hi")
        assertThat(wireframes[0]["visible"]).isEqualTo(true)
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            // Not JSON at all.
            "not json",
            // Valid JSON, but not an object.
            "[]",
            // No viewID to attribute the records to.
            """{"records":[{"type":1}]}""",
            // viewID of the wrong type.
            """{"records":[{"type":1}],"viewID":42}""",
            // Nothing to send.
            """{"records":[],"viewID":"view-id"}""",
            """{"viewID":"view-id"}""",
            // records of the wrong type.
            """{"records":{"type":1},"viewID":"view-id"}"""
        ]
    )
    fun `M return null W parse a segment that could not be delivered`(segment: String) {
        // Then - the native receiver would drop these anyway, and returning null keeps the caller
        // from treating a dud segment as delivered
        assertThat(SegmentParser.parse(segment)).isNull()
    }
}
