// จัดรูปแบบวันที่/เวลาเอง เพราะโปรเจคยังไม่ได้ลง package intl
// รวมไว้ที่เดียวเพราะหน้า Party, หน้าสร้างห้อง และการ์ดห้องในหน้า Explore ต้องใช้รูปแบบเดียวกัน
// (ก่อนหน้านี้ก๊อป _monthNames กันไปคนละไฟล์ พอแก้รูปแบบทีต้องไล่แก้หลายที่)
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _pad(int n) => n.toString().padLeft(2, '0');

/// เช่น "Sep 13, 2026  ·  09:00" — ใช้กับวันเวลานัดหมายของห้องปาร์ตี้
String formatEventDateTime(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}  ·  ${_pad(date.hour)}:${_pad(date.minute)}';

/// เช่น "Sep 13, 2026" — เวอร์ชันไม่เอาเวลา ใช้ตอนพื้นที่แคบ
String formatEventDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

/// เช่น "2 hours ago" / "Yesterday" — ใช้กับเวลาของแจ้งเตือน
/// เกินประมาณ 7 วันแล้ว fallback ไปโชว์วันที่เต็มแทน (formatEventDate) เพราะ "N days ago" ที่นานมากอ่านยาก
String formatRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);

  if (diff.inDays >= 7) return formatEventDate(date);
  if (diff.inDays >= 2) return '${diff.inDays} days ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inHours >= 1) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  return 'Just now';
}
