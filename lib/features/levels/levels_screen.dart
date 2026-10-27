import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/navigation.dart';
import '../../models/level.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';

class LevelsScreen extends ConsumerWidget {
  const LevelsScreen({required this.chapterId, super.key});

  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    if (app == null) return const Scaffold(backgroundColor: AppColors.background);
    final chapter = app.catalog.chapterDef(chapterId);
    final levels = app.catalog.inChapter(chapterId);
    final done = levels
        .where((level) => app.save.completedLevelIds.contains(level.id))
        .length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CabinBackground(
        asset: Art.chambersBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  title: chapter.name,
                  onBack: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/chapters',
                      (route) => route.settings.name == '/home',
                    );
                  },
                ),
                const SizedBox(height: 8),
                TechnicalLabel('$done / ${levels.length}'),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: levels.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    itemBuilder: (context, index) {
                      final level = levels[index];
                      return _LevelCard(
                        level: level,
                        escaped: app.save.completedLevelIds.contains(level.id),
                        efficient: () {
                          final best = app.save.bestActionCounts[level.id];
                          return best != null && best <= level.efficiencyTarget;
                        }(),
                        memory: app.save.collectedFragmentLevelIds.contains(level.id),
                        onTap: () => _open(context, ref, level),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Level level) async {
    final app = ref.read(appProvider)!;
    if (!app.catalog.isUnlocked(app.save, level)) {
      app.audio.unavailable();
      await showCabinMessage(context, 'Complete the previous chamber first.');
      return;
    }
    app.audio.tap();
    final attempt = app.save.currentAttempt;
    final resume = attempt != null && attempt.levelId == level.id;
    if (!context.mounted) return;
    await openPlay(context, ref, level.id, resume: resume);
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 11,
        height: 1.3,
        letterSpacing: 0.6,
        color: AppColors.text,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.escaped,
    required this.efficient,
    required this.memory,
    required this.onTap,
  });

  final Level level;
  final bool escaped;
  final bool efficient;
  final bool memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.steel),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level.number.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                level.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              if (escaped) const _LevelBadge('ESCAPED'),
              if (efficient) const _LevelBadge('EFFICIENT'),
              if (memory) const _LevelBadge('MEMORY'),
            ],
          ),
        ),
      ),
    );
  }
}
