package vn.lasoai.liquid_shell

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class AttemptTest {
    @Test
    fun aReadThatSucceedsPassesItsValueThrough() {
        assertEquals(42, attempt { 42 })
    }

    @Test
    fun runtimeAndSecurityFailuresBecomeNull() {
        assertNull(attempt<Int> { throw IllegalStateException("x") })
        assertNull(attempt<Int> { throw SecurityException("x") })
    }

    // A platform method missing on an old device (minSdk lowered, or an
    // OEM build without it) throws a LinkageError, not an exception.
    @Test
    fun aMissingPlatformMethodOrClassBecomesNull() {
        assertNull(attempt<Boolean> { throw NoSuchMethodError("hasSystemFeature") })
        assertNull(attempt<Boolean> { throw NoClassDefFoundError("UiModeManager") })
    }
}
