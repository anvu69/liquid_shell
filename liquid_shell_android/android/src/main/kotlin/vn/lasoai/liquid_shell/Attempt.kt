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
