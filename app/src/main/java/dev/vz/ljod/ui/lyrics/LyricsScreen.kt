package dev.vz.ljod.ui.lyrics

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
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
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassChip
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.data.lyrics.LyricsResult
import dev.vz.ljod.playback.PlaybackController

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
    val palette = LjodTheme.palette
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
        modifier =
            Modifier
                .fillMaxSize()
                .background(palette.bg)
                .padding(horizontal = 18.dp, vertical = 10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            GlassIconButton(
                icon = Icons.AutoMirrored.Rounded.ArrowBack,
                contentDescription = "Back",
                onClick = onBack,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "Lyrics",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = palette.accent,
            )
            if (lyrics != null) {
                Spacer(Modifier.width(8.dp))
                Text(
                    lyrics.source,
                    style = MaterialTheme.typography.labelSmall,
                    color = palette.textSecondary.copy(alpha = 0.6f),
                )
            }
            Spacer(Modifier.weight(1f))
            GlassIconButton(
                icon = Icons.Rounded.Settings,
                contentDescription = "Settings",
                onClick = { showSettings = !showSettings },
                tone = if (showSettings) GlassTone.Accent else GlassTone.Subtle,
            )
        }

        Spacer(Modifier.height(8.dp))

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

        Spacer(Modifier.height(8.dp))
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
                    color = palette.textSecondary,
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
    val palette = LjodTheme.palette
    var showLangPicker by remember { mutableStateOf(false) }

    GlassSurface(
        tone = GlassTone.Subtle,
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = LjodDimens.radiusLg,
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .clip(
                            LjodDimens.radiusMd.let {
                                androidx.compose.foundation.shape
                                    .RoundedCornerShape(it)
                            },
                        ).background(Brush.verticalGradient(listOf(palette.surfaceHigh, palette.surface)))
                        .clickable { onToggleRomanization(!romanizationEnabled) }
                        .padding(vertical = 8.dp, horizontal = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "Romanization",
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                        color = palette.textPrimary,
                    )
                    Text("Pinyin, Romaji, etc. below original", style = MaterialTheme.typography.labelSmall, color = palette.textSecondary)
                }
                Box(
                    modifier =
                        Modifier
                            .size(30.dp)
                            .shadow(
                                4.dp,
                                LjodDimens.radiusSm.let {
                                    androidx.compose.foundation.shape
                                        .RoundedCornerShape(it)
                                },
                            ).clip(
                                LjodDimens.radiusSm.let {
                                    androidx.compose.foundation.shape
                                        .RoundedCornerShape(it)
                                },
                            ).background(
                                Brush.verticalGradient(
                                    if (romanizationEnabled) {
                                        listOf(palette.accent, palette.accentDeep)
                                    } else {
                                        listOf(palette.surface, palette.surfaceHigh)
                                    },
                                ),
                            ),
                    contentAlignment = Alignment.Center,
                ) {
                    if (romanizationEnabled) {
                        Icon(Icons.Rounded.Check, contentDescription = null, tint = palette.onAccent, modifier = Modifier.size(16.dp))
                    }
                }
            }
            Spacer(Modifier.height(6.dp))
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .clip(
                            LjodDimens.radiusMd.let {
                                androidx.compose.foundation.shape
                                    .RoundedCornerShape(it)
                            },
                        ).background(Brush.verticalGradient(listOf(palette.surfaceHigh, palette.surface)))
                        .clickable { showLangPicker = !showLangPicker }
                        .padding(vertical = 8.dp, horizontal = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "Translate to",
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                        color = palette.textPrimary,
                    )
                    Text(targetLanguage, style = MaterialTheme.typography.labelSmall, color = palette.accent)
                }
                Text(
                    if (showLangPicker) "▲" else "▼",
                    style = MaterialTheme.typography.labelSmall,
                    color = palette.textSecondary,
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
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .clip(
                                        LjodDimens.radiusSm.let {
                                            androidx.compose.foundation.shape
                                                .RoundedCornerShape(it)
                                        },
                                    ).background(
                                        if (lang ==
                                            targetLanguage
                                        ) {
                                            Brush.verticalGradient(
                                                listOf(palette.accent.copy(alpha = 0.4f), palette.accent.copy(alpha = 0.1f)),
                                            )
                                        } else {
                                            Brush.verticalGradient(listOf(palette.surfaceHigh, palette.surface))
                                        },
                                    ).clickable {
                                        onSetTargetLanguage(lang)
                                        showLangPicker = false
                                    }.padding(horizontal = 10.dp, vertical = 5.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                lang,
                                style = MaterialTheme.typography.labelSmall,
                                color = if (lang == targetLanguage) palette.accent else palette.textPrimary,
                            )
                            if (lang == targetLanguage) {
                                Spacer(Modifier.weight(1f))
                                Icon(Icons.Rounded.Check, contentDescription = null, tint = palette.accent, modifier = Modifier.size(12.dp))
                            }
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
        GlassButton(text = "SEARCH", compact = true, onClick = onSearchLyrics, tone = GlassTone.Subtle)
        GlassButton(
            text = "TRANSLATE",
            compact = true,
            enabled = !isTranslating && !isRomanizing && lyrics != null && lyrics.lines.isNotEmpty(),
            onClick = onTranslate,
        )
        GlassButton(
            text = "ROMANIZE",
            compact = true,
            enabled = !isTranslating && !isRomanizing && lyrics != null && lyrics.lines.isNotEmpty(),
            onClick = onRomanize,
        )
        GlassButton(
            text = "AI GEN",
            compact = true,
            enabled = !isTranslating && !isRomanizing && (lyrics == null || lyrics.lines.isEmpty()),
            onClick = onGenerateWithAI,
        )
    }
}

@Composable
private fun LoadingIndicator() {
    val palette = LjodTheme.palette
    val inf = rememberInfiniteTransition(label = "load")
    val alpha by inf.animateFloat(0.3f, 1f, infiniteRepeatable(tween(800, easing = LinearEasing), RepeatMode.Reverse), label = "a")
    val scale by inf.animateFloat(
        0.9f,
        1.1f,
        infiniteRepeatable(tween(1000, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "s",
    )
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(
                color = palette.accent,
                modifier =
                    Modifier
                        .size(26.dp)
                        .graphicsLayer {
                            this.alpha = alpha
                            scaleX = scale
                            scaleY = scale
                        },
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.height(6.dp))
            Text("Working...", style = MaterialTheme.typography.labelSmall, color = palette.textSecondary)
        }
    }
}

@Composable
private fun SyncedLyricsList(
    lyrics: LyricsResult,
    activeLine: Int,
    listState: androidx.compose.foundation.lazy.LazyListState,
) {
    val palette = LjodTheme.palette
    LazyColumn(
        state = listState,
        contentPadding = PaddingValues(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        itemsIndexed(lyrics.lines) { index, line ->
            val isActive = index == activeLine && lyrics.isSynced
            val hasAny = line.romanized != null || line.translated != null
            val mainColor by animateFloatAsState(
                targetValue = if (isActive) 1f else 0.6f,
                animationSpec = tween(300),
                label = "mc",
            )
            val bgAlpha by animateFloatAsState(
                targetValue = if (isActive) 0.12f else 0f,
                animationSpec = tween(300),
                label = "ba",
            )
            val scale by animateFloatAsState(
                targetValue = if (isActive) 1.01f else 1f,
                animationSpec = tween(300),
                label = "sc",
            )
            val glowAlpha by animateFloatAsState(
                targetValue = if (isActive) 0.2f else 0f,
                animationSpec = tween(400),
                label = "ga",
            )

            Column(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .graphicsLayer {
                            scaleX = scale
                            scaleY = scale
                        }.shadow(
                            if (isActive) 10.dp else 0.dp,
                            LjodDimens.radiusMd.let {
                                androidx.compose.foundation.shape
                                    .RoundedCornerShape(it)
                            },
                            ambientColor = palette.accent.copy(alpha = glowAlpha),
                            spotColor = palette.accent.copy(alpha = glowAlpha),
                        ).clip(
                            LjodDimens.radiusMd.let {
                                androidx.compose.foundation.shape
                                    .RoundedCornerShape(it)
                            },
                        ).background(
                            Brush.horizontalGradient(
                                listOf(
                                    palette.accent.copy(alpha = bgAlpha),
                                    palette.accentDeep.copy(alpha = bgAlpha * 0.5f),
                                    palette.bg.copy(alpha = 0f),
                                ),
                            ),
                        ).padding(horizontal = 10.dp, vertical = if (hasAny) 6.dp else 3.dp),
            ) {
                Text(
                    text = line.text,
                    color = palette.textPrimary.copy(alpha = mainColor.coerceAtLeast(0.5f)),
                    fontSize = if (isActive) 17.sp else 13.sp,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = if (lyrics.isSynced) TextAlign.Center else TextAlign.Start,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (line.romanized != null) {
                    Text(
                        text = line.romanized,
                        color = palette.accentMuted.copy(alpha = 0.7f),
                        fontSize = if (isActive) 11.sp else 10.sp,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = if (lyrics.isSynced) TextAlign.Center else TextAlign.Start,
                        modifier = Modifier.fillMaxWidth().padding(top = 1.dp),
                    )
                }
                if (line.translated != null) {
                    Text(
                        text = line.translated,
                        color = palette.accentHot.copy(alpha = 0.8f),
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
