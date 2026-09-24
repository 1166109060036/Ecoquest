// ค่า kgCO2e ในแอพเป็น "ค่าประมาณ" เสมอ (ที่มาดู CO2_RESEARCH.md) — ใส่ "≈" ทุกครั้ง และต่ำกว่า 1 kg
// แสดงเป็นกรัม (เดิมใช้ toStringAsFixed(1) ทำให้ค่าเล็กๆ แบบ 0.04 kg โชว์เป็น "0.0 kg")
String formatCo2e(double kg) {
  if (kg <= 0) return '0 g';
  if (kg < 1) return '≈ ${(kg * 1000).round()} g';
  return '≈ ${kg.toStringAsFixed(2)} kg';
}
