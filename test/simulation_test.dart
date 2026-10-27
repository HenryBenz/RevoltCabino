import 'package:flutter_test/flutter_test.dart';
import 'package:revolt_cabino/game/simulation/simulation.dart';
import 'package:revolt_cabino/game/solver/solver.dart';
import 'package:revolt_cabino/models/core.dart';
import 'package:revolt_cabino/models/game_state.dart';
import 'package:revolt_cabino/models/level.dart';

void main() {
  test('player and cargo slide until blocked, closest entity first', () {
    final level = _chamber(
      player: const Cell(1, 1),
      cargo: const [CargoDef(id: 'c1', position: Cell(3, 1))],
      exit: const Cell(5, 3),
      extraWalls: const [Cell(1, 2), Cell(3, 2), Cell(5, 2)],
    );
    final result = applyAction(
      level,
      initialState(level),
      const GravityAction(Direction.right),
    )!;
    expect(result.outcome, Outcome.playing);
    expect(result.state.player, const Cell(4, 1));
    expect(result.state.cargo['c1'], const Cell(5, 1));
    expect(result.state.actionCount, 1);
    expect(
      applyAction(level, result.state, const GravityAction(Direction.right)),
      isNull,
    );
  });

  test('cargo stops on an enabled magnetic pad', () {
    final level = _chamber(
      player: const Cell(1, 1),
      cargo: const [CargoDef(id: 'c1', position: Cell(3, 2))],
      exit: const Cell(1, 3),
      extraWalls: const [Cell(1, 2)],
      pads: const [Cell(3, 5)],
    );
    final result = resolve(
      level,
      initialState(level).copyWith(gravity: Direction.down),
    );
    expect(result.state.cargo['c1'], const Cell(3, 5));
    expect(result.state.anchored, contains('c1'));
  });

  test('turning magnets off releases anchored cargo', () {
    final level = _chamber(
      player: const Cell(1, 1),
      cargo: const [CargoDef(id: 'c1', position: Cell(3, 3))],
      exit: const Cell(1, 3),
      extraWalls: const [Cell(1, 2), Cell(3, 6)],
      pads: const [Cell(3, 3)],
    );
    final start = initialState(level);
    expect(start.anchored, contains('c1'));
    expect(isStable(level), isTrue);
    final result = applyAction(level, start, const MagnetAction())!;
    expect(result.state.magnetsEnabled, isFalse);
    expect(result.state.cargo['c1'], const Cell(3, 5));
    expect(result.state.anchored, isEmpty);
  });

  test('a gate stays open while occupied and never removes the player', () {
    final level = _chamber(
      player: const Cell(3, 3),
      cargo: const [CargoDef(id: 'c1', position: Cell(1, 4))],
      exit: const Cell(5, 6),
      extraWalls: const [Cell(3, 5), Cell(4, 4), Cell(1, 5)],
      plates: const [
        PlateDef(id: 'p1', position: Cell(1, 4), symbol: 'dot'),
      ],
      gates: const [
        GateDef(
          id: 'g1',
          position: Cell(3, 4),
          plateIds: ['p1'],
          symbol: 'dot',
        ),
      ],
    );
    final entered = resolve(
      level,
      initialState(level).copyWith(gravity: Direction.down),
    );
    expect(entered.state.player, const Cell(3, 4));
    expect(entered.outcome, Outcome.playing);
    final released = applyAction(
      level,
      entered.state,
      const GravityAction(Direction.right),
    )!;
    expect(released.state.player, const Cell(3, 4));
    expect(released.state.cargo['c1'], isNot(const Cell(1, 4)));
    expect(
      openGateIds(level, released.state, activePlateIds(level, released.state)),
      contains('g1'),
    );
    final left = applyAction(
      level,
      released.state,
      const GravityAction(Direction.up),
    )!;
    expect(left.state.player, isNot(const Cell(3, 4)));
    expect(
      openGateIds(level, left.state, activePlateIds(level, left.state)),
      isNot(contains('g1')),
    );
  });

  test('lasers catch intermediate cells before the exit', () {
    final level = _chamber(
      player: const Cell(3, 1),
      exit: const Cell(3, 6),
      lasers: const [
        LaserDef(id: 'l1', position: Cell(1, 4), direction: Direction.right),
      ],
    );
    final falling = resolve(level, initialState(level));
    expect(falling.outcome, Outcome.lost);
    expect(falling.state.player, const Cell(3, 4));
    expect(
      falling.frames.any((frame) => frame.player == const Cell(3, 6)),
      isFalse,
    );
  });

  test('cargo blocks a beam and a blocked exit is ordinary floor', () {
    final shielded = _chamber(
      player: const Cell(5, 4),
      cargo: const [CargoDef(id: 'c1', position: Cell(3, 4))],
      exit: const Cell(5, 6),
      extraWalls: const [Cell(5, 5)],
      lasers: const [
        LaserDef(id: 'l1', position: Cell(1, 4), direction: Direction.right),
      ],
    );
    expect(playerInLaser(shielded, initialState(shielded)), isFalse);

    final locked = _chamber(
      player: const Cell(1, 4),
      exit: const Cell(5, 4),
      extraWalls: const [Cell(1, 5)],
      plates: const [
        PlateDef(id: 'p1', position: Cell(2, 6), symbol: 'dot'),
      ],
      exitPlates: const ['p1'],
    );
    final slide = applyAction(
      locked,
      initialState(locked),
      const GravityAction(Direction.right),
    )!;
    expect(slide.outcome, Outcome.playing);
    expect(slide.state.player, const Cell(5, 4));
  });

  test('hint search does not treat a dead end as a paid step', () {
    final level = _chamber(
      player: const Cell(1, 1),
      exit: const Cell(5, 5),
      extraWalls: const [Cell(2, 1), Cell(1, 2)],
    );
    final hint = searchHint(level, initialState(level));
    expect(hint.unreachable, isTrue);
    expect(hint.action, isNull);
  });
}

Level _chamber({
  required Cell player,
  required Cell exit,
  List<CargoDef> cargo = const [],
  List<Cell> extraWalls = const [],
  List<PlateDef> plates = const [],
  List<GateDef> gates = const [],
  List<Cell> pads = const [],
  List<LaserDef> lasers = const [],
  List<String> exitPlates = const [],
  Cell? fragment,
}) {
  final walls = <Cell>[
    for (var x = 0; x < 7; x++) ...[Cell(x, 0), Cell(x, 8)],
    for (var y = 1; y < 8; y++) ...[Cell(0, y), Cell(6, y)],
    ...extraWalls,
  ];
  return Level(
    id: 'test',
    chapterId: 'awakening',
    number: 1,
    title: 'Test',
    width: 7,
    height: 9,
    walls: walls,
    playerStart: player,
    cargo: cargo,
    exit: exit,
    exitRequiredPlateIds: exitPlates,
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
    mechanicFocus: 'Test',
  );
}
