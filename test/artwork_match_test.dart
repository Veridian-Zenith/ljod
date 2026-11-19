import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/services/library/artwork_match.dart';

void main() {
  group('normalizeArtworkText', () {
    test('folds case, punctuation and spacing', () {
      expect(
        normalizeArtworkText('  Хулиганка (Phonk  Remix) '),
        'хулиганка phonk remix',
      );
      expect(
        normalizeArtworkText('NEEL — Холодный подонок'),
        'neel холодный подонок',
      );
    });

    test('keeps digits and drops everything else', () {
      expect(normalizeArtworkText('24/7 (Deluxe)'), '24 7 deluxe');
      expect(normalizeArtworkText('...'), '');
    });
  });

  group('artworkMemoKey', () {
    test('uses the album when there is one', () {
      expect(
        artworkMemoKey(artist: 'NEEL', album: 'Phonk', title: 'Anything'),
        'neel|phonk',
      );
    });

    test('falls back to the title for untagged albums', () {
      expect(
        artworkMemoKey(artist: 'WELLAY', album: '  ', title: 'Хулиганка'),
        'wellay|хулиганка',
      );
    });

    test('an empty identity has no key', () {
      expect(artworkMemoKey(artist: '', album: '', title: ''), '');
    });
  });

  group('pickDeezerCover', () {
    test('prefers the exact album over a near match', () {
      final payload = {
        'data': [
          {'title': 'Phonk Anthems', 'cover_xl': 'https://cdn/near.jpg'},
          {'title': 'Phonk', 'cover_xl': 'https://cdn/exact.jpg'},
        ],
      };
      expect(pickDeezerCover(payload, album: 'Phonk'), 'https://cdn/exact.jpg');
    });

    test('reads track results where the album is nested', () {
      final payload = {
        'data': [
          {
            'title': 'Хулиганка',
            'album': {'title': 'Remixes', 'cover_xl': 'https://cdn/xl.jpg'},
          },
        ],
      };
      expect(pickDeezerCover(payload, album: 'Remixes'), 'https://cdn/xl.jpg');
    });

    test('falls back to the first cover when names differ', () {
      final payload = {
        'data': [
          {'title': 'Unknown', 'cover_xl': 'https://cdn/include.jpg'},
        ],
      };
      expect(
        pickDeezerCover(payload, album: 'Phonk'),
        'https://cdn/include.jpg',
      );
    });

    test('no data means no cover', () {
      expect(pickDeezerCover(const {}, album: 'Phonk'), isNull);
    });
  });

  group('pickItunesCover', () {
    test('upscales the thumbnail to 600 px', () {
      final payload = {
        'results': [
          {
            'collectionName': 'Phonk',
            'artworkUrl100': 'https://itunes/a/100x100bb.jpg',
          },
        ],
      };
      expect(
        pickItunesCover(payload, album: 'Phonk'),
        'https://itunes/a/600x600bb.jpg',
      );
    });

    test('leaves an unrecognised size alone', () {
      expect(
        itunesArtworkUrl('https://itunes/a/cover.jpg'),
        'https://itunes/a/cover.jpg',
      );
      expect(itunesArtworkUrl('not a url'), isNull);
    });
  });
}
