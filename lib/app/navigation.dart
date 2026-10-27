import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/level.dart';
import '../shared/theme/app_theme.dart';
import '../services/audio/audio_service.dart';
import '../shared/widgets/cabin_widgets.dart';
import 'app_controller.dart';

class PlayArgs {
  const PlayArgs(this.levelId, {required this.resume});

  final String levelId;
  final bool resume;
}

class StoreArgs {
  const StoreArgs({this.focusForbidden = false});

  final bool focusForbidden;
}

class CabinStack extends NavigatorObserver {
  CabinStack(this.onChanged);

  final VoidCallback onChanged;
  final List<Route<dynamic>> routes = [];

  List<String> get names => [
    for (final route in routes) route.settings.name ?? '',
  ];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final index = routes.indexOf(oldRoute);
      if (index >= 0 && newRoute != null) {
        routes[index] = newRoute;
      } else {
        routes.remove(oldRoute);
        if (newRoute != null) routes.add(newRoute);
      }
    }
    onChanged();
  }
}

class AppHooks extends InheritedWidget {
  const AppHooks({required this.syncMusic, required super.child, super.key});

  final VoidCallback syncMusic;

  static AppHooks of(BuildContext context) {
    final hooks = context.dependOnInheritedWidgetOfExactType<AppHooks>();
    assert(hooks != null, 'AppHooks missing');
    return hooks!;
  }

  @override
  bool updateShouldNotify(AppHooks oldWidget) => false;
}

final routeObserver = RouteObserver<ModalRoute<void>>();

MusicTrack? musicFor(List<String> names, Level? level) {
  if (names.contains('/play')) {
    if (level == null) return null;
    if (level.chapterId == 'revolt' || level.chapterId == 'forbidden_sector') {
      return MusicTrack.finale;
    }
    return MusicTrack.gameplay;
  }
  return MusicTrack.menu;
}

Route<void> fadeRoute(String name, Widget page) {
  return PageRouteBuilder<void>(
    settings: RouteSettings(name: name),
    transitionDuration: Motion.transition,
    reverseTransitionDuration: Motion.transition,
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Future<void> openPlay(
  BuildContext context,
  WidgetRef ref,
  String levelId, {
  required bool resume,
}) async {
  final save = ref.read(appProvider)?.save;
  if (save != null && !resume) {
    final attempt = save.currentAttempt;
    if (attempt != null && attempt.levelId != levelId) {
      final replace = await showCabinConfirm(
        context,
        title: 'Replace current attempt?',
        body: 'Your completed levels will remain saved.',
        confirm: 'OPEN CHAMBER',
        cancel: 'KEEP PLAYING',
      );
      if (!replace || !context.mounted) return;
    }
  }
  if (!context.mounted) return;
  await Navigator.pushNamed(
    context,
    '/play',
    arguments: PlayArgs(levelId, resume: resume),
  );
}

void openLevels(BuildContext context, String chapterId) {
  Navigator.pushNamedAndRemoveUntil(
    context,
    '/levels',
    (route) => route.settings.name == '/home',
    arguments: chapterId,
  );
}
