import 'core.dart';

class CargoDef {
  const CargoDef({required this.id, required this.position});

  final String id;
  final Cell position;
}

class PlateDef {
  const PlateDef({
    required this.id,
    required this.position,
    required this.symbol,
  });

  final String id;
  final Cell position;
  final String symbol;
}

class GateDef {
  const GateDef({
    required this.id,
    required this.position,
    required this.plateIds,
    required this.symbol,
  });

  final String id;
  final Cell position;
  final List<String> plateIds;
  final String symbol;
}

class LaserDef {
  const LaserDef({
    required this.id,
    required this.position,
    required this.direction,
  });

  final String id;
  final Cell position;
  final Direction direction;
}

class Level {
  Level({
    required this.id,
    required this.chapterId,
    required this.number,
    required this.title,
    required this.width,
    required this.height,
    required this.walls,
    required this.playerStart,
    required this.cargo,
    required this.exit,
    required this.exitRequiredPlateIds,
    required this.plates,
    required this.gates,
    required this.magneticPads,
    required this.magnetsInitiallyEnabled,
    required this.laserEmitters,
    required this.memoryFragment,
    required this.initialGravity,
    required this.efficiencyTarget,
    required this.tutorialId,
    required this.curatedHints,
    required this.referenceSolution,
    required this.mechanicFocus,
  }) : wallSet = walls.toSet(),
       magnetSet = magneticPads.toSet(),
       emitterSet = laserEmitters.map((laser) => laser.position).toSet();

  final String id;
  final String chapterId;
  final int number;
  final String title;
  final int width;
  final int height;
  final List<Cell> walls;
  final Cell playerStart;
  final List<CargoDef> cargo;
  final Cell exit;
  final List<String> exitRequiredPlateIds;
  final List<PlateDef> plates;
  final List<GateDef> gates;
  final List<Cell> magneticPads;
  final bool magnetsInitiallyEnabled;
  final List<LaserDef> laserEmitters;
  final Cell? memoryFragment;
  final Direction initialGravity;
  final int efficiencyTarget;
  final String? tutorialId;
  final List<String> curatedHints;
  final List<String> referenceSolution;
  final String mechanicFocus;

  final Set<Cell> wallSet;
  final Set<Cell> magnetSet;
  final Set<Cell> emitterSet;

  bool get hasMagnets => magneticPads.isNotEmpty;

  Level copyWith({
    int? efficiencyTarget,
    String? tutorialId,
    bool clearTutorial = false,
    List<String>? curatedHints,
    List<String>? referenceSolution,
    Cell? memoryFragment,
    bool updateFragment = false,
  }) {
    return Level(
      id: id,
      chapterId: chapterId,
      number: number,
      title: title,
      width: width,
      height: height,
      walls: walls,
      playerStart: playerStart,
      cargo: cargo,
      exit: exit,
      exitRequiredPlateIds: exitRequiredPlateIds,
      plates: plates,
      gates: gates,
      magneticPads: magneticPads,
      magnetsInitiallyEnabled: magnetsInitiallyEnabled,
      laserEmitters: laserEmitters,
      memoryFragment: updateFragment
          ? memoryFragment
          : this.memoryFragment,
      initialGravity: initialGravity,
      efficiencyTarget: efficiencyTarget ?? this.efficiencyTarget,
      tutorialId: clearTutorial ? null : (tutorialId ?? this.tutorialId),
      curatedHints: curatedHints ?? this.curatedHints,
      referenceSolution: referenceSolution ?? this.referenceSolution,
      mechanicFocus: mechanicFocus,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'chapterId': chapterId,
    'number': number,
    'title': title,
    'width': width,
    'height': height,
    'walls': walls.map(_cellJson).toList(),
    'playerStart': _cellJson(playerStart),
    'cargo': [
      for (final item in cargo)
        {'id': item.id, 'position': _cellJson(item.position)},
    ],
    'exit': _cellJson(exit),
    'exitRequiredPlateIds': exitRequiredPlateIds,
    'plates': [
      for (final plate in plates)
        {
          'id': plate.id,
          'position': _cellJson(plate.position),
          'symbol': plate.symbol,
        },
    ],
    'gates': [
      for (final gate in gates)
        {
          'id': gate.id,
          'position': _cellJson(gate.position),
          'plateIds': gate.plateIds,
          'symbol': gate.symbol,
        },
    ],
    'magneticPads': magneticPads.map(_cellJson).toList(),
    'magnetsInitiallyEnabled': magnetsInitiallyEnabled,
    'laserEmitters': [
      for (final laser in laserEmitters)
        {
          'id': laser.id,
          'position': _cellJson(laser.position),
          'direction': laser.direction.name,
        },
    ],
    'memoryFragment': memoryFragment == null
        ? null
        : _cellJson(memoryFragment!),
    'initialGravity': initialGravity.name,
    'efficiencyTarget': efficiencyTarget,
    'tutorialId': tutorialId,
    'curatedHints': curatedHints,
    'referenceSolution': referenceSolution,
    'mechanicFocus': mechanicFocus,
  };

  factory Level.fromJson(Map<String, Object?> json) {
    return Level(
      id: json['id']! as String,
      chapterId: json['chapterId']! as String,
      number: (json['number']! as num).toInt(),
      title: json['title']! as String,
      width: (json['width']! as num).toInt(),
      height: (json['height']! as num).toInt(),
      walls: _cells(json['walls']),
      playerStart: _cell(json['playerStart']),
      cargo: [for (final item in json['cargo']! as List) _cargo(item)],
      exit: _cell(json['exit']),
      exitRequiredPlateIds: [
        for (final id in json['exitRequiredPlateIds']! as List) id! as String,
      ],
      plates: [for (final raw in json['plates']! as List) _plate(raw)],
      gates: [for (final raw in json['gates']! as List) _gate(raw)],
      magneticPads: _cells(json['magneticPads']),
      magnetsInitiallyEnabled: json['magnetsInitiallyEnabled']! as bool,
      laserEmitters: [for (final raw in json['laserEmitters']! as List) _laser(raw)],
      memoryFragment: json['memoryFragment'] == null
          ? null
          : _cell(json['memoryFragment']),
      initialGravity: Direction.parse(json['initialGravity']! as String),
      efficiencyTarget: (json['efficiencyTarget']! as num).toInt(),
      tutorialId: json['tutorialId'] as String?,
      curatedHints: [
        for (final hint in json['curatedHints']! as List) hint! as String,
      ],
      referenceSolution: [
        for (final step in json['referenceSolution']! as List) step! as String,
      ],
      mechanicFocus: json['mechanicFocus']! as String,
    );
  }
}

CargoDef _cargo(Object? raw) {
  final map = raw! as Map;
  return CargoDef(id: map['id'] as String, position: _cell(map['position']));
}

PlateDef _plate(Object? raw) {
  final map = raw! as Map;
  return PlateDef(
    id: map['id'] as String,
    position: _cell(map['position']),
    symbol: map['symbol'] as String,
  );
}

GateDef _gate(Object? raw) {
  final map = raw! as Map;
  return GateDef(
    id: map['id'] as String,
    position: _cell(map['position']),
    plateIds: [for (final id in map['plateIds'] as List) id! as String],
    symbol: map['symbol'] as String,
  );
}

LaserDef _laser(Object? raw) {
  final map = raw! as Map;
  return LaserDef(
    id: map['id'] as String,
    position: _cell(map['position']),
    direction: Direction.parse(map['direction'] as String),
  );
}

List<int> _cellJson(Cell cell) => [cell.x, cell.y];

Cell _cell(Object? value) {
  final pair = value! as List;
  return Cell((pair[0]! as num).toInt(), (pair[1]! as num).toInt());
}

List<Cell> _cells(Object? value) => [
  for (final item in value! as List) _cell(item),
];
