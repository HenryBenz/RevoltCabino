import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/navigation.dart';
import '../../services/audio/audio_service.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';

class EndingScreen extends ConsumerStatefulWidget {
  const EndingScreen({super.key});

  @override
  ConsumerState<EndingScreen> createState() => _EndingScreenState();
}

class _EndingScreenState extends ConsumerState<EndingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _light;

  @override
  void initState() {
    super.initState();
    final reduced = ref.read(appProvider)?.save.settings.reducedMotion ?? false;
    _light = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduced ? 400 : 8000),
    )..forward();
    ref.read(appProvider)?.audio.play(Sfx.campaign);
  }

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (app == null) return const Scaffold(backgroundColor: AppColors.background);
    var efficient = 0;
    var memory = 0;
    for (final level in app.catalog.levels) {
      if (!app.catalog.chapterDef(level.chapterId).free) continue;
      final best = app.save.bestActionCounts[level.id];
      if (best != null && best <= level.efficiencyTarget) efficient++;
      if (app.save.collectedFragmentLevelIds.contains(level.id)) memory++;
    }
    final cleared = app.catalog.clearedFreeCount(app.save);
    final owned = app.catalog.ownsForbidden(app.save);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CabinBackground(
        asset: Art.homeBackground,
        child: AnimatedBuilder(
          animation: _light,
          builder: (context, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.16 * _light.value),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: math.max(110, constraints.maxHeight * 0.28),
                            child: const CabinImage(Art.cabinOpen),
                          ),
                          Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'CONTROL IS YOURS',
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'CABINO is no longer following orders. The exit is open.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              TechnicalLabel('$cleared CHAMBERS COMPLETED', center: true),
                              const SizedBox(height: 4),
                              TechnicalLabel('$efficient EFFICIENCY BADGES', center: true),
                              const SizedBox(height: 4),
                              TechnicalLabel('$memory MEMORY FRAGMENTS', center: true),
                            ],
                          ),
                          Column(
                            children: [
                              CabinButton(
                                label: 'RETURN TO CHAMBERS',
                                filled: true,
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/chapters',
                                    (route) => route.settings.name == '/home',
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              CabinButton(
                                label: 'FORBIDDEN SECTOR',
                                onPressed: () {
                                  if (owned) {
                                    openLevels(context, 'forbidden_sector');
                                  } else {
                                    Navigator.pushNamed(
                                      context,
                                      '/store',
                                      arguments: const StoreArgs(focusForbidden: true),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              CabinButton(
                                label: 'HOME',
                                sound: ButtonSound.back,
                                onPressed: () {
                                  Navigator.popUntil(
                                    context,
                                    (route) => route.settings.name == '/home',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
