package dev.vz.ljod.data.romanization

import android.icu.text.Transliterator
import dev.vz.ljod.data.lyrics.LyricsLine
import dev.vz.ljod.data.lyrics.LyricsResult
import timber.log.Timber

object Romanizer {
    private val scriptTransliterators =
        mapOf(
            "Han" to "Han-Latin",
            "Hiragana" to "Hiragana-Latin",
            "Katakana" to "Katakana-Latin",
            "Hangul" to "Hangul-Latin",
            "Arabic" to "Arabic-Latin",
            "Cyrillic" to "Cyrillic-Latin",
            "Devanagari" to "Devanagari-Latin",
            "Thai" to "Thai-Latin",
            "Hebrew" to "Hebrew-Latin",
            "Greek" to "Greek-Latin",
            "Bengali" to "Bengali-Latin",
            "Tamil" to "Tamil-Latin",
            "Telugu" to "Telugu-Latin",
            "Georgian" to "Georgian-Latin",
            "Armenian" to "Armenian-Latin",
        )

    fun romanize(text: String): String {
        val script = detectScript(text)
        if (script == null || script == "Latin") return text

        val ruleId =
            scriptTransliterators[script] ?: run {
                Timber.d("No romanization rule for script: $script")
                return text
            }

        return try {
            val transliterator = Transliterator.getInstance(ruleId)
            transliterator.transliterate(text)
        } catch (e: Exception) {
            Timber.w(e, "Transliteration failed for rule: $ruleId")
            text
        }
    }

    fun romanizeLyrics(lyrics: LyricsResult): LyricsResult {
        val romanizedLines =
            lyrics.lines.map { line ->
                val romanized = romanize(line.text)
                if (romanized != line.text) {
                    line.copy(romanized = romanized)
                } else {
                    line
                }
            }

        val anyChanged =
            romanizedLines.zip(lyrics.lines).any { (a, b) ->
                a.romanized != b.romanized
            }

        return if (anyChanged) {
            LyricsResult(
                lines = romanizedLines,
                source = lyrics.source,
                isSynced = lyrics.isSynced,
            )
        } else {
            lyrics
        }
    }

    private fun detectScript(text: String): String? {
        for (char in text) {
            if (char.isLetter() && !isLatin(char)) {
                val block = Character.UnicodeBlock.of(char)
                return blockToScript(block)
            }
        }
        return "Latin"
    }

    private fun isLatin(char: Char): Boolean {
        val block = Character.UnicodeBlock.of(char)
        return block == Character.UnicodeBlock.BASIC_LATIN ||
            block == Character.UnicodeBlock.LATIN_EXTENDED_ADDITIONAL
    }

    private val blockScriptMap =
        mapOf(
            Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS to "Han",
            Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS_EXTENSION_A to "Han",
            Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS_EXTENSION_B to "Han",
            Character.UnicodeBlock.HIRAGANA to "Hiragana",
            Character.UnicodeBlock.KATAKANA to "Katakana",
            Character.UnicodeBlock.HANGUL_SYLLABLES to "Hangul",
            Character.UnicodeBlock.HANGUL_JAMO to "Hangul",
            Character.UnicodeBlock.HANGUL_COMPATIBILITY_JAMO to "Hangul",
            Character.UnicodeBlock.ARABIC to "Arabic",
            Character.UnicodeBlock.CYRILLIC to "Cyrillic",
            Character.UnicodeBlock.CYRILLIC_SUPPLEMENTARY to "Cyrillic",
            Character.UnicodeBlock.DEVANAGARI to "Devanagari",
            Character.UnicodeBlock.THAI to "Thai",
            Character.UnicodeBlock.HEBREW to "Hebrew",
            Character.UnicodeBlock.GREEK to "Greek",
            Character.UnicodeBlock.GREEK_EXTENDED to "Greek",
            Character.UnicodeBlock.BENGALI to "Bengali",
            Character.UnicodeBlock.TAMIL to "Tamil",
            Character.UnicodeBlock.TELUGU to "Telugu",
            Character.UnicodeBlock.GEORGIAN to "Georgian",
            Character.UnicodeBlock.ARMENIAN to "Armenian",
        )

    private fun blockToScript(block: Character.UnicodeBlock?): String? = blockScriptMap[block]
}
