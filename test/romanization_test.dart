import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/services/lyrics/lyrics_service.dart';

void main() {
  group('script detection', () {
    // The distinction most players get wrong: Han alone means Chinese, but any
    // kana means the line is Japanese, whatever else it contains.
    test('kana makes a line Japanese even when it is mostly Han', () {
      expect(detectScript('君の名は'), LyricScript.japanese);
      expect(detectScript('ありがとう'), LyricScript.japanese);
      expect(detectScript('カタカナとひらがな'), LyricScript.japanese);
      expect(detectScript('你的名字'), LyricScript.chinese);
      expect(detectScript('你好，世界'), LyricScript.chinese);
    });

    test('the remaining scripts are told apart', () {
      expect(detectScript('안녕하세요'), LyricScript.korean);
      expect(detectScript('Привет, мир'), LyricScript.russian);
      expect(detectScript('สวัสดี'), LyricScript.thai);
      expect(detectScript('Tiếng Việt'), LyricScript.vietnamese);
      expect(detectScript('hello world'), LyricScript.latin);
    });
  });

  group('romanization', () {
    test('Chinese goes through pinyin', () {
      expect(romanizeLyrics('你好世界'), 'ni hao shi jie');
      expect(romanizeLyrics('I love 你'), contains('ni'));
    });

    test('Japanese goes through Hepburn, never pinyin', () {
      expect(romanizeLyrics('ありがとう'), 'arigatou');
      expect(romanizeLyrics('カタカナ'), 'katakana');
    });

    test('Korean uses Revised Romanization', () {
      expect(romanizeLyrics('안녕하세요'), 'annyeonghaseyo');
    });

    test('Russian is transliterated letter by letter', () {
      expect(romanizeLyrics('Привет'), 'Privet');
    });

    test('Thai is transliterated to readable Latin', () {
      final romanized = romanizeLyrics('สวัสดี');
      expect(romanized, isNotEmpty);
      expect(RegExp(r'^[a-z]+$').hasMatch(romanized), isTrue, reason: romanized);
    });

    test('Vietnamese loses its diacritics', () {
      expect(romanizeLyrics('Tiếng Việt'), 'Tieng Viet');
      expect(romanizeLyrics('Đường'), 'Duong');
      // One character from each group, so a misaligned table cannot slip past.
      const tails = {
        'ạ': 'a',
        'ặ': 'a',
        'ậ': 'a',
        'đ': 'd',
        'ệ': 'e',
        'ị': 'i',
        'ợ': 'o',
        'ự': 'u',
        'ỵ': 'y',
      };
      for (final entry in tails.entries) {
        expect(romanizeLyrics(entry.key), entry.value, reason: entry.key);
      }
    });

    test('Latin lyrics are left alone', () {
      expect(romanizeLyrics('hello world'), 'hello world');
      expect(romanizeLyrics('   '), '');
    });
  });
}
