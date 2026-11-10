import 'dart:math';

/// Builds a play order for [length] items where the item at [first] comes first
/// and every other index appears exactly once.
///
/// A Fisher–Yates deal, so every arrangement is equally likely. Because the
/// result is a permutation, no track repeats until the queue has been played
/// through — a guarantee the UI cannot make when it is handed an unordered
/// `just_audio` shuffle order it cannot see.
List<int> shuffledOrder(int length, {int first = 0, Random? random}) {
  if (length <= 0) return const [];
  final order = [for (var i = 0; i < length; i++) i];
  final rng = random ?? Random();
  for (var i = length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final swap = order[i];
    order[i] = order[j];
    order[j] = swap;
  }

  // Whatever was dealt, the current track stays where it is: enabling shuffle
  // must not interrupt what is already playing.
  final head = first.clamp(0, length - 1);
  if (head != 0) {
    final at = order.indexOf(head);
    order[at] = order[0];
    order[0] = head;
  }
  return order;
}
