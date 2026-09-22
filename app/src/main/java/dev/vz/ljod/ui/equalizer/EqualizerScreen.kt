package dev.vz.ljod.ui.equalizer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.glass.GlassChip
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.playback.PlaybackController

private val PRESETS = listOf("Flat", "Bass Boost", "Vocal", "Treble", "Acoustic", "Rock", "Pop", "Jazz")

@Composable
fun EqualizerScreen(
    controller: PlaybackController,
    onBack: () -> Unit,
) {
    val palette = LjodTheme.palette
    var enabled by remember { mutableStateOf(true) }
    var selectedPreset by remember { mutableStateOf("Flat") }
    val detected = controller.equalizerBandCount().coerceIn(5, 10)
    val minMax = controller.equalizerBandLevelRange()
    var bandLevels by remember(detected) { mutableStateOf(MutableList(detected) { 0 }) }

    LaunchedEffect(detected) {
        if (bandLevels.size != detected) {
            bandLevels = MutableList(detected) { 0 }
        }
    }

    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
        Spacer(Modifier.height(40.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            GlassIconButton(
                icon = Icons.AutoMirrored.Rounded.ArrowBack,
                contentDescription = "Back",
                onClick = onBack,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "Equalizer",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = palette.textPrimary,
            )
            Spacer(Modifier.weight(1f))
            GlassChip(
                text = if (enabled) "Enabled" else "Off",
                selected = enabled,
                onClick = { enabled = !enabled },
            )
        }
        Spacer(Modifier.height(16.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(PRESETS) { preset ->
                GlassChip(
                    text = preset,
                    selected = selectedPreset == preset,
                    onClick = { selectedPreset = preset },
                )
            }
        }
        Spacer(Modifier.height(20.dp))
        GlassSurface(
            tone = GlassTone.Warm,
            modifier = Modifier.fillMaxWidth(),
            cornerRadius = LjodDimens.radiusXl,
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.GraphicEq, contentDescription = null, tint = palette.accent)
                    Spacer(Modifier.width(8.dp))
                    Text("Bands", style = MaterialTheme.typography.titleSmall, color = palette.textPrimary)
                }
                Spacer(Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    bandLevels.forEachIndexed { index, level ->
                        Column(
                            modifier = Modifier.width(46.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                text = "${if (level > 0) "+" else ""}$level",
                                style = MaterialTheme.typography.labelSmall,
                                color =
                                    if (level > 0) {
                                        palette.accentHot
                                    } else if (level < 0) {
                                        palette.accent
                                    } else {
                                        palette.textSecondary
                                    },
                            )
                            Spacer(Modifier.height(6.dp))
                            BandBar(level = level, minLevel = minMax.first.toInt(), maxLevel = minMax.second.toInt())
                            Spacer(Modifier.height(6.dp))
                            Slider(
                                value = level.toFloat(),
                                onValueChange = { v ->
                                    val newLevel = v.toInt()
                                    bandLevels = bandLevels.toMutableList().also { it[index] = newLevel }
                                    controller.setEqualizerBand(newLevel, index)
                                },
                                valueRange = minMax.first.toFloat()..minMax.second.toFloat(),
                                steps = 0,
                                colors =
                                    SliderDefaults.colors(
                                        thumbColor = palette.accent,
                                        activeTrackColor = palette.accent,
                                        inactiveTrackColor = palette.surfaceHigh,
                                    ),
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Text(
                                text = bandLabel(index, detected),
                                style = MaterialTheme.typography.labelSmall,
                                color = palette.textSecondary,
                            )
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(20.dp))
        GlassSurface(
            tone = GlassTone.Subtle,
            modifier = Modifier.fillMaxWidth(),
            cornerRadius = LjodDimens.radiusLg,
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Notes", style = MaterialTheme.typography.titleSmall, color = palette.textPrimary)
                Spacer(Modifier.height(6.dp))
                Text(
                    "Uses your device's audio effects engine. Bands adjust from -15 to +15 dB; presets approximate common curves.",
                    style = MaterialTheme.typography.bodySmall,
                    color = palette.textSecondary,
                )
            }
        }
    }
}

@Composable
private fun BandBar(
    level: Int,
    minLevel: Int,
    maxLevel: Int,
) {
    val palette = LjodTheme.palette
    val range = (maxLevel - minLevel).coerceAtLeast(1)
    val normalized = (level - minLevel).toFloat() / range
    Box(
        modifier =
            Modifier
                .width(8.dp)
                .height(120.dp)
                .clip(
                    androidx.compose.foundation.shape
                        .RoundedCornerShape(4.dp),
                ).background(palette.surfaceHigh),
    ) {
        Box(
            modifier =
                Modifier
                    .align(Alignment.BottomCenter)
                    .width(8.dp)
                    .height((120.dp.value * normalized).coerceIn(2f, 120f).dp)
                    .background(Brush.verticalGradient(listOf(palette.accent, palette.accentDeep))),
        )
    }
}

private fun bandLabel(
    index: Int,
    total: Int,
): String {
    val bandTotal = total
    val labels = listOf("60", "170", "310", "600", "1K", "3K", "6K", "12K", "14K", "16K")
    return "${labels[index]}Hz (bands: $bandTotal)"
}
