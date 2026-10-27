import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../game/simulation/simulation.dart';
import '../../game/solver/solver.dart';
import '../../models/core.dart';
import '../../models/game_state.dart';
import '../../models/level.dart';
import '../../services/audio/audio_service.dart';
import '../../services/save/save_data.dart';

enum PlayPhase { ready, animating, failure, complete }

sealed class HintOutcome {
  const HintOutcome();
}

class HintShown extends HintOutcome {
  const HintShown(this.text);

  final String text;
}

class HintUnreachable extends HintOutcome {
  const HintUnreachable();
}

class HintLimited extends HintOutcome {
  const HintLimited(this.text);

  final String text;
}

class HintNoCredit extends HintOutcome {
  const HintNoCredit();
}

class GameplayModel {
  const GameplayModel({
    required this.session,
    required this.level,
    required this.state,
    required this.undo,
    required this.phase,
    required this.animToken,
    required this.failureToken,
    this.animFrom,
    this.anim,
    this.hintText,
    this.hintAction,
    this.tutorial = false,
    this.chapterReward = false,
    this.resumePause = false,
  });

  final int session;
  final Level level;
  final GameState state;
  final List<GameState> undo;
  final PlayPhase phase;
  final int animToken;
  final int failureToken;
  final GameState? animFrom;
  final SimResult? anim;
  final String? hintText;
  final GameAction? hintAction;
  final bool tutorial;
  final bool chapterReward;
  final bool resumePause;

  GameplayModel copyWith({
    GameState? state,
    List<GameState>? undo,
    PlayPhase? phase,
    int? animToken,
    int? failureToken,
    GameState? animFrom,
    SimResult? anim,
    bool clearAnim = false,
    String? hintText,
    GameAction? hintAction,
    bool clearHint = false,
    bool? tutorial,
    bool? chapterReward,
    bool? resumePause,
  }) {
    return GameplayModel(
      session: session,
      level: level,
      state: state ?? this.state,
      undo: undo ?? this.undo,
      phase: phase ?? this.phase,
      animToken: animToken ?? this.animToken,
      failureToken: failureToken ?? this.failureToken,
      animFrom: clearAnim ? null : (animFrom ?? this.animFrom),
      anim: clearAnim ? null : (anim ?? this.anim),
      hintText: clearHint ? null : (hintText ?? this.hintText),
      hintAction: clearHint ? null : (hintAction ?? this.hintAction),
      tutorial: tutorial ?? this.tutorial,
      chapterReward: chapterReward ?? this.chapterReward,
      resumePause: resumePause ?? this.resumePause,
    );
  }
}

class GameplayController extends Notifier<GameplayModel?> {
  @override
  GameplayModel? build() => null;

  var _hintToken = 0;

  void open(String levelId, {required bool resume}) {
    final app = ref.read(appProvider);
    if (app == null) return;
    final level = app.catalog[levelId];
    if (level == null) return;
    final attempt = app.save.currentAttempt;
    final useAttempt = resume && attempt != null && attempt.levelId == levelId;
    final game = useAttempt ? attempt.state : initialState(level);
    final undo = useAttempt ? List<GameState>.of(attempt.undo) : <GameState>[];
    if (!useAttempt) {
      ref.read(appProvider.notifier).replace(
        app.save.copyWith(
          currentAttempt: AttemptData(levelId: levelId, state: game, undo: undo),
        ),
      );
    }
    final tutorialId = level.tutorialId;
    state = GameplayModel(
      session: (state?.session ?? 0) + 1,
      level: level,
      state: game,
      undo: undo,
      phase: PlayPhase.ready,
      animToken: 0,
      failureToken: 0,
      tutorial:
          tutorialId != null && !app.save.tutorialFlags.contains(tutorialId),
    );
  }

  void act(GameAction action) {
    final model = state;
    final app = ref.read(appProvider);
    if (model == null || app == null) return;
    if (model.phase != PlayPhase.ready || model.tutorial) return;
    final result = applyAction(model.level, model.state, action);
    if (result == null) {
      app.audio.unavailable();
      return;
    }
    final before = model.state;
    final undo = [...model.undo, before];
    var reward = false;
    if (result.outcome == Outcome.won) {
      final chapter = app.catalog.chapterDef(model.level.chapterId);
      final completed = {...app.save.completedLevelIds, model.level.id};
      final justFinished = chapter.free &&
          app.catalog
              .inChapter(model.level.chapterId)
              .every((level) => completed.contains(level.id));
      final update = recordCompletion(
        save: app.save,
        level: model.level,
        state: result.state,
        chapterJustFinished: justFinished,
        chapterId: model.level.chapterId,
      );
      reward = update.chapterReward;
      ref.read(appProvider.notifier).replace(update.save);
    } else if (result.outcome == Outcome.lost) {
      ref.read(appProvider.notifier).replace(
        app.save.copyWith(
          currentAttempt: AttemptData(
            levelId: model.level.id,
            state: before,
            undo: model.undo,
          ),
        ),
      );
    } else {
      ref.read(appProvider.notifier).replace(
        app.save.copyWith(
          currentAttempt: AttemptData(
            levelId: model.level.id,
            state: result.state,
            undo: undo,
          ),
        ),
      );
    }
    state = model.copyWith(
      state: result.state,
      undo: undo,
      phase: PlayPhase.animating,
      animFrom: before,
      anim: result,
      animToken: model.animToken + 1,
      failureToken: result.outcome == Outcome.lost
          ? model.failureToken + 1
          : model.failureToken,
      clearHint: true,
      chapterReward: reward,
      resumePause: false,
    );
    app.audio.playResolution(
      level: model.level,
      before: before,
      action: action,
      result: result,
    );
  }

  void finishAnimation() {
    final model = state;
    if (model == null || model.phase != PlayPhase.animating) return;
    final outcome = model.anim?.outcome ?? Outcome.playing;
    final phase = switch (outcome) {
      Outcome.won => PlayPhase.complete,
      Outcome.lost => PlayPhase.failure,
      Outcome.playing => PlayPhase.ready,
    };
    state = model.copyWith(phase: phase, clearAnim: true);
    if (outcome == Outcome.won) {
      ref.read(appProvider)?.audio.play(
        model.chapterReward ? Sfx.chapter : Sfx.level,
      );
    }
  }

  void snap() {
    if (state?.phase == PlayPhase.animating) finishAnimation();
  }

  void markResumePause() {
    final model = state;
    if (model == null || model.phase != PlayPhase.ready || model.tutorial) {
      return;
    }
    state = model.copyWith(resumePause: true);
  }

  void consumeResumePause() {
    final model = state;
    if (model == null || !model.resumePause) return;
    state = model.copyWith(resumePause: false);
  }

  void dismissTutorial() {
    final model = state;
    final app = ref.read(appProvider);
    if (model == null || app == null) return;
    final tutorialId = model.level.tutorialId;
    if (tutorialId != null) {
      ref.read(appProvider.notifier).replace(
        app.save.copyWith(tutorialFlags: {...app.save.tutorialFlags, tutorialId}),
      );
    }
    state = model.copyWith(tutorial: false);
  }

  void undo() {
    final model = state;
    final app = ref.read(appProvider);
    if (model == null || app == null || model.undo.isEmpty) return;
    if (model.phase != PlayPhase.ready && model.phase != PlayPhase.failure) {
      return;
    }
    final restored = model.undo.last;
    final undo = model.undo.sublist(0, model.undo.length - 1);
    app.audio.play(Sfx.undo);
    app.audio.feedback();
    ref.read(appProvider.notifier).replace(
      app.save.copyWith(
        currentAttempt: AttemptData(
          levelId: model.level.id,
          state: restored,
          undo: undo,
        ),
      ),
    );
    state = model.copyWith(
      state: restored,
      undo: undo,
      phase: PlayPhase.ready,
      clearAnim: true,
      clearHint: true,
    );
  }

  void restart() {
    final model = state;
    final app = ref.read(appProvider);
    if (model == null || app == null) return;
    final fresh = initialState(model.level);
    ref.read(appProvider.notifier).replace(
      app.save.copyWith(
        currentAttempt: AttemptData(
          levelId: model.level.id,
          state: fresh,
          undo: const [],
        ),
      ),
    );
    final tutorialId = model.level.tutorialId;
    final flags = ref.read(appProvider)!.save.tutorialFlags;
    state = GameplayModel(
      session: model.session,
      level: model.level,
      state: fresh,
      undo: const [],
      phase: PlayPhase.ready,
      animToken: model.animToken,
      failureToken: model.failureToken,
      tutorial: tutorialId != null && !flags.contains(tutorialId),
    );
  }

  void persistReady() {
    final model = state;
    final app = ref.read(appProvider);
    if (model == null || app == null) return;
    if (model.phase == PlayPhase.animating) {
      snap();
      return;
    }
    if (model.phase != PlayPhase.ready) return;
    ref.read(appProvider.notifier).replace(
      app.save.copyWith(
        currentAttempt: AttemptData(
          levelId: model.level.id,
          state: model.state,
          undo: model.undo,
        ),
      ),
    );
  }

  void cancelHint() {
    _hintToken++;
  }

  Future<HintOutcome> reveal() async {
    final model = state;
    final app = ref.read(appProvider);
    if (model == null ||
        app == null ||
        model.phase != PlayPhase.ready ||
        app.save.hintBalance <= 0) {
      return const HintNoCredit();
    }
    final token = ++_hintToken;
    final levelJson = model.level.toJson();
    final stateJson = model.state.toJson();
    Map<String, Object?> wire;
    try {
      wire = await Isolate.run(() => searchHintWire(levelJson, stateJson));
    } catch (_) {
      wire = {
        'action': null,
        'instruction': null,
        'unreachable': false,
        'limited': true,
      };
    }
    if (token != _hintToken) return const HintNoCredit();
    final latest = state;
    final latestApp = ref.read(appProvider);
    if (latest == null || latestApp == null || latest.phase != PlayPhase.ready) {
      return const HintNoCredit();
    }
    if (wire['unreachable'] == true) return const HintUnreachable();
    final actionWire = wire['action'];
    if (wire['limited'] == true || actionWire is! String) {
      final curated = curatedHintForState(latest.level, latest.state) ??
          (latest.level.curatedHints.isEmpty
              ? null
              : latest.level.curatedHints.first);
      if (curated == null) return const HintNoCredit();
      return HintLimited(curated);
    }
    final instruction = wire['instruction'];
    if (instruction is! String || instruction.isEmpty) return const HintNoCredit();
    ref.read(appProvider.notifier).replace(
      latestApp.save.copyWith(hintBalance: latestApp.save.hintBalance - 1),
    );
    state = latest.copyWith(
      hintText: instruction,
      hintAction: actionFromWire(actionWire),
    );
    latestApp.audio.play(Sfx.hint);
    return HintShown(instruction);
  }
}

final gameplayProvider = NotifierProvider<GameplayController, GameplayModel?>(
  GameplayController.new,
);
