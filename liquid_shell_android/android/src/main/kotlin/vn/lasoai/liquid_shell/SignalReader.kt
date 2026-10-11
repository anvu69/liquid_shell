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
    /** ActivityManager.isLowRamDevice. */
    val isLowRamDevice: Boolean? = null,
    /** ActivityManager.MemoryInfo.totalMem, bytes. */
    val totalMemBytes: Long? = null,
    /** FEATURE_VULKAN_HARDWARE_VERSION >= 1.1 (Impeller's Vulkan floor). */
    val vulkan11: Boolean? = null,
)

/**
 * Pure mapping from raw system values to the channel payload (spec P1 §6.1;
 * `lowEnd` and `glesOnly`: spec 2026-10-10 §7.1).
 */
internal object SignalReader {
    /** Under 3 GiB of memory counts as low end (owner Q5). */
    const val LOW_END_BYTES = 3L * 1024 * 1024 * 1024

    /** Vulkan 1.1 as PackageManager encodes it: (1 shl 22) or (1 shl 12). */
    const val VULKAN_1_1 = 0x00401000

    fun toPayload(raw: RawSignals): Map<String, Boolean> = mapOf(
        "reduceTransparency" to reduceTransparency(raw),
        "powerSave" to (raw.powerSaveMode == true),
        "blurDisabled" to (raw.apiLevel >= 31 && raw.crossWindowBlurEnabled == false),
        "lowEnd" to lowEnd(raw),
        "glesOnly" to (raw.apiLevel >= 29 && raw.vulkan11 == false),
    )

    private fun lowEnd(raw: RawSignals): Boolean =
        raw.isLowRamDevice == true ||
            (raw.totalMemBytes != null && raw.totalMemBytes < LOW_END_BYTES)

    private fun reduceTransparency(raw: RawSignals): Boolean =
        raw.animatorDurationScale == 0f ||
            (raw.apiLevel >= 34 && (raw.contrast ?: 0f) > 0f) ||
            raw.highTextContrast == 1
}
