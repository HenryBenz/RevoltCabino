import 'dart:convert';
import 'dart:io';

import 'package:revolt_cabino/game/simulation/simulation.dart';
import 'package:revolt_cabino/game/solver/solver.dart';
import 'package:revolt_cabino/models/core.dart';
import 'package:revolt_cabino/models/game_state.dart';
import 'package:revolt_cabino/models/level.dart';

import 'grids.dart';
import 'package:revolt_cabino/game/levels/validator.dart';


const _chapters = <String>[
  'awakening', 'awakening', 'awakening', 'awakening', 'awakening', 'awakening',
  'pressure', 'pressure', 'pressure', 'pressure', 'pressure', 'pressure',
  'magnetic_hold', 'magnetic_hold', 'magnetic_hold', 'magnetic_hold', 'magnetic_hold', 'magnetic_hold',
  'white_line', 'white_line', 'white_line', 'white_line', 'white_line', 'white_line',
  'revolt', 'revolt', 'revolt', 'revolt', 'revolt', 'revolt',
  'forbidden_sector', 'forbidden_sector', 'forbidden_sector', 'forbidden_sector', 'forbidden_sector',
  'forbidden_sector', 'forbidden_sector', 'forbidden_sector', 'forbidden_sector', 'forbidden_sector',
];

void main() {
  if (drafts.length != 40) {
    stderr.writeln('Expected 40 drafts, found ${drafts.length}');
    exit(1);
  }
  final levels = <Level>[];
  final problems = <String>[];
  for (var index = 0; index < drafts.length; index++) {
    final draft = drafts[index];
    try {
      final parsed = _parse(draft, index);
      final solved = _solve(parsed);
      levels.add(solved);
      stdout.writeln(
        '${solved.id}  ${solved.referenceSolution.join(',')}  ${_route(solved)}  ${solved.title}',
      );
    } catch (error) {
      problems.add('${_idFor(index)} ${draft.title}: $error');
      stdout.writeln('FAIL ${_idFor(index)} ${draft.title}: $error');
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln('${problems.length} levels failed');
    exit(1);
  }
  _assignTutorials(levels);
  final issues = validateCampaign(levels);
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln(issue);
    }
    exit(1);
  }
  final directory = Directory('assets/levels');
  directory.createSync(recursive: true);
  for (final level in levels) {
    File('${directory.path}/${level.id}.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(level.toJson())}\n',
    );
  }
  stdout.writeln('Wrote ${levels.length} levels');
}

Level _solve(Level level) {
  final unstable = _instability(level);
  if (unstable != null) {
    throw Exception('unstable ($unstable)');
  }
  if (playerInLaser(level, initialState(level))) {
    throw Exception('player starts in a laser');
  }
  final search = shortestPath(level, initialState(level));
  if (search.limited) throw Exception('solver limit');
  final path = search.path;
  if (path == null || path.actions.isEmpty) throw Exception('no exit route');
  final fragment = _fragmentOnPath(level, path.actions);
  final placed = level.copyWith(updateFragment: true, memoryFragment: fragment);
  final withFragment = shortestPath(
    placed,
    initialState(placed),
    requireFragment: true,
  );
  final chosen = withFragment.path ?? path;
  if (withFragment.path == null) {
    throw Exception('fragment cannot be collected');
  }
  var cursor = initialState(placed);
  final hints = <String>[];
  for (final action in chosen.actions) {
    final result = applyAction(placed, cursor, action);
    if (result == null) throw Exception('solution step stalled');
    hints.add(instructionFor(placed, cursor, action, result));
    cursor = result.state;
    if (result.outcome == Outcome.lost) throw Exception('solution hits a laser');
  }
  if (cursor.player != placed.exit || !cursor.fragmentCollected) {
    throw Exception('finished solution is incomplete');
  }
  final optimal = search.path!.actions.length;
  return placed.copyWith(
    efficiencyTarget: optimal,
    referenceSolution: chosen.actions.map(actionToWire).toList(),
    curatedHints: hints,
  );
}

String? _instability(Level level) {
  final start = initialState(level);
  final result = resolve(level, start);
  if (result.frames.isEmpty) return null;
  final notes = <String>[];
  if (result.state.player != start.player) {
    notes.add('player ${start.player}->${result.state.player}');
  }
  for (final id in start.cargo.keys) {
    if (result.state.cargo[id] != start.cargo[id]) {
      notes.add('$id ${start.cargo[id]}->${result.state.cargo[id]}');
    }
  }
  return notes.isEmpty ? 'state changed' : notes.join(', ');
}

Cell _fragmentOnPath(Level level, List<GameAction> actions) {
  var state = initialState(level);
  final visited = <Cell>[state.player];
  for (final action in actions) {
    final result = applyAction(level, state, action)!;
    for (final frame in result.frames) {
      visited.add(frame.player);
    }
    state = result.state;
  }
  final preferred = level.memoryFragment;
  if (preferred != null &&
      visited.contains(preferred) &&
      _legalFragment(level, preferred)) {
    return preferred;
  }
  for (final cell in visited.reversed) {
    if (cell == level.exit) continue;
    if (_legalFragment(level, cell)) return cell;
  }
  if (_legalFragment(level, level.exit)) return level.exit;
  throw Exception('no legal fragment cell on the route');
}

bool _legalFragment(Level level, Cell cell) {
  if (cell == level.playerStart) return false;
  if (level.wallSet.contains(cell)) return false;
  if (level.emitterSet.contains(cell)) return false;
  if (level.gates.any((gate) => gate.position == cell)) return false;
  if (level.cargo.any((cargo) => cargo.position == cell)) return false;
  return true;
}

void _assignTutorials(List<Level> levels) {
  final ordered = [...levels];
  String? firstWhere(bool Function(Level level) test) {
    for (final level in ordered) {
      if (test(level)) return level.id;
    }
    return null;
  }

  final tutors = {
    ordered.first.id: 'gravity',
    firstWhere((level) => level.cargo.isNotEmpty): 'cargo',
    firstWhere((level) => level.plates.isNotEmpty): 'plate',
    firstWhere((level) => level.magneticPads.isNotEmpty): 'magnet',
    firstWhere((level) => level.laserEmitters.isNotEmpty): 'laser',
  };
  for (var index = 0; index < levels.length; index++) {
    final tutorial = tutors[levels[index].id];
    levels[index] = tutorial == null
        ? levels[index].copyWith(clearTutorial: true)
        : levels[index].copyWith(tutorialId: tutorial);
  }
}

Level _parse(Draft draft, int index) {
  if (draft.grid.length != 9) {
    throw Exception('grid must have 9 rows');
  }
  final walls = <Cell>[];
  Cell? player;
  Cell? exit;
  Cell? fragment;
  final cargo = <CargoDef>[];
  final pads = <Cell>[];
  final lasers = <LaserDef>[];
  final platePos = <String, Cell>{};
  final gatePos = <String, Cell>{};
  var laserCount = 0;
  for (var y = 0; y < 9; y++) {
    final row = draft.grid[y];
    if (row.length != 7) throw Exception('row $y width ${row.length}');
    for (var x = 0; x < 7; x++) {
      final char = row[x];
      final cell = Cell(x, y);
      switch (char) {
        case '#':
          walls.add(cell);
        case '.':
          break;
        case '@':
          player = cell;
        case 'X':
          exit = cell;
        case 'f':
          fragment = cell;
        case 'm':
          pads.add(cell);
        case 'a':
          cargo.add(CargoDef(id: 'c1', position: cell));
        case 'D':
          cargo.add(CargoDef(id: 'c1', position: cell));
          platePos['p1'] = cell;
        case 'b':
          cargo.add(CargoDef(id: 'c2', position: cell));
        case 'c':
          cargo.add(CargoDef(id: 'c3', position: cell));
        case 'A':
          cargo.add(CargoDef(id: 'c1', position: cell));
          pads.add(cell);
        case 'B':
          cargo.add(CargoDef(id: 'c2', position: cell));
          pads.add(cell);
        case 'C':
          cargo.add(CargoDef(id: 'c3', position: cell));
          pads.add(cell);
        case '1':
          platePos['p1'] = cell;
        case '2':
          platePos['p2'] = cell;
        case '3':
          platePos['p3'] = cell;
        case '4':
          gatePos['g1'] = cell;
        case '5':
          gatePos['g2'] = cell;
        case '6':
          gatePos['g3'] = cell;
        case '7':
          gatePos['g4'] = cell;
        case '8':
          gatePos['g5'] = cell;
        case '9':
          gatePos['g6'] = cell;
        case '^':
        case '>':
        case 'v':
        case '<':
          laserCount++;
          lasers.add(
            LaserDef(
              id: 'l$laserCount',
              position: cell,
              direction: switch (char) {
                '^' => Direction.up,
                '>' => Direction.right,
                'v' => Direction.down,
                _ => Direction.left,
              },
            ),
          );
        default:
          throw Exception('unknown char $char');
      }
    }
  }
  if (player == null || exit == null) throw Exception('missing player or exit');
  final gates = <GateDef>[
    if (gatePos['g1'] != null)
      GateDef(id: 'g1', position: gatePos['g1']!, plateIds: const ['p1'], symbol: 'dot'),
    if (gatePos['g2'] != null)
      GateDef(id: 'g2', position: gatePos['g2']!, plateIds: const ['p2'], symbol: 'double'),
    if (gatePos['g3'] != null)
      GateDef(id: 'g3', position: gatePos['g3']!, plateIds: const ['p3'], symbol: 'triangle'),
    if (gatePos['g4'] != null)
      GateDef(
        id: 'g4',
        position: gatePos['g4']!,
        plateIds: const ['p1', 'p2'],
        symbol: 'triangle',
      ),
    if (gatePos['g5'] != null)
      GateDef(
        id: 'g5',
        position: gatePos['g5']!,
        plateIds: const ['p2', 'p3'],
        symbol: 'triangle',
      ),
    if (gatePos['g6'] != null)
      GateDef(
        id: 'g6',
        position: gatePos['g6']!,
        plateIds: const ['p1', 'p2', 'p3'],
        symbol: 'triangle',
      ),
  ];
  String symbolFor(String plateId) {
    final linked = gates.where((gate) => gate.plateIds.contains(plateId));
    if (linked.any((gate) => gate.plateIds.length > 1)) return 'triangle';
    if (linked.isEmpty) {
      return switch (plateId) {
        'p1' => 'dot',
        'p2' => 'double',
        _ => 'triangle',
      };
    }
    return linked.first.symbol;
  }

  final plates = [
    for (final entry in platePos.entries)
      PlateDef(
        id: entry.key,
        position: entry.value,
        symbol: symbolFor(entry.key),
      ),
  ];
  return Level(
    id: _idFor(index),
    chapterId: _chapters[index],
    number: index < 30 ? index + 1 : index - 29,
    title: draft.title,
    width: 7,
    height: 9,
    walls: walls,
    playerStart: player,
    cargo: cargo,
    exit: exit,
    exitRequiredPlateIds: const [],
    plates: plates,
    gates: gates,
    magneticPads: pads,
    magnetsInitiallyEnabled: true,
    laserEmitters: lasers,
    memoryFragment: fragment,
    initialGravity: Direction.down,
    efficiencyTarget: 1,
    tutorialId: null,
    curatedHints: const [],
    referenceSolution: const [],
    mechanicFocus: draft.focus,
  );
}

String _route(Level level) {
  var state = initialState(level);
  final cells = <String>['${state.player.x}${state.player.y}'];
  for (final step in level.referenceSolution) {
    final result = applyAction(level, state, actionFromWire(step))!;
    state = result.state;
    cells.add('${state.player.x}${state.player.y}');
  }
  return cells.join('-');
}

Level parseDraft(Draft draft, int index) => _parse(draft, index);

String? instabilityOf(Level level) => _instability(level);

String _idFor(int index) => index < 30
    ? 'c${(index + 1).toString().padLeft(2, '0')}'
    : 'f${(index - 29).toString().padLeft(2, '0')}';
