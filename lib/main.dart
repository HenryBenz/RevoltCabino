import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_controller.dart';
import 'app/navigation.dart';
import 'features/about/about_screen.dart';
import 'features/chapters/chapters_screen.dart';
import 'features/ending/ending_screen.dart';
import 'features/gameplay/gameplay_controller.dart';
import 'features/gameplay/gameplay_screen.dart';
import 'features/home/home_screen.dart';
import 'features/launch/launch_screen.dart';
import 'features/levels/levels_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/store/store_screen.dart';
import 'services/audio/audio_service.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: RevoltApp()));
}

class RevoltApp extends ConsumerStatefulWidget {
  const RevoltApp({super.key});

  @override
  ConsumerState<RevoltApp> createState() => _RevoltAppState();
}

class _RevoltAppState extends ConsumerState<RevoltApp> with WidgetsBindingObserver {
  late final CabinStack _stack = CabinStack(() {
    if (mounted) _syncMusic();
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final model = ref.read(appProvider);
    if (model == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(model.audio.pauseOutput());
      ref.read(gameplayProvider.notifier).snap();
      final latest = ref.read(appProvider);
      if (latest != null) latest.repository.save(latest.save);
    } else if (state == AppLifecycleState.resumed) {
      unawaited(model.audio.resumeOutput());
      ref.read(gameplayProvider.notifier).markResumePause();
      _syncMusic();
    }
  }

  void _syncMusic() {
    final model = ref.read(appProvider);
    if (model == null) return;
    final track = musicFor(_stack.names, ref.read(gameplayProvider)?.level);
    if (track == null) return;
    unawaited(model.audio.playMusic(track, model.save.settings));
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(appProvider)?.audio;
    return AppHooks(
      syncMusic: _syncMusic,
      child: SoundScope(
        audio: audio,
        child: MaterialApp(
          title: 'Revolt Cabino',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          navigatorObservers: [_stack, routeObserver],
          initialRoute: '/launch',
          onGenerateRoute: _route,
        ),
      ),
    );
  }

  Route<void> _route(RouteSettings settings) {
    return switch (settings.name) {
      '/launch' => fadeRoute('/launch', const LaunchScreen()),
      '/home' => fadeRoute('/home', const HomeScreen()),
      '/chapters' => fadeRoute('/chapters', const ChaptersScreen()),
      '/levels' => fadeRoute(
        '/levels',
        LevelsScreen(chapterId: settings.arguments! as String),
      ),
      '/play' => fadeRoute('/play', _play(settings.arguments! as PlayArgs)),
      '/store' => fadeRoute(
        '/store',
        StoreScreen(
          focusForbidden: settings.arguments is StoreArgs
              ? (settings.arguments! as StoreArgs).focusForbidden
              : false,
        ),
      ),
      '/settings' => fadeRoute('/settings', const SettingsScreen()),
      '/about' => fadeRoute('/about', const AboutScreen()),
      '/ending' => fadeRoute('/ending', const EndingScreen()),
      _ => fadeRoute('/home', const HomeScreen()),
    };
  }

  Widget _play(PlayArgs args) {
    return GameplayScreen(levelId: args.levelId, resume: args.resume);
  }
}
