import '../../models/level.dart';
import '../../services/save/save_data.dart';

class ChapterDef {
  const ChapterDef({
    required this.id,
    required this.number,
    required this.name,
    required this.free,
  });

  final String id;
  final int number;
  final String name;
  final bool free;
}

const chapters = <ChapterDef>[
  ChapterDef(id: 'awakening', number: 1, name: 'Awakening', free: true),
  ChapterDef(id: 'pressure', number: 2, name: 'Pressure', free: true),
  ChapterDef(id: 'magnetic_hold', number: 3, name: 'Magnetic Hold', free: true),
  ChapterDef(id: 'white_line', number: 4, name: 'White Line', free: true),
  ChapterDef(id: 'revolt', number: 5, name: 'Revolt', free: true),
  ChapterDef(
    id: 'forbidden_sector',
    number: 6,
    name: 'Forbidden Sector',
    free: false,
  ),
];

const freeCampaignSize = 30;

class LevelCatalog {
  LevelCatalog(this.levels);

  final List<Level> levels;

  Level? operator [](String id) {
    for (final level in levels) {
      if (level.id == id) return level;
    }
    return null;
  }

  List<Level> inChapter(String chapterId) {
    final chapterLevels = [
      for (final level in levels)
        if (level.chapterId == chapterId) level,
    ]..sort((a, b) => a.number.compareTo(b.number));
    return chapterLevels;
  }

  ChapterDef chapterDef(String chapterId) =>
      chapters.firstWhere((chapter) => chapter.id == chapterId);

  bool ownsForbidden(SaveData save) =>
      save.permanentEntitlements.contains(forbiddenEntitlementId);

  bool isUnlocked(SaveData save, Level level) {
    final chapter = chapterDef(level.chapterId);
    if (!chapter.free && !ownsForbidden(save)) return false;
    final group = inChapter(level.chapterId);
    final index = group.indexWhere((item) => item.id == level.id);
    if (index < 0) return false;
    if (index == 0) {
      if (chapter.number == 1) return true;
      if (!chapter.free) return ownsForbidden(save);
      final previous = chapters[chapter.number - 2];
      final previousLevels = inChapter(previous.id);
      return previousLevels.isNotEmpty &&
          save.completedLevelIds.contains(previousLevels.last.id);
    }
    return save.completedLevelIds.contains(group[index - 1].id);
  }

  bool isChapterUnlocked(SaveData save, ChapterDef chapter) {
    final group = inChapter(chapter.id);
    if (group.isEmpty) return false;
    if (!chapter.free && !ownsForbidden(save)) return false;
    return isUnlocked(save, group.first);
  }

  String lockedChapterMessage(ChapterDef chapter) {
    final previous = chapters[chapter.number - 2];
    return 'Complete ${previous.name} to unlock this chapter.';
  }

  int clearedFreeCount(SaveData save) {
    var count = 0;
    for (final level in levels) {
      if (chapterDef(level.chapterId).free &&
          save.completedLevelIds.contains(level.id)) {
        count++;
      }
    }
    return count;
  }

  bool freeCampaignComplete(SaveData save) =>
      clearedFreeCount(save) >= freeCampaignSize;

  Level? nextIncompleteFree(SaveData save) {
    final ordered = [
      for (final chapter in chapters.where((item) => item.free))
        ...inChapter(chapter.id),
    ];
    for (final level in ordered) {
      if (!save.completedLevelIds.contains(level.id) && isUnlocked(save, level)) {
        return level;
      }
    }
    return null;
  }

  Level? nextAfter(Level level) {
    final group = inChapter(level.chapterId);
    final index = group.indexWhere((item) => item.id == level.id);
    if (index >= 0 && index + 1 < group.length) return group[index + 1];
    final chapterIndex = chapters.indexWhere((item) => item.id == level.chapterId);
    if (chapterIndex < 0 || chapterIndex + 1 >= chapters.length) return null;
    final nextChapter = chapters[chapterIndex + 1];
    if (!nextChapter.free) return null;
    final nextGroup = inChapter(nextChapter.id);
    return nextGroup.isEmpty ? null : nextGroup.first;
  }

  bool campaignStarted(SaveData save) =>
      save.currentAttempt != null || save.completedLevelIds.isNotEmpty;
}

const forbiddenEntitlementId = 'revolt_cabino.forbidden_sector';

enum ContinueKind { resume, level, chapters }

class ContinuePlan {
  const ContinuePlan(this.kind, [this.levelId]);

  final ContinueKind kind;
  final String? levelId;
}

ContinuePlan planContinue(LevelCatalog catalog, SaveData save) {
  final attempt = save.currentAttempt;
  if (attempt != null) {
    final level = catalog[attempt.levelId];
    if (level != null && catalog.isUnlocked(save, level)) {
      return ContinuePlan(ContinueKind.resume, level.id);
    }
  }
  if (catalog.freeCampaignComplete(save)) {
    return const ContinuePlan(ContinueKind.chapters);
  }
  final next = catalog.nextIncompleteFree(save);
  if (next == null) return const ContinuePlan(ContinueKind.chapters);
  return ContinuePlan(ContinueKind.level, next.id);
}
