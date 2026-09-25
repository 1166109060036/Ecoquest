// path รูปปกเควสจาก Quest.imageKey (ตั้งใน backend/scripts/seedQuests.js) — null ถ้าเควสยังไม่มีรูป
// imageKey ที่มีนามสกุลมาด้วย (เช่น 'sortwastecorrectly.jpg') ใช้ตามนั้นเลย ไม่มีนามสกุลถือเป็น .png
// ⚠️ ชื่อไฟล์ต้องตรงตัวพิมพ์เล็ก-ใหญ่เป๊ะ — Android แยกตัวพิมพ์ สะกดผิดนิดเดียวรูปไม่ขึ้น (fallback เป็นพื้นเขียวเงียบๆ)
String? questCoverAsset(String? imageKey) {
  if (imageKey == null || imageKey.isEmpty) return null;
  final file = imageKey.contains('.') ? imageKey : '$imageKey.png';
  return 'lib/utils/assets/questimg/$file';
}
