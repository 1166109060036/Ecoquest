import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/quest_card_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/constants.dart';
import '../../utils/date_format.dart';

// หน้าสร้างห้อง (Party) จาก party quest ที่มีอยู่แล้ว — เหมือนสร้างห้องในเกมให้คนอื่นกดเข้าร่วม
// เข้าถึงได้ทางเดียว: กดปุ่ม + (FAB) มุมขวาล่างของหน้า Explore ตอนเลือก chip "Party"
// (เดิมกด "Create Party" บนการ์ด quest ได้เลย แต่ตอนนี้การ์ด quest หายไปจาก Explore แล้ว —
// เควส party จะเจอได้เฉพาะในขั้นตอนเลือกเควสของหน้านี้เท่านั้น)
class CreatePartyPage extends StatefulWidget {
  const CreatePartyPage({super.key});

  @override
  State<CreatePartyPage> createState() => _CreatePartyPageState();
}

enum _Step { pickQuest, details }

class _CreatePartyPageState extends State<CreatePartyPage> {
  _Step _step = _Step.pickQuest;
  QuestCardModel? _selectedQuest;

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _eventDate;
  int _capacity = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // เติมค่า default ของฟอร์มจากเควสที่เลือก — ผู้ใช้แก้ต่อได้ทุกช่อง
  void _applyQuest(QuestCardModel quest) {
    _selectedQuest = quest;
    _nameController.text = '${quest.title} Party';
    _locationController.text = quest.location;
    _capacity = quest.capacity;
  }

  void _selectQuest(QuestCardModel quest) {
    setState(() {
      _applyQuest(quest);
      _step = _Step.details;
    });
  }

  Future<void> _pickEventDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _eventDate != null
          ? TimeOfDay.fromDateTime(_eventDate!)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (pickedTime == null) return;

    setState(() {
      _eventDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _setQuickDate(Duration from, {int hour = 9}) {
    final date = DateTime.now().add(from);
    setState(() => _eventDate = DateTime(date.year, date.month, date.day, hour, 0));
  }

  Future<void> _submit() async {
    final quest = _selectedQuest;
    if (quest == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name')),
      );
      return;
    }
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick the event date and time')),
      );
      return;
    }
    if (_eventDate!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event date must be in the future')),
      );
      return;
    }
    if (_capacity > 0 && _capacity < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capacity must allow at least 2 members')),
      );
      return;
    }

    final partyProvider = context.read<PartyProvider>();
    final success = await partyProvider.create(
      questId: quest.id,
      name: name,
      eventDate: _eventDate!,
      location: _locationController.text.trim(),
      capacity: _capacity,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Party created!')),
      );
      // ส่ง true กลับไปให้หน้า Explore เอาไปสลับไปแท็บ Party ให้อัตโนมัติ
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to create the party')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = context.watch<PartyProvider>().isBusy;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      onBack: () {
                        // อยู่ขั้นกรอกรายละเอียดแล้ว -> กดย้อนกลับให้ถอยไปเลือกเควสใหม่ก่อน ไม่ใช่ออกจากหน้าเลย
                        if (_step == _Step.details) {
                          setState(() => _step = _Step.pickQuest);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: switch (_step) {
                        _Step.pickQuest => _QuestPicker(onSelect: _selectQuest),
                        _Step.details => _DetailsForm(
                            quest: _selectedQuest!,
                            nameController: _nameController,
                            locationController: _locationController,
                            eventDate: _eventDate,
                            capacity: _capacity,
                            isBusy: isBusy,
                            onChangeQuest: () => setState(() => _step = _Step.pickQuest),
                            onPickDate: _pickEventDateTime,
                            onQuickDate: _setQuickDate,
                            onCapacityChanged: (v) => setState(() => _capacity = v),
                            onSubmit: _submit,
                          ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ขั้นที่ 1: เลือก party quest ที่จะเอามาสร้างห้อง
// ---------------------------------------------------------------------------
class _QuestPicker extends StatelessWidget {
  final ValueChanged<QuestCardModel> onSelect;

  const _QuestPicker({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final quests = context
        .watch<QuestProvider>()
        .quests
        .where((q) => q.category == QuestCardCategory.party)
        .toList();
    final myLevel = context.watch<AuthProvider>().user?.level ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose a party quest to host',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: quests.isEmpty
              ? const Center(
                  child: Text(
                    'No party quests available right now',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.separated(
                  itemCount: quests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final quest = quests[index];
                    final locked = myLevel < quest.minLevelToHost;
                    return _QuestPickerTile(
                      quest: quest,
                      locked: locked,
                      onTap: locked ? null : () => onSelect(quest),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _QuestPickerTile extends StatelessWidget {
  final QuestCardModel quest;
  final bool locked;
  final VoidCallback? onTap;

  const _QuestPickerTile({required this.quest, required this.locked, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      locked
                          ? 'Requires Lv. ${quest.minLevelToHost}'
                          : '+${quest.pointsReward} P  ·  +${quest.xpReward} XP',
                      style: TextStyle(
                        color: locked ? Colors.orangeAccent : Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ขั้นที่ 2: กรอกรายละเอียดห้อง (ชื่อ, วันเวลา, สถานที่, จำนวนคนรับ)
// ---------------------------------------------------------------------------
class _DetailsForm extends StatelessWidget {
  final QuestCardModel quest;
  final TextEditingController nameController;
  final TextEditingController locationController;
  final DateTime? eventDate;
  final int capacity;
  final bool isBusy;
  final VoidCallback onChangeQuest;
  final VoidCallback onPickDate;
  final void Function(Duration from, {int hour}) onQuickDate;
  final ValueChanged<int> onCapacityChanged;
  final VoidCallback onSubmit;

  const _DetailsForm({
    required this.quest,
    required this.nameController,
    required this.locationController,
    required this.eventDate,
    required this.capacity,
    required this.isBusy,
    required this.onChangeQuest,
    required this.onPickDate,
    required this.onQuickDate,
    required this.onCapacityChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hosting: ${quest.title}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: onChangeQuest,
                  child: const Text('Change', style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FieldLabel('Room name'),
            _DarkTextField(controller: nameController, hint: 'e.g. Saturday cleanup crew'),
            const SizedBox(height: 16),
            _FieldLabel('Event date & time'),
            Row(
              children: [
                _QuickDateChip(label: 'Tomorrow', onTap: () => onQuickDate(const Duration(days: 1))),
                const SizedBox(width: 8),
                _QuickDateChip(label: 'In 3 days', onTap: () => onQuickDate(const Duration(days: 3))),
                const SizedBox(width: 8),
                _QuickDateChip(label: 'Next week', onTap: () => onQuickDate(const Duration(days: 7))),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      eventDate == null ? 'Tap to pick date & time' : formatEventDateTime(eventDate!),
                      style: TextStyle(
                        color: eventDate == null ? Colors.white54 : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Location'),
            _DarkTextField(controller: locationController, hint: 'e.g. Riverside Park'),
            const SizedBox(height: 16),
            _FieldLabel('Capacity'),
            Row(
              children: [
                Text(
                  capacity == 0 ? 'Unlimited' : '$capacity members',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  onPressed: capacity > 0 ? () => onCapacityChanged(capacity - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.green,
                ),
                IconButton(
                  onPressed: () => onCapacityChanged(capacity + 1),
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isBusy ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Party', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _DarkTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green),
        ),
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
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.profileBgAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3E5C4E), Color(0xFF2C3E50)],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const Expanded(
          child: Text(
            'CREATE PARTY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 36),
      ],
    );
  }
}
