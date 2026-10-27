import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolt_cabino/app/app_controller.dart';
import 'package:revolt_cabino/app/navigation.dart';
import 'package:revolt_cabino/features/about/about_screen.dart';
import 'package:revolt_cabino/features/chapters/chapters_screen.dart';
import 'package:revolt_cabino/features/ending/ending_screen.dart';
import 'package:revolt_cabino/features/gameplay/gameplay_screen.dart';
import 'package:revolt_cabino/features/home/home_screen.dart';
import 'package:revolt_cabino/features/levels/levels_screen.dart';
import 'package:revolt_cabino/features/settings/settings_screen.dart';
import 'package:revolt_cabino/features/store/store_screen.dart';
import 'package:revolt_cabino/game/levels/level_loader.dart';
import 'package:revolt_cabino/game/levels/progression.dart';
import 'package:revolt_cabino/services/audio/audio_service.dart';
import 'package:revolt_cabino/services/purchases/purchase_service.dart';
import 'package:revolt_cabino/services/save/save_data.dart';
import 'package:revolt_cabino/services/save/save_repository.dart';
import 'package:revolt_cabino/shared/theme/app_theme.dart';
import 'package:revolt_cabino/shared/widgets/cabin_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LevelCatalog catalog;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async => null,
        );
    catalog = await loadLevels();
  });

  testWidgets('screens stay inside 320 and 390 frames', (tester) async {
    final first = catalog.levels.firstWhere((level) => level.id == 'c01');
    final save = SaveData.fresh().copyWith(
      completedLevelIds: {'c01'},
      bestActionCounts: {'c01': first.efficiencyTarget},
      collectedFragmentLevelIds: {'c01'},
      permanentEntitlements: {forbiddenEntitlementId},
    );
    final harness = _Harness(catalog, save);
    addTearDown(harness.dispose);
    harness.model.purchases
      ..available = false
      ..queryFinished = true;

    const screens = <Widget>[
      HomeScreen(),
      ChaptersScreen(),
      LevelsScreen(chapterId: 'awakening'),
      LevelsScreen(chapterId: 'magnetic_hold'),
      LevelsScreen(chapterId: 'forbidden_sector'),
      StoreScreen(focusForbidden: false),
      SettingsScreen(),
      AboutScreen(),
      EndingScreen(),
      GameplayScreen(levelId: 'c13', resume: false),
      GameplayScreen(levelId: 'c19', resume: false),
    ];

    for (final size in const [Size(320, 568), Size(390, 844)]) {
      for (final scaler in const [TextScaler.noScaling, TextScaler.linear(1.3)]) {
        for (final screen in screens) {
          await _pump(tester, harness, size, scaler, screen);
          expect(tester.takeException(), isNull, reason: '$size ${screen.runtimeType}');
        }
      }
    }
  });

  testWidgets('matching controls share one size', (tester) async {
    final harness = _Harness(catalog, SaveData.fresh());
    addTearDown(harness.dispose);

    await _pump(tester, harness, const Size(320, 568), TextScaler.noScaling, const HomeScreen());
    final homeButtons = [
      'START REVOLT',
      'CHAMBERS',
      'STORE',
      'SETTINGS',
      'ABOUT',
    ].map((label) => tester.getSize(find.widgetWithText(CabinButton, label))).toList();
    for (final size in homeButtons) {
      expect(size, homeButtons.first);
    }

    await _pump(
      tester,
      harness,
      const Size(320, 568),
      TextScaler.noScaling,
      const ChaptersScreen(),
    );
    final chapterCards = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => chapters.any((chapter) => chapter.name == text.data))
        .map((text) => text.data!)
        .toList();
    expect(chapterCards, isNotEmpty);
    final cardHeights = chapterCards.map((name) {
      final card = find.ancestor(
        of: find.text(name),
        matching: find.byType(GestureDetector),
      );
      return tester.getSize(card.first).height;
    }).toList();
    for (final height in cardHeights) {
      expect(height, cardHeights.first);
    }

    await _pump(
      tester,
      harness,
      const Size(320, 568),
      TextScaler.noScaling,
      const StoreScreen(focusForbidden: false),
    );
    final packHeights = <double>[];
    for (final name in [
      'Small Analysis Pack',
      'Medium Analysis Pack',
      'Large Analysis Pack',
    ]) {
      final card = find.byKey(ValueKey(name));
      await tester.scrollUntilVisible(card, 120);
      packHeights.add(tester.getSize(card).height);
    }
    for (final height in packHeights) {
      expect(height, packHeights.first);
    }

    await _pump(
      tester,
      harness,
      const Size(320, 568),
      TextScaler.noScaling,
      const GameplayScreen(levelId: 'c01', resume: false),
    );
    final directions = ['UP', 'RIGHT', 'DOWN', 'LEFT']
        .map((label) => tester.getSize(find.widgetWithText(CabinButton, label)))
        .toList();
    for (final size in directions) {
      expect(size, directions.first);
    }
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      harness,
      const Size(320, 568),
      TextScaler.noScaling,
      const SettingsScreen(),
    );
    final reset = find.text('RESET GAME PROGRESS');
    await tester.scrollUntilVisible(reset, 200);
    await tester.tap(reset);
    for (var frame = 0; frame < 20 && find.text('Reset game progress?').evaluate().isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Reset game progress?'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _Harness harness,
  Size size,
  TextScaler scaler,
  Widget screen,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: AppHooks(
        syncMusic: () {},
        child: SoundScope(
          audio: null,
          child: MaterialApp(
            theme: AppTheme.dark,
            navigatorObservers: [routeObserver],
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scaler),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _Harness {
  _Harness(this.catalog, SaveData save)
    : directory = Directory.systemTemp.createTempSync('cabino-layout') {
    repository = SaveRepository(directory);
    repository.save(save);
    model = AppModel(
      catalog: catalog,
      save: save,
      repository: repository,
      audio: AudioService(),
      purchases: PurchaseService((_, _, _) => false),
    );
    container = ProviderContainer(
      overrides: [appProvider.overrideWith(() => _SeededApp(model))],
    );
  }

  final LevelCatalog catalog;
  final Directory directory;
  late final SaveRepository repository;
  late final AppModel model;
  late final ProviderContainer container;

  void dispose() {
    container.dispose();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

class _SeededApp extends AppController {
  _SeededApp(this.seed);

  final AppModel seed;

  @override
  AppModel? build() => seed;
}
