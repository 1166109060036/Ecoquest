import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// รวมการเล่นเสียงทั้งหมดของแอพไว้ที่เดียว — ตอนนี้มี 2 อย่าง: เพลงพื้นหลัง (เล่นวนตั้งแต่เปิดแอพ)
// กับเสียงกดปุ่ม (เล่นเฉพาะตอนแตะ widget ที่กดได้จริงๆ ผ่าน SoundSplashFactory ด้านล่างไฟล์นี้ ที่ครอบ
// ThemeData ทั้งก้อนใน lib/main.dart — ไม่ใช่ทุกจุดที่แตะหน้าจอเหมือนที่เคยลองด้วย Listener ตอนแรก
// เพราะพื้นที่ว่างก็ดังไปด้วย ผู้ใช้ไม่ต้องการแบบนั้น)
//
// ไฟล์เสียงจริงยังไม่มี (ผู้ใช้จะหามาใส่เอง) — วางไว้ที่ lib/utils/assets/sounds/ ตามชื่อที่กำหนดไว้ด้านล่าง
// (ดู lib/utils/assets/sounds/README.md) ทุกเมธอดในนี้ต้องดัก error เงียบๆ เสมอ ไม่ throw ต่อ เพราะไฟล์
// อาจจะยังไม่มี — แอพต้องรันได้ปกติทุกอย่างเหมือนเดิม แค่ไม่มีเสียงเฉยๆ (แนวเดียวกับ errorBuilder ที่
// InventoryCard ใช้ตอนหารูปไอเทมไม่เจอ)
class SoundService {
  SoundService._() {
    // ⚠️ ต้อง assign .audioCache ให้แต่ละ player ในนี้ (constructor body) ไม่ใช่ไปแก้ AudioCache.instance
    // ตัว global เฉยๆ เพราะ AudioPlayer จับค่า AudioCache.instance ไปเก็บเป็นของตัวเองตอนสร้างออบเจกต์
    // (`AudioCache audioCache = AudioCache.instance;` เป็น field initializer รันก่อน constructor body
    // ของ SoundService นี้เสมอ — ถ้าไปแก้ AudioCache.instance ในนี้จะช้าไปแล้ว ผู้เล่นทั้งคู่จับ instance
    // เก่าไปแล้วตั้งแต่บรรทัด `final AudioPlayer _music = AudioPlayer();` ด้านล่าง)
    _music.audioCache = _cache;
    _click.audioCache = _cache;
  }
  static final SoundService instance = SoundService._();

  static const _backgroundMusicAsset = 'lib/utils/assets/sounds/background_music.mp3';
  static const _buttonClickAsset = 'lib/utils/assets/sounds/button_click.mp3';

  // audioplayers เติม prefix "assets/" ให้ AssetSource เองโดย default — โปรเจคนี้ไม่ได้เก็บ asset ไว้ใต้
  // โฟลเดอร์ assets/ (เก็บใต้ lib/utils/assets/ ตามที่ pubspec.yaml ประกาศไว้จริง) เลยต้องเคลียร์ prefix
  // ทิ้งแล้วใช้ path เต็มตรงกับที่ประกาศใน pubspec เป๊ะๆ (ดู _backgroundMusicAsset/_buttonClickAsset ด้านบน)
  static final AudioCache _cache = AudioCache(prefix: '');

  // ⚠️ ค่า default ของ audioplayers คือ AndroidAudioFocus.gain — แปลว่าทุกครั้งที่ play() ถูกเรียก
  // แอพจะไปขอ audio focus แบบ "เป็นเจ้าของเสียงคนเดียว" กับระบบ Android ซึ่งทำให้เสียงอื่นที่เล่นอยู่ก่อน
  // (รวมถึง player อีกตัวในแอพเดียวกันเอง) โดน pause ไปเงียบๆ — นี่คือสาเหตุที่กดปุ่มแล้วเพลงพื้นหลังหาย
  // ต้องตั้งเป็น mixWithOthers (Android: AndroidAudioFocus.none) ให้ทั้งคู่ ไม่ขอ focus แบบผูกขาด
  // ถึงจะเล่นซ้อนกันได้โดยไม่แย่งกันเอง
  static final AudioContext _mixContext =
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  final AudioPlayer _music = AudioPlayer();
  // ⚠️ เคยลองใช้ PlayerMode.lowLatency (SoundPool บน Android) เพื่อลด delay ตอนกดรัวๆ แต่ SoundPool
  // เข้มงวดเรื่องฟอร์แมต mp3 มาก — ไฟล์เสียงบางแบบ (เช่น VBR/มี ID3 tag แปลกๆ) ทำให้ decode ไม่ผ่านแล้ว
  // เงียบไปเลยไม่มี error ให้เห็น (โหลดไม่สำเร็จ กด play ก็ไม่มีเสียงออกโดยไม่ throw) เปลี่ยนกลับมาใช้
  // PlayerMode.mediaPlayer (ค่า default เดียวกับ _music) เพราะรองรับไฟล์เสียงได้กว้างกว่ามาก
  final AudioPlayer _click = AudioPlayer();

  // ---- ระดับเสียง — แยกเพลงพื้นหลัง/เสียงระบบ (ปุ่มกด) ออกจากกัน ปรับได้ในหน้า Settings ----
  static const _musicVolumeKey = 'sound_music_volume';
  static const _clickVolumeKey = 'sound_click_volume';

  double _musicVolume = 1.0;
  double _clickVolume = 1.0;

  double get musicVolume => _musicVolume;
  double get clickVolume => _clickVolume;

  Future<void> playBackgroundMusic() async {
    try {
      await _music.setAudioContext(_mixContext);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource(_backgroundMusicAsset));
    } catch (e) {
      // ยังไม่มีไฟล์เพลง หรือเล่นไม่ได้ — เงียบไว้ ไม่ทำให้แอพพัง (debugPrint ไม่โชว์ผู้ใช้จริง
      // แต่ช่วยเช็คได้ตอนรัน `flutter run` ว่าจริงๆ แล้วพังเพราะอะไร)
      debugPrint('SoundService: playBackgroundMusic failed — $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _music.stop();
    } catch (_) {
      // ไม่ได้เล่นอยู่แล้วก็ไม่เป็นไร
    }
  }

  Future<void> playClick() async {
    try {
      await _click.setAudioContext(_mixContext);
      await _click.play(AssetSource(_buttonClickAsset));
    } catch (e) {
      debugPrint('SoundService: playClick failed — $e');
    }
  }

  // เรียกครั้งเดียวตอนเปิดแอพ (ก่อน playBackgroundMusic ใน main()) — โหลดระดับเสียงที่เคยตั้งไว้
  // ครั้งก่อนกลับมาใช้ ไม่งั้นทุกครั้งที่เปิดแอพใหม่เสียงจะรีเซ็ทกลับไปดังสุดเสมอ
  Future<void> loadSavedVolumes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicVolume = prefs.getDouble(_musicVolumeKey) ?? 1.0;
      _clickVolume = prefs.getDouble(_clickVolumeKey) ?? 1.0;
      await _music.setVolume(_musicVolume);
      await _click.setVolume(_clickVolume);
    } catch (e) {
      debugPrint('SoundService: loadSavedVolumes failed — $e');
    }
  }

  // persist: false ใช้ตอนลากสไลเดอร์อยู่ (ปรับเสียงสดๆ ให้ได้ยินทันที แต่ไม่ต้องเขียนดิสก์ทุกเฟรมที่ลาก)
  // ค่อยส่ง persist: true (ค่า default) ตอนปล่อยนิ้วครั้งเดียวพอ — ดู _VolumeSliderItem ในหน้า Settings
  Future<void> setMusicVolume(double volume, {bool persist = true}) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    try {
      await _music.setVolume(_musicVolume);
      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_musicVolumeKey, _musicVolume);
      }
    } catch (e) {
      debugPrint('SoundService: setMusicVolume failed — $e');
    }
  }

  Future<void> setClickVolume(double volume, {bool persist = true}) async {
    _clickVolume = volume.clamp(0.0, 1.0);
    try {
      await _click.setVolume(_clickVolume);
      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_clickVolumeKey, _clickVolume);
      }
    } catch (e) {
      debugPrint('SoundService: setClickVolume failed — $e');
    }
  }
}

// เล่นเสียงคลิกเฉพาะตอนแตะ widget ที่ "กดได้จริงๆ" เท่านั้น (ปุ่ม, InkWell, แถวในลิสต์ที่กดได้ ฯลฯ)
// ไม่ใช่ทุกจุดที่แตะหน้าจอ — Flutter ไม่มี callback กลางที่ดักได้เฉพาะปุ่มตรงๆ แต่ widget ที่กดได้แทบทุกตัว
// ในแอพ (ElevatedButton/TextButton/IconButton/InkWell/ListTile ฯลฯ) ใช้ InkWell/InkResponse ข้างใน ซึ่ง
// ทุกตัวสร้าง "ระลอกคลื่นตอนกด" (ink splash) ผ่าน Theme.splashFactory ตัวเดียวกันเสมอ — ครอบตรงนี้ที่เดียว
// เลยเท่ากับดักได้ทุกปุ่ม/ของที่กดได้ทั่วแอพ โดยไม่ต้องแก้ไฟล์ปุ่มทีละไฟล์ และพื้นที่ว่าง (ไม่มี ink splash)
// จะไม่มีเสียงออกมาด้วย ตรงตามที่ต้องการ
//
// ⚠️ ข้อจำกัด: widget ที่ทำปุ่มเองด้วย GestureDetector ตรงๆ (ไม่ผ่าน InkWell/Material) จะไม่มี ink splash
// เลยไม่มีเสียงตามไปด้วย — ถ้าเจอจุดไหนกดแล้วไม่มีเสียงทั้งที่ควรจะมี บอกได้ จะเพิ่มให้เฉพาะจุดนั้น
class SoundSplashFactory extends InteractiveInkFeatureFactory {
  const SoundSplashFactory(this._inner);

  // ระลอกคลื่นจริงๆ ยังวาดตามปกติ แค่แอบเล่นเสียงแทรกเข้าไปก่อน ไม่ได้เปลี่ยนหน้าตาการกดของแอพเลย
  final InteractiveInkFeatureFactory _inner;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    SoundService.instance.playClick();
    return _inner.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}
