import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/services/audio/playback_session.dart';
import 'package:ljod/services/audio/shuffle_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('shuffledOrder', () {
    test('is a permutation that starts with the requested track', () {
      final order = shuffledOrder(12, first: 7, random: Random(1));

      expect(order, hasLength(12));
      expect(order.toSet(), hasLength(12), reason: 'no index may repeat');
      expect(order.every((index) => index >= 0 && index < 12), isTrue);
      // Enabling shuffle must not interrupt the current track.
      expect(order.first, 7);
    });

    test('handles empty, single and out-of-range requests', () {
      expect(shuffledOrder(0), isEmpty);
      expect(shuffledOrder(1), [0]);
      expect(shuffledOrder(1, first: 9), [0]);
      expect(shuffledOrder(3, first: -4).first, 0);
    });

    test('deals a different order on each run', () {
      // Two independent 10-item deals match with probability 1/10!.
      final first = shuffledOrder(10, random: Random(2));
      final second = shuffledOrder(10, random: Random(3));

      expect(first, isNot(equals(second)));
    });
  });

  group('PlaybackSessionStore', () {
    late SharedPreferences preferences;
    late PlaybackSessionStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      store = PlaybackSessionStore(preferences);
    });

    test('round-trips the queue, position, shuffle and repeat', () async {
      await store.write(
        const PlaybackSession(
          queue: ['a', 'b', 'c'],
          index: 1,
          position: Duration(seconds: 42),
          repeat: PlaybackRepeat.one,
          shuffle: true,
        ),
      );

      final restored = store.read();
      expect(restored, isNotNull);
      expect(restored!.queue, ['a', 'b', 'c']);
      expect(restored.index, 1);
      expect(restored.position, const Duration(seconds: 42));
      expect(restored.repeat, PlaybackRepeat.one);
      expect(restored.shuffle, isTrue);
    });

    test('clamps an index that no longer fits the queue', () async {
      await store.write(
        const PlaybackSession(
          queue: ['a'],
          index: 5,
          position: Duration.zero,
          repeat: PlaybackRepeat.off,
        ),
      );

      expect(store.read()!.index, 0);
    });

    test('ignores a missing, corrupt or empty entry', () async {
      expect(store.read(), isNull);

      await preferences.setString(PlaybackSessionStore.key, '{not json');
      expect(store.read(), isNull);

      await preferences.setString(PlaybackSessionStore.key, '{"queue": []}');
      expect(store.read(), isNull);
    });

    test('clear forgets the session', () async {
      await store.write(
        const PlaybackSession(
          queue: ['a'],
          index: 0,
          position: Duration.zero,
          repeat: PlaybackRepeat.off,
        ),
      );
      expect(store.read(), isNotNull);

      await store.clear();
      expect(store.read(), isNull);
    });
  });
}
