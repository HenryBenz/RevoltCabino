import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/navigation.dart';
import '../../services/save/save_data.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double? _music;
  double? _effects;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (app == null) return const Scaffold(backgroundColor: AppColors.background);
    final settings = app.save.settings;
    final owned = app.catalog.ownsForbidden(app.save);
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
                  title: 'SETTINGS',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      _switch(
                        'MUSIC',
                        settings.musicEnabled,
                        (value) => _update(settings.copyWith(musicEnabled: value)),
                      ),
                      _slider(
                        'MUSIC VOLUME',
                        _music ?? settings.musicVolume,
                        (value) {
                          setState(() => _music = value);
                          unawaited(
                            app.audio.applySettings(settings.copyWith(musicVolume: value)),
                          );
                        },
                        (value) {
                          _update(settings.copyWith(musicVolume: value));
                          setState(() => _music = null);
                        },
                      ),
                      _switch(
                        'SOUND EFFECTS',
                        settings.sfxEnabled,
                        (value) => _update(settings.copyWith(sfxEnabled: value)),
                      ),
                      _slider(
                        'SOUND EFFECTS VOLUME',
                        _effects ?? settings.sfxVolume,
                        (value) => setState(() => _effects = value),
                        (value) {
                          _update(settings.copyWith(sfxVolume: value));
                          setState(() => _effects = null);
                        },
                      ),
                      _switch(
                        'HAPTICS',
                        settings.hapticsEnabled,
                        (value) => _update(settings.copyWith(hapticsEnabled: value)),
                      ),
                      _switch(
                        'REDUCED MOTION',
                        settings.reducedMotion,
                        (value) => _update(settings.copyWith(reducedMotion: value)),
                      ),
                      const SizedBox(height: 12),
                      const TechnicalLabel('CABIN FINISH'),
                      const SizedBox(height: 8),
                      CabinButton(
                        label: 'GRAPHITE',
                        filled: settings.cabinFinish == CabinFinish.graphite,
                        onPressed: () => _update(
                          settings.copyWith(cabinFinish: CabinFinish.graphite),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CabinButton(
                        label: 'BRUSHED STEEL',
                        filled: owned && settings.cabinFinish == CabinFinish.brushedSteel,
                        onPressed: () {
                          if (!owned) {
                            Navigator.pushNamed(
                              context,
                              '/store',
                              arguments: const StoreArgs(focusForbidden: true),
                            );
                            return;
                          }
                          _update(settings.copyWith(cabinFinish: CabinFinish.brushedSteel));
                        },
                      ),
                      const SizedBox(height: 16),
                      CabinButton(
                        label: 'SHOW TUTORIALS AGAIN',
                        onPressed: () => ref.read(appProvider.notifier).replace(
                          app.save.copyWith(tutorialFlags: {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CabinButton(
                        label: 'RESTORE PURCHASES',
                        onPressed: app.purchases.restore,
                      ),
                      const SizedBox(height: 8),
                      CabinButton(
                        label: 'RESET GAME PROGRESS',
                        onPressed: _reset,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _update(SettingsData settings) {
    final save = ref.read(appProvider)?.save;
    if (save == null) return;
    ref.read(appProvider.notifier).replace(save.copyWith(settings: settings));
  }

  Future<void> _reset() async {
    final confirmed = await showCabinConfirm(
      context,
      title: 'Reset game progress?',
      body: 'Completed chambers and collected memories will be cleared. Purchases and remaining hint credits will stay available.',
      confirm: 'RESET PROGRESS',
      cancel: 'CANCEL',
    );
    if (!confirmed) return;
    final save = ref.read(appProvider)?.save;
    if (save == null) return;
    ref.read(appProvider.notifier).replace(resetProgress(save));
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(child: TechnicalLabel(label)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    ValueChanged<double> onChanged,
    ValueChanged<double> onChangeEnd,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TechnicalLabel(label),
        Slider(value: value.clamp(0, 1), onChanged: onChanged, onChangeEnd: onChangeEnd),
      ],
    );
  }
}
