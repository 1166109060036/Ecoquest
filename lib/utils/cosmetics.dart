import 'package:flutter/material.dart';

// แคตตาล็อก "หน้าตา" ของของตกแต่งโปรไฟล์ทั้งหมด — คู่กับ backend/utils/inventory.js#ITEMS
// (itemType ต้องตรงกันเป๊ะ) backend ไม่ส่ง icon/สี/รูปมาเลยตามธรรมเนียมเดิมของแอพ (ดู
// InventoryItemModel.icon/accentColor/imageAsset ที่ resolve เองด้วย switch (itemType))
// แยกไฟล์นี้ออกมาต่างหากเพราะ InventoryItemModel เป็นแค่ DTO ไม่ควรมีข้อมูลภาพขนาดนี้ปนอยู่
//
// งานศิลป์รอบแรกวาดด้วยโค้ดล้วน (gradient/CustomPainter) ตามที่ตกลงไว้ — ช่อง background มี
// backgroundAsset เผื่อไว้ล่วงหน้า วางไฟล์ PNG ทีหลังได้โดยไม่ต้องแก้โครงสร้างนี้

enum CosmeticSlot { frame, nameStyle, background, effect }

// ต้องตรงกับรูปแบบที่ AmbientOverlay รองรับ (lib/widgets/falling_leaves_overlay.dart)
enum AmbientEffectType { leaves, snow, rain, ember }

class CosmeticStyle {
  final CosmeticSlot slot;
  final IconData icon;
  final Color accentColor;

  // ---- slot: frame — วงแหวนรอบรูปโปรไฟล์ ----
  final Gradient? ringGradient;
  final double ringWidth;
  final Color? ringGlowColor; // ไม่ null = มีเรืองแสงรอบวงแหวนด้วย (เช่น Golden Sun)

  // ---- slot: nameStyle — สีชื่อที่แสดง ----
  final Color? nameColor; // สีเดียว
  final Gradient? nameGradient; // ไล่เฉด (ใช้แทน nameColor ถ้ามีค่า)
  final List<Shadow>? nameGlow;

  // ---- slot: background — พื้นหลังโปรไฟล์ ----
  final Gradient? backgroundGradient; // ใช้ก่อนจนกว่าจะมีไฟล์รูปจริง
  final String? backgroundAsset; // เผื่ออนาคต — ยังไม่มีไฟล์จริงตอนนี้

  // ---- slot: effect — แอนิเมชันบรรยากาศ ----
  final AmbientEffectType? effect;

  const CosmeticStyle({
    required this.slot,
    required this.icon,
    required this.accentColor,
    this.ringGradient,
    this.ringWidth = 3,
    this.ringGlowColor,
    this.nameColor,
    this.nameGradient,
    this.nameGlow,
    this.backgroundGradient,
    this.backgroundAsset,
    this.effect,
  });
}

const Map<String, CosmeticStyle> kCosmetics = {
  // ---- nameStyle ----
  'name_mint': CosmeticStyle(
    slot: CosmeticSlot.nameStyle,
    icon: Icons.text_fields_rounded,
    accentColor: Color(0xFF3DE8B0),
    nameColor: Color(0xFF3DE8B0),
  ),
  'name_sunset': CosmeticStyle(
    slot: CosmeticSlot.nameStyle,
    icon: Icons.text_fields_rounded,
    accentColor: Colors.deepOrangeAccent,
    nameGradient: LinearGradient(colors: [Colors.orangeAccent, Colors.pinkAccent]),
  ),
  'name_aurora': CosmeticStyle(
    slot: CosmeticSlot.nameStyle,
    icon: Icons.text_fields_rounded,
    accentColor: Colors.purpleAccent,
    nameGradient: LinearGradient(colors: [Colors.greenAccent, Colors.purpleAccent]),
    nameGlow: [Shadow(color: Colors.greenAccent, blurRadius: 12)],
  ),

  // ---- frame ----
  'frame_leaf': CosmeticStyle(
    slot: CosmeticSlot.frame,
    icon: Icons.eco_rounded,
    accentColor: Colors.green,
    ringGradient: SweepGradient(colors: [
      Color(0xFF8BE28B),
      Color(0xFF2E7D32),
      Color(0xFF8BE28B),
    ]),
  ),
  'frame_ocean': CosmeticStyle(
    slot: CosmeticSlot.frame,
    icon: Icons.water_rounded,
    accentColor: Colors.lightBlue,
    ringGradient: SweepGradient(colors: [
      Color(0xFF81D4FA),
      Color(0xFF01579B),
      Color(0xFF81D4FA),
    ]),
  ),
  'frame_gold': CosmeticStyle(
    slot: CosmeticSlot.frame,
    icon: Icons.wb_sunny_rounded,
    accentColor: Colors.amber,
    ringGradient: SweepGradient(colors: [
      Color(0xFFFFE082),
      Color(0xFFFF8F00),
      Color(0xFFFFE082),
    ]),
    ringGlowColor: Colors.amberAccent,
  ),

  // ---- effect ----
  'fx_leaves': CosmeticStyle(
    slot: CosmeticSlot.effect,
    icon: Icons.eco_outlined,
    accentColor: Colors.green,
    effect: AmbientEffectType.leaves,
  ),
  'fx_snow': CosmeticStyle(
    slot: CosmeticSlot.effect,
    icon: Icons.ac_unit_rounded,
    accentColor: Colors.lightBlueAccent,
    effect: AmbientEffectType.snow,
  ),
  'fx_rain': CosmeticStyle(
    slot: CosmeticSlot.effect,
    icon: Icons.grain_rounded,
    accentColor: Colors.blueGrey,
    effect: AmbientEffectType.rain,
  ),
  'fx_ember': CosmeticStyle(
    slot: CosmeticSlot.effect,
    icon: Icons.local_fire_department_rounded,
    accentColor: Colors.deepOrange,
    effect: AmbientEffectType.ember,
  ),

  // ---- background ----
  'bg_forest': CosmeticStyle(
    slot: CosmeticSlot.background,
    icon: Icons.forest_rounded,
    accentColor: Color(0xFF2E7D32),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B3B2A), Color(0xFF0B1F14)],
    ),
  ),
  'bg_night': CosmeticStyle(
    slot: CosmeticSlot.background,
    icon: Icons.nightlight_round,
    accentColor: Color(0xFF283593),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D1333), Color(0xFF1A1443)],
    ),
  ),
};

CosmeticStyle? cosmeticStyleFor(String? itemType) =>
    itemType == null ? null : kCosmetics[itemType];
