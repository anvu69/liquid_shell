package vn.lasoai.liquid_shell

import kotlin.test.Test
import kotlin.test.assertEquals

class RegisterAllTest {
    @Test
    fun everyRegistrationRunsAndTheItemIsKept() {
        val registered = mutableListOf<String>()
        var kept: String? = null
        registerAll(
            "observer",
            { kept = it },
            { registered += "global:$it" },
            { registered += "secure:$it" },
        )
        assertEquals(listOf("global:observer", "secure:observer"), registered)
        assertEquals("observer", kept)
    }

    // VK-702 M3: the first registration went through, the second threw.
    // The item must still be kept, or the remove path cannot undo the first.
    @Test
    fun theItemIsKeptWhenALaterRegistrationFails() {
        val registered = mutableListOf<String>()
        var kept: String? = null
        registerAll(
            "observer",
            { kept = it },
            { registered += "global:$it" },
            { throw SecurityException("secure settings") },
        )
        assertEquals(listOf("global:observer"), registered)
        assertEquals("observer", kept, "kept, so the remove path can undo the first registration")
    }
}
