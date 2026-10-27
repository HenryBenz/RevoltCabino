import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/navigation.dart';
import '../../models/core.dart';
import '../../services/audio/audio_service.dart';
import '../../services/save/save_data.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';
import 'board_view.dart';
import 'gameplay_controller.dart';

class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({required this.levelId, required this.resume, super.key});

  final String levelId;
  final bool resume;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with TickerProviderStateMixin, RouteAware {
  late final AnimationController _move;
  late final AnimationController _pulse;
  late final AnimationController _flash;
  late final AnimationController _badge;
  ModalRoute<void>? _route;
  var _pauseOpen = false;
  var _swipeArmed = false;
  Offset _swipeOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _move = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          ref.read(gameplayProvider.notifier).finishAnimation();
        }
      });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _badge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLevel());
  }

  @override
  void didUpdateWidget(GameplayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levelId == widget.levelId && oldWidget.resume == widget.resume) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLevel());
  }

  void _openLevel() {
    if (!mounted) return;
    ref.read(gameplayProvider.notifier).open(
      widget.levelId,
      resume: widget.resume,
    );
    AppHooks.of(context).syncMusic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _move.dispose();
    _pulse.dispose();
    _flash.dispose();
    _badge.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _maybePause();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(gameplayProvider);
    final app = ref.watch(appProvider);
    ref.listen(gameplayProvider, (previous, next) {
      if (next == null) return;
      if (next.animToken != previous?.animToken && next.phase == PlayPhase.animating) {
        _move.duration = Duration(milliseconds: _moveMs(next));
        _move.forward(from: 0);
      }
      if (next.failureToken != previous?.failureToken) {
        _flash.forward(from: 0);
      }
      if (next.phase == PlayPhase.complete && previous?.phase != PlayPhase.complete) {
        _badge.forward(from: 0);
      }
      if (next.level.id != previous?.level.id) {
        AppHooks.of(context).syncMusic();
      }
      if (next.resumePause && previous?.resumePause != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybePause());
      }
    });
    if (model == null || app == null) {
      return const Scaffold(backgroundColor: AppColors.background);
    }
    final reduced = app.save.settings.reducedMotion;
    final pulse = !reduced;
    if (pulse != _pulse.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (pulse) {
          _pulse.repeat();
        } else {
          _pulse.stop();
        }
      });
    }
    final blocked = model.phase != PlayPhase.ready || model.tutorial;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && model.phase != PlayPhase.complete) _openPause();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CabinBackground(
          asset: Art.gameplayBackground,
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    children: [
                      _topBar(model),
                      const SizedBox(height: 8),
                      Expanded(
                        child: DecoratedBox(
                          decoration: model.tutorial
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.text),
                                )
                              : const BoxDecoration(),
                          child: Padding(
                            padding: EdgeInsets.all(model.tutorial ? 6 : 0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Column(
                                  children: [
                                    Expanded(
                                      child: IgnorePointer(
                                        ignoring: model.tutorial,
                                        child: _board(model, reduced),
                                      ),
                                    ),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: constraints.maxHeight,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            const SizedBox(height: 8),
                                            IgnorePointer(
                                              ignoring: model.tutorial || blocked,
                                              child: _info(model),
                                            ),
                                            const SizedBox(height: 8),
                                            IgnorePointer(
                                              ignoring: model.tutorial || blocked,
                                              child: _controls(model, app.save),
                                            ),
                                            if (model.hintText != null) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                model.hintText!,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(color: AppColors.text),
                                              ),
                                            ],
                                            if (model.tutorial) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                _tutorialCopy(model.level.tutorialId),
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(color: AppColors.text),
                                              ),
                                              const SizedBox(height: 8),
                                              CabinButton(
                                                label: 'GOT IT',
                                                filled: true,
                                                onPressed: () => ref
                                                    .read(gameplayProvider.notifier)
                                                    .dismissTutorial(),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (model.phase == PlayPhase.failure)
                  Positioned.fill(child: _failure(model)),
                if (model.phase == PlayPhase.failure)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _flash,
                        builder: (context, child) => ColoredBox(
                          color: Colors.white.withValues(
                            alpha: (1 - _flash.value) * 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (model.phase == PlayPhase.complete)
                  Positioned.fill(child: _complete(model, app.save)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(GameplayModel model) {
    final number = model.level.number.toString().padLeft(2, '0');
    return Row(
      children: [
        CabinButton(
          label: 'PAUSE',
          sound: ButtonSound.none,
          onPressed: model.phase == PlayPhase.complete ? null : _openPause,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Text(
                '$number · ${model.level.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TechnicalLabel('ACTIONS ${model.state.actionCount}', center: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _board(GameplayModel model, bool reduced) {
    final shake = !reduced &&
            model.phase == PlayPhase.failure &&
            _flash.value < 1
        ? Offset(math.sin(_flash.value * math.pi * 6) * 3 * (1 - _flash.value), 0)
        : Offset.zero;
    return Center(
      child: AspectRatio(
        aspectRatio: model.level.width / model.level.height,
        child: Transform.translate(
          offset: shake,
          child: GestureDetector(
            onPanStart: (details) {
              final play = ref.read(gameplayProvider);
              _swipeArmed =
                  play?.phase == PlayPhase.ready && play?.tutorial == false;
              _swipeOrigin = details.localPosition;
            },
            onPanUpdate: (details) {
              if (!_swipeArmed) return;
              final delta = details.localPosition - _swipeOrigin;
              if (delta.distance < 24) return;
              _swipeArmed = false;
              final direction = delta.dx.abs() > delta.dy.abs()
                  ? (delta.dx > 0 ? Direction.right : Direction.left)
                  : (delta.dy > 0 ? Direction.down : Direction.up);
              ref.read(gameplayProvider.notifier).act(GravityAction(direction));
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_move, _pulse, _flash]),
              builder: (context, child) {
                final app = ref.read(appProvider)!;
                return BoardView(
                  level: model.level,
                  state: model.state,
                  from: model.animFrom,
                  anim: model.phase == PlayPhase.animating ? model.anim : null,
                  t: _move.value,
                  pulse: _pulse.value,
                  steel: app.steelFinish,
                  hidePlayer:
                      model.phase == PlayPhase.failure ||
                      model.phase == PlayPhase.complete,
                  burst: model.phase == PlayPhase.failure ? _flash.value : 0,
                  highlightMagnets: model.hintAction is MagnetAction,
                  reducedMotion: reduced,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(GameplayModel model) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GravityMark(direction: model.state.gravity),
            const SizedBox(width: 6),
            TechnicalLabel(model.state.gravity.label),
          ],
        ),
        if (model.level.memoryFragment != null)
          Opacity(
            opacity: model.state.fragmentCollected ? 1 : 0.35,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CabinImage(Art.fragment),
            ),
          ),
        if (model.level.hasMagnets)
          TechnicalLabel(model.state.magnetsEnabled ? 'MAGNETS ON' : 'MAGNETS OFF'),
      ],
    );
  }

  Widget _controls(GameplayModel model, SaveData save) {
    final current = model.state.gravity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final direction in Direction.values) ...[
              if (direction != Direction.up) const SizedBox(width: 6),
              Expanded(
                child: CabinButton(
                  label: direction.label,
                  sound: ButtonSound.none,
                  highlighted:
                      model.hintAction is GravityAction &&
                      (model.hintAction as GravityAction).direction == direction,
                  onPressed: direction == current
                      ? null
                      : () => ref.read(gameplayProvider.notifier).act(
                          GravityAction(direction),
                        ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: CabinButton(
                label: 'UNDO',
                sound: ButtonSound.none,
                onPressed: model.undo.isEmpty
                    ? null
                    : () => ref.read(gameplayProvider.notifier).undo(),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: CabinButton(
                label: 'RESTART',
                onPressed: _confirmRestart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        CabinButton(
          label: 'HINT ${save.hintBalance}',
          onPressed: _showHint,
        ),
        if (model.level.hasMagnets) ...[
          const SizedBox(height: 6),
          CabinButton(
            label: model.state.magnetsEnabled ? 'MAGNETS ON' : 'MAGNETS OFF',
            sound: ButtonSound.none,
            highlighted: model.hintAction is MagnetAction,
            onPressed: () =>
                ref.read(gameplayProvider.notifier).act(const MagnetAction()),
          ),
        ],
      ],
    );
  }

  Widget _failure(GameplayModel model) {
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.82),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'SIGNAL LOST',
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The laser intercepted your route.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            CabinButton(
              label: 'UNDO LAST ACTION',
              filled: true,
              sound: ButtonSound.none,
              onPressed: () => ref.read(gameplayProvider.notifier).undo(),
            ),
            const SizedBox(height: 10),
            CabinButton(
              label: 'RESTART',
              sound: ButtonSound.none,
              onPressed: () => ref.read(gameplayProvider.notifier).restart(),
            ),
            const SizedBox(height: 10),
            CabinButton(
              label: 'CHAMBERS',
              sound: ButtonSound.back,
              onPressed: () => openLevels(context, model.level.chapterId),
            ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _complete(GameplayModel model, SaveData save) {
    final level = model.level;
    final number = level.number.toString().padLeft(2, '0');
    final best = save.bestActionCounts[level.id];
    final efficient = best != null && best <= level.efficiencyTarget;
    final memory = save.collectedFragmentLevelIds.contains(level.id);
    final next = ref.read(appProvider)!.catalog.nextAfter(level);
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.94),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'CHAMBER CLEARED',
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$number · ${level.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TechnicalLabel('ACTIONS ${model.state.actionCount}', center: true),
            const SizedBox(height: 4),
            TechnicalLabel('EFFICIENCY ${level.efficiencyTarget}', center: true),
            const SizedBox(height: 16),
            _badgeLabel('ESCAPED', true, 0),
            _badgeLabel('EFFICIENT', efficient, 0.18),
            _badgeLabel('MEMORY', memory, 0.36),
            if (model.state.fragmentCollected) ...[
              const SizedBox(height: 12),
              const SizedBox(width: 72, height: 72, child: CabinImage(Art.fragment)),
            ],
            if (model.chapterReward) ...[
              const SizedBox(height: 12),
              const TechnicalLabel(
                'CHAPTER COMPLETE · +3 HINT CREDITS',
                center: true,
              ),
            ],
            const SizedBox(height: 20),
            if (level.id == 'c30')
              CabinButton(
                label: 'FINISH REVOLT',
                filled: true,
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/ending',
                    (route) => route.settings.name == '/home',
                  );
                },
              )
            else if (next != null)
              CabinButton(
                label: 'NEXT CHAMBER',
                filled: true,
                onPressed: () => ref.read(gameplayProvider.notifier).open(
                  next.id,
                  resume: false,
                ),
              ),
            const SizedBox(height: 10),
            CabinButton(
              label: 'REPLAY',
              onPressed: () => ref.read(gameplayProvider.notifier).open(
                level.id,
                resume: false,
              ),
            ),
            const SizedBox(height: 10),
            CabinButton(
              label: 'CHAMBERS',
              sound: ButtonSound.back,
              onPressed: () => openLevels(context, level.chapterId),
            ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _badgeLabel(String label, bool earned, double start) {
    final animation = CurvedAnimation(
      parent: _badge,
      curve: Interval(start, (start + 0.5).clamp(0, 1), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: earned ? AppColors.text : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _openPause() async {
    final model = ref.read(gameplayProvider);
    final app = ref.read(appProvider);
    if (model == null || app == null || _pauseOpen) return;
    if (model.phase == PlayPhase.failure || model.phase == PlayPhase.complete) {
      return;
    }
    _pauseOpen = true;
    await app.audio.setDucked(true);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height * 0.92),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PAUSED', style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    model.level.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
              const SizedBox(height: 4),
              TechnicalLabel('ACTIONS ${model.state.actionCount}'),
              const SizedBox(height: 16),
              CabinButton(
                label: 'RESUME',
                filled: true,
                onPressed: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 8),
              CabinButton(
                label: 'RESTART CHAMBER',
                onPressed: () async {
                  final restart = await showCabinConfirm(
                    sheetContext,
                    title: 'Restart chamber?',
                    body: 'This attempt will return to its starting position.',
                    confirm: 'RESTART',
                    cancel: 'CANCEL',
                  );
                  if (!restart || !sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  ref.read(gameplayProvider.notifier).restart();
                },
              ),
              const SizedBox(height: 8),
              CabinButton(
                label: 'SETTINGS',
                onPressed: () => Navigator.of(sheetContext).pushNamed('/settings'),
              ),
              const SizedBox(height: 8),
              CabinButton(
                label: 'CHAMBER SELECT',
                onPressed: () {
                  ref.read(gameplayProvider.notifier).persistReady();
                  Navigator.pop(sheetContext);
                  openLevels(context, model.level.chapterId);
                },
              ),
              const SizedBox(height: 8),
                  CabinButton(
                    label: 'HOME',
                    sound: ButtonSound.back,
                    onPressed: () {
                      ref.read(gameplayProvider.notifier).persistReady();
                      Navigator.of(context, rootNavigator: true).popUntil(
                        (route) => route.settings.name == '/home',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _pauseOpen = false;
    if (mounted) await ref.read(appProvider)?.audio.setDucked(false);
  }

  Future<void> _confirmRestart() async {
    final restart = await showCabinConfirm(
      context,
      title: 'Restart chamber?',
      body: 'This attempt will return to its starting position.',
      confirm: 'RESTART',
      cancel: 'CANCEL',
    );
    if (!restart || !mounted) return;
    ref.read(gameplayProvider.notifier).restart();
  }

  Future<void> _showHint() async {
    final outcome = await showDialog<HintOutcome>(
      context: context,
      builder: (dialogContext) => _HintDialog(
        onClose: () => Navigator.pop(dialogContext),
      ),
    );
    if (!mounted || outcome == null) {
      ref.read(gameplayProvider.notifier).cancelHint();
      return;
    }
    if (outcome is HintUnreachable) {
      await _showUnreachable();
    } else if (outcome is HintLimited) {
      ref.read(appProvider)?.audio.play(Sfx.hint);
      if (!mounted) return;
      await showCabinMessage(context, outcome.text);
    }
  }

  Future<void> _showUnreachable() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _CabinChoice(
          body: 'No escape route remains from this position. Undo a move or restart the chamber.',
          actions: [
            CabinButton(
              label: 'UNDO',
              sound: ButtonSound.none,
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(gameplayProvider.notifier).undo();
              },
            ),
            CabinButton(
              label: 'RESTART',
              onPressed: () async {
                final restart = await showCabinConfirm(
                  dialogContext,
                  title: 'Restart chamber?',
                  body: 'This attempt will return to its starting position.',
                  confirm: 'RESTART',
                  cancel: 'CANCEL',
                );
                if (!restart || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ref.read(gameplayProvider.notifier).restart();
              },
            ),
            CabinButton(
              label: 'CLOSE',
              sound: ButtonSound.back,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        );
      },
    );
  }

  void _maybePause() {
    final model = ref.read(gameplayProvider);
    if (model == null || !model.resumePause || _pauseOpen) {
      if (_pauseOpen) ref.read(gameplayProvider.notifier).consumeResumePause();
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;
    ref.read(gameplayProvider.notifier).consumeResumePause();
    _openPause();
  }

  int _moveMs(GameplayModel model) {
    final ticks = model.anim?.frames.length ?? 0;
    final reduced = ref.read(appProvider)?.save.settings.reducedMotion ?? false;
    final per = reduced ? 45 : 85;
    final raw = math.max(reduced ? 90 : 160, ticks * per);
    return math.min(reduced ? 320 : 700, raw);
  }
}

String _tutorialCopy(String? id) {
  return switch (id) {
    'cargo' => 'Cargo moves with gravity. Use it to shape your route.',
    'plate' => 'Keep this plate occupied to hold the gate open.',
    'magnet' => 'Magnetic pads hold cargo. Toggle magnets to release it.',
    'laser' => 'Cargo blocks laser beams. You cannot cross an active beam.',
    _ => 'Swipe to change gravity.',
  };
}

class _HintDialog extends ConsumerStatefulWidget {
  const _HintDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_HintDialog> createState() => _HintDialogState();
}

class _HintDialogState extends ConsumerState<_HintDialog> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(appProvider)?.save.hintBalance ?? 0;
    return _CabinChoice(
      title: 'SYSTEM ANALYSIS',
      body: 'Use one credit to reveal the next step from your current position.',
      extra: TechnicalLabel('$balance'),
      actions: [
        CabinButton(
          label: 'REVEAL — 1 CREDIT',
          filled: true,
          sound: _busy ? ButtonSound.none : ButtonSound.tap,
          onPressed: balance <= 0 || _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final outcome = await ref.read(gameplayProvider.notifier).reveal();
                  if (!context.mounted) return;
                  if (outcome is HintNoCredit) {
                    setState(() => _busy = false);
                    return;
                  }
                  Navigator.pop(context, outcome);
                },
        ),
        CabinButton(
          label: 'GET CREDITS',
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/store',
              arguments: const StoreArgs(),
            );
          },
        ),
        CabinButton(
          label: 'CLOSE',
          sound: ButtonSound.back,
          onPressed: widget.onClose,
        ),
      ],
    );
  }
}

class _CabinChoice extends StatelessWidget {
  const _CabinChoice({
    required this.body,
    required this.actions,
    this.title,
    this.extra,
  });

  final String? title;
  final String body;
  final Widget? extra;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.steel),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
              ],
              if (extra != null) ...[extra!, const SizedBox(height: 12)],
              Text(body, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                actions[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
