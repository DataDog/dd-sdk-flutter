/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.context.UserInfo
import java.util.concurrent.Callable
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executor
import java.util.concurrent.FutureTask
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicReference

/**
 * Reads the Datadog context with a bounded wait, for callers on the Flutter UI thread.
 *
 * The SDK's context read waits for the SDK's single context thread, which also processes
 * RUM events in order. When that thread is backed up, an unbounded wait from the UI thread
 * can exceed the ANR threshold. This reader runs the read on a background thread and waits
 * at most [timeoutMs] for it.
 *
 * A caller gets the full context only from a read it started and that finished in time.
 * Otherwise it gets the last context read, without user and account information, or `null`
 * if no read has finished yet. User and account changes are applied on the same context
 * thread, so an earlier context may still hold a user or account that has since been
 * cleared.
 *
 * Only one read runs at a time. A caller that arrives while a read is in progress gets the
 * fallback without waiting.
 */
internal class CoreContextReader(
    private val timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    private val executor: Executor = createReaderExecutor(),
    private val withoutIdentity: (DatadogContext) -> DatadogContext = ::removeUserAndAccount,
    private val readContext: () -> DatadogContext?
) {
    private val inFlightRead = AtomicReference<FutureTask<DatadogContext?>?>(null)

    @Volatile
    private var lastKnownContext: DatadogContext? = null

    // Any failure to get a fresh context falls back to the last known one.
    @Suppress("SwallowedException")
    fun read(): DatadogContext? {
        val newRead = startReadIfIdle() ?: return fallbackContext()
        return try {
            newRead.get(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: TimeoutException) {
            fallbackContext()
        } catch (e: ExecutionException) {
            fallbackContext()
        } catch (e: CancellationException) {
            fallbackContext()
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            fallbackContext()
        }
    }

    private fun fallbackContext(): DatadogContext? = lastKnownContext?.let(withoutIdentity)

    // Returns the started read, or `null` if a read is already in progress or was rejected.
    @Suppress("SwallowedException")
    private fun startReadIfIdle(): FutureTask<DatadogContext?>? {
        val existing = inFlightRead.get()
        if (existing != null && !existing.isDone) return null

        val newRead = FutureTask(
            Callable {
                readContext().also { lastKnownContext = it }
            }
        )
        if (!inFlightRead.compareAndSet(existing, newRead)) return null
        return try {
            executor.execute(newRead)
            newRead
        } catch (e: RejectedExecutionException) {
            inFlightRead.compareAndSet(newRead, null)
            null
        }
    }

    companion object {
        internal const val DEFAULT_TIMEOUT_MS = 100L
        private const val THREAD_NAME = "datadog-flutter-context-reader"
        private const val KEEP_ALIVE_SECONDS = 30L

        internal fun removeUserAndAccount(context: DatadogContext): DatadogContext =
            context.copy(userInfo = UserInfo(), accountInfo = null)

        private fun createReaderExecutor(): Executor = ThreadPoolExecutor(
            1,
            1,
            KEEP_ALIVE_SECONDS,
            TimeUnit.SECONDS,
            LinkedBlockingQueue()
        ) { runnable ->
            Thread(runnable, THREAD_NAME).apply { isDaemon = true }
        }.apply { allowCoreThreadTimeOut(true) }
    }
}
