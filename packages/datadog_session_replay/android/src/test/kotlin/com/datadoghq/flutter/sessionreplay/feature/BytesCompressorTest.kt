/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import assertk.assertThat
import assertk.assertions.isEqualTo
import com.datadoghq.flutter.sessionreplay.forge.SRForgeConfigurator
import com.datadoghq.flutter.sessionreplay.models.EnrichedRecord
import fr.xgouchet.elmyr.annotation.Forgery
import fr.xgouchet.elmyr.junit5.ForgeConfiguration
import fr.xgouchet.elmyr.junit5.ForgeExtension
import java.util.zip.Inflater
import org.junit.jupiter.api.RepeatedTest
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.api.extension.Extensions

@Extensions(ExtendWith(ForgeExtension::class))
@ForgeConfiguration(SRForgeConfigurator::class)
internal class BytesCompressorTest {
    @RepeatedTest(20)
    fun `M compress the provided bytearray W compressBytes`(
        @Forgery fakeEnrichedRecord: EnrichedRecord
    ) {
        // Given
        val fakeData = fakeEnrichedRecord.toJson()
        val fakeDataAsByteArray = fakeData.toByteArray()

        // When
        val compressed = BytesCompressor.compressBytes(fakeDataAsByteArray)

        // Then
        // Decompress the bytes by removing the last fake checksum
        val decompressor = Inflater()
        decompressor.setInput(
            compressed.sliceArray(
                0..compressed.size -
                    BytesCompressor.CHECKSUM_FLAG_SIZE_IN_BYTES
            )
        )
        val result = ByteArray(fakeDataAsByteArray.size)
        val resultLength = decompressor.inflate(result)
        decompressor.end()
        val outputString = String(result, 0, resultLength)
        assertThat(fakeData).isEqualTo(outputString)
    }
}
