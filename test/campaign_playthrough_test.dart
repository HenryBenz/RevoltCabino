import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolt_cabino/app/app_controller.dart';
import 'package:revolt_cabino/app/navigation.dart';
import 'package:revolt_cabino/features/gameplay/gameplay_controller.dart';
import 'package:revolt_cabino/features/gameplay/gameplay_screen.dart';
import 'package:revolt_cabino/game/levels/level_loader.dart';
import 'package:revolt_cabino/game/levels/progression.dart';
import 'package:revolt_cabino/game/simulation/simulation.dart';
import 'package:revolt_cabino/game/solver/solver.dart';
import 'package:revolt_cabino/models/core.dart';
import 'package:revolt_cabino/models/game_state.dart';
import 'package:revolt_cabino/models/level.dart';
import 'package:revolt_cabino/services/audio/audio_service.dart';
import 'package:revolt_cabino/services/purchases/purchase_service.dart';
import 'package:revolt_cabino/services/save/save_data.dart';
import 'package:revolt_cabino/services/save/save_repository.dart';
import 'package:revolt_cabino/shared/art.dart';
import 'package:revolt_cabino/shared/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LevelCatalog catalog;

  setUpAll(() async {
    _stubPlatform();
    catalog = await loadLevels();
  });

  test('bundled art, audio, and fonts exist', () async {
    for (final asset in Art.all) {
      await rootBundle.load(asset);
    }
    for (final track in MusicTrack.values) {
      await rootBundle.load('assets/${track.asset}');
    }
    for (final effect in Sfx.values) {
      await rootBundle.load('assets/${effect.asset}');
    }
    await rootBundle.load('assets/fonts/Manrope-Regular.ttf');
    await rootBundle.load('assets/fonts/Manrope-Medium.ttf');
    await rootBundle.load('assets/fonts/Manrope-Bold.ttf');
    await rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf');
    await rootBundle.load('assets/fonts/OFL.txt');
  });

  test('every chamber can be escaped, undone, hinted, and reloaded', () {
    final issues = <String>[];
    var pressureUsesGate = false;
    var magnetsUsesToggle = false;
    var lasersCanKill = false;

    for (final level in catalog.levels) {
      final optimal = shortestPath(level, initialState(level));
      if (optimal.path == null) {
        issues.add('${level.id} has no escape');
        continue;
      }
      if (optimal.path!.actions.length != level.efficiencyTarget) {
        issues.add(
          '${level.id} efficiency ${level.efficiencyTarget} != '
          'optimal ${optimal.path!.actions.length}',
        );
      }

      final fragmentPath = shortestPath(
        level,
        initialState(level),
        requireFragment: level.memoryFragment != null,
      );
      if (fragmentPath.path == null) {
        issues.add('${level.id} cannot collect its fragment and escape');
      }

      var state = initialState(level);
      final history = <GameState>[state];
      for (var index = 0; index < level.referenceSolution.length; index++) {
        final wire = level.referenceSolution[index];
        final hint = level.curatedHints[index];
        if (!_hintMatches(hint, wire)) {
          issues.add('${level.id} hint ${index + 1} does not match $wire: $hint');
        }
        final before = state;
        final result = applyAction(level, state, actionFromWire(wire));
        if (result == null) {
          issues.add('${level.id} reference step $wire is a no-op');
          break;
        }
        _checkResult(issues, level, result);
        if (result.outcome == Outcome.lost) {
          issues.add('${level.id} reference solution hits a laser');
          break;
        }
        final encoded = jsonDecode(jsonEncode(result.state.toJson()));
        final restored = GameState.fromJson(
          Map<String, Object?>.from(encoded as Map),
          level,
        );
        final anchorsMatch =
            restored.anchored.length == result.state.anchored.length &&
            restored.anchored.containsAll(result.state.anchored);
        if (restored.key != result.state.key ||
            restored.actionCount != result.state.actionCount ||
            !anchorsMatch) {
          issues.add('${level.id} state does not survive a save round trip');
        }
        final hintSearch = searchHint(level, before);
        if (hintSearch.action == null || hintSearch.unreachable || hintSearch.limited) {
          issues.add('${level.id} has no hint before step ${index + 1}');
        } else if (!_followHints(level, before)) {
          issues.add('${level.id} hints do not escape before step ${index + 1}');
        }
        final wireHint = searchHintWire(level.toJson(), before.toJson());
        if (wireHint['action'] != actionToWire(hintSearch.action!)) {
          issues.add('${level.id} hint payload disagrees with the solver');
        }
        state = result.state;
        history.add(state);
      }
      if (state.actionCount != 0 &&
          (history.last.key != state.key ||
              applyAction(level, history[history.length - 2], actionFromWire(level.referenceSolution.last))
                      ?.outcome !=
                  Outcome.won)) {
        issues.add('${level.id} reference solution does not clear the chamber');
      }
      if (level.memoryFragment != null && !state.fragmentCollected) {
        issues.add('${level.id} reference solution misses the fragment');
      }

      for (var index = 0; index < history.length; index++) {
        if (history[index].actionCount != index) {
          issues.add('${level.id} action count drifted at step $index');
        }
      }
      if (history.first.key != initialState(level).key) {
        issues.add('${level.id} history does not start at the opening position');
      }

      if (!_followHints(level, initialState(level))) {
        issues.add('${level.id} hints from the start do not escape');
      }
      if (!_fuzz(level)) {
        issues.add('${level.id} breaks an invariant during play');
      }

      if (level.chapterId == 'pressure' && _pathUsesGate(level, optimal.path!)) {
        pressureUsesGate = true;
      }
      if (level.hasMagnets &&
          (optimal.path!.actions.any((action) => action is MagnetAction) ||
              (fragmentPath.path?.actions.any((action) => action is MagnetAction) ??
                  false))) {
        magnetsUsesToggle = true;
      }
      final fatal = _reachableLoss(level);
      if (level.laserEmitters.isEmpty && fatal) {
        issues.add('${level.id} can fail without a laser');
      }
      if (level.laserEmitters.isNotEmpty && fatal) lasersCanKill = true;
      if (level.laserEmitters.isNotEmpty && !fatal) {
        issues.add('${level.id} laser can never reach the player');
      }
    }

    if (!pressureUsesGate) {
      issues.add('pressure chambers never send the player through a gate');
    }
    if (!magnetsUsesToggle) {
      issues.add('magnetic chambers never toggle magnets');
    }
    if (!lasersCanKill) issues.add('no laser can intercept the player');
    expect(issues, isEmpty, reason: issues.join('\n'));
  });

  test('campaign progress, rewards, hints, death, and resume', () async {
    final harness = _Harness(catalog);
    addTearDown(harness.dispose);
    final play = harness.play;
    final app = harness.container.read(appProvider.notifier);

    expect(catalog.isUnlocked(harness.save, catalog['c01']!), isTrue);
    expect(catalog.isUnlocked(harness.save, catalog['c02']!), isFalse);
    expect(catalog.isUnlocked(harness.save, catalog['f01']!), isFalse);

    play.open('c01', resume: false);
    play.dismissTutorial();
    final hinted = await play.reveal();
    expect(hinted, isA<HintShown>());
    expect(harness.save.hintBalance, 4);
    final opening = play.state!.state.key;
    play.act(actionFromWire(catalog['c01']!.referenceSolution.first));
    play.finishAnimation();
    play.undo();
    expect(play.state!.phase, PlayPhase.ready);
    expect(play.state!.state.key, opening);
    expect(play.state!.state.actionCount, 0);
    _playSolution(play, catalog['c01']!);
    expect(play.state!.phase, PlayPhase.complete);
    expect(harness.save.completedLevelIds, contains('c01'));
    expect(harness.save.currentAttempt, isNull);
    expect(catalog.isUnlocked(harness.save, catalog['c02']!), isTrue);
    expect(catalog.isUnlocked(harness.save, catalog['c03']!), isFalse);

    final reloaded = harness.repository.load((id) => catalog[id]!);
    expect(reloaded.completedLevelIds, contains('c01'));
    expect(reloaded.hintBalance, 4);

    for (final level in catalog.levels.where((level) => level.chapterId != 'forbidden_sector')) {
      if (level.id == 'c01') continue;
      play.open(level.id, resume: false);
      if (play.state!.tutorial) play.dismissTutorial();
      _playSolution(play, level);
      expect(play.state!.phase, PlayPhase.complete, reason: level.id);
      expect(harness.save.completedLevelIds, contains(level.id));
    }

    expect(harness.save.hintBalance, 19);
    expect(harness.save.claimedChapterRewards, {
      'awakening',
      'pressure',
      'magnetic_hold',
      'white_line',
      'revolt',
    });
    expect(catalog.freeCampaignComplete(harness.save), isTrue);
    expect(planContinue(catalog, harness.save).kind, ContinueKind.chapters);

    final beforeReplay = harness.save.hintBalance;
    play.open('c06', resume: false);
    _playSolution(play, catalog['c06']!);
    expect(harness.save.hintBalance, beforeReplay);
    expect(harness.save.collectedFragmentLevelIds.where((id) => id == 'c06').length, 1);

    final resumed = _Harness(catalog, save: harness.save);
    addTearDown(resumed.dispose);
    final level = catalog['c04']!;
    resumed.play.open(level.id, resume: false);
    final first = actionFromWire(level.referenceSolution.first);
    resumed.play.act(first);
    resumed.play.finishAnimation();
    expect(resumed.save.currentAttempt!.state.actionCount, 1);
    final disk = resumed.repository.load((id) => catalog[id]!);
    final continued = _Harness(catalog, save: disk);
    addTearDown(continued.dispose);
    continued.play.open(level.id, resume: true);
    expect(continued.play.state!.state.actionCount, 1);
    for (final step in level.referenceSolution.skip(1)) {
      continued.play.act(actionFromWire(step));
      continued.play.finishAnimation();
    }
    expect(continued.play.state!.phase, PlayPhase.complete);

    final death = _firstLoss(catalog);
    expect(death, isNotNull);
    final fatalLevel = death!.$1;
    final fatalPlay = _Harness(catalog, save: harness.save.copyWith(
      permanentEntitlements: {forbiddenEntitlementId},
    ));
    addTearDown(fatalPlay.dispose);
    fatalPlay.play.open(fatalLevel.id, resume: false);
    if (fatalPlay.play.state!.tutorial) fatalPlay.play.dismissTutorial();
    for (final step in death.$2) {
      fatalPlay.play.act(step);
      fatalPlay.play.finishAnimation();
    }
    final safe = fatalPlay.play.state!.state;
    fatalPlay.play.act(death.$3);
    fatalPlay.play.finishAnimation();
    expect(fatalPlay.play.state!.phase, PlayPhase.failure);
    expect(fatalPlay.save.currentAttempt!.state.key, safe.key);
    expect(fatalPlay.save.currentAttempt!.state.actionCount, safe.actionCount);
    final credits = fatalPlay.save.hintBalance;
    fatalPlay.play.undo();
    expect(fatalPlay.play.state!.phase, PlayPhase.ready);
    expect(fatalPlay.play.state!.state.key, safe.key);
    expect(fatalPlay.save.hintBalance, credits);

    app.replace(harness.save);
    expect(catalog.isUnlocked(harness.save, catalog['f01']!), isFalse);
    final owned = harness.save.copyWith(
      permanentEntitlements: {forbiddenEntitlementId},
    );
    expect(catalog.isUnlocked(owned, catalog['f01']!), isTrue);
    expect(catalog.isUnlocked(owned, catalog['f02']!), isFalse);
    final sector = _Harness(catalog, save: owned);
    addTearDown(sector.dispose);
    for (final level in catalog.levels.where((level) => level.chapterId == 'forbidden_sector')) {
      expect(catalog.isUnlocked(sector.save, level), isTrue, reason: level.id);
      sector.play.open(level.id, resume: false);
      _playSolution(sector.play, level);
      expect(sector.play.state!.phase, PlayPhase.complete, reason: level.id);
    }
    expect(sector.save.claimedChapterRewards.contains('forbidden_sector'), isFalse);
    expect(sector.save.hintBalance, owned.hintBalance);
  });

  testWidgets('a small phone can clear the first chamber', (tester) async {
    final harness = _Harness(catalog);
    addTearDown(harness.dispose);
    await _pumpGame(tester, harness, const Size(320, 568), 'c01');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('GOT IT'));
    await tester.pump();
    await tester.tap(find.text('RIGHT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('DOWN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('CHAMBER CLEARED'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('NEXT CHAMBER'));
    await tester.tap(find.text('NEXT CHAMBER'));
    await tester.pump();
    expect(find.text('GOT IT'), findsOneWidget);
    expect(find.textContaining('Side Step'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('magnet and laser chambers fit on a small phone', (tester) async {
    final harness = _Harness(catalog);
    addTearDown(harness.dispose);
    await _pumpGame(tester, harness, const Size(320, 568), 'c13');
    expect(find.text('GOT IT'), findsOneWidget);
    expect(find.text('MAGNETS ON'), findsWidgets);
    await tester.tap(find.text('GOT IT'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await _pumpGame(tester, harness, const Size(390, 844), 'c19');
    expect(find.text('GOT IT'), findsOneWidget);
    await tester.tap(find.text('GOT IT'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _playSolution(GameplayController play, Level level) {
  var state = play.state!.state;
  for (final step in level.referenceSolution) {
    final action = actionFromWire(step);
    play.act(action);
    play.finishAnimation();
    state = play.state!.state;
  }
  expect(state.actionCount, level.referenceSolution.length);
}

void _checkResult(List<String> issues, Level level, SimResult result) {
  final seen = <Cell>{result.state.player};
  for (final cell in result.state.cargo.values) {
    if (!seen.add(cell)) {
      issues.add('${level.id} overlaps two entities at $cell');
    }
  }
  if (result.state.cargo.length != level.cargo.length) {
    issues.add('${level.id} changed the cargo count');
  }
  for (final frame in result.frames) {
    final cells = <Cell>{frame.player};
    for (final cell in frame.cargo.values) {
      if (!cells.add(cell)) {
        issues.add('${level.id} overlaps during a slide at $cell');
      }
    }
  }
  if (result.outcome == Outcome.playing) {
    final again = resolve(level, result.state);
    if (again.frames.isNotEmpty) {
      issues.add('${level.id} does not settle after a move');
    }
  }
  if (result.outcome == Outcome.won &&
      (result.state.player != level.exit || playerInLaser(level, result.state))) {
    issues.add('${level.id} records a win that is not a safe exit');
  }
}

bool _followHints(Level level, GameState start) {
  var state = start;
  final seen = <String>{state.key};
  for (var step = 0; step < 40; step++) {
    final hint = searchHint(level, state);
    if (hint.action == null) return false;
    final result = applyAction(level, state, hint.action!);
    if (result == null || result.outcome == Outcome.lost) return false;
    if (result.outcome == Outcome.won) return true;
    if (!seen.add(result.state.key)) return false;
    state = result.state;
  }
  return false;
}

bool _fuzz(Level level) {
  final random = Random(level.id.hashCode);
  var state = initialState(level);
  for (var step = 0; step < 24; step++) {
    final actions = legalActions(level, state);
    final result = applyAction(level, state, actions[random.nextInt(actions.length)]);
    if (result == null) return false;
    final cells = <Cell>{result.state.player};
    for (final cell in result.state.cargo.values) {
      if (!cells.add(cell)) return false;
      if (cell.x <= 0 || cell.y <= 0 || cell.x >= level.width - 1 || cell.y >= level.height - 1) {
        return false;
      }
    }
    if (result.state.player.x <= 0 ||
        result.state.player.y <= 0 ||
        result.state.player.x >= level.width - 1 ||
        result.state.player.y >= level.height - 1) {
      return false;
    }
    if (result.state.cargo.length != level.cargo.length) return false;
    if (result.outcome == Outcome.lost && !playerInLaser(level, result.state)) return false;
    if (result.outcome == Outcome.won) return true;
    if (result.outcome == Outcome.playing && resolve(level, result.state).frames.isNotEmpty) {
      return false;
    }
    state = result.state;
  }
  return true;
}

bool _pathUsesGate(Level level, SolvedPath path) {
  var state = initialState(level);
  for (final action in path.actions) {
    final result = applyAction(level, state, action)!;
    for (final frame in result.frames) {
      if (level.gates.any((gate) => gate.position == frame.player)) return true;
    }
    state = result.state;
  }
  return false;
}

bool _reachableLoss(Level level) {
  final queue = Queue<GameState>()..add(initialState(level));
  final seen = <String>{initialState(level).key};
  var expanded = 0;
  while (queue.isNotEmpty && expanded < 30000) {
    final state = queue.removeFirst();
    expanded++;
    for (final action in legalActions(level, state)) {
      final result = applyAction(level, state, action);
      if (result == null) continue;
      if (result.outcome == Outcome.lost) return true;
      if (result.outcome == Outcome.won) continue;
      if (seen.add(result.state.key)) queue.add(result.state);
    }
  }
  return false;
}

(Level, List<GameAction>, GameAction)? _firstLoss(LevelCatalog catalog) {
  for (final level in catalog.levels.where((level) => level.laserEmitters.isNotEmpty)) {
    final found = _lossPath(level);
    if (found != null) return (level, found.$1, found.$2);
  }
  return null;
}

(List<GameAction>, GameAction)? _lossPath(Level level) {
  final queue = Queue<(GameState, List<GameAction>)>()..add((initialState(level), const []));
  final seen = <String>{initialState(level).key};
  var expanded = 0;
  while (queue.isNotEmpty && expanded < 30000) {
    final (state, path) = queue.removeFirst();
    expanded++;
    for (final action in legalActions(level, state)) {
      final result = applyAction(level, state, action);
      if (result == null) continue;
      if (result.outcome == Outcome.lost) return (path, action);
      if (result.outcome == Outcome.won) continue;
      if (seen.add(result.state.key)) queue.add((result.state, [...path, action]));
    }
  }
  return null;
}

void _stubPlatform() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async => null,
      );
}

bool _hintMatches(String hint, String wire) {
  if (wire == 'magnet') return hint.toLowerCase().contains('magnet');
  return hint.contains(Direction.parse(wire).label);
}

class _Harness {
  _Harness(this.catalog, {SaveData? save})
    : directory = Directory.systemTemp.createTempSync('cabino-play') {
    repository = SaveRepository(directory);
    final data = save ?? SaveData.fresh();
    repository.save(data);
    container = ProviderContainer(
      overrides: [
        appProvider.overrideWith(
          () => _SeededApp(
            AppModel(
              catalog: catalog,
              save: data,
              repository: repository,
              audio: AudioService(),
              purchases: PurchaseService((_, _, _) => false),
            ),
          ),
        ),
      ],
    );
    play = container.read(gameplayProvider.notifier);
  }

  final LevelCatalog catalog;
  final Directory directory;
  late SaveRepository repository;
  late final ProviderContainer container;
  late final GameplayController play;

  SaveData get save => container.read(appProvider)!.save;

  void dispose() {
    container.dispose();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

class _SeededApp extends AppController {
  _SeededApp(this.seed);

  final AppModel seed;

  @override
  AppModel? build() => seed;
}

Future<void> _pumpGame(
  WidgetTester tester,
  _Harness harness,
  Size size,
  String levelId,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: AppHooks(
        syncMusic: () {},
        child: SoundScope(
          audio: null,
          child: MaterialApp(
            theme: AppTheme.dark,
            navigatorObservers: [routeObserver],
            home: GameplayScreen(levelId: levelId, resume: false),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
