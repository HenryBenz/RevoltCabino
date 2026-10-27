import 'package:flutter/material.dart';

import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  title: 'ABOUT',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'Revolt Cabino',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Revolt Cabino takes place inside a metallic experimental cabin controlled by a hostile automated system. The player must rotate gravity, move cargo blocks, activate mechanisms, and reach the exit of each chamber.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      const TechnicalLabel('VERSION ${AppInfo.version}', center: true),
                      const SizedBox(height: 16),
                      Text(
                        'Manrope by Mikhail Sharanda, SIL Open Font License.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Artwork and audio were created for Revolt Cabino.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your game progress and settings are saved on this device. Revolt Cabino does not require an account or access to your camera, microphone, or photo library.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      CabinButton(
                        label: 'LICENSES',
                        onPressed: () {
                          showLicensePage(
                            context: context,
                            applicationName: 'Revolt Cabino',
                            applicationVersion: AppInfo.version,
                          );
                        },
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
}
