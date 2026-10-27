import '../../models/core.dart';
import '../../models/game_state.dart';
import '../../models/level.dart';

enum Outcome { playing, won, lost }

class Beam {
  const Beam({
    required this.emitterId,
    required this.origin,
    required this.direction,
    required this.lethal,
    required this.stoppedBy,
  });

  final String emitterId;
  final Cell origin;
  final Direction direction;
  final List<Cell> lethal;
  final Cell? stoppedBy;
}

class SimFrame {
  const SimFrame({
    required this.player,
    required this.cargo,
    required this.anchored,
    required this.fragmentCollected,
    required this.activePlateIds,
    required this.openGateIds,
    required this.beams,
    required this.won,
    required this.lost,
  });

  final Cell player;
  final Map<String, Cell> cargo;
  final Set<String> anchored;
  final bool fragmentCollected;
  final Set<String> activePlateIds;
  final Set<String> openGateIds;
  final List<Beam> beams;
  final bool won;
  final bool lost;
}

class SimResult {
  const SimResult({
    required this.state,
    required this.outcome,
    required this.frames,
  });

  final GameState state;
  final Outcome outcome;
  final List<SimFrame> frames;
}

class BoardFacts {
  const BoardFacts({
    required this.activePlateIds,
    required this.openGateIds,
    required this.beams,
  });

  final Set<String> activePlateIds;
  final Set<String> openGateIds;
  final List<Beam> beams;
}

BoardFacts inspect(Level level, GameState state) {
  final plates = activePlateIds(level, state);
  final gates = openGateIds(level, state, plates);
  return BoardFacts(
    activePlateIds: plates,
    openGateIds: gates,
    beams: laserBeams(level, state, gates),
  );
}

bool exitIsReady(Level level, Set<String> plates) {
  return level.exitRequiredPlateIds.every(plates.contains);
}

Set<String> activePlateIds(Level level, GameState state) {
  final active = <String>{};
  for (final plate in level.plates) {
    if (_occupied(state, plate.position)) active.add(plate.id);
  }
  return active;
}

Set<String> openGateIds(
  Level level,
  GameState state,
  Set<String> plates,
) {
  final open = <String>{};
  for (final gate in level.gates) {
    final powered = gate.plateIds.every(plates.contains);
    if (powered || _occupied(state, gate.position)) open.add(gate.id);
  }
  return open;
}

List<Beam> laserBeams(Level level, GameState state, Set<String> openGates) {
  final closedGates = {
    for (final gate in level.gates)
      if (!openGates.contains(gate.id)) gate.position,
  };
  final cargoCells = state.cargo.values.toSet();
  final beams = <Beam>[];
  for (final emitter in level.laserEmitters) {
    final lethal = <Cell>[];
    var cursor = emitter.position.shift(emitter.direction);
    Cell? stoppedBy;
    while (_inside(level, cursor)) {
      if (level.wallSet.contains(cursor) ||
          closedGates.contains(cursor) ||
          cargoCells.contains(cursor)) {
        stoppedBy = cursor;
        break;
      }
      lethal.add(cursor);
      cursor = cursor.shift(emitter.direction);
    }
    beams.add(
      Beam(
        emitterId: emitter.id,
        origin: emitter.position,
        direction: emitter.direction,
        lethal: lethal,
        stoppedBy: stoppedBy,
      ),
    );
  }
  return beams;
}

bool playerInLaser(Level level, GameState state) {
  final facts = inspect(level, state);
  return facts.beams.any((beam) => beam.lethal.contains(state.player));
}

SimResult resolve(Level level, GameState input) {
  var state = input;
  final frames = <SimFrame>[];
  final maxTicks = level.width + level.height + 4;
  while (frames.length < maxTicks) {
    final tick = _tick(level, state);
    if (tick == null) break;
    state = tick.$1;
    frames.add(tick.$2);
    if (tick.$2.won || tick.$2.lost) break;
  }
  final outcome = frames.isEmpty
      ? Outcome.playing
      : frames.last.lost
      ? Outcome.lost
      : frames.last.won
      ? Outcome.won
      : Outcome.playing;
  return SimResult(state: state, outcome: outcome, frames: frames);
}

SimResult? applyAction(Level level, GameState state, GameAction action) {
  switch (action) {
    case GravityAction(:final direction):
      if (direction == state.gravity) return null;
      return resolve(
        level,
        state.copyWith(gravity: direction, actionCount: state.actionCount + 1),
      );
    case MagnetAction():
      if (!level.hasMagnets) return null;
      final enabled = !state.magnetsEnabled;
      final anchored = anchorsFor(level, state.cargo, enabled);
      return resolve(
        level,
        state.copyWith(
          magnetsEnabled: enabled,
          anchored: anchored,
          actionCount: state.actionCount + 1,
        ),
      );
  }
}

bool isStable(Level level) {
  final result = resolve(level, initialState(level));
  return result.frames.isEmpty && result.outcome == Outcome.playing;
}

(GameState, SimFrame)? _tick(Level level, GameState state) {
  final platesBefore = activePlateIds(level, state);
  final openBefore = openGateIds(level, state, platesBefore);
  final closed = {
    for (final gate in level.gates)
      if (!openBefore.contains(gate.id)) gate.id: gate.position,
  };

  final positions = <String, Cell>{'player': state.player, ...state.cargo};
  final movers = <String>[
    'player',
    for (final id in state.cargo.keys)
      if (!state.anchored.contains(id)) id,
  ];
  movers.sort((a, b) {
    final distance = _edgeDistance(
      positions[a]!,
      state.gravity,
      level,
    ).compareTo(_edgeDistance(positions[b]!, state.gravity, level));
    if (distance != 0) return distance;
    return a.compareTo(b);
  });

  final next = Map<String, Cell>.from(positions);
  var moved = false;
  for (final id in movers) {
    final destination = next[id]!.shift(state.gravity);
    if (!_inside(level, destination)) continue;
    if (level.wallSet.contains(destination)) continue;
    if (level.emitterSet.contains(destination)) continue;
    if (closed.values.contains(destination)) continue;
    if (next.values.any((cell) => cell == destination)) continue;
    next[id] = destination;
    moved = true;
  }
  if (!moved) return null;

  final cargo = <String, Cell>{
    for (final id in state.cargo.keys) id: next[id]!,
  };
  final anchored = <String>{...state.anchored};
  if (state.magnetsEnabled) {
    for (final entry in cargo.entries) {
      if (level.magnetSet.contains(entry.value)) anchored.add(entry.key);
    }
  } else {
    anchored.clear();
  }

  final player = next['player']!;
  final fragment =
      state.fragmentCollected ||
      (level.memoryFragment != null && player == level.memoryFragment);
  final updated = state.copyWith(
    player: player,
    cargo: cargo,
    anchored: anchored,
    fragmentCollected: fragment,
  );
  final plates = activePlateIds(level, updated);
  final gates = openGateIds(level, updated, plates);
  final beams = laserBeams(level, updated, gates);
  final lost = beams.any((beam) => beam.lethal.contains(player));
  final won = !lost && player == level.exit && exitIsReady(level, plates);
  return (
    updated,
    SimFrame(
      player: player,
      cargo: cargo,
      anchored: anchored,
      fragmentCollected: fragment,
      activePlateIds: plates,
      openGateIds: gates,
      beams: beams,
      won: won,
      lost: lost,
    ),
  );
}

bool _occupied(GameState state, Cell cell) {
  if (state.player == cell) return true;
  return state.cargo.values.any((position) => position == cell);
}

bool _inside(Level level, Cell cell) {
  return cell.x >= 0 &&
      cell.y >= 0 &&
      cell.x < level.width &&
      cell.y < level.height;
}

int _edgeDistance(Cell cell, Direction gravity, Level level) {
  return switch (gravity) {
    Direction.down => level.height - 1 - cell.y,
    Direction.up => cell.y,
    Direction.right => level.width - 1 - cell.x,
    Direction.left => cell.x,
  };
}
