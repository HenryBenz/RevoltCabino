import 'package:revolt_cabino/game/simulation/simulation.dart';
import 'package:revolt_cabino/game/solver/solver.dart';
import 'package:revolt_cabino/models/core.dart';
import 'package:revolt_cabino/models/game_state.dart';
import 'package:revolt_cabino/models/level.dart';
import 'author_levels.dart';

void main() {
  final bases = <String, List<String>>{
    'cold': const [
      '#######',
      '#@..#.#',
      '##.#.##',
      '#.A...#',
      '#..>..#',
      '#.....#',
      '##.#.##',
      '#.....#',
      '#######',
    ],
    'magnet': const [
      '#######',
      '#@....#',
      '###.#.#',
      '#.A.1.#',
      '###4#.#',
      '#.....#',
      '#.....#',
      '#.....#',
      '#######',
    ],
    'laser': const [
      '#######',
      '#.@..##',
      '####.##',
      '#.1a..#',
      '##4^.##',
      '#.....#',
      '#.#...#',
      '#.#...#',
      '#######',
    ],
  };
  for (final entry in bases.entries) {
    final hits = <int, List<String>>{};
    final rows = entry.value;
    for (var ey = 1; ey <= 7; ey++) {
      for (var ex = 1; ex <= 5; ex++) {
        final grid = [for (final row in rows) row.split('')];
        final previous = grid[ey][ex];
        if (previous == '#' || previous == '@') continue;
        grid[ey][ex] = 'X';
        final draft = Draft(entry.key, entry.key, grid.map((row) => row.join()).toList());
        try {
          final level = parseDraft(draft, 0);
          if (instabilityOf(level) != null) continue;
          final search = shortestPath(level, initialState(level), limit: 30000);
          final length = search.path?.actions.length ?? 0;
          if (length < 3) continue;
          hits.putIfAbsent(length, () => []).add(draft.grid.join(' / '));
        } catch (_) {}
      }
    }
    print('BASE ${entry.key}');
    final lengths = hits.keys.toList()..sort();
    for (final length in lengths) {
      for (final grid in hits[length]!) {
        print('$length $grid');
      }
    }
  }
}
