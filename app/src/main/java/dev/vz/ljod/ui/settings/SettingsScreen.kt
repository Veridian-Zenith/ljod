package dev.vz.ljod.ui.settings

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Fingerprint
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Power
import androidx.compose.material.icons.rounded.Security
import androidx.compose.material.icons.rounded.SmartToy
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.vz.ljod.app.LjodViewModel
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassChip
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.glass.LjodSwitch
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.data.gemini.AvailableModel
import dev.vz.ljod.data.settings.RepeatMode

private val LANGUAGES =
    listOf(
        "English",
        "Spanish",
        "French",
        "German",
        "Italian",
        "Portuguese",
        "Japanese",
        "Korean",
        "Chinese",
        "Russian",
        "Arabic",
        "Hindi",
        "Turkish",
        "Dutch",
    )

@Composable
fun SettingsScreen(viewModel: LjodViewModel = hiltViewModel()) {
    val context = LocalContext.current
    val palette = LjodTheme.palette

    val targetLang by viewModel.targetLanguage.collectAsState()
    val romanization by viewModel.romanizationEnabled.collectAsState()
    val pureBlack by viewModel.pureBlack.collectAsState()
    val animations by viewModel.animationsEnabled.collectAsState()
    val shuffle by viewModel.shuffleMode.collectAsState()
    val repeatMode by viewModel.repeatMode.collectAsState()
    val crossfadeMs by viewModel.crossfadeMs.collectAsState()
    val eqEnabled by viewModel.eqEnabled.collectAsState()

    var biometric by remember { mutableStateOf(false) }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp)
                .verticalScroll(rememberScrollState()),
    ) {
        Spacer(Modifier.height(40.dp))
        Text(
            "Settings",
            style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Black),
            color = palette.accent,
        )
        Spacer(Modifier.height(16.dp))

        SettingsCard(title = "AI (Optional)", icon = Icons.Rounded.SmartToy) {
            GeminiSection(viewModel)
        }
        Spacer(Modifier.height(12.dp))

        SettingsCard(title = "Playback", icon = Icons.Rounded.Power) {
            ToggleRow(
                title = "Shuffle",
                subtitle = "Play in random order",
                checked = shuffle,
                onToggle = {
                    viewModel.toggleShuffle()
                },
            )
            RepeatRow(
                current = repeatMode,
                onSelect = {
                    viewModel.setRepeatMode(it)
                },
            )
            SliderRow(
                title = "Crossfade",
                subtitle = "Overlap tracks (0 = off)",
                value = crossfadeMs.toFloat(),
                range = 0f..12_000f,
                steps = 11,
                onChange = { v ->
                    viewModel.setCrossfadeMs(v.toInt())
                },
                valueLabel = "${crossfadeMs / 1000}s",
            )
            ToggleRow(
                title = "Equalizer",
                subtitle = "System-wide audio effects",
                checked = eqEnabled,
                onToggle = { viewModel.setEqEnabled(it) },
            )
        }
        Spacer(Modifier.height(12.dp))

        SettingsCard(title = "Lyrics", icon = Icons.Rounded.Language) {
            TranslationLanguageRow(targetLang) { viewModel.setTargetLanguage(it) }
            ToggleRow(
                title = "Romanization",
                subtitle = "Pinyin, Romaji, etc. below original",
                checked = romanization,
                onToggle = { viewModel.setRomanization(it) },
            )
        }
        Spacer(Modifier.height(12.dp))

        SettingsCard(title = "Appearance", icon = Icons.Rounded.Palette) {
            ToggleRow(
                title = "Pure black (AMOLED)",
                subtitle = "Saves battery on OLED",
                checked = pureBlack,
                onToggle = { viewModel.setPureBlack(it) },
            )
            ToggleRow(
                title = "Animations",
                subtitle = "Smooth transitions and effects",
                checked = animations,
                onToggle = { viewModel.setAnimationsEnabled(it) },
            )
        }
        Spacer(Modifier.height(12.dp))

        SettingsCard(title = "Security", icon = Icons.Rounded.Security) {
            ToggleRow(
                title = "App lock",
                subtitle = "Require biometric to open Ljod",
                checked = biometric,
                onToggle = { biometric = it },
            )
        }
        Spacer(Modifier.height(12.dp))

        SettingsCard(title = "System", icon = Icons.Rounded.Notifications) {
            SystemRow("Notification permission", "For playback controls") {
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                        },
                    )
                } catch (_: Exception) {
                    Toast.makeText(context, "Cannot open notification settings", Toast.LENGTH_SHORT).show()
                }
            }
            SystemRow("Battery optimization", "Keep playback alive") {
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                        },
                    )
                } catch (_: Exception) {
                    Toast.makeText(context, "Cannot open battery settings", Toast.LENGTH_SHORT).show()
                }
            }
            SystemRow("Rescan library") {
                viewModel.rescan()
                Toast.makeText(context, "Library rescanning...", Toast.LENGTH_SHORT).show()
            }
        }
        Spacer(Modifier.height(12.dp))

        SettingsCard(title = "About", icon = Icons.Rounded.Info) {
            Text(
                "Ljod v0.2.0",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = palette.textPrimary,
            )
            Text(
                "Veridian Zenith — Forge your sound.",
                style = MaterialTheme.typography.bodySmall,
                color = palette.accent,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                "Built with Jetpack Compose, Media3, Hilt, Room, and the Android Keystore.",
                style = MaterialTheme.typography.bodySmall,
                color = palette.textSecondary,
            )
        }
        Spacer(Modifier.height(40.dp))
    }
}

@Composable
private fun SettingsCard(
    title: String,
    icon: ImageVector,
    content: @Composable () -> Unit,
) {
    val palette = LjodTheme.palette
    GlassSurface(
        tone = GlassTone.Subtle,
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = LjodDimens.radiusXl,
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = palette.accent, modifier = Modifier.size(LjodDimens.iconMd))
                Spacer(Modifier.width(8.dp))
                Text(title.uppercase(), style = MaterialTheme.typography.titleSmall.copy(letterSpacing = 1.5.sp), color = palette.accent)
            }
            Spacer(Modifier.height(12.dp))
            content()
        }
    }
}

@Composable
private fun ToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onToggle: (Boolean) -> Unit,
) {
    val palette = LjodTheme.palette
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(LjodDimens.radiusMd))
                .clickable { onToggle(!checked) }
                .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = palette.textPrimary)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
        }
        LjodSwitch(checked = checked, onCheckedChange = onToggle)
    }
}

@Composable
private fun RepeatRow(
    current: RepeatMode,
    onSelect: (RepeatMode) -> Unit,
) {
    val palette = LjodTheme.palette
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text("Repeat", style = MaterialTheme.typography.bodyLarge, color = palette.textPrimary)
            Text("Loop a song or the whole queue", style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            GlassChip("Off", selected = current == RepeatMode.Off, onClick = { onSelect(RepeatMode.Off) })
            GlassChip("All", selected = current == RepeatMode.All, onClick = { onSelect(RepeatMode.All) })
            GlassChip("One", selected = current == RepeatMode.One, onClick = { onSelect(RepeatMode.One) })
        }
    }
}

@Composable
private fun TranslationLanguageRow(
    current: String,
    onSelect: (String) -> Unit,
) {
    val palette = LjodTheme.palette
    var showDialog by remember { mutableStateOf(false) }
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(LjodDimens.radiusMd.let { RoundedCornerShape(it) })
                .clickable { showDialog = true }
                .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text("Translation language", style = MaterialTheme.typography.bodyLarge, color = palette.textPrimary)
            Text(current, style = MaterialTheme.typography.bodySmall, color = palette.accent)
        }
    }
    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            containerColor = palette.surface,
            titleContentColor = palette.accent,
            textContentColor = palette.textPrimary,
            title = { Text("Translation language") },
            text = {
                Column {
                    LANGUAGES.forEach { lang ->
                        Text(
                            text = lang,
                            color = if (lang == current) palette.accent else palette.textPrimary,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .clip(LjodDimens.radiusSm.let { RoundedCornerShape(it) })
                                    .clickable {
                                        onSelect(lang)
                                        showDialog = false
                                    }.padding(12.dp),
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showDialog = false }) { Text("Close", color = palette.accent) }
            },
        )
    }
}

@Composable
private fun SliderRow(
    title: String,
    subtitle: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    steps: Int,
    onChange: (Float) -> Unit,
    valueLabel: String,
) {
    val palette = LjodTheme.palette
    Column(modifier = Modifier.padding(vertical = 6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.bodyLarge, color = palette.textPrimary)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
            }
            Text(
                valueLabel,
                style = MaterialTheme.typography.labelMedium,
                color = palette.accent,
            )
        }
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            steps = steps,
            colors =
                SliderDefaults.colors(
                    thumbColor = palette.accent,
                    activeTrackColor = palette.accent,
                    inactiveTrackColor = palette.surfaceHigh,
                ),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun SystemRow(
    title: String,
    subtitle: String? = null,
    onClick: () -> Unit,
) {
    val palette = LjodTheme.palette
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(LjodDimens.radiusMd.let { RoundedCornerShape(it) })
                .clickable(onClick = onClick)
                .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, color = palette.textPrimary)
            if (subtitle != null) {
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
            }
        }
        Text("›", color = palette.accent)
    }
}

@Composable
private fun GeminiSection(viewModel: LjodViewModel) {
    val context = LocalContext.current
    val palette = LjodTheme.palette
    var showApiKeyInput by remember { mutableStateOf(false) }
    var editingKey by remember { mutableStateOf("") }
    var showModelDialog by remember { mutableStateOf(false) }
    var availableModels by remember { mutableStateOf<List<AvailableModel>>(emptyList()) }
    var isLoadingModels by remember { mutableStateOf(false) }
    var hasKey by remember { mutableStateOf(false) }

    Column {
        Text(
            "All core features work without an API key. AI features are optional.",
            style = MaterialTheme.typography.bodySmall,
            color = palette.textSecondary,
        )
        Spacer(Modifier.height(8.dp))
        ToggleRow(
            title = "API key",
            subtitle = if (hasKey) "Configured" else "Add a key to enable AI",
            checked = hasKey,
            onToggle = { showApiKeyInput = !showApiKeyInput },
        )
        if (showApiKeyInput) {
            OutlinedTextField(
                value = editingKey,
                onValueChange = { editingKey = it },
                label = { Text("Gemini API key") },
                singleLine = true,
                colors =
                    OutlinedTextFieldDefaults.colors(
                        focusedTextColor = palette.textPrimary,
                        unfocusedTextColor = palette.textPrimary,
                        focusedBorderColor = palette.accent,
                        unfocusedBorderColor = palette.border,
                        focusedLabelColor = palette.accent,
                        cursorColor = palette.accent,
                    ),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(8.dp))
            GlassButton(
                text = "Save key",
                onClick = {
                    viewModel.setGeminiApiKey(editingKey)
                    hasKey = editingKey.isNotBlank()
                    showApiKeyInput = false
                    editingKey = ""
                    Toast.makeText(context, "API key saved", Toast.LENGTH_SHORT).show()
                },
                tone = GlassTone.Accent,
            )
        }
        AnimatedVisibility(visible = isLoadingModels) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(color = palette.accent, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text("Fetching models...", style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
            }
        }
        if (hasKey) {
            Spacer(Modifier.height(8.dp))
            GlassButton(
                text = "Browse models",
                onClick = {
                    isLoadingModels = true
                    viewModel.fetchAvailableModels { models ->
                        availableModels = models
                        isLoadingModels = false
                        showModelDialog = models.isNotEmpty()
                    }
                },
                tone = GlassTone.Subtle,
            )
        }
    }
    if (showModelDialog && availableModels.isNotEmpty()) {
        AlertDialog(
            onDismissRequest = { showModelDialog = false },
            containerColor = palette.surface,
            titleContentColor = palette.accent,
            textContentColor = palette.textPrimary,
            title = { Text("Select model") },
            text = {
                Column {
                    availableModels.forEach { model ->
                        Text(
                            model.displayName,
                            style = MaterialTheme.typography.bodyMedium,
                            color = palette.textPrimary,
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .clip(LjodDimens.radiusSm.let { RoundedCornerShape(it) })
                                    .clickable { showModelDialog = false }
                                    .padding(12.dp),
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showModelDialog = false }) { Text("Close", color = palette.accent) }
            },
        )
    }
}
