import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/fridge_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fridge_provider.dart';
import '../../providers/quest_provider.dart';
import '../../widgets/inventory_card.dart';

// หน้าดูของในตู้เย็น + บันทึกของใหม่ — เข้าได้ 2 ทาง:
//   1) กดไอเทม Fridge ในหน้า Inventory
//   2) กด Start บน quest "Check Your Food & Expiration Dates" (quest ที่มี actionKey = fridge_check)
//
// การบันทึกของที่นี่ *คือ* ตัว Mini Quest จริงๆ — พอกด Save สำเร็จจะไปกดจบ quest ให้อัตโนมัติ
// (backend ก็เช็คซ้ำอีกชั้นว่าต้องมีของที่บันทึกวันนี้จริงถึงจะให้คะแนน กดปุ่มเฉยๆ ไม่ผ่าน)
const IconData _foodFallbackIcon = Icons.restaurant;

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // เดินนาฬิกาทุก 1 วินาที เพราะของที่เหลือน้อยกว่า 24 ชม. ต้องโชว์วินาทีถอยหลังจริงๆ
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FridgeProvider>().loadItems();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _openAddItemSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // ให้ sheet ดันขึ้นเหนือคีย์บอร์ด
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddItemSheet(),
    );
  }

  // Save ของที่กรอกไว้ แล้วถ้ามี quest เช็คตู้เย็นที่ยังไม่ได้ทำวันนี้ ก็กดจบ quest ให้เลย
  Future<void> _saveAndCompleteQuest() async {
    final fridgeProvider = context.read<FridgeProvider>();
    final questProvider = context.read<QuestProvider>();
    final authProvider = context.read<AuthProvider>();

    final saved = await fridgeProvider.saveDrafts();
    if (!mounted) return;

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fridgeProvider.errorMessage ?? 'Failed to save items')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // หา quest เช็คตู้เย็นที่ยังทำได้อยู่ (ถ้าวันนี้ทำไปแล้วก็แค่บันทึกของเฉยๆ ไม่ได้คะแนนซ้ำ)
    final pending = questProvider.quests
        .where((q) => q.actionKey == 'fridge_check' && !q.completedToday)
        .toList();
    final fridgeQuest = pending.isEmpty ? null : pending.first;

    if (fridgeQuest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fridge items saved')),
      );
      return;
    }

    final reward = await questProvider.completeQuest(fridgeQuest.id);
    if (!mounted) return;

    if (reward == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(questProvider.errorMessage ?? 'Items saved, but the quest failed')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Quest complete! +${reward.points} points, +${reward.xp} XP')),
    );
    await authProvider.refreshProfile();
  }

  Future<void> _confirmDelete(FridgeItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove item?'),
        content: Text('"${item.name}" will be removed from your fridge.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final fridgeProvider = context.read<FridgeProvider>();
    final ok = await fridgeProvider.deleteItem(item.id);
    if (!mounted || ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(fridgeProvider.errorMessage ?? 'Failed to remove item')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fridgeProvider = context.watch<FridgeProvider>();
    final items = fridgeProvider.items;
    final drafts = fridgeProvider.drafts;
    final now = DateTime.now();
    final isEmpty = items.isEmpty && drafts.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItemSheet,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---- หัวข้อ: ปุ่ม back + ชื่อหน้า + ปุ่ม Save (โผล่เฉพาะตอนมีของค้าง) ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  const Text('Fridge',
                      style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // ค่อยๆ fade เข้า/ออก จะได้ไม่กระตุกตอนเพิ่มของชิ้นแรก
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: drafts.isEmpty
                        ? const SizedBox.shrink()
                        : _SaveButton(
                            count: drafts.length,
                            isSaving: fridgeProvider.isSaving,
                            onSave: _saveAndCompleteQuest,
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: fridgeProvider.isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : isEmpty
                      ? _EmptyState(errorMessage: fridgeProvider.errorMessage)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                          children: [
                            // ---- ของที่กรอกไว้แต่ยังไม่ได้ Save ----
                            if (drafts.isNotEmpty) ...[
                              const _SectionLabel('Not saved yet'),
                              const SizedBox(height: 8),
                              for (int i = 0; i < drafts.length; i++) ...[
                                _FadeSlideIn(
                                  // key ผูกกับชื่อ+ลำดับ เพื่อให้ animate เฉพาะใบที่เพิ่งเพิ่มจริงๆ
                                  key: ValueKey('draft-$i-${drafts[i].name}'),
                                  child: _DraftCard(
                                    draft: drafts[i],
                                    onRemove: () => context.read<FridgeProvider>().removeDraft(i),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              const SizedBox(height: 4),
                              const _SectionLabel('In your fridge'),
                              const SizedBox(height: 8),
                            ],
                            // ---- ของที่บันทึกไว้แล้ว ----
                            if (items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Nothing saved yet',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              )
                            else
                              for (final item in items) ...[
                                InventoryCard(
                                  // ของในตู้เย็นใช้รูปที่ผู้ใช้ถ่ายเองเป็นหลัก
                                  // ยังไม่มีรูป (หรือไฟล์หาย) ค่อย fallback เป็นไอคอนอาหาร
                                  imageFile:
                                      item.photoPath != null ? File(item.photoPath!) : null,
                                  icon: _foodFallbackIcon,
                                  iconColor: Colors.green,
                                  title: item.name,
                                  description: _describeExpiry(item, now),
                                  // หมดอายุแล้วให้ตัวหนังสือเป็นสีแดง
                                  descriptionColor:
                                      item.isExpiredAt(now) ? Colors.red : null,
                                  quantity: item.quantity,
                                  onLongPress: () => _confirmDelete(item),
                                ),
                                const SizedBox(height: 14),
                              ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ปุ่ม Save มุมขวาบน — โชว์จำนวนของที่ยังไม่ได้บันทึกไปด้วย
// ---------------------------------------------------------------------------
class _SaveButton extends StatelessWidget {
  final int count;
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveButton({required this.count, required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isSaving ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.green.withValues(alpha: 0.5),
        elevation: 0,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: isSaving
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text('Save ($count)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------------------------------------------------------------------
// ฟอร์มเพิ่มของ — รูป + ชื่อ + วันหมดอายุ + จำนวน
// ออกแบบให้กรอกรัวๆ ได้: โฟกัสช่องชื่อให้เลย, มีปุ่มลัดเลือกวันหมดอายุ,
// และมีปุ่ม "Add another" ที่ไม่ปิด sheet เพื่อกรอกชิ้นถัดไปต่อได้ทันที
// ---------------------------------------------------------------------------
class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet();

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _picker = ImagePicker();

  DateTime? _expirationDate;
  int _quantity = 1;
  String? _photoPath;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      // ย่อรูปตั้งแต่ตอนถ่าย — แสดงจริงแค่ 72px ไม่ต้องเก็บไฟล์ใหญ่
      final shot = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (shot != null && mounted) {
        setState(() => _photoPath = shot.path);
      }
    } catch (e) {
      if (!mounted) return;
      // เครื่องไม่มีกล้อง / ผู้ใช้ปฏิเสธ permission
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera')),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now.add(const Duration(days: 3)),
      // เลือกวันย้อนหลังได้ด้วย เผื่อเพิ่งมาบันทึกของที่หมดอายุไปแล้ว
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  void _setQuickDate(Duration from) {
    setState(() => _expirationDate = DateTime.now().add(from));
  }

  // คืน draft ถ้ากรอกครบ / null ถ้ายังขาด (พร้อมเด้ง SnackBar บอก)
  FridgeItemDraft? _buildDraft() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the item name')),
      );
      return null;
    }
    if (_expirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick an expiration date')),
      );
      return null;
    }

    return FridgeItemDraft(
      name: name,
      // ตั้งเป็นสิ้นวันที่เลือก ของจะได้ไม่หมดอายุตั้งแต่เที่ยงคืนของวันนั้น
      expirationDate: DateTime(
        _expirationDate!.year,
        _expirationDate!.month,
        _expirationDate!.day,
        23,
        59,
        59,
      ),
      quantity: _quantity,
      photoPath: _photoPath,
    );
  }

  void _add({required bool keepOpen}) {
    final draft = _buildDraft();
    if (draft == null) return;

    context.read<FridgeProvider>().addDraft(draft);
    HapticFeedback.selectionClick();

    if (!keepOpen) {
      Navigator.pop(context);
      return;
    }

    // เคลียร์ฟอร์มแล้วโฟกัสช่องชื่อต่อ กรอกชิ้นถัดไปได้เลยไม่ต้องเปิด sheet ใหม่
    setState(() {
      _nameController.clear();
      _expirationDate = null;
      _quantity = 1;
      _photoPath = null;
    });
    _nameFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ดัน sheet ขึ้นเหนือคีย์บอร์ดตอนพิมพ์
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              // ---- รูป + ชื่อ อยู่แถวเดียวกัน ประหยัดพื้นที่ตอนคีย์บอร์ดขึ้น ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoPickerBox(
                    photoPath: _photoPath,
                    onTakePhoto: () => _pickPhoto(ImageSource.camera),
                    onPickFromGallery: () => _pickPhoto(ImageSource.gallery),
                    onClear: () => setState(() => _photoPath = null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      autofocus: true, // พิมพ์ได้เลยไม่ต้องแตะช่องก่อน
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(keepOpen: false),
                      decoration: InputDecoration(
                        labelText: 'Item name',
                        hintText: 'e.g. Milk',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ---- ปุ่มลัดวันหมดอายุ กดทีเดียวจบ ไม่ต้องเปิด date picker ----
              Row(
                children: [
                  _QuickDateChip(label: '3 days', onTap: () => _setQuickDate(const Duration(days: 3))),
                  const SizedBox(width: 8),
                  _QuickDateChip(label: '1 week', onTap: () => _setQuickDate(const Duration(days: 7))),
                  const SizedBox(width: 8),
                  _QuickDateChip(label: '1 month', onTap: () => _setQuickDate(const Duration(days: 30))),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expiration date',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _expirationDate == null
                            ? 'Tap to pick a date'
                            : _formatDate(_expirationDate!),
                        style: TextStyle(
                          color: _expirationDate == null ? Colors.grey.shade500 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Quantity', style: TextStyle(fontSize: 14, color: Colors.black87)),
                  const Spacer(),
                  IconButton(
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.green,
                  ),
                  Text('$_quantity',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _add(keepOpen: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Add', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => _add(keepOpen: true),
                child: const Text('Add another', style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// กล่องเลือกรูป 72×72 — แตะ = เปิดกล้องเลย, ปุ่มเล็กมุมล่างขวา = เลือกจากคลังรูป
class _PhotoPickerBox extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final VoidCallback onClear;

  const _PhotoPickerBox({
    required this.photoPath,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null;

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: hasPhoto ? onClear : onTakePhoto,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Image.file(
                      File(photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, color: Colors.green),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera, color: Colors.green, size: 24),
                        SizedBox(height: 2),
                        Text('Photo',
                            style: TextStyle(fontSize: 10, color: Colors.green)),
                      ],
                    ),
            ),
          ),
          // มีรูปแล้ว -> ปุ่มนี้กลายเป็น "ลบรูป", ยังไม่มีรูป -> "เลือกจากคลังรูป"
          Positioned(
            right: -6,
            bottom: -6,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: hasPhoto ? onClear : onPickFromGallery,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    hasPhoto ? Icons.close : Icons.photo_library_outlined,
                    size: 15,
                    color: hasPhoto ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickDateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green,
          side: BorderSide(color: Colors.green.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// ค่อยๆ เลื่อนขึ้น + จางเข้า ตอนการ์ดใบใหม่โผล่มา ให้ไม่กระตุกตาเวลาเพิ่มของ
class _FadeSlideIn extends StatelessWidget {
  final Widget child;
  const _FadeSlideIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดของที่ยังไม่ได้บันทึก — หน้าตาต่างจากของที่บันทึกแล้วเพื่อให้แยกออกชัดๆ
// ---------------------------------------------------------------------------
class _DraftCard extends StatelessWidget {
  final FridgeItemDraft draft;
  final VoidCallback onRemove;

  const _DraftCard({required this.draft, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: draft.photoPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(draft.photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(_foodFallbackIcon, color: Colors.green, size: 28),
                    ),
                  )
                : const Icon(_foodFallbackIcon, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(draft.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  'Expires ${_formatDate(draft.expirationDate)}  ·  x${draft.quantity}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close, color: Colors.grey.shade500, size: 20),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ข้อความบรรทัดรายละเอียด: วันหมดอายุ + เวลาที่เหลือ
// ---------------------------------------------------------------------------
String _describeExpiry(FridgeItemModel item, DateTime now) {
  final date = _formatDate(item.expirationDate);

  if (item.isExpiredAt(now)) {
    return 'Expired ($date)';
  }
  return 'Expires $date · ${_formatRemaining(item.remainingFrom(now))} left';
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

// เหลือเกิน 24 ชม. -> วัน:ชั่วโมง:นาที
// เหลือไม่ถึง 24 ชม. -> ชั่วโมง:นาที:วินาที
String _formatRemaining(Duration remaining) {
  if (remaining.inHours >= 24) {
    return '${remaining.inDays}:'
        '${_twoDigits(remaining.inHours % 24)}:'
        '${_twoDigits(remaining.inMinutes % 60)}';
  }
  return '${_twoDigits(remaining.inHours)}:'
      '${_twoDigits(remaining.inMinutes % 60)}:'
      '${_twoDigits(remaining.inSeconds % 60)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chevron_left, color: Colors.black54, size: 22),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? errorMessage;
  const _EmptyState({this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(failed ? Icons.cloud_off : Icons.kitchen_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              failed ? errorMessage! : 'Your fridge is empty',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (!failed) ...[
              const SizedBox(height: 6),
              Text(
                'Tap "Add Item" to record food and expiration dates',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
