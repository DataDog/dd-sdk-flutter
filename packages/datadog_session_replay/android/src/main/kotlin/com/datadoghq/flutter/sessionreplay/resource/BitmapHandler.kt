/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import android.graphics.Bitmap
import android.os.Build
import com.datadog.android.api.InternalLogger
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

/**
 * Handles bitmap operations such as encoding, decoding, and processing.
 */
internal interface BitmapHandler {
    fun createBitmap(width: Int, height: Int, buffer: ByteBuffer): Bitmap
    fun compressBitmap(bitmap: Bitmap, quality: Int): ByteArray?
}

// This class has no unit tests because `Bitmap.createBitmap` cannot be mocked or forged.
internal class DefaultBitmapHandler(
    val internalLogger: InternalLogger
) : BitmapHandler {
    override fun createBitmap(width: Int, height: Int, buffer: ByteBuffer): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)

        // Despite what the above `Bitmap.Config` says, the actual pixel format is RGBA_8888
        // with premultiplied alpha, which is the exact format that Flutter uses.
        bitmap.copyPixelsFromBuffer(buffer)
        return bitmap
    }

    override fun compressBitmap(bitmap: Bitmap, quality: Int): ByteArray? {
        val byteOutputStream = ByteArrayOutputStream(bitmap.allocationByteCount)
        val imageFormat = getImageCompressionFormat()

        @Suppress("SwallowedException")
        try {
            // stream is not null and image quality is between 0 and 100
            @Suppress("UnsafeThirdPartyFunctionCall")
            bitmap.compress(imageFormat, quality, byteOutputStream)
        } catch (e: IllegalStateException) {
            // probably if the bitmap was recycled while we were working on it
            internalLogger.log(
                InternalLogger.Level.ERROR,
                listOf(InternalLogger.Target.MAINTAINER, InternalLogger.Target.TELEMETRY),
                { IMAGE_COMPRESSION_ERROR },
                e
            )

            return null
        }

        return byteOutputStream.toByteArray()
    }

    private fun getImageCompressionFormat(): Bitmap.CompressFormat =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            @Suppress("DEPRECATION")
            Bitmap.CompressFormat.WEBP
        }

    companion object {
        private const val IMAGE_COMPRESSION_ERROR = "Error while compressing the image."
    }
}
