import '../../models/core.dart';
import '../../models/game_state.dart';
import '../../models/level.dart';
import '../simulation/simulation.dart';
import '../solver/solver.dart';
import 'progression.dart';

List<String> validateLevel(Level level) {
  final issues = <String>[];
  if (level.width != 7 || level.height != 9) {
    issues.add('dimensions must be 7x9');
  }
  if (level.title.trim().isEmpty) issues.add('missing title');
  if (level.mechanicFocus.trim().isEmpty) issues.add('missing mechanic focus');
  if (level.initialGravity != Direction.down) {
    issues.add('initial gravity must be down');
  }
  if (level.cargo.length > 3) issues.add('more than three cargo blocks');

  final ids = <String>[];
  void unique(String id, String label) {
    if (ids.contains(id)) issues.add('duplicate id $id');
    ids.add(id);
    if (id.trim().isEmpty) issues.add('empty $label id');
  }

  for (final cargo in level.cargo) {
    unique(cargo.id, 'cargo');
  }
  for (final plate in level.plates) {
    unique(plate.id, 'plate');
  }
  for (final gate in level.gates) {
    unique(gate.id, 'gate');
  }
  for (final laser in level.laserEmitters) {
    unique(laser.id, 'laser');
  }

  final wallCounts = <Cell, int>{};
  for (final wall in level.walls) {
    wallCounts[wall] = (wallCounts[wall] ?? 0) + 1;
  }
  for (final entry in wallCounts.entries) {
    if (entry.value > 1) issues.add('duplicate wall ${entry.key}');
  }
  for (var y = 0; y < level.height; y++) {
    for (var x = 0; x < level.width; x++) {
      final border = x == 0 || y == 0 || x == level.width - 1 || y == level.height - 1;
      if (border && !level.wallSet.contains(Cell(x, y))) {
        issues.add('open boundary at ($x,$y)');
      }
    }
  }

  final plateIds = level.plates.map((plate) => plate.id).toSet();
  for (final gate in level.gates) {
    if (gate.plateIds.isEmpty) issues.add('gate ${gate.id} has no plates');
    for (final plateId in gate.plateIds) {
      if (!plateIds.contains(plateId)) {
        issues.add('gate ${gate.id} references missing plate $plateId');
      }
    }
    if (!_symbols.contains(gate.symbol)) {
      issues.add('gate ${gate.id} has unknown symbol');
    }
  }
  for (final plate in level.plates) {
    if (!_symbols.contains(plate.symbol)) {
      issues.add('plate ${plate.id} has unknown symbol');
    }
  }
  for (final plateId in level.exitRequiredPlateIds) {
    if (!plateIds.contains(plateId)) {
      issues.add('exit requires missing plate $plateId');
    }
  }

  final occupied = <Cell, String>{};
  void claim(Cell cell, String label) {
    if (!_inside(level, cell)) {
      issues.add('$label is outside the board');
      return;
    }
    if (level.wallSet.contains(cell)) {
      issues.add('$label overlaps a wall at $cell');
    }
    final previous = occupied[cell];
    if (previous != null) issues.add('$label overlaps $previous at $cell');
    occupied[cell] = label;
  }

  claim(level.playerStart, 'player');
  claim(level.exit, 'exit');
  for (final cargo in level.cargo) {
    claim(cargo.position, cargo.id);
  }
  for (final laser in level.laserEmitters) {
    claim(laser.position, laser.id);
  }
  for (final gate in level.gates) {
    claim(gate.position, gate.id);
  }
  if (level.memoryFragment != null) claim(level.memoryFragment!, 'fragment');

  void floorFeature(Cell cell, String label) {
    if (!_inside(level, cell)) {
      issues.add('$label is outside the board');
      return;
    }
    if (level.wallSet.contains(cell)) issues.add('$label is on a wall');
    if (level.emitterSet.contains(cell)) issues.add('$label is on an emitter');
    if (level.gates.any((gate) => gate.position == cell)) {
      issues.add('$label is on a gate');
    }
  }

  final featureCells = <Cell, String>{};
  void feature(Cell cell, String label) {
    floorFeature(cell, label);
    final previous = featureCells[cell];
    if (previous != null) issues.add('$label overlaps $previous');
    featureCells[cell] = label;
  }

  for (final plate in level.plates) {
    feature(plate.position, plate.id);
  }
  for (final pad in level.magneticPads) {
    feature(pad, 'magnet$pad');
  }

  if (playerInLaser(level, initialState(level))) {
    issues.add('player starts in a laser');
  }
  if (!isStable(level)) issues.add('starting layout is not stable');

  if (level.referenceSolution.isEmpty) issues.add('missing reference solution');
  if (level.curatedHints.length != level.referenceSolution.length) {
    issues.add('curated hints do not match the reference solution');
  }
  if (level.efficiencyTarget < 1) issues.add('efficiency target is missing');

  var state = initialState(level);
  SimResult? last;
  for (final step in level.referenceSolution) {
    final result = applyAction(level, state, actionFromWire(step));
    if (result == null) {
      issues.add('reference step $step does not change the state');
      last = null;
      break;
    }
    if (result.outcome == Outcome.lost) {
      issues.add('reference solution hits a laser');
      last = result;
      break;
    }
    state = result.state;
    last = result;
  }
  if (last != null && last.outcome != Outcome.won) {
    issues.add('reference solution does not reach the exit');
  }
  if (level.memoryFragment != null &&
      last != null &&
      last.outcome == Outcome.won &&
      !last.state.fragmentCollected) {
    issues.add('reference solution misses the memory fragment');
  }

  final optimal = shortestPath(level, initialState(level));
  if (optimal.limited) {
    issues.add('solver exceeded its resource budget');
  } else if (optimal.path == null) {
    issues.add('exit is not reachable');
  } else if (optimal.path!.actions.isEmpty) {
    issues.add('exit is already reached at the start');
  } else if (optimal.path!.actions.length > level.efficiencyTarget) {
    issues.add('efficiency badge is not achievable');
  }

  if (level.memoryFragment != null) {
    final withFragment = shortestPath(
      level,
      initialState(level),
      requireFragment: true,
    );
    if (withFragment.limited) {
      issues.add('fragment search exceeded its resource budget');
    } else if (withFragment.path == null) {
      issues.add('memory fragment is not reachable in a successful run');
    }
  }

  return issues;
}

List<String> validateCampaign(List<Level> levels) {
  final issues = <String>[];
  if (levels.length != 40) issues.add('expected 40 levels, found ${levels.length}');
  final ids = <String>{};
  final titles = <String>{};
  final layouts = <String, String>{};
  for (final level in levels) {
    if (!ids.add(level.id)) issues.add('duplicate level id ${level.id}');
    if (!titles.add(level.title)) issues.add('duplicate title ${level.title}');
    final key = _layoutKey(level);
    for (final previous in layouts.entries) {
      if (previous.value == key ||
          previous.value == _layoutKey(level, flipX: true) ||
          previous.value == _layoutKey(level, flipY: true) ||
          previous.value == _layoutKey(level, flipX: true, flipY: true)) {
        issues.add('${level.id} mirrors ${previous.key}');
      }
    }
    layouts[level.id] = key;
    issues.addAll(validateLevel(level).map((issue) => '${level.id}: $issue'));
  }

  final ordered = _ordered(levels);
  if (ordered.where((level) => chapters
          .firstWhere((chapter) => chapter.id == level.chapterId)
          .free)
      .length !=
      30) {
    issues.add('expected 30 free levels');
  }
  for (final chapter in chapters) {
    final count = levels.where((level) => level.chapterId == chapter.id).length;
    final expected = chapter.free ? 6 : 10;
    if (count != expected) {
      issues.add('${chapter.name} has $count levels');
    }
  }

  if (ordered.isNotEmpty) {
    _expectTutorial(issues, ordered, ordered.first, 'gravity');
    _expectTutorial(
      issues,
      ordered,
      ordered.firstWhere((level) => level.cargo.isNotEmpty),
      'cargo',
    );
    _expectTutorial(
      issues,
      ordered,
      ordered.firstWhere((level) => level.plates.isNotEmpty),
      'plate',
    );
    _expectTutorial(
      issues,
      ordered,
      ordered.firstWhere((level) => level.magneticPads.isNotEmpty),
      'magnet',
    );
    _expectTutorial(
      issues,
      ordered,
      ordered.firstWhere((level) => level.laserEmitters.isNotEmpty),
      'laser',
    );
  }
  const allowed = {'gravity', 'cargo', 'plate', 'magnet', 'laser'};
  for (final level in ordered) {
    final tutorial = level.tutorialId;
    if (tutorial != null && !allowed.contains(tutorial)) {
      issues.add('${level.id} has unknown tutorial $tutorial');
    }
  }
  return issues;
}

void _expectTutorial(
  List<String> issues,
  List<Level> ordered,
  Level level,
  String tutorialId,
) {
  if (level.tutorialId != tutorialId) {
    issues.add('${level.id} should teach $tutorialId');
  }
  for (final other in ordered) {
    if (other.id != level.id && other.tutorialId == tutorialId) {
      issues.add('${other.id} repeats the $tutorialId tutorial');
    }
  }
}

List<Level> _ordered(List<Level> levels) {
  final copy = [...levels];
  copy.sort((a, b) {
    final chapter = chapters
        .indexWhere((chapter) => chapter.id == a.chapterId)
        .compareTo(chapters.indexWhere((chapter) => chapter.id == b.chapterId));
    if (chapter != 0) return chapter;
    return a.number.compareTo(b.number);
  });
  return copy;
}

String _layoutKey(Level level, {bool flipX = false, bool flipY = false}) {
  Cell mapCell(Cell cell) => Cell(
    flipX ? level.width - 1 - cell.x : cell.x,
    flipY ? level.height - 1 - cell.y : cell.y,
  );
  String mapDirection(Direction direction) {
    if (flipX && direction == Direction.left) return Direction.right.name;
    if (flipX && direction == Direction.right) return Direction.left.name;
    if (flipY && direction == Direction.up) return Direction.down.name;
    if (flipY && direction == Direction.down) return Direction.up.name;
    return direction.name;
  }

  String cells(Iterable<Cell> values) =>
      (values.map(mapCell).toList()..sort((a, b) => a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x)))
          .map((cell) => '${cell.x},${cell.y}')
          .join(';');

  final gates = [
    for (final gate in level.gates)
      '${mapCell(gate.position)}:${[...gate.plateIds]..sort()}',
  ]..sort();
  final lasers = [
    for (final laser in level.laserEmitters)
      '${mapCell(laser.position)}:${mapDirection(laser.direction)}',
  ]..sort();
  return [
    cells(level.walls),
    mapCell(level.playerStart),
    cells(level.cargo.map((cargo) => cargo.position)),
    mapCell(level.exit),
    cells(level.plates.map((plate) => plate.position)),
    gates.join('|'),
    cells(level.magneticPads),
    lasers.join('|'),
    level.memoryFragment == null ? '' : mapCell(level.memoryFragment!),
    level.exitRequiredPlateIds.join(','),
    level.magnetsInitiallyEnabled,
  ].join('#');
}

bool _inside(Level level, Cell cell) =>
    cell.x >= 0 && cell.y >= 0 && cell.x < level.width && cell.y < level.height;

const _symbols = {'dot', 'double', 'triangle'};
