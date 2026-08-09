package dev.vz.ljod.ui.lyrics

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.vz.ljod.core.ui.theme.GlassStyle
import dev.vz.ljod.core.ui.theme.NordicPalette
import dev.vz.ljod.data.lyrics.LyricsResult
import dev.vz.ljod.playback.PlaybackController

private val LANGUAGES = listOf(
    "English", "Spanish", "French", "German", "Italian",
    "Portuguese", "Japanese", "Korean", "Chinese",
    "Russian", "Arabic", "Hindi", "Turkish", "Dutch",
)

@Composable
fun LyricsScreen(
    controller: PlaybackController,
    lyrics: LyricsResult?,
    isTranslating: Boolean = false,
    isRomanizing: Boolean = false,
    romanizationEnabled: Boolean = false,
    targetLanguage: String = "English",
    onSearchLyrics: () -> Unit = {},
    onTranslate: () -> Unit = {},
    onRomanize: () -> Unit = {},
    onGenerateWithAI: () -> Unit = {},
    onToggleRomanization: (Boolean) -> Unit = {},
    onSetTargetLanguage: (String) -> Unit = {},
    onBack: () -> Unit = {},
) {
    val position by controller.position.collectAsState()
    val listState = rememberLazyListState()
    var activeLine by remember { mutableIntStateOf(0) }
    var showSettings by remember { mutableStateOf(false) }

    LaunchedEffect(lyrics, position) {
        if (lyrics == null || !lyrics.isSynced) return@LaunchedEffect
        val idx = lyrics.lines.indexOfLast { it.timeMs <= position }
        if (idx >= 0 && idx != activeLine) {
            activeLine = idx
            listState.animateScrollToItem(index = idx, scrollOffset = -200)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(NordicPalette.bg)
            .padding(horizontal = 18.dp, vertical = 10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.AutoMirrored.Rounded.ArrowBack,
                contentDescription = "Back",
                tint = NordicPalette.accent,
                modifier = Modifier
                    .size(30.dp)
                    .shadow(6.dp, RoundedCornerShape(10.dp))
                    .clip(RoundedCornerShape(10.dp))
                    .background(GlassStyle.accentGradient)
                    .border(1.dp, NordicPalette.accent.copy(alpha = 0.25f), RoundedCornerShape(10.dp))
                    .clickable(onClick = onBack)
                    .padding(5.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "Lyrics",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = NordicPalette.accent,
            )
            if (lyrics != null) {
                Spacer(Modifier.width(8.dp))
                Text(
                    lyrics.source,
                    style = MaterialTheme.typography.labelSmall,
                    color = NordicPalette.textSecondary.copy(alpha = 0.5f),
                )
            }
            Spacer(Modifier.weight(1f))
            Icon(
                Icons.Rounded.Settings,
                contentDescription = "Settings",
                tint = if (showSettings) NordicPalette.accent else NordicPalette.textSecondary,
                modifier = Modifier
                    .size(28.dp)
                    .shadow(6.dp, RoundedCornerShape(10.dp))
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (showSettings) GlassStyle.accentGradient else GlassStyle.verticalGradient)
                    .border(
                        1.dp,
                        if (showSettings) NordicPalette.accent.copy(alpha = 0.4f) else NordicPalette.glassBorder,
                        RoundedCornerShape(10.dp),
                    )
                    .clickable { showSettings = !showSettings }
                    .padding(5.dp),
            )
        }

        Spacer(Modifier.height(6.dp))

        AnimatedVisibility(
            visible = showSettings,
            enter = expandVertically(tween(300, easing = FastOutSlowInEasing)) + fadeIn(tween(200)),
            exit = shrinkVertically(tween(200)) + fadeOut(tween(150)),
        ) {
            LyricsSettingsPanel(
                romanizationEnabled = romanizationEnabled,
                targetLanguage = targetLanguage,
                onToggleRomanization = onToggleRomanization,
                onSetTargetLanguage = onSetTargetLanguage,
            )
        }

        Spacer(Modifier.height(6.dp))
        LyricsActionRow(lyrics, isTranslating, isRomanizing, onSearchLyrics, onTranslate, onRomanize, onGenerateWithAI)
        Spacer(Modifier.height(8.dp))

        AnimatedVisibility(
            visible = isTranslating || isRomanizing,
            enter = fadeIn(),
            exit = fadeOut(),
        ) {
            LoadingIndicator()
        }

        AnimatedVisibility(
            visible = lyrics != null && lyrics.lines.isNotEmpty() && !isTranslating && !isRomanizing,
            enter = fadeIn(tween(300)) + slideInVertically(tween(300, easing = FastOutSlowInEasing)),
            exit = fadeOut(),
        ) {
            lyrics?.let { SyncedLyricsList(it, activeLine, listState) }
        }

        val showEmpty = lyrics == null || (!isTranslating && !isRomanizing && lyrics.lines.isEmpty())
        if (showEmpty) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    "No lyrics found",
                    style = MaterialTheme.typography.bodyMedium,
                    color = NordicPalette.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun LyricsSettingsPanel(
    romanizationEnabled: Boolean,
    targetLanguage: String,
    onToggleRomanization: (Boolean) -> Unit,
    onSetTargetLanguage: (String) -> Unit,
) {
    var showLangPicker by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(12.dp, RoundedCornerShape(16.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.1f))
            .clip(RoundedCornerShape(16.dp))
            .background(GlassStyle.surfaceGradient)
            .border(1.dp, NordicPalette.glassBorder, RoundedCornerShape(16.dp))
            .padding(12.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(GlassStyle.verticalGradient)
                .clickable { onToggleRomanization(!romanizationEnabled) }
                .padding(vertical = 8.dp, horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Romanization",
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                    color = NordicPalette.textPrimary,
                )
                Text(
                    "Pinyin, Romaji, etc. below original",
                    style = MaterialTheme.typography.labelSmall,
                    color = NordicPalette.textSecondary,
                )
            }
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .shadow(4.dp, RoundedCornerShape(8.dp))
                    .clip(RoundedCornerShape(8.dp))
                    .background(
                        Brush.verticalGradient(
                            if (romanizationEnabled) listOf(NordicPalette.accent, NordicPalette.gradient2)
                            else listOf(NordicPalette.surface, NordicPalette.surfaceHigh),
                        ),
                    )
                    .border(1.dp, NordicPalette.glassBorder, RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center,
            ) {
                if (romanizationEnabled) {
                    Icon(Icons.Rounded.Check, contentDescription = null, tint = NordicPalette.bg, modifier = Modifier.size(16.dp))
                }
            }
        }

        Spacer(Modifier.height(6.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(GlassStyle.verticalGradient)
                .clickable { showLangPicker = !showLangPicker }
                .padding(vertical = 8.dp, horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Translate to",
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                    color = NordicPalette.textPrimary,
                )
                Text(targetLanguage, style = MaterialTheme.typography.labelSmall, color = NordicPalette.accent)
            }
            Text(
                if (showLangPicker) "▲" else "▼",
                style = MaterialTheme.typography.labelSmall,
                color = NordicPalette.textSecondary,
            )
        }

        AnimatedVisibility(
            visible = showLangPicker,
            enter = expandVertically(tween(200)) + fadeIn(tween(150)),
            exit = shrinkVertically(tween(150)) + fadeOut(tween(100)),
        ) {
            Column(modifier = Modifier.padding(top = 6.dp)) {
                LANGUAGES.forEach { lang ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(
                                if (lang == targetLanguage) GlassStyle.accentGradient else GlassStyle.verticalGradient,
                            )
                            .border(
                                1.dp,
                                if (lang == targetLanguage) NordicPalette.accent.copy(alpha = 0.2f) else NordicPalette.glassBorder,
                                RoundedCornerShape(8.dp),
                            )
                            .clickable { onSetTargetLanguage(lang); showLangPicker = false }
                            .padding(horizontal = 10.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            lang,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (lang == targetLanguage) NordicPalette.accent else NordicPalette.textPrimary,
                        )
                        if (lang == targetLanguage) {
                            Spacer(Modifier.weight(1f))
                            Icon(Icons.Rounded.Check, contentDescription = null, tint = NordicPalette.accent, modifier = Modifier.size(12.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LyricsActionRow(
    lyrics: LyricsResult?,
    isTranslating: Boolean,
    isRomanizing: Boolean,
    onSearchLyrics: () -> Unit,
    onTranslate: () -> Unit,
    onRomanize: () -> Unit,
    onGenerateWithAI: () -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        GlassChip("SEARCH", enabled = true, onClick = onSearchLyrics)
        GlassChip(
            "TRANSLATE",
            enabled = !isTranslating && !isRomanizing && lyrics != null && lyrics.lines.isNotEmpty(),
            onClick = onTranslate,
        )
        GlassChip(
            "ROMANIZE",
            enabled = !isTranslating && !isRomanizing && lyrics != null && lyrics.lines.isNotEmpty(),
            onClick = onRomanize,
        )
        GlassChip(
            "AI GEN",
            enabled = !isTranslating && !isRomanizing && (lyrics == null || lyrics.lines.isEmpty()),
            onClick = onGenerateWithAI,
        )
    }
}

@Composable
private fun GlassChip(label: String, enabled: Boolean, onClick: () -> Unit) {
    val infTransition = rememberInfiniteTransition(label = "chip")
    val glowAlpha by infTransition.animateFloat(
        initialValue = 0.0f,
        targetValue = if (enabled) 0.2f else 0f,
        animationSpec = infiniteRepeatable(tween(1500, easing = LinearEasing), RepeatMode.Reverse),
        label = "glow",
    )

    Text(
        label,
        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
        color = if (enabled) NordicPalette.accent else NordicPalette.textSecondary.copy(alpha = 0.4f),
        modifier = Modifier
            .shadow(8.dp, RoundedCornerShape(10.dp), ambientColor = NordicPalette.accent.copy(alpha = glowAlpha))
            .clip(RoundedCornerShape(10.dp))
            .background(
                if (enabled) GlassStyle.chipGradient else GlassStyle.verticalGradient,
            )
            .border(
                1.dp,
                if (enabled) NordicPalette.accent.copy(alpha = 0.35f) else NordicPalette.glassBorder,
                RoundedCornerShape(10.dp),
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp),
    )
}

@Composable
private fun LoadingIndicator() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            val inf = rememberInfiniteTransition(label = "load")
            val alpha by inf.animateFloat(0.3f, 1f, infiniteRepeatable(tween(800, easing = LinearEasing), RepeatMode.Reverse), label = "a")
            val scale by inf.animateFloat(0.9f, 1.1f, infiniteRepeatable(tween(1000, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "s")
            CircularProgressIndicator(
                color = NordicPalette.accent,
                modifier = Modifier.size(26.dp).graphicsLayer { this.alpha = alpha; scaleX = scale; scaleY = scale },
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.height(6.dp))
            Text("Working...", style = MaterialTheme.typography.labelSmall, color = NordicPalette.textSecondary)
        }
    }
}

@Composable
private fun SyncedLyricsList(
    lyrics: LyricsResult,
    activeLine: Int,
    listState: androidx.compose.foundation.lazy.LazyListState,
) {
    LazyColumn(
        state = listState,
        contentPadding = PaddingValues(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        itemsIndexed(lyrics.lines) { index, line ->
            val isActive = index == activeLine && lyrics.isSynced
            val hasAny = line.romanized != null || line.translated != null

            val mainColor by animateColorAsState(
                targetValue = if (isActive) NordicPalette.accent else NordicPalette.textSecondary.copy(alpha = 0.6f),
                animationSpec = tween(300), label = "mc",
            )
            val bgAlpha by animateFloatAsState(
                targetValue = if (isActive) 0.12f else 0f,
                animationSpec = tween(300), label = "ba",
            )
            val scale by animateFloatAsState(
                targetValue = if (isActive) 1.01f else 1f,
                animationSpec = spring(stiffness = Spring.StiffnessLow), label = "sc",
            )
            val glowAlpha by animateFloatAsState(
                targetValue = if (isActive) 0.15f else 0f,
                animationSpec = tween(400), label = "ga",
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .graphicsLayer { scaleX = scale; scaleY = scale }
                    .shadow(
                        if (isActive) 10.dp else 0.dp,
                        RoundedCornerShape(10.dp),
                        ambientColor = NordicPalette.accent.copy(alpha = glowAlpha),
                        spotColor = NordicPalette.accent.copy(alpha = glowAlpha),
                    )
                    .clip(RoundedCornerShape(10.dp))
                    .background(
                        Brush.horizontalGradient(
                            listOf(
                                NordicPalette.accent.copy(alpha = bgAlpha),
                                NordicPalette.gradient2.copy(alpha = bgAlpha * 0.5f),
                                NordicPalette.bg.copy(alpha = 0f),
                            ),
                        ),
                    )
                    .padding(horizontal = 10.dp, vertical = if (hasAny) 6.dp else 3.dp),
            ) {
                Text(
                    text = line.text,
                    color = mainColor,
                    fontSize = if (isActive) 17.sp else 13.sp,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = if (lyrics.isSynced) TextAlign.Center else TextAlign.Start,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (line.romanized != null) {
                    Text(
                        text = line.romanized,
                        color = NordicPalette.accent2.copy(alpha = 0.7f),
                        fontSize = if (isActive) 11.sp else 10.sp,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = if (lyrics.isSynced) TextAlign.Center else TextAlign.Start,
                        modifier = Modifier.fillMaxWidth().padding(top = 1.dp),
                    )
                }
                if (line.translated != null) {
                    Text(
                        text = line.translated,
                        color = NordicPalette.accent3.copy(alpha = 0.8f),
                        fontSize = if (isActive) 11.sp else 10.sp,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = if (lyrics.isSynced) TextAlign.Center else TextAlign.Start,
                        modifier = Modifier.fillMaxWidth().padding(top = 1.dp),
                    )
                }
            }
        }
    }
}
