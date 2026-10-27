import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:revolt_cabino/game/levels/progression.dart';
import 'package:revolt_cabino/services/purchases/grant.dart';
import 'package:revolt_cabino/services/save/save_data.dart';
import 'package:revolt_cabino/services/save/save_repository.dart';

void main() {
  test('grants a transaction once and ignores restored consumables', () {
    final first = grantProduct(
      SaveData.fresh(),
      productId: 'revolt_cabino.hints_5',
      transactionId: 'hint-tx',
      restored: false,
    );
    expect(first.hintBalance, 10);
    final repeat = grantProduct(
      first,
      productId: 'revolt_cabino.hints_5',
      transactionId: 'hint-tx',
      restored: false,
    );
    expect(identical(repeat, first), isTrue);

    final restoredHints = grantProduct(
      SaveData.fresh(),
      productId: 'revolt_cabino.hints_15',
      transactionId: 'restored-hints',
      restored: true,
    );
    expect(restoredHints.hintBalance, 5);
    expect(restoredHints.processedTransactionIds, isEmpty);

    final owned = grantProduct(
      SaveData.fresh(),
      productId: forbiddenEntitlementId,
      transactionId: 'sector-tx',
      restored: true,
    );
    expect(owned.permanentEntitlements, contains(forbiddenEntitlementId));
    final ownedAgain = grantProduct(
      owned,
      productId: forbiddenEntitlementId,
      transactionId: 'sector-tx',
      restored: false,
    );
    expect(identical(ownedAgain, owned), isTrue);
  });

  test('reset keeps purchases, credits, and settings', () {
    final save = SaveData.fresh().copyWith(
      hintBalance: 17,
      completedLevelIds: {'c01'},
      permanentEntitlements: {forbiddenEntitlementId},
      processedTransactionIds: {'sector-tx'},
      tutorialFlags: {'gravity'},
      settings: const SettingsData(musicEnabled: false),
    );
    final reset = resetProgress(save);
    expect(reset.completedLevelIds, isEmpty);
    expect(reset.tutorialFlags, isEmpty);
    expect(reset.currentAttempt, isNull);
    expect(reset.hintBalance, 17);
    expect(reset.permanentEntitlements, contains(forbiddenEntitlementId));
    expect(reset.processedTransactionIds, contains('sector-tx'));
    expect(reset.settings.musicEnabled, isFalse);
  });

  test('save falls back to the backup and salvages the purchase ledger', () {
    final directory = Directory.systemTemp.createTempSync('cabino-save');
    addTearDown(() => directory.deleteSync(recursive: true));
    final repository = SaveRepository(directory);
    final original = SaveData.fresh().copyWith(
      hintBalance: 11,
      permanentEntitlements: {forbiddenEntitlementId},
      processedTransactionIds: {'tx1'},
    );
    repository.save(original);
    repository.save(original.copyWith(hintBalance: 12));

    final main = File('${directory.path}/revolt_cabino_save.json');
    main.writeAsStringSync('{');
    final fromBackup = repository.load((id) => throw StateError(id));
    expect(fromBackup.hintBalance, 11);
    expect(fromBackup.permanentEntitlements, contains(forbiddenEntitlementId));

    final backup = File('${directory.path}/revolt_cabino_save.json.bak');
    backup.writeAsStringSync('{');
    main.writeAsStringSync(
      '{"hintBalance":9,"permanentEntitlements":["$forbiddenEntitlementId"],"processedTransactionIds":["tx1"]}',
    );
    final salvaged = repository.load((id) => throw StateError(id));
    expect(salvaged.hintBalance, 9);
    expect(salvaged.completedLevelIds, isEmpty);
    expect(salvaged.permanentEntitlements, contains(forbiddenEntitlementId));
    expect(salvaged.processedTransactionIds, contains('tx1'));
  });
}
