import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/simulation/simulation.dart';
import '../../models/core.dart';
import '../../models/game_state.dart';
import '../../models/level.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';

class BoardView extends StatelessWidget {
  const BoardView({
    required this.level,
    required this.state,
    required this.t,
    required this.pulse,
    required this.steel,
    required this.hidePlayer,
    required this.burst,
    required this.highlightMagnets,
    required this.reducedMotion,
    this.from,
    this.anim,
    super.key,
  });

  final Level level;
  final GameState state;
  final GameState? from;
  final SimResult? anim;
  final double t;
  final double pulse;
  final bool steel;
  final bool hidePlayer;
  final double burst;
  final bool highlightMagnets;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: steel ? const Color(0xFF8E97A3) : AppColors.steel,
          width: 3,
        ),
        image: steel
            ? const DecorationImage(
                image: AssetImage(Art.steel),
                fit: BoxFit.cover,
              )
            : null,
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cell = constraints.maxWidth / level.width;
            return SizedBox(
              width: constraints.maxWidth,
              height: cell * level.height,
              child: Stack(
                children: [
                  for (var y = 0; y < level.height; y++)
                    for (var x = 0; x < level.width; x++)
                      _tile(Art.floor, x, y, cell),
                  for (final wall in level.walls) _tile(Art.wall, wall.x, wall.y, cell),
                  for (final pad in level.magneticPads)
                    _tile(
                      state.magnetsEnabled ? Art.magnetOn : Art.magnetOff,
                      pad.x,
                      pad.y,
                      cell,
                    ),
                  for (final plate in level.plates)
                    _tile(
                      snap.plates.contains(plate.id) ? Art.plateOn : Art.plateOff,
                      plate.position.x,
                      plate.position.y,
                      cell,
                    ),
                  _tile(
                    exitIsReady(level, snap.plates) ? Art.exitReady : Art.exitLocked,
                    level.exit.x,
                    level.exit.y,
                    cell,
                  ),
                  if (level.memoryFragment != null && snap.fragmentOpacity > 0)
                    _offsetTile(
                      Art.fragment,
                      Offset.lerp(
                        _unit(level.memoryFragment!),
                        snap.player,
                        1 - snap.fragmentOpacity,
                      )!,
                      cell,
                      opacity: snap.fragmentOpacity,
                      scale: 0.62,
                    ),
                  for (final gate in level.gates)
                    _tile(
                      snap.gates.contains(gate.id) ? Art.gateOpen : Art.gateClosed,
                      gate.position.x,
                      gate.position.y,
                      cell,
                    ),
                  for (final laser in level.laserEmitters)
                    _offsetTile(
                      Art.laser,
                      _unit(laser.position),
                      cell,
                      turns: _turns(laser.direction),
                    ),
                  for (final entry in snap.cargo.entries)
                    _offsetTile(
                      Art.cargo,
                      entry.value,
                      cell,
                      scale: snap.cargoScale,
                    ),
                  if (!hidePlayer && snap.playerOpacity > 0)
                    _offsetTile(
                      Art.player,
                      snap.player,
                      cell,
                      opacity: snap.playerOpacity,
                      scale: 0.86 * snap.playerScale,
                    ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BoardPaint(
                        level: level,
                        cell: cell,
                        beams: snap.beams,
                        plates: snap.plates,
                        gates: snap.gates,
                        pulse: reducedMotion ? 0.5 : pulse,
                        burst: reducedMotion ? 0 : burst,
                        burstAt: snap.player,
                        highlightMagnets: highlightMagnets,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  _Snap _snapshot() {
    final origin = from;
    final result = anim;
    if (origin == null || result == null || result.frames.isEmpty) {
      final facts = inspect(level, state);
      return _Snap(
        player: _unit(state.player),
        cargo: {for (final entry in state.cargo.entries) entry.key: _unit(entry.value)},
        plates: facts.activePlateIds,
        gates: facts.openGateIds,
        beams: facts.beams,
        playerOpacity: hidePlayer ? 0 : 1,
        playerScale: 1,
        cargoScale: 1,
        fragmentOpacity: state.fragmentCollected ? 0 : 1,
      );
    }
    final frames = result.frames;
    final scaled = t.clamp(0.0, 1.0) * frames.length;
    var index = scaled.floor();
    if (index >= frames.length) index = frames.length - 1;
    final local = t >= 1 ? 1.0 : (scaled - index).clamp(0.0, 1.0);
    final frame = frames[index];
    final previousPlayer = index == 0 ? origin.player : frames[index - 1].player;
    final cargo = <String, Offset>{};
    for (final id in state.cargo.keys) {
      final previous = index == 0
          ? origin.cargo[id] ?? state.cargo[id]!
          : frames[index - 1].cargo[id] ?? state.cargo[id]!;
      final next = frame.cargo[id] ?? state.cargo[id]!;
      cargo[id] = _lerp(_unit(previous), _unit(next), local);
    }
    final last = index == frames.length - 1;
    final squash = !reducedMotion && last && local > 0.72 ? 0.94 : 1.0;
    final collectedNow = frame.fragmentCollected;
    final collectedBefore = index == 0
        ? origin.fragmentCollected
        : frames[index - 1].fragmentCollected;
    return _Snap(
      player: _lerp(_unit(previousPlayer), _unit(frame.player), local),
      cargo: cargo,
      plates: frame.activePlateIds,
      gates: frame.openGateIds,
      beams: frame.beams,
      playerOpacity: frame.won ? 1 - local : 1,
      playerScale: squash,
      cargoScale: squash,
      fragmentOpacity: collectedNow && !collectedBefore ? 1 - local : (collectedNow ? 0 : 1),
    );
  }

  Widget _tile(String asset, int x, int y, double cell) {
    return _offsetTile(asset, Offset(x.toDouble(), y.toDouble()), cell);
  }

  Widget _offsetTile(
    String asset,
    Offset cellPosition,
    double cell, {
    double opacity = 1,
    double scale = 1,
    double turns = 0,
  }) {
    return Positioned(
      left: cellPosition.dx * cell,
      top: cellPosition.dy * cell,
      width: cell,
      height: cell,
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.rotate(
          angle: turns,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _Snap {
  const _Snap({
    required this.player,
    required this.cargo,
    required this.plates,
    required this.gates,
    required this.beams,
    required this.playerOpacity,
    required this.playerScale,
    required this.cargoScale,
    required this.fragmentOpacity,
  });

  final Offset player;
  final Map<String, Offset> cargo;
  final Set<String> plates;
  final Set<String> gates;
  final List<Beam> beams;
  final double playerOpacity;
  final double playerScale;
  final double cargoScale;
  final double fragmentOpacity;
}

class _BoardPaint extends CustomPainter {
  const _BoardPaint({
    required this.level,
    required this.cell,
    required this.beams,
    required this.plates,
    required this.gates,
    required this.pulse,
    required this.burst,
    required this.burstAt,
    required this.highlightMagnets,
  });

  final Level level;
  final double cell;
  final List<Beam> beams;
  final Set<String> plates;
  final Set<String> gates;
  final double pulse;
  final double burst;
  final Offset burstAt;
  final bool highlightMagnets;

  @override
  void paint(Canvas canvas, Size size) {
    for (final beam in beams) {
      final direction = Offset(beam.direction.dx.toDouble(), beam.direction.dy.toDouble());
      final start = _center(beam.origin) + direction * cell * 0.22;
      final end = beam.lethal.isEmpty
          ? start + direction * cell * 0.2
          : _center(beam.lethal.last);
      final glow = Paint()
        ..color = AppColors.steel.withValues(alpha: 0.45)
        ..strokeWidth = cell * 0.18
        ..strokeCap = StrokeCap.round;
      final core = Paint()
        ..color = AppColors.beam.withValues(alpha: 0.92)
        ..strokeWidth = math.max(1.5, cell * 0.045)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, glow);
      canvas.drawLine(start, end, core);
      final head = Offset.lerp(start, end, (pulse * 0.85 + 0.15) % 1)!;
      canvas.drawCircle(
        head,
        cell * 0.06,
        Paint()..color = AppColors.beam.withValues(alpha: 0.8),
      );
    }
    for (final plate in level.plates) {
      _symbol(
        canvas,
        plate.symbol,
        _center(plate.position),
        plates.contains(plate.id),
      );
    }
    for (final gate in level.gates) {
      _symbol(
        canvas,
        gate.symbol,
        _center(gate.position) + Offset(0, cell * 0.28),
        gates.contains(gate.id),
      );
    }
    if (highlightMagnets) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.text;
      for (final pad in level.magneticPads) {
        canvas.drawCircle(_center(pad), cell * 0.42, paint);
      }
    }
    if (burst > 0) {
      final origin = Offset((burstAt.dx + 0.5) * cell, (burstAt.dy + 0.5) * cell);
      for (var index = 0; index < 7; index++) {
        final angle = index / 7 * math.pi * 2;
        final point = origin + Offset(math.cos(angle), math.sin(angle)) * cell * 0.34 * burst;
        canvas.drawCircle(
          point,
          cell * 0.05,
          Paint()..color = AppColors.beam.withValues(alpha: 1 - burst),
        );
      }
    }
  }

  void _symbol(Canvas canvas, String symbol, Offset center, bool active) {
    final paint = Paint()
      ..color = active ? AppColors.beam : AppColors.muted
      ..style = PaintingStyle.fill;
    final radius = math.max(2.0, cell * 0.035);
    if (symbol == 'double') {
      canvas.drawCircle(center + Offset(-radius * 1.6, 0), radius, paint);
      canvas.drawCircle(center + Offset(radius * 1.6, 0), radius, paint);
      return;
    }
    if (symbol == 'triangle') {
      final path = Path()
        ..moveTo(center.dx, center.dy - radius * 1.8)
        ..lineTo(center.dx + radius * 1.7, center.dy + radius)
        ..lineTo(center.dx - radius * 1.7, center.dy + radius)
        ..close();
      canvas.drawPath(path, paint);
      return;
    }
    canvas.drawCircle(center, radius, paint);
  }

  Offset _center(Cell cellPosition) =>
      Offset((cellPosition.x + 0.5) * cell, (cellPosition.y + 0.5) * cell);

  @override
  bool shouldRepaint(_BoardPaint oldDelegate) => true;
}

class GravityMark extends StatelessWidget {
  const GravityMark({required this.direction, this.size = 18, super.key});

  final Direction direction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArrowPainter(direction)),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.direction);

  final Direction direction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final quarter = switch (direction) {
      Direction.up => 0.0,
      Direction.right => math.pi / 2,
      Direction.down => math.pi,
      Direction.left => -math.pi / 2,
    };
    canvas.rotate(quarter);
    final paint = Paint()
      ..color = AppColors.text
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final length = size.shortestSide * 0.34;
    canvas.drawLine(Offset(0, length), Offset(0, -length), paint);
    canvas.drawLine(Offset(0, -length), Offset(-length * 0.55, -length * 0.2), paint);
    canvas.drawLine(Offset(0, -length), Offset(length * 0.55, -length * 0.2), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.direction != direction;
}

Offset _unit(Cell cell) => Offset(cell.x.toDouble(), cell.y.toDouble());

Offset _lerp(Offset a, Offset b, double t) =>
    Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

double _turns(Direction direction) => switch (direction) {
  Direction.up => 0,
  Direction.right => math.pi / 2,
  Direction.down => math.pi,
  Direction.left => -math.pi / 2,
};
