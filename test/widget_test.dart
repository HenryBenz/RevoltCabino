import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolt_cabino/shared/theme/app_theme.dart';
import 'package:revolt_cabino/shared/widgets/cabin_widgets.dart';

void main() {
  testWidgets('restart confirmation uses the specified copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            return CabinButton(
              label: 'OPEN',
              onPressed: () {
                showCabinConfirm(
                  context,
                  title: 'Restart chamber?',
                  body: 'This attempt will return to its starting position.',
                  confirm: 'RESTART',
                  cancel: 'CANCEL',
                );
              },
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('Restart chamber?'), findsOneWidget);
    expect(
      find.text('This attempt will return to its starting position.'),
      findsOneWidget,
    );
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('RESTART'), findsOneWidget);
  });
}
