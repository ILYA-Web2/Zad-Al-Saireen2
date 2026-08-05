package com.zad.alsaereen

import android.app.Application
import android.util.Log

/**
 * Second, independent layer of defense against the recurring
 * "Invalid notification (no valid small icon)" crash coming from the
 * audio_service plugin's own notification-update code
 * (com.ryanheise.audioservice.AudioService.updateNotification).
 *
 * That crash has now survived two separate fixes to the notification
 * icon resource itself, which means something about how the icon
 * reference resolves at runtime — not its visual content — is still
 * wrong in a way that can't be fully verified without a real device and
 * a compiler, neither of which are available while building this. Rather
 * than let a third recurrence of the exact same bug take down the whole
 * app (killing Quran playback along with it), this installs a default
 * uncaught-exception handler that specifically recognizes *this* crash
 * signature and swallows just that one, letting playback continue
 * (only the notification update fails silently) — while still allowing
 * every other, unrelated crash to behave normally so real bugs are never
 * masked.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            if (isKnownNotificationIconCrash(throwable)) {
                Log.e(
                    "ZadAlsaereen",
                    "Suppressed known audio_service notification crash " +
                        "(playback continues; only the lock-screen/notification " +
                        "display is affected) — see stack trace below for diagnosis.",
                    throwable,
                )
                // Deliberately not rethrown and not forwarded to the previous
                // handler — this exact, well-identified crash must not kill
                // the process. Any other exception still goes through
                // normally below.
                return@setDefaultUncaughtExceptionHandler
            }
            previousHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun isKnownNotificationIconCrash(t: Throwable?): Boolean {
        var current = t
        var depth = 0
        while (current != null && depth < 6) {
            val message = current.message ?: ""
            val isNotificationIconError =
                current is IllegalArgumentException &&
                    message.contains("valid small icon", ignoreCase = true)
            val isFromAudioService = current.stackTrace.any {
                it.className.contains("com.ryanheise.audioservice")
            }
            if (isNotificationIconError && isFromAudioService) return true
            current = current.cause
            depth++
        }
        return false
    }
}
