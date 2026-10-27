import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../game/levels/level_loader.dart';
import '../game/levels/progression.dart';
import '../services/audio/audio_service.dart';
import '../services/purchases/grant.dart';
import '../services/purchases/purchase_service.dart';
import '../services/save/save_data.dart';
import '../services/save/save_repository.dart';
import '../shared/art.dart';
import '../shared/theme/app_theme.dart';

class AppModel {
  const AppModel({
    required this.catalog,
    required this.save,
    required this.repository,
    required this.audio,
    required this.purchases,
  });

  final LevelCatalog catalog;
  final SaveData save;
  final SaveRepository repository;
  final AudioService audio;
  final PurchaseService purchases;

  bool get steelFinish =>
      catalog.ownsForbidden(save) &&
      save.settings.cabinFinish == CabinFinish.brushedSteel;

  AppModel copyWith({SaveData? save}) {
    return AppModel(
      catalog: catalog,
      save: save ?? this.save,
      repository: repository,
      audio: audio,
      purchases: purchases,
    );
  }
}

class AppController extends Notifier<AppModel?> {
  @override
  AppModel? build() => null;

  var _booting = false;
  var _licensed = false;

  Future<void> boot(BuildContext context) async {
    if (state != null || _booting) return;
    _booting = true;
    final catalog = await loadLevels();
    final directory = await getApplicationSupportDirectory();
    final repository = SaveRepository(directory);
    final save = repository.load((id) {
      final level = catalog[id];
      if (level == null) throw StateError('Missing level $id');
      return level;
    });
    Motion.reduced = save.settings.reducedMotion;
    final audio = AudioService();
    try {
      await audio.prepare();
    } catch (_) {}
    if (!_licensed) {
      _licensed = true;
      LicenseRegistry.addLicense(() async* {
        final text = await rootBundle.loadString('assets/fonts/OFL.txt');
        yield LicenseEntryWithLineBreaks(const ['Manrope'], text);
      });
    }
    final model = AppModel(
      catalog: catalog,
      save: save,
      repository: repository,
      audio: audio,
      purchases: PurchaseService(_grant),
    );
    state = model;
    unawaited(model.purchases.start());
    unawaited(audio.playMusic(MusicTrack.menu, save.settings));
    if (context.mounted) {
      for (final asset in Art.all) {
        await precacheImage(AssetImage(asset), context);
      }
    }
  }

  bool _grant(String productId, String transactionId, bool restored) {
    final current = state;
    if (current == null) return false;
    final next = grantProduct(
      current.save,
      productId: productId,
      transactionId: transactionId,
      restored: restored,
    );
    if (identical(next, current.save)) return false;
    replace(next);
    return true;
  }

  void replace(SaveData save) {
    final current = state;
    if (current == null) return;
    try {
      current.repository.save(save);
    } catch (_) {}
    Motion.reduced = save.settings.reducedMotion;
    unawaited(current.audio.applySettings(save.settings));
    state = current.copyWith(save: save);
  }
}

final appProvider = NotifierProvider<AppController, AppModel?>(AppController.new);
