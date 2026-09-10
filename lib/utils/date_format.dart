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
