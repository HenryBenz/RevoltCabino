import '../../models/game_state.dart';
import '../../models/level.dart';

class SettingsData {
  const SettingsData({
    this.musicEnabled = true,
    this.musicVolume = 0.8,
    this.sfxEnabled = true,
    this.sfxVolume = 0.8,
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.cabinFinish = CabinFinish.graphite,
  });

  final bool musicEnabled;
  final double musicVolume;
  final bool sfxEnabled;
  final double sfxVolume;
  final bool hapticsEnabled;
  final bool reducedMotion;
  final CabinFinish cabinFinish;

  SettingsData copyWith({
    bool? musicEnabled,
    double? musicVolume,
    bool? sfxEnabled,
    double? sfxVolume,
    bool? hapticsEnabled,
    bool? reducedMotion,
    CabinFinish? cabinFinish,
  }) {
    return SettingsData(
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      cabinFinish: cabinFinish ?? this.cabinFinish,
    );
  }

  Map<String, Object?> toJson() => {
    'musicEnabled': musicEnabled,
    'musicVolume': musicVolume,
    'sfxEnabled': sfxEnabled,
    'sfxVolume': sfxVolume,
    'hapticsEnabled': hapticsEnabled,
    'reducedMotion': reducedMotion,
    'cabinFinish': cabinFinish.name,
  };

  factory SettingsData.fromJson(Object? value) {
    if (value is! Map) return const SettingsData();
    return SettingsData(
      musicEnabled: value['musicEnabled'] as bool? ?? true,
      musicVolume: (value['musicVolume'] as num?)?.toDouble() ?? 0.8,
      sfxEnabled: value['sfxEnabled'] as bool? ?? true,
      sfxVolume: (value['sfxVolume'] as num?)?.toDouble() ?? 0.8,
      hapticsEnabled: value['hapticsEnabled'] as bool? ?? true,
      reducedMotion: value['reducedMotion'] as bool? ?? false,
      cabinFinish: CabinFinish.values.asNameMap()[value['cabinFinish']] ??
          CabinFinish.graphite,
    );
  }
}

enum CabinFinish { graphite, brushedSteel }

class AttemptData {
  const AttemptData({
    required this.levelId,
    required this.state,
    required this.undo,
  });

  final String levelId;
  final GameState state;
  final List<GameState> undo;

  Map<String, Object?> toJson() => {
    'levelId': levelId,
    'gravityDirection': state.gravity.name,
    'playerPosition': [state.player.x, state.player.y],
    'cargoPositions': state.toJson()['cargoPositions'],
    'magnetState': state.magnetsEnabled,
    'attemptFragmentCollected': state.fragmentCollected,
    'actionCount': state.actionCount,
    'undoHistory': [for (final step in undo) step.toJson()],
  };

  static AttemptData? fromJson(Object? value, Level Function(String id) lookup) {
    if (value is! Map) return null;
    final levelId = value['levelId'];
    if (levelId is! String) return null;
    final level = lookup(levelId);
    final state = GameState.fromJson(value.cast<String, Object?>(), level);
    final undo = <GameState>[];
    final history = value['undoHistory'];
    if (history is List) {
      for (final item in history) {
        if (item is Map) {
          undo.add(GameState.fromJson(item.cast<String, Object?>(), level));
        }
      }
    }
    return AttemptData(levelId: levelId, state: state, undo: undo);
  }
}

class SaveData {
  const SaveData({
    required this.schemaVersion,
    required this.completedLevelIds,
    required this.bestActionCounts,
    required this.collectedFragmentLevelIds,
    required this.claimedChapterRewards,
    required this.hintBalance,
    required this.initialHintGrantApplied,
    required this.permanentEntitlements,
    required this.processedTransactionIds,
    required this.tutorialFlags,
    required this.settings,
    required this.currentAttempt,
  });

  final int schemaVersion;
  final Set<String> completedLevelIds;
  final Map<String, int> bestActionCounts;
  final Set<String> collectedFragmentLevelIds;
  final Set<String> claimedChapterRewards;
  final int hintBalance;
  final bool initialHintGrantApplied;
  final Set<String> permanentEntitlements;
  final Set<String> processedTransactionIds;
  final Set<String> tutorialFlags;
  final SettingsData settings;
  final AttemptData? currentAttempt;

  factory SaveData.fresh() => const SaveData(
    schemaVersion: 1,
    completedLevelIds: {},
    bestActionCounts: {},
    collectedFragmentLevelIds: {},
    claimedChapterRewards: {},
    hintBalance: 5,
    initialHintGrantApplied: true,
    permanentEntitlements: {},
    processedTransactionIds: {},
    tutorialFlags: {},
    settings: SettingsData(),
    currentAttempt: null,
  );

  SaveData copyWith({
    Set<String>? completedLevelIds,
    Map<String, int>? bestActionCounts,
    Set<String>? collectedFragmentLevelIds,
    Set<String>? claimedChapterRewards,
    int? hintBalance,
    bool? initialHintGrantApplied,
    Set<String>? permanentEntitlements,
    Set<String>? processedTransactionIds,
    Set<String>? tutorialFlags,
    SettingsData? settings,
    AttemptData? currentAttempt,
    bool clearAttempt = false,
  }) {
    return SaveData(
      schemaVersion: schemaVersion,
      completedLevelIds: completedLevelIds ?? this.completedLevelIds,
      bestActionCounts: bestActionCounts ?? this.bestActionCounts,
      collectedFragmentLevelIds:
          collectedFragmentLevelIds ?? this.collectedFragmentLevelIds,
      claimedChapterRewards: claimedChapterRewards ?? this.claimedChapterRewards,
      hintBalance: hintBalance ?? this.hintBalance,
      initialHintGrantApplied:
          initialHintGrantApplied ?? this.initialHintGrantApplied,
      permanentEntitlements: permanentEntitlements ?? this.permanentEntitlements,
      processedTransactionIds:
          processedTransactionIds ?? this.processedTransactionIds,
      tutorialFlags: tutorialFlags ?? this.tutorialFlags,
      settings: settings ?? this.settings,
      currentAttempt: clearAttempt
          ? null
          : (currentAttempt ?? this.currentAttempt),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'completedLevelIds': completedLevelIds.toList(),
    'bestActionCounts': bestActionCounts,
    'collectedFragmentLevelIds': collectedFragmentLevelIds.toList(),
    'claimedChapterRewards': claimedChapterRewards.toList(),
    'hintBalance': hintBalance,
    'initialHintGrantApplied': initialHintGrantApplied,
    'permanentEntitlements': permanentEntitlements.toList(),
    'processedTransactionIds': processedTransactionIds.toList(),
    'tutorialFlags': tutorialFlags.toList(),
    'settings': settings.toJson(),
    'currentAttempt': currentAttempt?.toJson(),
  };

  factory SaveData.fromJson(
    Map<String, Object?> json, {
    required Level Function(String id) lookup,
    bool preserveLedgerOnFailure = true,
  }) {
    try {
      final ledger = _ledger(json);
      final gameplayOk = json['completedLevelIds'] is List;
      if (!gameplayOk && preserveLedgerOnFailure) {
        return SaveData.fresh().copyWith(
          hintBalance: ledger.hintBalance,
          initialHintGrantApplied: true,
          permanentEntitlements: ledger.entitlements,
          processedTransactionIds: ledger.transactions,
          settings: SettingsData.fromJson(json['settings']),
        );
      }
      var hintBalance = (json['hintBalance'] as num?)?.toInt();
      final grantApplied = json['initialHintGrantApplied'] == true;
      if (!grantApplied && hintBalance == null) hintBalance = 5;
      return SaveData(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        completedLevelIds: _stringSet(json['completedLevelIds']),
        bestActionCounts: _intMap(json['bestActionCounts']),
        collectedFragmentLevelIds: _stringSet(json['collectedFragmentLevelIds']),
        claimedChapterRewards: _stringSet(json['claimedChapterRewards']),
        hintBalance: hintBalance ?? ledger.hintBalance,
        initialHintGrantApplied: true,
        permanentEntitlements: ledger.entitlements,
        processedTransactionIds: ledger.transactions,
        tutorialFlags: _stringSet(json['tutorialFlags']),
        settings: SettingsData.fromJson(json['settings']),
        currentAttempt: AttemptData.fromJson(json['currentAttempt'], lookup),
      );
    } catch (_) {
      if (!preserveLedgerOnFailure) rethrow;
      final ledger = _ledger(json);
      return SaveData.fresh().copyWith(
        hintBalance: ledger.hintBalance,
        permanentEntitlements: ledger.entitlements,
        processedTransactionIds: ledger.transactions,
        settings: SettingsData.fromJson(json['settings']),
      );
    }
  }
}

class _Ledger {
  const _Ledger(this.hintBalance, this.entitlements, this.transactions);

  final int hintBalance;
  final Set<String> entitlements;
  final Set<String> transactions;
}

_Ledger _ledger(Map<String, Object?> json) {
  return _Ledger(
    (json['hintBalance'] as num?)?.toInt() ?? 5,
    _stringSet(json['permanentEntitlements']),
    _stringSet(json['processedTransactionIds']),
  );
}

Set<String> _stringSet(Object? value) {
  if (value is! List) return {};
  return {for (final item in value) if (item is String) item};
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

SaveData resetProgress(SaveData data) {
  return SaveData(
    schemaVersion: data.schemaVersion,
    completedLevelIds: const {},
    bestActionCounts: const {},
    collectedFragmentLevelIds: const {},
    claimedChapterRewards: const {},
    hintBalance: data.hintBalance,
    initialHintGrantApplied: true,
    permanentEntitlements: data.permanentEntitlements,
    processedTransactionIds: data.processedTransactionIds,
    tutorialFlags: const {},
    settings: data.settings,
    currentAttempt: null,
  );
}

class CompletionUpdate {
  const CompletionUpdate({
    required this.save,
    required this.chapterReward,
    required this.firstClear,
  });

  final SaveData save;
  final bool chapterReward;
  final bool firstClear;
}

CompletionUpdate recordCompletion({
  required SaveData save,
  required Level level,
  required GameState state,
  required bool chapterJustFinished,
  required String chapterId,
}) {
  final completed = {...save.completedLevelIds, level.id};
  final best = Map<String, int>.of(save.bestActionCounts);
  final previous = best[level.id];
  if (previous == null || state.actionCount < previous) {
    best[level.id] = state.actionCount;
  }
  final fragments = {...save.collectedFragmentLevelIds};
  if (state.fragmentCollected && level.memoryFragment != null) {
    fragments.add(level.id);
  }
  final claimed = {...save.claimedChapterRewards};
  var hints = save.hintBalance;
  var reward = false;
  if (chapterJustFinished && !claimed.contains(chapterId)) {
    claimed.add(chapterId);
    hints += 3;
    reward = true;
  }
  return CompletionUpdate(
    save: save.copyWith(
      completedLevelIds: completed,
      bestActionCounts: best,
      collectedFragmentLevelIds: fragments,
      claimedChapterRewards: claimed,
      hintBalance: hints,
      clearAttempt: true,
    ),
    chapterReward: reward,
    firstClear: !save.completedLevelIds.contains(level.id),
  );
}
