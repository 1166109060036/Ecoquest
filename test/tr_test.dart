import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecoquest/l10n/tr.dart';
import 'package:ecoquest/l10n/ja.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tr: English passthrough, Japanese lookup, placeholders, fallback', () async {
    SharedPreferences.setMockInitialValues({});
    await setLanguage('en');
    expect(tr('Explore'), 'Explore');
    expect(tr('Day {0}/{1}', [2, 7]), 'Day 2/7');

    await setLanguage('ja');
    expect(tr('Explore'), '探す');
    expect(tr('Day {0}/{1}', [2, 7]), '2/7日目');
    expect(tr('Not a key yet'), 'Not a key yet');
    expect(chosenLanguage, 'ja');

    await setLanguage(null);
    expect(chosenLanguage, isNull);
  });

  test('every Japanese entry keeps its placeholders', () {
    final ph = RegExp(r'\{\d\}');
    for (final e in ja.entries) {
      final keyPh = ph.allMatches(e.key).map((m) => m[0]).toSet();
      final valPh = ph.allMatches(e.value).map((m) => m[0]).toSet();
      expect(keyPh.containsAll(valPh), isTrue, reason: e.key);
    }
  });
}
