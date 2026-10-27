import 'core.dart';
import 'level.dart';

class GameState {
  GameState({
    required this.gravity,
    required this.player,
    required Map<String, Cell> cargo,
    required Set<String> anchored,
    required this.magnetsEnabled,
    required this.fragmentCollected,
    required this.actionCount,
  }) : cargo = Map.unmodifiable(cargo),
       anchored = Set.unmodifiable(anchored);

  final Direction gravity;
  final Cell player;
  final Map<String, Cell> cargo;
  final Set<String> anchored;
  final bool magnetsEnabled;
  final bool fragmentCollected;
  final int actionCount;

  String get key {
    final cargoKey = cargo.entries
        .map(
          (entry) =>
              '${entry.key}:${entry.value.x},${entry.value.y}${anchored.contains(entry.key) ? 'a' : ''}',
        )
        .join(';');
    return '${gravity.name}|${player.x},${player.y}|$cargoKey|${magnetsEnabled ? 1 : 0}|${fragmentCollected ? 1 : 0}';
  }

  GameState copyWith({
    Direction? gravity,
    Cell? player,
    Map<String, Cell>? cargo,
    Set<String>? anchored,
    bool? magnetsEnabled,
    bool? fragmentCollected,
    int? actionCount,
  }) {
    return GameState(
      gravity: gravity ?? this.gravity,
      player: player ?? this.player,
      cargo: cargo ?? this.cargo,
      anchored: anchored ?? this.anchored,
      magnetsEnabled: magnetsEnabled ?? this.magnetsEnabled,
      fragmentCollected: fragmentCollected ?? this.fragmentCollected,
      actionCount: actionCount ?? this.actionCount,
    );
  }

  Map<String, Object?> toJson() => {
    'gravityDirection': gravity.name,
    'playerPosition': [player.x, player.y],
    'cargoPositions': {
      for (final entry in cargo.entries)
        entry.key: [entry.value.x, entry.value.y],
    },
    'magnetState': magnetsEnabled,
    'attemptFragmentCollected': fragmentCollected,
    'actionCount': actionCount,
  };

  static GameState fromJson(Map<String, Object?> json, Level level) {
    final cargo = <String, Cell>{};
    final rawCargo = json['cargoPositions']! as Map;
    for (final entry in rawCargo.entries) {
      final pair = entry.value as List;
      cargo[entry.key as String] = Cell(
        (pair[0] as num).toInt(),
        (pair[1] as num).toInt(),
      );
    }
    final magnetsEnabled = json['magnetState']! as bool;
    return GameState(
      gravity: Direction.parse(json['gravityDirection']! as String),
      player: _pair(json['playerPosition']),
      cargo: cargo,
      anchored: anchorsFor(level, cargo, magnetsEnabled),
      magnetsEnabled: magnetsEnabled,
      fragmentCollected: json['attemptFragmentCollected']! as bool,
      actionCount: (json['actionCount']! as num).toInt(),
    );
  }
}

Cell _pair(Object? value) {
  final pair = value! as List;
  return Cell((pair[0] as num).toInt(), (pair[1] as num).toInt());
}

Set<String> anchorsFor(
  Level level,
  Map<String, Cell> cargo,
  bool magnetsEnabled,
) {
  if (!magnetsEnabled) return <String>{};
  return {
    for (final entry in cargo.entries)
      if (level.magnetSet.contains(entry.value)) entry.key,
  };
}

GameState initialState(Level level) {
  final cargo = {for (final item in level.cargo) item.id: item.position};
  return GameState(
    gravity: level.initialGravity,
    player: level.playerStart,
    cargo: cargo,
    anchored: anchorsFor(level, cargo, level.magnetsInitiallyEnabled),
    magnetsEnabled: level.magnetsInitiallyEnabled,
    fragmentCollected: false,
    actionCount: 0,
  );
}
