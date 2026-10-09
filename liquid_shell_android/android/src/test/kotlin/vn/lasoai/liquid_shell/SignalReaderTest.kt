package vn.lasoai.liquid_shell

import kotlin.test.Test
import kotlin.test.assertEquals

class SignalReaderTest {
    private fun raw(
        api: Int,
        animatorDurationScale: Float? = 1f,
        contrast: Float? = 0f,
        highTextContrast: Int? = 0,
        powerSaveMode: Boolean? = false,
        crossWindowBlurEnabled: Boolean? = true,
    ) = RawSignals(
        animatorDurationScale = animatorDurationScale,
        contrast = contrast,
        highTextContrast = highTextContrast,
        powerSaveMode = powerSaveMode,
        crossWindowBlurEnabled = crossWindowBlurEnabled,
        apiLevel = api,
    )

    private fun payload(
        reduceTransparency: Boolean = false,
        powerSave: Boolean = false,
        blurDisabled: Boolean = false,
    ) = mapOf(
        "reduceTransparency" to reduceTransparency,
        "powerSave" to powerSave,
        "blurDisabled" to blurDisabled,
    )

    @Test
    fun defaultSettingsAreAllOffOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(payload(), SignalReader.toPayload(raw(api)), "API $api")
        }
    }

    @Test
    fun animatorScaleZeroReducesTransparencyOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(
                payload(reduceTransparency = true),
                SignalReader.toPayload(raw(api, animatorDurationScale = 0f)),
                "API $api",
            )
        }
    }

    @Test
    fun highTextContrastReducesTransparencyOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(
                payload(reduceTransparency = true),
                SignalReader.toPayload(raw(api, highTextContrast = 1)),
                "API $api",
            )
        }
    }

    @Test
    fun contrastAboveZeroCountsFromApi34Only() {
        assertEquals(payload(), SignalReader.toPayload(raw(30, contrast = 0.5f)))
        assertEquals(payload(), SignalReader.toPayload(raw(31, contrast = 0.5f)))
        assertEquals(
            payload(reduceTransparency = true),
            SignalReader.toPayload(raw(34, contrast = 0.5f)),
        )
        assertEquals(
            payload(reduceTransparency = true),
            SignalReader.toPayload(raw(36, contrast = 1f)),
        )
        assertEquals(payload(), SignalReader.toPayload(raw(36, contrast = -0.5f)))
    }

    @Test
    fun powerSaveOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(
                payload(powerSave = true),
                SignalReader.toPayload(raw(api, powerSaveMode = true)),
                "API $api",
            )
        }
    }

    @Test
    fun blurDisabledCountsFromApi31Only() {
        assertEquals(
            payload(),
            SignalReader.toPayload(raw(30, crossWindowBlurEnabled = false)),
        )
        for (api in listOf(31, 34, 36)) {
            assertEquals(
                payload(blurDisabled = true),
                SignalReader.toPayload(raw(api, crossWindowBlurEnabled = false)),
                "API $api",
            )
        }
    }

    @Test
    fun failedReadsAreOff() {
        val failed = RawSignals(
            animatorDurationScale = null,
            contrast = null,
            highTextContrast = null,
            powerSaveMode = null,
            crossWindowBlurEnabled = null,
            apiLevel = 36,
        )
        assertEquals(payload(), SignalReader.toPayload(failed))
    }
}
