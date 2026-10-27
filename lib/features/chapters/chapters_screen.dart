import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/navigation.dart';
import '../../game/levels/progression.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';

class ChaptersScreen extends ConsumerWidget {
  const ChaptersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    if (app == null) return const Scaffold(backgroundColor: AppColors.background);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CabinBackground(
        asset: Art.chambersBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              children: [
                ScreenHeader(
                  title: 'CHAMBERS',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: chapters.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      final levels = app.catalog.inChapter(chapter.id);
                      final done = levels
                          .where((level) => app.save.completedLevelIds.contains(level.id))
                          .length;
                      final unlocked = app.catalog.isChapterUnlocked(app.save, chapter);
                      final owned = app.catalog.ownsForbidden(app.save);
                      return _ChapterCard(
                        chapter: chapter,
                        done: done,
                        total: levels.length,
                        unlocked: unlocked,
                        owned: owned,
                        onTap: () => _open(context, ref, chapter, unlocked, owned),
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

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ChapterDef chapter,
    bool unlocked,
    bool owned,
  ) async {
    final app = ref.read(appProvider)!;
    if (!chapter.free && !owned) {
      app.audio.tap();
      await Navigator.pushNamed(
        context,
        '/store',
        arguments: const StoreArgs(focusForbidden: true),
      );
      return;
    }
    if (!unlocked) {
      app.audio.unavailable();
      await showCabinMessage(context, app.catalog.lockedChapterMessage(chapter));
      return;
    }
    if (!context.mounted) return;
    app.audio.tap();
    await Navigator.pushNamed(context, '/levels', arguments: chapter.id);
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.done,
    required this.total,
    required this.unlocked,
    required this.owned,
    required this.onTap,
  });

  final ChapterDef chapter;
  final int done;
  final int total;
  final bool unlocked;
  final bool owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = !chapter.free && !owned
        ? null
        : unlocked
        ? 'UNLOCKED'
        : 'LOCKED';
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.steel),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 48,
                child: chapter.free
                    ? Center(
                        child: Text(
                          chapter.number.toString().padLeft(2, '0'),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const CabinImage(Art.forbidden, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(child: TechnicalLabel('$done / $total')),
                        if (status != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
