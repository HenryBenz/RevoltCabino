import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/navigation.dart';
import '../../game/levels/progression.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (app == null) return const Scaffold(backgroundColor: AppColors.background);
    final reduced = app.save.settings.reducedMotion;
    final started = app.catalog.campaignStarted(app.save);
    final cleared = app.catalog.clearedFreeCount(app.save);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CabinBackground(
        asset: Art.homeBackground,
        child: Stack(
          children: [
            if (!reduced)
              AnimatedBuilder(
                animation: _drift,
                builder: (context, child) {
                  final travel = math.sin(_drift.value * math.pi * 2);
                  return Positioned(
                    left: 24 + travel * 18,
                    top: 72,
                    child: IgnorePointer(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Revolt Cabino',
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.displayLarge,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const TechnicalLabel('TAKE BACK CONTROL', center: true),
                              ],
                            ),
                            SizedBox(
                              height: math.max(96, constraints.maxHeight * 0.26),
                              child: AnimatedBuilder(
                                animation: _drift,
                                builder: (context, child) {
                                  final lift = reduced
                                      ? 0.0
                                      : math.sin(_drift.value * math.pi * 2) * 6;
                                  return Transform.translate(
                                    offset: Offset(0, lift),
                                    child: child,
                                  );
                                },
                                child: CabinImage(
                                  cabinIllustration(steel: app.steelFinish),
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                TechnicalLabel(
                                  '$cleared / $freeCampaignSize CHAMBERS CLEARED',
                                  center: true,
                                ),
                                const SizedBox(height: 16),
                                CabinButton(
                                  label: started ? 'CONTINUE' : 'START REVOLT',
                                  filled: true,
                                  onPressed: () => _primary(started),
                                ),
                                const SizedBox(height: 10),
                                CabinButton(
                                  label: 'CHAMBERS',
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/chapters'),
                                ),
                                const SizedBox(height: 10),
                                CabinButton(
                                  label: 'STORE',
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/store',
                                    arguments: const StoreArgs(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                CabinButton(
                                  label: 'SETTINGS',
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/settings'),
                                ),
                                const SizedBox(height: 10),
                                CabinButton(
                                  label: 'ABOUT',
                                  onPressed: () => Navigator.pushNamed(context, '/about'),
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
          ],
        ),
      ),
    );
  }

  Future<void> _primary(bool started) async {
    final app = ref.read(appProvider);
    if (app == null) return;
    if (!started) {
      final first = app.catalog.inChapter('awakening').first;
      await openPlay(context, ref, first.id, resume: false);
      return;
    }
    final plan = planContinue(app.catalog, app.save);
    if (!mounted) return;
    switch (plan.kind) {
      case ContinueKind.resume:
        await openPlay(context, ref, plan.levelId!, resume: true);
      case ContinueKind.level:
        await openPlay(context, ref, plan.levelId!, resume: false);
      case ContinueKind.chapters:
        await Navigator.pushNamed(context, '/chapters');
    }
  }
}
