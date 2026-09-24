import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item_model.dart';
import '../providers/auth_provider.dart';
import '../utils/cosmetics.dart';
import 'falling_leaves_overlay.dart';
import 'profile_sections.dart';

// ดูตัวอย่างของตกแต่งก่อนซื้อ — วาดส่วนหัวโปรไฟล์จริงของผู้เล่น (ชื่อ/รูป/เลเวล) ด้วย widget ชุดเดียวกับ
// หน้า Profile เป๊ะ (ProfileBackground + AmbientOverlay + UserHeader) โดยสวมชิ้นที่กำลังดูแทนช่องของมัน
// ส่วนช่องอื่นใช้ของที่ใส่อยู่จริงตอนนี้ — ผลที่เห็นจึงตรงกับตอนใส่จริงทุกอย่าง
Future<void> showCosmeticPreview(
  BuildContext context, {
  required InventoryItemModel item,
  required bool owned,
  required bool canAfford,
  VoidCallback? onBuy,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CosmeticPreviewSheet(item: item, owned: owned, canAfford: canAfford, onBuy: onBuy),
  );
}

class _CosmeticPreviewSheet extends StatelessWidget {
  final InventoryItemModel item;
  final bool owned;
  final bool canAfford;
  final VoidCallback? onBuy;

  const _CosmeticPreviewSheet({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final progress = auth.profile?.progress;
    final equipped = user?.cosmetics;

    String? wear(CosmeticSlot slot, String? current) => item.slot == slot ? item.itemType : current;
    final frame = wear(CosmeticSlot.frame, equipped?.frame);
    final nameStyle = wear(CosmeticSlot.nameStyle, equipped?.nameStyle);
    final background = wear(CosmeticSlot.background, equipped?.background);
    final effect = wear(CosmeticSlot.effect, equipped?.effect);

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SizedBox(
        height: screenHeight * 0.6,
        child: Stack(
          children: [
            Positioned.fill(child: ProfileBackground(backgroundItemType: background)),
            // overlay มืดชุดเดียวกับหน้า Profile ให้สีตัวหนังสือ/ชื่อออกมาเหมือนตอนใส่จริง
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.53),
                      Colors.black.withValues(alpha: 0.33),
                      Colors.black.withValues(alpha: 0.63),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: AmbientOverlay(effect: cosmeticStyleFor(effect)?.effect)),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.accentColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PREVIEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cosmeticSlotLabel(item.slot!),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    UserHeader(
                      displayName: user?.displayName ?? 'Player',
                      avatarUrl: user?.avatarUrl,
                      frameItemType: frame,
                      nameStyleItemType: nameStyle,
                      level: progress?.level ?? user?.level ?? 1,
                      xp: progress?.xpIntoLevel ?? 0,
                      xpToNext: progress?.xpForNextLevel ?? 0,
                    ),
                    const Spacer(),
                    Text(
                      owned
                          ? 'You already own this — equip it from Custom Profile.'
                          : 'This is how your profile will look with ${item.title}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        if (!owned) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canAfford && onBuy != null
                                  ? () {
                                      Navigator.pop(context);
                                      onBuy!();
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: item.accentColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white24,
                                disabledForegroundColor: Colors.white60,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              child: Text(
                                canAfford ? 'Buy · ${item.cost} P' : 'Need ${item.cost} P',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
