/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import com.datadog.android.api.InternalLogger
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

internal interface ResourceResolver {
    class ResourceEntry(
        // The resource ID from Flutter
        val resourceKey: Int,
        // The width of the resource
        val width: Int,
        // The height of the resource
        val height: Int,
        // The resource Id which is the MD5 hash of the actual resource.
        // Volatile because [DefaultResourceResolver.resolveResource] reads it on a fast path
        // outside the entry's lock, while the thread that resolves it writes it under that lock.
        @Volatile var resourceId: String? = null,
        // The actual byte array of the resource, which is valid only until
        // the resource's hash is generated, at which point it is set to null.
        // Only ever touched while holding the entry's lock.
        var resourceBytes: ByteBuffer?
    )

    /**
     * Adds a resource with the given Flutter Key to be resolved later.
     *
     * @param engineToken Identifies the engine that issued [resourceKey]. Resource keys are only
     * unique within one engine, so this is what keeps two engines' resources apart — see the note
     * on engine scoping in [DefaultResourceResolver].
     */
    fun addResource(
        engineToken: String,
        resourceKey: Int,
        width: Int,
        height: Int,
        resourceBytes: ByteBuffer
    ): ResourceEntry

    /**
     * Resolves the resource ID (MD5 hash) for the given Flutter resource key.
     * This will process the resource if it has not been processed yet, and therefore
     * should only be called on a background thread.
     *
     * @param engineToken The engine that issued [resourceKey], as passed to [addResource].
     * @param resourceKey The Flutter resource key to resolve.
     * @return The resource ID (MD5 hash) or null if the resource key is unknown or processing failed.
     */
    fun resolveResource(engineToken: String, resourceKey: Int): String?

    /**
     * Forgets every resource belonging to [engineToken], called when that engine detaches.
     */
    fun releaseEngine(engineToken: String)
}

/**
 * ResourceResolver is responsible for processing resources and pairing Flutter's
 * resource keys with their corresponding resource IDs (which are MD5 hashes of the
 * contents of the resource).
 *
 * This uses synchronous, on-demand resource processing. When the processor requests
 * the ID of a resource, it will compress the resource bytes, generate the MD5 hash, then
 * write the resource to ResourcesFeature, which will upload the resources asynchronously.
 */
internal class DefaultResourceResolver(
    val internalLogger: InternalLogger,
    val resourceWriter: ResourceWriter,
    val bitmapHandler: BitmapHandler = DefaultBitmapHandler(internalLogger)
) : ResourceResolver {
    /**
     * Engine token -> that engine's resources by key. Nested rather than keyed on a composite so a
     * lookup allocates nothing — [resolveResource] runs for every resource in every segment — and
     * so [releaseEngine] is a single removal.
     */
    @Suppress("UnsafeThirdPartyFunctionCall") // map is initialized empty
    private val resourcesByEngine:
        MutableMap<String, MutableMap<Int, ResourceResolver.ResourceEntry>> = ConcurrentHashMap()

    @Suppress("UnsafeThirdPartyFunctionCall") // map is initialized empty
    private val knownResources: MutableSet<String> =
        Collections.newSetFromMap(ConcurrentHashMap<String, Boolean>())

    override fun addResource(
        engineToken: String,
        resourceKey: Int,
        width: Int,
        height: Int,
        resourceBytes: ByteBuffer
    ): ResourceResolver.ResourceEntry {
        val entry = ResourceResolver.ResourceEntry(
            resourceKey,
            width,
            height,
            resourceBytes = resourceBytes
        )
        // computeIfAbsent rather than getOrPut: two engines enabling at once would otherwise each
        // build a map and one would be dropped, taking whatever the loser had already added.
        @Suppress("UnsafeThirdPartyFunctionCall") // map is initialized empty
        val engineResources = resourcesByEngine.computeIfAbsent(engineToken) { ConcurrentHashMap() }
        engineResources[resourceKey] = entry
        return entry
    }

    override fun releaseEngine(engineToken: String) {
        resourcesByEngine.remove(engineToken)
    }

    override fun resolveResource(engineToken: String, resourceKey: Int): String? {
        // TODO(RUM-0): Telemetry, unknown resource key
        val resourceEntry = resourcesByEngine[engineToken]?.get(resourceKey) ?: return null

        resourceEntry.resourceId?.let { return it }

        return synchronized(resourceEntry) {
            resourceEntry.resourceId?.let { return@synchronized it }

            val resourceBytes = resourceEntry.resourceBytes ?: return@synchronized null
            val bitmap = bitmapHandler.createBitmap(
                resourceEntry.width,
                resourceEntry.height,
                resourceBytes
            )
            // Discard the original bytes as fast as possible as they are no longer needed
            resourceEntry.resourceBytes = null

            val compressedData = bitmapHandler.compressBitmap(bitmap, IMAGE_QUALITY)
                ?: return@synchronized null

            // Generate the resource ID (MD5 hash) from the bytes
            val resourceId = generateResourceId(compressedData) ?: return@synchronized null
            resourceEntry.resourceId = resourceId

            // `add` reports whether the ID was new, which makes the check-and-claim atomic;
            // `contains` followed by `add` would let two threads both write the same resource.
            if (knownResources.add(resourceId)) {
                resourceWriter.write(identifier = resourceId, resourceData = compressedData)
            }

            resourceId
        }
    }

    private fun generateResourceId(input: ByteArray): String? {
        return try {
            val messageDigest = MessageDigest.getInstance("MD5")
            messageDigest.update(input)

            val hashBytes = messageDigest.digest()

            hashBytes.toHexString()
        } catch (e: NoSuchAlgorithmException) {
            internalLogger.log(
                InternalLogger.Level.ERROR,
                listOf(InternalLogger.Target.MAINTAINER, InternalLogger.Target.TELEMETRY),
                { MD5_HASH_GENERATION_ERROR },
                e
            )
            null
        }
    }

    companion object {
        // This is the default compression for webp when writing to the output stream -
        // a lower quality leads to a lower filesize and worse fidelity image
        private const val IMAGE_QUALITY = 75

        private const val MD5_HASH_GENERATION_ERROR = "Cannot generate MD5 hash."
    }
}

private const val BYTE_MASK = 0xff
private const val HEX_SHIFT = 4
private const val LOWER_NIBBLE_MASK = 0x0f
private const val HEX_CHARS = "0123456789abcdef"

/**
 * Converts a ByteArray to its corresponding hexadecimal String representation.
 *
 * Each byte in the array is converted into two hexadecimal characters.
 * For example, the byte array `[0xA, 0x1F]` will be converted to the string `"0a1f"`.
 *
 * This method avoids performance overhead by using bitwise operations and
 * minimizing object allocations compared to alternatives like `joinToString`.
 *
 * @receiver ByteArray The byte array to be converted.
 * @return A hexadecimal [String] representation of the byte array.
 *
 */
// TODO(RUM-0): See if we can grab this from the Android SDK directly instead of copying it here.
fun ByteArray.toHexString(): String {
    @Suppress("UnsafeThirdPartyFunctionCall") // byte array size is always positive.
    val result = StringBuilder(size * 2)
    for (byte in this) {
        val intVal = byte.toInt() and BYTE_MASK
        result.append(HEX_CHARS[intVal ushr HEX_SHIFT]) // Append first half of byte
        result.append(HEX_CHARS[intVal and LOWER_NIBBLE_MASK]) // Append second half of byte
    }
    return result.toString()
}
