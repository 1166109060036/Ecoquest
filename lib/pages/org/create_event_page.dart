import 'package:flutter/material.dart';
import '../../models/org_event_model.dart';
import '../../services/org_service.dart';
import '../../utils/date_format.dart';
import '../../widgets/bubble_toast.dart';

// ฟอร์มสร้างอีเวนต์ขององค์กร (14 ต.ค. 2026) — กติกาตรวจซ้ำที่ backend/routes/org.js ทุกข้อ:
// แต้ม 10–40, ยาว 15 นาที–8 ชม., ล่วงหน้าไม่เกิน 60 วัน, รับ 1–1000 คน, ไม่เกิน 3 งานต่อวัน
// สร้างสำเร็จ = pop กลับพร้อม OrgEventModel
class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  static const _minPoints = 10;
  static const _maxPoints = 40;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  String _category = 'community';
  int _points = 25;
  late DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 12, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final startAt = _at(_start);
    final endAt = _at(_end);
    if (!endAt.isAfter(startAt)) {
      showBubbleToast(context, 'The end time must be after the start time');
      return;
    }
    setState(() => _saving = true);
    try {
      final event = await OrgService().createEvent(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        location: _location.text.trim(),
        startAt: startAt,
        endAt: endAt,
        capacity: int.parse(_capacity.text.trim()),
        points: _points,
      );
      if (!mounted) return;
      Navigator.pop(context, event);
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.green)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('New event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 60,
              decoration: _decoration('Event name', hint: 'e.g. Riverside Cleanup'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'At least 3 characters' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              maxLength: 1000,
              maxLines: 4,
              decoration: _decoration('What will people do?', hint: 'What to bring, where to meet...'),
            ),
            const SizedBox(height: 8),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final entry in orgEventCategoryLabels.entries)
                  ChoiceChip(
                    avatar: Icon(orgEventCategoryIcon(entry.key),
                        size: 16, color: _category == entry.key ? Colors.white : Colors.black54),
                    label: Text(entry.value),
                    selected: _category == entry.key,
                    onSelected: (_) => setState(() => _category = entry.key),
                    selectedColor: Colors.green,
                    backgroundColor: Colors.white,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: _category == entry.key ? Colors.white : Colors.black87, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              maxLength: 120,
              decoration: _decoration('Location', hint: 'e.g. Nopporo Forest Park, north gate'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the location' : null,
            ),
            const SizedBox(height: 8),
            _PickerTile(icon: Icons.calendar_today, label: 'Date', value: formatEventDate(_date), onTap: _pickDate),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(icon: Icons.schedule, label: 'Start', value: _start.format(context), onTap: () => _pickTime(true)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerTile(icon: Icons.schedule, label: 'End', value: _end.format(context), onTap: () => _pickTime(false)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: _decoration('Max participants'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return n == null || n < 1 || n > 1000 ? '1–1000 people' : null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Points per participant', style: TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Text('+$_points P  ·  +$_points XP',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _points.toDouble(),
              min: _minPoints.toDouble(),
              max: _maxPoints.toDouble(),
              divisions: _maxPoints - _minPoints,
              activeColor: Colors.green,
              label: '$_points',
              onChanged: (v) => setState(() => _points = v.round()),
            ),
            Text(
              'Regular party quests give 20–30 points. Use more points for longer or harder events.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create event', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade300)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Text('$label  ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
