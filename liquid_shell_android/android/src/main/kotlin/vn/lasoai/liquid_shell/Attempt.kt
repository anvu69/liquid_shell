package vn.lasoai.liquid_shell

import android.provider.Settings

/**
 * Runs [block]; a SecurityException, any other runtime failure, or a
 * LinkageError → null.
 *
 * LinkageError covers a platform method or class missing on the device
 * (NoSuchMethodError, NoClassDefFoundError), e.g. an API newer than the
 * device that slipped past an SDK_INT guard. Other Errors, such as
 * OutOfMemoryError, are not caught.
 */
internal inline fun <T> attempt(block: () -> T): T? =
    try {
        block()
    } catch (e: SecurityException) {
        null
    } catch (e: Settings.SettingNotFoundException) {
        null
    } catch (e: RuntimeException) {
        null
    } catch (e: LinkageError) {
        null
    }

/**
 * Hands [item] to [keep] first, then registers it with every one of
 * [registrations] as one [attempt]. Kept first, a registration that throws
 * part-way still leaves the remove path able to undo the earlier ones.
 */
internal fun <T> registerAll(item: T, keep: (T) -> Unit, vararg registrations: (T) -> Unit) {
    keep(item)
    attempt { registrations.forEach { it(item) } }
}
