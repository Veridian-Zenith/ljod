import 'package:kana_kit/kana_kit.dart';
import 'package:pinyin/pinyin.dart';

/// Writing system of a lyric line.
enum LyricScript { latin, japanese, chinese, korean, russian, thai, vietnamese }

/// Detects the script a line is written in.
///
/// Kana is what separates Japanese from Chinese, and it is decided first: a line
/// containing any kana is Japanese even when most of its characters are Han.
/// That is the case most players get wrong — treating Han as Chinese sends
/// Japanese lyrics through pinyin, which produces something that is neither
/// language.
LyricScript detectScript(String text) {
  var hasKana = false;
  var hasHangul = false;
  var hasThai = false;
  var hasCyrillic = false;
  var hasHan = false;
  var hasVietnamese = false;

  for (final rune in text.runes) {
    if (_isKana(rune)) {
      hasKana = true;
    } else if (_isHangul(rune)) {
      hasHangul = true;
    } else if (rune >= 0x0E00 && rune <= 0x0E7F) {
      hasThai = true;
    } else if (rune >= 0x0400 && rune <= 0x04FF) {
      hasCyrillic = true;
    } else if (_isHan(rune)) {
      hasHan = true;
    } else if (rune > 0x7F &&
        _vietnamese.containsKey(String.fromCharCode(rune).toLowerCase())) {
      hasVietnamese = true;
    }
  }

  if (hasKana) return LyricScript.japanese;
  if (hasHangul) return LyricScript.korean;
  if (hasThai) return LyricScript.thai;
  if (hasCyrillic) return LyricScript.russian;
  if (hasVietnamese) return LyricScript.vietnamese;
  if (hasHan) return LyricScript.chinese;
  return LyricScript.latin;
}

/// Romanizes [text] according to the script it is written in.
///
/// Latin text is returned untouched. Everything else is transliterated with the
/// conventions of its own language rather than run through one shared table.
String romanizeLyrics(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  final romanized = switch (detectScript(trimmed)) {
    LyricScript.japanese => _romanizeJapanese(trimmed),
    LyricScript.chinese => _romanizeChinese(trimmed),
    LyricScript.korean => _romanizeHangul(trimmed),
    LyricScript.russian => _romanizeCyrillic(trimmed),
    LyricScript.thai => _romanizeThai(trimmed),
    LyricScript.vietnamese => _stripVietnamese(trimmed),
    LyricScript.latin => trimmed,
  };

  return romanized.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

// ---------------------------------------------------------------------------
// Script tests
// ---------------------------------------------------------------------------

bool _isKana(int rune) =>
    (rune >= 0x3040 && rune <= 0x309F) ||
    (rune >= 0x30A0 && rune <= 0x30FF) ||
    (rune >= 0x31F0 && rune <= 0x31FF);

bool _isHan(int rune) =>
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xF900 && rune <= 0xFAFF);

bool _isHangul(int rune) =>
    (rune >= 0xAC00 && rune <= 0xD7A3) ||
    (rune >= 0x1100 && rune <= 0x11FF) ||
    (rune >= 0x3130 && rune <= 0x318F);

// ---------------------------------------------------------------------------
// Japanese: kana through Hepburn; kanji is left alone
// ---------------------------------------------------------------------------

final KanaKit _kanaKit = KanaKit();

String _romanizeJapanese(String text) {
  final buffer = StringBuffer();
  final runes = text.runes.toList();
  var index = 0;
  while (index < runes.length) {
    if (_isKana(runes[index])) {
      var end = index;
      while (end < runes.length && _isKana(runes[end])) {
        end++;
      }
      buffer.write(
        _kanaKit.toRomaji(String.fromCharCodes(runes.sublist(index, end))),
      );
      index = end;
      continue;
    }
    // Kanji stays as it is: reading it as Chinese pinyin would be wrong, and
    // dropping it would delete the word from the line.
    buffer.write(String.fromCharCode(runes[index]));
    index++;
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Chinese: Han runs through pinyin
// ---------------------------------------------------------------------------

String _romanizeChinese(String text) {
  final buffer = StringBuffer();
  final runes = text.runes.toList();
  var index = 0;
  while (index < runes.length) {
    if (_isHan(runes[index])) {
      var end = index;
      while (end < runes.length && _isHan(runes[end])) {
        end++;
      }
      final run = String.fromCharCodes(runes.sublist(index, end));
      try {
        buffer.write(PinyinHelper.getPinyin(run, separator: ' '));
      } catch (_) {
        // A character with no reading: keep it rather than lose the word.
        buffer.write(run);
      }
      index = end;
      continue;
    }
    buffer.write(String.fromCharCode(runes[index]));
    index++;
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Korean: Revised Romanization, composed from the syllable blocks
// ---------------------------------------------------------------------------

const List<String> _hangulInitial = [
  'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', //
  'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h',
];

const List<String> _hangulMedial = [
  'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', //
  'wae', 'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i',
];

const List<String> _hangulFinal = [
  '', 'k', 'k', 'ks', 'n', 'nj', 'nh', 't', 'l', 'lk', //
  'lm', 'lb', 'ls', 'lt', 'lp', 'lh', 'm', 'p', 'ps', 't',
  't', 'ng', 't', 't', 'k', 't', 'p', 'h',
];

String _romanizeHangul(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0xAC00 && rune <= 0xD7A3) {
      final syllable = rune - 0xAC00;
      buffer
        ..write(_hangulInitial[syllable ~/ 588])
        ..write(_hangulMedial[(syllable % 588) ~/ 28])
        ..write(_hangulFinal[syllable % 28]);
      continue;
    }
    buffer.write(String.fromCharCode(rune));
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Russian: per-letter transliteration
// ---------------------------------------------------------------------------

const Map<String, String> _cyrillic = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'e',
  'ё': 'yo',
  'ж': 'zh',
  'з': 'z',
  'и': 'i',
  'й': 'y',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ф': 'f',
  'х': 'kh',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'shch',
  'ъ': '',
  'ы': 'y',
  'ь': '',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};

String _romanizeCyrillic(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final mapped = _cyrillic[lower];
    if (mapped == null) {
      buffer.write(char);
      continue;
    }
    buffer.write(char == lower ? mapped : _capitalize(mapped));
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Thai: letter-level transliteration
// ---------------------------------------------------------------------------

/// Thai has no word spaces and its vowels wrap consonants, so a letter-level
/// pass is approximate by nature; it is still readable, which is the point.
const Map<String, String> _thai = {
  'ก': 'k', 'ข': 'kh', 'ฃ': 'kh', 'ค': 'kh', 'ฅ': 'kh', 'ฆ': 'kh', 'ง': 'ng',
  'จ': 'ch', 'ฉ': 'ch', 'ช': 'ch', 'ซ': 's', 'ฌ': 'ch', 'ญ': 'y', 'ฎ': 'd',
  'ฏ': 't', 'ฐ': 'th', 'ฑ': 'th', 'ฒ': 'th', 'ณ': 'n', 'ด': 'd', 'ต': 't',
  'ถ': 'th', 'ท': 'th', 'ธ': 'th', 'น': 'n', 'บ': 'b', 'ป': 'p', 'ผ': 'ph',
  'ฝ': 'f', 'พ': 'ph', 'ฟ': 'f', 'ภ': 'ph', 'ม': 'm', 'ย': 'y', 'ร': 'r',
  'ล': 'l', 'ว': 'w', 'ศ': 's', 'ษ': 's', 'ส': 's', 'ห': 'h', 'ฬ': 'l',
  'อ': 'o', 'ฮ': 'h',
  'ะ': 'a', 'ั': 'a', 'า': 'a', 'ำ': 'am', 'ิ': 'i', 'ี': 'i', 'ึ': 'ue',
  'ื': 'ue', 'ุ': 'u', 'ู': 'u', 'เ': 'e', 'แ': 'ae', 'โ': 'o', 'ใ': 'ai',
  'ไ': 'ai',
  // Tone marks and repetition signs carry no sound of their own.
  '่': '', '้': '', '๊': '', '๋': '', '็': '', '์': '', 'ๆ': '', 'ฯ': '',
};

String _romanizeThai(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_thai[char] ?? char);
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Vietnamese: Latin already, so the diacritics come off
// ---------------------------------------------------------------------------

/// One entry per accented letter rather than two index-aligned strings: an
/// off-by-one in a pair of parallel literals silently maps ệ to i, and is
/// invisible until a listener reads the output.
const Map<String, String> _vietnamese = {
  // Bare accented vowels carry no tone mark, so they need their own entries.
  'ă': 'a', 'â': 'a', 'ê': 'e', 'ô': 'o', 'ơ': 'o', 'ư': 'u',
  // a
  'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
  'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
  'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
  // d
  'đ': 'd',
  // e
  'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
  'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
  // i
  'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
  // o
  'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
  'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
  'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
  // u
  'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
  'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
  // y
  'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
};

String _stripVietnamese(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final plain = _vietnamese[lower];
    if (plain == null) {
      buffer.write(char);
      continue;
    }
    buffer.write(char == lower ? plain : plain.toUpperCase());
  }
  return buffer.toString();
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
