enum Direction {
  up,
  right,
  down,
  left;

  int get dx => switch (this) {
    Direction.up => 0,
    Direction.right => 1,
    Direction.down => 0,
    Direction.left => -1,
  };

  int get dy => switch (this) {
    Direction.up => -1,
    Direction.right => 0,
    Direction.down => 1,
    Direction.left => 0,
  };

  String get label => switch (this) {
    Direction.up => 'UP',
    Direction.right => 'RIGHT',
    Direction.down => 'DOWN',
    Direction.left => 'LEFT',
  };

  static Direction parse(String value) =>
      Direction.values.firstWhere((direction) => direction.name == value);
}

class Cell {
  const Cell(this.x, this.y);

  final int x;
  final int y;

  Cell shift(Direction direction) => Cell(x + direction.dx, y + direction.dy);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

sealed class GameAction {
  const GameAction();
}

class GravityAction extends GameAction {
  const GravityAction(this.direction);

  final Direction direction;
}

class MagnetAction extends GameAction {
  const MagnetAction();
}

GameAction actionFromWire(String value) {
  if (value == 'magnet') return const MagnetAction();
  return GravityAction(Direction.parse(value));
}

String actionToWire(GameAction action) => switch (action) {
  GravityAction(:final direction) => direction.name,
  MagnetAction() => 'magnet',
};
