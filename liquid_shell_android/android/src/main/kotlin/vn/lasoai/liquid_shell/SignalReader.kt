package vn.lasoai.liquid_shell

/**
 * Raw values read from the system. A field is null when its read failed or
 * the API does not exist on this device.
 */
internal data class RawSignals(
    /** Settings.Global.ANIMATOR_DURATION_SCALE. */
    val animatorDurationScale: Float?,
    /** UiModeManager.getContrast(), API 34+. */
    val contrast: Float?,
    /** Settings.Secure "high_text_contrast_enabled". */
    val highTextContrast: Int?,
    /** PowerManager.isPowerSaveMode. */
    val powerSaveMode: Boolean?,
    /** WindowManager.isCrossWindowBlurEnabled, API 31+. */
    val crossWindowBlurEnabled: Boolean?,
    /** Build.VERSION.SDK_INT. */
    val apiLevel: Int,
)

/** Pure mapping from raw system values to the channel payload (spec §6.1). */
internal object SignalReader {
    fun toPayload(raw: RawSignals): Map<String, Boolean> = mapOf(
        "reduceTransparency" to reduceTransparency(raw),
        "powerSave" to (raw.powerSaveMode == true),
        "blurDisabled" to (raw.apiLevel >= 31 && raw.crossWindowBlurEnabled == false),
    )

    private fun reduceTransparency(raw: RawSignals): Boolean =
        raw.animatorDurationScale == 0f ||
            (raw.apiLevel >= 34 && (raw.contrast ?: 0f) > 0f) ||
            raw.highTextContrast == 1
}
