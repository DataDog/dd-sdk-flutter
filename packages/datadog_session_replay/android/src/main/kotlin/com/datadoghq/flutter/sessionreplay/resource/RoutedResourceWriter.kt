/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

/**
 * Hands a resource to the native Session Replay, returning `false` when it cannot take it.
 *
 * Mirrors `_SessionReplayInternalProxy.addEmbeddedContentResource`, minus the core, which the
 * manager supplies.
 */
internal typealias EmbeddedResourceSink = (
    identifier: String,
    resourceData: ByteArray,
    mimeType: String
) -> Boolean

/**
 * Sends resources to the native Session Replay when Flutter is embedded, and to the Flutter
 * resources feature otherwise.
 *
 * Embedded resources have to go through the native recording rather than be uploaded from here:
 * both sides hash resources by content, so routing them together is what lets a resource shared
 * between native and Flutter content be uploaded once, and it puts Flutter resources behind the
 * native module's persistent known-resources store, which survives app launches.
 *
 * [sendToNative] answers whether it took the resource — rather than being asked up front — because
 * the embedding state can change under us: an engine writes resources before the host has
 * registered its view, and a pure-Flutter app has no native module at all. Anything it declines
 * falls through to [standaloneWriter], so a resource is never dropped.
 */
internal class RoutedResourceWriter(
    private val standaloneWriter: ResourceWriter,
    private val sendToNative: EmbeddedResourceSink
) : ResourceWriter {
    override fun write(identifier: String, resourceData: ByteArray) {
        if (sendToNative(identifier, resourceData, MIME_TYPE)) {
            return
        }
        standaloneWriter.write(identifier, resourceData)
    }

    companion object {
        /**
         * The images are actually WEBP — see `BitmapHandler.getImageCompressionFormat` — but the
         * intake is told `image/png`, matching what [ResourceRequestBodyFactory] declares on the
         * standalone path and what the native SDK sends for its own resources.
         */
        internal const val MIME_TYPE = "image/png"
    }
}
