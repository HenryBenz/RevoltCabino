import 'package:flutter_test/flutter_test.dart';
import 'package:revolt_cabino/game/levels/level_loader.dart';
import 'package:revolt_cabino/game/levels/validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled campaign passes validation', () async {
    final catalog = await loadLevels();
    expect(validateCampaign(catalog.levels), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
