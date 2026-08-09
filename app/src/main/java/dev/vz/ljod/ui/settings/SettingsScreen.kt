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
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Power
import androidx.compose.material.icons.rounded.SmartToy
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.vz.ljod.core.ui.theme.NordicPalette
import dev.vz.ljod.data.gemini.AvailableModel
import dev.vz.ljod.data.gemini.GeminiLyricsSource
import dev.vz.ljod.data.settings.SettingsRepository
import kotlinx.coroutines.launch

private val LANGUAGES = listOf(
    "English", "Spanish", "French", "German", "Italian",
    "Portuguese", "Japanese", "Korean", "Chinese",
    "Russian", "Arabic", "Hindi", "Turkish", "Dutch",
)

@Composable
fun SettingsScreen(padding: PaddingValues = PaddingValues()) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val settings = remember { SettingsRepository(context) }
    val apiKey by settings.geminiApiKey.collectAsState(initial = "")
    val targetLang by settings.targetLanguage.collectAsState(initial = "English")
    val geminiModel by settings.geminiModel.collectAsState(initial = "gemini-2.0-flash")
    val romanization by settings.romanization.collectAsState(initial = false)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
    ) {
        Text(
            "Settings",
            style = MaterialTheme.typography.headlineLarge.copy(
                fontWeight = FontWeight.Bold,
            ),
            color = NordicPalette.accent,
        )
        Spacer(Modifier.height(24.dp))
        GeminiSection(settings, apiKey, geminiModel, scope, context)
        TranslationSection(settings, targetLang, romanization, scope)
        PlaybackSection(context)
        SystemSection(context)
        Spacer(Modifier.height(24.dp))
        Text("Ljod v0.1.0", style = MaterialTheme.typography.bodySmall, color = NordicPalette.textSecondary)
        Text("Veridian Zenith", style = MaterialTheme.typography.bodySmall, color = NordicPalette.accent)
    }
}

@Composable
private fun SettingsCard(
    title: String,
    icon: ImageVector,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .shadow(8.dp, RoundedCornerShape(20.dp))
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.verticalGradient(
                    listOf(NordicPalette.surfaceHigh, NordicPalette.surface),
                ),
            )
            .border(1.dp, NordicPalette.border, RoundedCornerShape(20.dp))
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = NordicPalette.accent, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, style = MaterialTheme.typography.titleMedium, color = NordicPalette.accent)
        }
        Spacer(Modifier.height(12.dp))
        content()
    }
}

@Composable
private fun GeminiSection(
    settings: SettingsRepository,
    apiKey: String,
    currentModel: String,
    scope: kotlinx.coroutines.CoroutineScope,
    context: android.content.Context,
) {
    var showApiKeyInput by remember { mutableStateOf(false) }
    var editingKey by remember { mutableStateOf(apiKey) }
    var showModelDialog by remember { mutableStateOf(false) }
    var availableModels by remember { mutableStateOf<List<AvailableModel>>(emptyList()) }
    var isLoadingModels by remember { mutableStateOf(false) }
    val geminiSource = remember { GeminiLyricsSource() }

    SettingsCard(title = "Gemini AI (Optional)", icon = Icons.Rounded.SmartToy) {
        Text(
            "All core features work without an API key. AI features are optional enhancements.",
            style = MaterialTheme.typography.bodySmall,
            color = NordicPalette.textSecondary,
        )
        Spacer(Modifier.height(8.dp))
        SettingsItem(
            title = "AI Model",
            subtitle = if (apiKey.isNotBlank()) {
                availableModels.find { it.id == currentModel }?.displayName ?: currentModel
            } else {
                "Add an API key first"
            },
            enabled = apiKey.isNotBlank(),
            onClick = {
                if (apiKey.isNotBlank()) {
                    if (availableModels.isEmpty()) {
                        isLoadingModels = true
                        scope.launch {
                            availableModels = geminiSource.fetchAvailableModels(apiKey)
                            isLoadingModels = false
                            showModelDialog = true
                        }
                    } else {
                        showModelDialog = true
                    }
                } else {
                    showApiKeyInput = true
                }
            },
        )
        AnimatedVisibility(visible = isLoadingModels) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(
                    color = NordicPalette.accent,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text("Fetching available models...", style = MaterialTheme.typography.bodySmall, color = NordicPalette.textSecondary)
            }
        }
        SettingsItem(
            title = "Gemini API Key",
            subtitle = if (apiKey.isNotBlank()) {
                "Configured (${apiKey.take(8)}...)"
            } else {
                "Add a key to enable AI features"
            },
            enabled = true,
            onClick = { showApiKeyInput = !showApiKeyInput },
        )
        if (showApiKeyInput) {
            ApiKeyInput(editingKey, { editingKey = it }) {
                scope.launch {
                    settings.setGeminiApiKey(editingKey)
                    showApiKeyInput = false
                    availableModels = emptyList()
                    Toast.makeText(context, "API key saved", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    if (showModelDialog && availableModels.isNotEmpty()) {
        ModelDialog(
            models = availableModels,
            currentModel = currentModel,
            onSelect = { model ->
                scope.launch { settings.setGeminiModel(model) }
                showModelDialog = false
            },
            onDismiss = { showModelDialog = false },
        )
    }
    Spacer(Modifier.height(12.dp))
}

@Composable
private fun ApiKeyInput(
    value: String,
    onValueChange: (String) -> Unit,
    onSave: () -> Unit,
) {
    Spacer(Modifier.height(8.dp))
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text("API Key") },
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = NordicPalette.textPrimary,
            unfocusedTextColor = NordicPalette.textPrimary,
            focusedBorderColor = NordicPalette.accent,
            unfocusedBorderColor = NordicPalette.border,
            focusedLabelColor = NordicPalette.accent,
            cursorColor = NordicPalette.accent,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(8.dp))
    Text(
        "SAVE KEY",
        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
        color = NordicPalette.accent,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(NordicPalette.accentDim)
            .clickable(onClick = onSave)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
private fun ModelDialog(
    models: List<AvailableModel>,
    currentModel: String,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = NordicPalette.surfaceHigh,
        titleContentColor = NordicPalette.accent,
        textContentColor = NordicPalette.textPrimary,
        title = { Text("Select AI Model") },
        text = {
            Column {
                models.forEach { model ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                if (currentModel == model.id) NordicPalette.accentDim else NordicPalette.bg,
                            )
                            .clickable { onSelect(model.id) }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(model.displayName, style = MaterialTheme.typography.bodyMedium, color = NordicPalette.textPrimary)
                            if (model.inputTokenLimit > 0) {
                                Text(
                                    "Context: ${model.inputTokenLimit / 1000}k tokens",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = NordicPalette.textSecondary,
                                )
                            }
                        }
                        if (currentModel == model.id) {
                            Text("Active", style = MaterialTheme.typography.bodySmall, color = NordicPalette.accent)
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = NordicPalette.textSecondary)
            }
        },
    )
}

@Composable
private fun TranslationSection(
    settings: SettingsRepository,
    targetLang: String,
    romanization: Boolean,
    scope: kotlinx.coroutines.CoroutineScope,
) {
    var showLangDialog by remember { mutableStateOf(false) }

    SettingsCard(title = "Translation & Romanization", icon = Icons.Rounded.Language) {
        SettingsItem(
            title = "Target Language",
            subtitle = targetLang,
            enabled = true,
            onClick = { showLangDialog = true },
        )
        ToggleItem(
            title = "Auto-Romanize",
            subtitle = "Show romanized text alongside original (Pinyin, Romaji, etc.)",
            checked = romanization,
        ) { scope.launch { settings.setRomanization(it) } }
    }

    if (showLangDialog) {
        AlertDialog(
            onDismissRequest = { showLangDialog = false },
            containerColor = NordicPalette.surfaceHigh,
            titleContentColor = NordicPalette.accent,
            textContentColor = NordicPalette.textPrimary,
            title = { Text("Translation Language") },
            text = {
                Column {
                    LANGUAGES.forEach { lang ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (lang == targetLang) NordicPalette.accentDim else NordicPalette.bg,
                                )
                                .clickable {
                                    scope.launch { settings.setTargetLanguage(lang) }
                                    showLangDialog = false
                                }
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(lang, style = MaterialTheme.typography.bodyLarge, color = NordicPalette.textPrimary)
                            if (lang == targetLang) {
                                Spacer(Modifier.weight(1f))
                                Text("Active", style = MaterialTheme.typography.bodySmall, color = NordicPalette.accent)
                            }
                        }
                        Spacer(Modifier.height(4.dp))
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showLangDialog = false }) {
                    Text("Cancel", color = NordicPalette.textSecondary)
                }
            },
        )
    }
    Spacer(Modifier.height(12.dp))
}

@Composable
private fun PlaybackSection(context: android.content.Context) {
    var audioFocus by remember { mutableStateOf(true) }
    var gapless by remember { mutableStateOf(true) }

    SettingsCard(title = "Playback", icon = Icons.Rounded.Power) {
        ToggleItem("Audio Focus", "Pause when other apps play audio", audioFocus) {
            audioFocus = it
            Toast.makeText(
                context,
                if (it) "Audio focus enabled" else "Audio focus disabled",
                Toast.LENGTH_SHORT,
            ).show()
        }
        ToggleItem("Gapless Playback", "Seamless track transitions", gapless) {
            gapless = it
            Toast.makeText(
                context,
                if (it) "Gapless enabled" else "Gapless disabled",
                Toast.LENGTH_SHORT,
            ).show()
        }
    }
    Spacer(Modifier.height(12.dp))
}

@Composable
private fun ToggleItem(
    title: String,
    subtitle: String,
    checked: Boolean,
    onToggle: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .clickable { onToggle(!checked) }
            .padding(vertical = 10.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, color = NordicPalette.textPrimary)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = NordicPalette.textSecondary)
        }
        Text(
            if (checked) "ON" else "OFF",
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
            color = if (checked) NordicPalette.accent else NordicPalette.textSecondary,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(if (checked) NordicPalette.accentDim else NordicPalette.bg)
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun SystemSection(context: android.content.Context) {
    SettingsCard(title = "System", icon = Icons.Rounded.Notifications) {
        if (Build.VERSION.SDK_INT >= 33) {
            SettingsItem("Notification Permission", "For playback controls", enabled = true) {
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
        }
        SettingsItem("Battery Optimization", "Keep playback alive", enabled = true) {
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
    }
    Spacer(Modifier.height(12.dp))
}

@Composable
private fun SettingsItem(title: String, subtitle: String, enabled: Boolean = true, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 10.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.bodyLarge,
                color = if (enabled) NordicPalette.textPrimary else NordicPalette.textSecondary,
            )
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = NordicPalette.textSecondary,
            )
        }
    }
}
