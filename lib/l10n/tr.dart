import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ja.dart';

// ระบบหลายภาษา (2 พ.ย. 2026) — ข้อความอังกฤษในโค้ดคือ key ของคำแปล: tr('Explore') / tr('{0} points', [n])
// ไม่มีคำแปลใน ja.dart = โชว์อังกฤษเดิม เลยเพิ่มข้อความใหม่ได้โดยไม่พัง แค่ยังไม่แปล
// เรียกได้ทุกที่ (service/provider ด้วย) เพราะไม่ต้องใช้ BuildContext

const supportedLanguages = {'en': 'English', 'ja': '日本語'};
const _prefKey = 'app_language';

String _lang = 'en';
String get appLanguage => _lang;

/// null = ตามภาษาของมือถือ (ค่าเริ่มต้น)
String? _chosen;
String? get chosenLanguage => _chosen;

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

String tr(String en, [List<Object?> args = const []]) {
  var s = _lang == 'ja' ? (ja[en] ?? en) : en;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

String _systemLanguage() {
  final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return supportedLanguages.containsKey(code) ? code : 'en';
}

void _apply(String lang) {
  _lang = lang;
  appLocale.value = Locale(lang);
}

/// เรียกใน main() ก่อน runApp
Future<void> loadSavedLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  _chosen = prefs.getString(_prefKey);
  _apply(_chosen ?? _systemLanguage());
}

/// lang = null -> กลับไปตามภาษามือถือ
Future<void> setLanguage(String? lang) async {
  final prefs = await SharedPreferences.getInstance();
  if (lang == null) {
    await prefs.remove(_prefKey);
  } else {
    await prefs.setString(_prefKey, lang);
  }
  _chosen = lang;
  _apply(lang ?? _systemLanguage());
  // tr() ไม่ผูกกับ widget tree — สั่ง build ใหม่ทั้งแอพให้ข้อความทุกหน้าเปลี่ยนทันที
  void rebuild(Element e) {
    e.markNeedsBuild();
    e.visitChildren(rebuild);
  }
  WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
}
