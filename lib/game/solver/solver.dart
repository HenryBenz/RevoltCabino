import 'dart:collection';

import '../../models/core.dart';
import '../../models/game_state.dart';
import '../../models/level.dart';
import '../simulation/simulation.dart';

class SolvedPath {
  const SolvedPath(this.actions);

  final List<GameAction> actions;
}

class PathSearch {
  const PathSearch.found(this.path) : limited = false;
  const PathSearch.limited() : path = null, limited = true;
  const PathSearch.none() : path = null, limited = false;

  final SolvedPath? path;
  final bool limited;
}

class HintSearch {
  const HintSearch({
    required this.action,
    required this.instruction,
    required this.unreachable,
    required this.limited,
  });

  final GameAction? action;
  final String? instruction;
  final bool unreachable;
  final bool limited;
}

const solverNodeLimit = 250000;

class _Node {
  const _Node(this.state, this.parent, this.action);

  final GameState state;
  final int parent;
  final GameAction? action;
}

List<GameAction> _rebuild(List<_Node> nodes, int index) {
  final actions = <GameAction>[];
  var cursor = index;
  while (nodes[cursor].parent >= 0) {
    actions.add(nodes[cursor].action!);
    cursor = nodes[cursor].parent;
  }
  return actions.reversed.toList();
}

PathSearch shortestPath(
  Level level,
  GameState start, {
  bool requireFragment = false,
  int limit = solverNodeLimit,
}) {
  final nodes = <_Node>[_Node(start, -1, null)];
  final queue = Queue<int>()..add(0);
  final seen = <String>{start.key};
  var expanded = 0;
  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    final current = nodes[index].state;
    expanded++;
    if (expanded > limit) return const PathSearch.limited();
    for (final action in legalActions(level, current)) {
      final result = applyAction(level, current, action);
      if (result == null || result.state.key == current.key) continue;
      if (result.outcome == Outcome.lost) continue;
      if (result.outcome == Outcome.won &&
          (!requireFragment || result.state.fragmentCollected)) {
        nodes.add(_Node(result.state, index, action));
        return PathSearch.found(SolvedPath(_rebuild(nodes, nodes.length - 1)));
      }
      if (result.outcome == Outcome.won) continue;
      if (seen.add(result.state.key)) {
        nodes.add(_Node(result.state, index, action));
        queue.add(nodes.length - 1);
      }
    }
  }
  return const PathSearch.none();
}

Map<String, Object?> searchHintWire(
  Map<String, Object?> levelJson,
  Map<String, Object?> stateJson,
) {
  final level = Level.fromJson(levelJson);
  final hint = searchHint(level, GameState.fromJson(stateJson, level));
  return {
    'action': hint.action == null ? null : actionToWire(hint.action!),
    'instruction': hint.instruction,
    'unreachable': hint.unreachable,
    'limited': hint.limited,
  };
}

HintSearch searchHint(Level level, GameState state, {int limit = 120000}) {
  if (_alreadyDead(level, state)) {
    return const HintSearch(
      action: null,
      instruction: null,
      unreachable: true,
      limited: false,
    );
  }
  final found = shortestPath(level, state, limit: limit);
  if (found.limited) {
    return const HintSearch(
      action: null,
      instruction: null,
      unreachable: false,
      limited: true,
    );
  }
  final path = found.path;
  if (path == null || path.actions.isEmpty) {
    return const HintSearch(
      action: null,
      instruction: null,
      unreachable: true,
      limited: false,
    );
  }
  final first = path.actions.first;
  final firstResult = applyAction(level, state, first)!;
  return HintSearch(
    action: first,
    instruction: instructionFor(level, state, first, firstResult),
    unreachable: false,
    limited: false,
  );
}

List<GameAction> legalActions(Level level, GameState state) {
  return [
    for (final direction in Direction.values)
      if (direction != state.gravity) GravityAction(direction),
    if (level.hasMagnets) const MagnetAction(),
  ];
}

String instructionFor(
  Level level,
  GameState before,
  GameAction action,
  SimResult result,
) {
  switch (action) {
    case GravityAction(:final direction):
      final text = StringBuffer('Set gravity ${direction.label}.');
      final beforePlates = activePlateIds(level, before);
      final afterPlates = activePlateIds(level, result.state);
      if (afterPlates.difference(beforePlates).isNotEmpty) {
        final cargoHeld = result.state.cargo.values.any(
          (cell) => level.plates.any(
            (plate) =>
                afterPlates.contains(plate.id) &&
                !beforePlates.contains(plate.id) &&
                plate.position == cell,
          ),
        );
        text.write(
          cargoHeld
              ? ' The cargo will hold the plate.'
              : ' The plate will be held.',
        );
      }
      final beforeGates = openGateIds(level, before, beforePlates);
      final afterGates = openGateIds(level, result.state, afterPlates);
      if (afterGates.difference(beforeGates).isNotEmpty) {
        text.write(' The gate will open.');
      }
      if (result.outcome == Outcome.won) {
        text.write(' You will reach the exit.');
      }
      return text.toString();
    case MagnetAction():
      if (before.magnetsEnabled) {
        final moved = result.frames.isNotEmpty;
        return moved
            ? 'Turn magnets OFF. Anchored cargo will move with gravity.'
            : 'Turn magnets OFF.';
      }
      return 'Turn magnets ON. Cargo on a magnetic pad will stay in place.';
  }
}

String? curatedHintForState(Level level, GameState state) {
  var cursor = initialState(level);
  if (cursor.key == state.key && level.curatedHints.isNotEmpty) {
    return level.curatedHints.first;
  }
  for (var index = 0; index < level.referenceSolution.length; index++) {
    final result = applyAction(
      level,
      cursor,
      actionFromWire(level.referenceSolution[index]),
    );
    if (result == null) return null;
    cursor = result.state;
    if (cursor.key == state.key && index + 1 < level.curatedHints.length) {
      return level.curatedHints[index + 1];
    }
  }
  return null;
}

bool _alreadyDead(Level level, GameState state) => playerInLaser(level, state);
