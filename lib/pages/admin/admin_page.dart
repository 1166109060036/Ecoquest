import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/upgrade_provider.dart';
import '../../providers/fridge_provider.dart';
import '../../providers/notification_provider.dart';

// หน้า Admin/Debug — dev/QA เท่านั้น เข้าได้เฉพาะ user.isAdmin (เช็คซ้ำจริงที่ backend ทุก request
// ผ่าน backend/middleware/admin.js) ใช้ "รีโมตคอนโทรล" ค่า/สถานะของระบบต่างๆ ตรงๆ ข้ามการเล่นเกมจริง
// เพื่อทดสอบผลลัพธ์ปลายทางได้เร็ว — ทำงานกับบัญชีของแอดมินเองเสมอ (ไม่มี user picker)
//
// ตั้งใจใช้ธีม Material เรียบๆ สีเทา/ขาว ไม่ใช้ธีมกระจกมืดของเกมจริง ให้รู้สึกชัดว่านี่คือ dev tool
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _pointsController = TextEditingController();
  final _xpController = TextEditingController();
  final _grantQuantityController = TextEditingController(text: '1');
  final _upgradeLevelController = TextEditingController();
  final _fridgeNameController = TextEditingController(text: 'Test Milk');
  final _fridgeHoursController = TextEditingController(text: '-1');

  String? _selectedQuestId;
  String? _selectedItemType;
  String? _selectedUpgradeType;

  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _seasons = [];
  bool _loadingParties = false;
  bool _loadingSeasons = false;

  @override
  void dispose() {
    _pointsController.dispose();
    _xpController.dispose();
    _grantQuantityController.dispose();
    _upgradeLevelController.dispose();
    _fridgeNameController.dispose();
    _fridgeHoursController.dispose();
    super.dispose();
  }

  // ทุก action เรียกผ่านนี้ทางเดียว — โชว์ snackbar ผลลัพธ์ + รับ callback ไป refresh provider
  // อื่นๆ ที่เกี่ยวข้อง (AdminPage เองไม่เก็บ state ของระบบนั้นซ้ำ)
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    String successMessage = 'Done',
    List<Future<void> Function()> onSuccess = const [],
  }) async {
    final adminProvider = context.read<AdminProvider>();
    final success = await adminProvider.runVoid(action);
    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(adminProvider.errorMessage ?? 'Action failed'), backgroundColor: Colors.red.shade700),
      );
      return;
    }

    for (final refresh in onSuccess) {
      await refresh();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green.shade700));
  }

  Future<bool> _confirm(BuildContext context, String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _loadParties(BuildContext context) async {
    setState(() => _loadingParties = true);
    final parties = await context.read<AdminProvider>().run(
          () => context.read<AdminProvider>().service.listParties(),
        );
    if (!mounted) return;
    setState(() {
      _parties = parties ?? [];
      _loadingParties = false;
    });
  }

  Future<void> _loadSeasons(BuildContext context) async {
    setState(() => _loadingSeasons = true);
    final seasons = await context.read<AdminProvider>().run(
          () => context.read<AdminProvider>().service.listSeasons(),
        );
    if (!mounted) return;
    setState(() {
      _seasons = seasons ?? [];
      _loadingSeasons = false;
    });
  }

  Future<void> _showRawUser(BuildContext context) async {
    final admin = context.read<AdminProvider>();
    final raw = await admin.run(() => admin.service.debugMe());
    if (!context.mounted) return;

    if (raw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? 'Failed to load')),
      );
      return;
    }

    const encoder = JsonEncoder.withIndent('  ');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raw User Document'),
        content: SingleChildScrollView(
          child: SelectableText(encoder.convert(raw), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final admin = context.read<AdminProvider>();
    final auth = context.read<AuthProvider>();
    final quests = context.watch<QuestProvider>().quests;
    final medals = context.watch<AchievementProvider>().achievements;
    final items = context.watch<InventoryProvider>().items;
    final upgrades = context.watch<UpgradeProvider>().items;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Admin Tools'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (adminProvider.isBusy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          const Text(
            'dev/QA only — actions here bypass normal game rules and affect your own account directly.',
            style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),

          // ---- User ----
          _Section(
            title: 'User',
            icon: Icons.person,
            children: [
              Row(
                children: [
                  Expanded(child: _numberField(_pointsController, 'Points')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_xpController, 'XP')),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _run(
                  context,
                  () => admin.service.setUserStats(
                    points: int.tryParse(_pointsController.text),
                    xp: int.tryParse(_xpController.text),
                  ),
                  successMessage: 'Stats updated',
                  onSuccess: [auth.refreshProfile],
                ),
                child: const Text('Set Points / XP'),
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  _boostButton(context, 'red', Colors.redAccent, auth),
                  _boostButton(context, 'blue', Colors.blueAccent, auth),
                  _boostButton(context, 'green', Colors.green, auth),
                  OutlinedButton(
                    onPressed: () => _run(
                      context,
                      admin.service.clearBoosts,
                      successMessage: 'Boosts cleared',
                      onSuccess: [auth.refreshProfile],
                    ),
                    child: const Text('Clear Boosts'),
                  ),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _showRawUser(context),
                    child: const Text('View Raw User JSON'),
                  ),
                  OutlinedButton(
                    onPressed: () => auth.updateAvatar(null),
                    child: const Text('Clear Avatar'),
                  ),
                ],
              ),
              const Divider(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                onPressed: () async {
                  if (!await _confirm(context, 'Reset account?',
                      'Wipes quest history, achievements, inventory and upgrades, and resets points/xp/level/rank. This cannot be undone.')) {
                    return;
                  }
                  if (!context.mounted) return;
                  await _run(
                    context,
                    admin.service.resetAccount,
                    successMessage: 'Account reset',
                    onSuccess: [
                      auth.refreshProfile,
                      () => context.read<QuestProvider>().loadQuests(),
                      () => context.read<AchievementProvider>().loadAchievements(),
                      () => context.read<InventoryProvider>().loadInventory(),
                      () => context.read<UpgradeProvider>().loadUpgrades(),
                    ],
                  );
                },
                child: const Text('Reset Account (destructive)'),
              ),
            ],
          ),

          // ---- Quest ----
          _Section(
            title: 'Quest',
            icon: Icons.flag,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedQuestId,
                decoration: const InputDecoration(labelText: 'Quest', border: OutlineInputBorder()),
                items: [
                  for (final q in quests) DropdownMenuItem(value: q.id, child: Text(q.title, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _selectedQuestId = v),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _selectedQuestId == null
                    ? null
                    : () => _run(
                          context,
                          () => admin.service.forceCompleteQuest(_selectedQuestId!),
                          successMessage: 'Quest force-completed',
                          onSuccess: [
                            auth.refreshProfile,
                            () => context.read<QuestProvider>().loadQuests(),
                            () => context.read<AchievementProvider>().loadAchievements(),
                          ],
                        ),
                child: const Text('Force Complete Selected Quest'),
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _run(
                      context,
                      admin.service.resetQuestsToday,
                      successMessage: "Today's quests reset",
                      onSuccess: [() => context.read<QuestProvider>().loadQuests()],
                    ),
                    child: const Text("Reset Today's Quests"),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      if (!await _confirm(context, 'Reset all quest history?', 'Deletes every completion record for your account.')) {
                        return;
                      }
                      if (!context.mounted) return;
                      await _run(
                        context,
                        admin.service.resetQuestsAll,
                        successMessage: 'All quest history reset',
                        onSuccess: [() => context.read<QuestProvider>().loadQuests()],
                      );
                    },
                    child: const Text('Reset All Quest History'),
                  ),
                ],
              ),
            ],
          ),

          // ---- Party ----
          _Section(
            title: 'Party',
            icon: Icons.groups,
            children: [
              OutlinedButton(
                onPressed: _loadingParties ? null : () => _loadParties(context),
                child: Text(_loadingParties ? 'Loading...' : 'Load Parties (latest 50)'),
              ),
              const SizedBox(height: 8),
              for (final p in _parties)
                Card(
                  child: ListTile(
                    dense: true,
                    title: Text('${p['name']} — ${p['questTitle']}'),
                    subtitle: Text('${p['status']} · ${p['memberCount']} member(s)'),
                    // 'completed' เท่านั้นที่ทำอะไรต่อไม่ได้แล้ว — 'open'/'started' ยังกด force ต่อได้
                    trailing: p['status'] == 'completed'
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p['status'] == 'open')
                                TextButton(
                                  onPressed: () => _run(
                                    context,
                                    () => admin.service.forceStartParty(p['id']),
                                    successMessage: 'Party force-started',
                                    onSuccess: [() => _loadParties(context)],
                                  ),
                                  child: const Text('Start'),
                                ),
                              TextButton(
                                onPressed: () => _run(
                                  context,
                                  () => admin.service.forceCompleteParty(p['id']),
                                  successMessage: 'Party force-completed',
                                  onSuccess: [() => _loadParties(context)],
                                ),
                                child: const Text('Complete'),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),

          // ---- Achievement ----
          _Section(
            title: 'Achievement',
            icon: Icons.emoji_events,
            children: [
              for (final m in medals)
                Card(
                  child: ListTile(
                    dense: true,
                    title: Text(m.title),
                    trailing: m.unlocked
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : TextButton(
                            onPressed: () => _run(
                              context,
                              () => admin.service.unlockAchievement(m.medalType),
                              successMessage: '${m.title} unlocked',
                              onSuccess: [
                                () => context.read<AchievementProvider>().loadAchievements(),
                                () => context.read<InventoryProvider>().loadInventory(),
                              ],
                            ),
                            child: const Text('Unlock'),
                          ),
                  ),
                ),
              const Divider(),
              OutlinedButton(
                onPressed: () async {
                  if (!await _confirm(context, 'Reset achievements?', 'Removes every unlocked medal for your account.')) {
                    return;
                  }
                  if (!context.mounted) return;
                  await _run(
                    context,
                    admin.service.resetAchievements,
                    successMessage: 'Achievements reset',
                    onSuccess: [() => context.read<AchievementProvider>().loadAchievements()],
                  );
                },
                child: const Text('Reset Achievements'),
              ),
            ],
          ),

          // ---- Inventory ----
          _Section(
            title: 'Inventory',
            icon: Icons.inventory_2,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedItemType,
                decoration: const InputDecoration(labelText: 'Item', border: OutlineInputBorder()),
                items: [
                  for (final i in items) DropdownMenuItem(value: i.itemType, child: Text(i.title)),
                ],
                onChanged: (v) => setState(() => _selectedItemType = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_grantQuantityController, 'Quantity')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedItemType == null
                        ? null
                        : () => _run(
                              context,
                              () => admin.service.grantItem(
                                _selectedItemType!,
                                int.tryParse(_grantQuantityController.text) ?? 1,
                              ),
                              successMessage: 'Item granted',
                              onSuccess: [() => context.read<InventoryProvider>().loadInventory()],
                            ),
                    child: const Text('Grant'),
                  ),
                ],
              ),
              const Divider(),
              OutlinedButton(
                onPressed: () async {
                  if (!await _confirm(context, 'Reset inventory?', 'Removes every item (starter items are re-granted automatically).')) {
                    return;
                  }
                  if (!context.mounted) return;
                  await _run(
                    context,
                    admin.service.resetInventory,
                    successMessage: 'Inventory reset',
                    onSuccess: [() => context.read<InventoryProvider>().loadInventory()],
                  );
                },
                child: const Text('Reset Inventory'),
              ),
            ],
          ),

          // ---- Upgrade ----
          _Section(
            title: 'Upgrade',
            icon: Icons.bolt,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedUpgradeType,
                decoration: const InputDecoration(labelText: 'Upgrade', border: OutlineInputBorder()),
                items: [
                  for (final u in upgrades)
                    DropdownMenuItem(value: u.upgradeType, child: Text('${u.title} (max ${u.maxLevel})')),
                ],
                onChanged: (v) => setState(() => _selectedUpgradeType = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_upgradeLevelController, 'Level')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedUpgradeType == null
                        ? null
                        : () => _run(
                              context,
                              () => admin.service.setUpgradeLevel(
                                _selectedUpgradeType!,
                                int.tryParse(_upgradeLevelController.text) ?? 0,
                              ),
                              successMessage: 'Upgrade level set',
                              onSuccess: [() => context.read<UpgradeProvider>().loadUpgrades()],
                            ),
                    child: const Text('Set Level'),
                  ),
                ],
              ),
            ],
          ),

          // ---- Season ----
          _Section(
            title: 'Season',
            icon: Icons.calendar_month,
            children: [
              OutlinedButton(
                onPressed: _loadingSeasons ? null : () => _loadSeasons(context),
                child: Text(_loadingSeasons ? 'Loading...' : 'Load Seasons'),
              ),
              const SizedBox(height: 8),
              for (final s in _seasons)
                ListTile(
                  dense: true,
                  title: Text('Season ${s['seasonNumber']}${s['isActive'] == true ? ' (active)' : ''}'),
                  subtitle: Text('ends ${s['endDate']}'),
                ),
              const Divider(),
              ElevatedButton(
                onPressed: () => _run(
                  context,
                  admin.service.expireCurrentSeason,
                  successMessage: 'Season rolled over',
                  onSuccess: [auth.refreshProfile, () => _loadSeasons(context)],
                ),
                child: const Text('Expire Current Season Now'),
              ),
            ],
          ),

          // ---- Notification ----
          _Section(
            title: 'Notification',
            icon: Icons.notifications,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final type in ['quest_complete', 'achievement', 'fridge_expiring'])
                    OutlinedButton(
                      onPressed: () => _run(
                        context,
                        () => admin.service.testNotification(type),
                        successMessage: 'Test notification sent',
                        onSuccess: [() => context.read<NotificationProvider>().loadNotifications()],
                      ),
                      child: Text('Test: $type'),
                    ),
                ],
              ),
            ],
          ),

          // ---- Fridge ----
          _Section(
            title: 'Fridge',
            icon: Icons.kitchen,
            children: [
              TextField(
                controller: _fridgeNameController,
                decoration: const InputDecoration(labelText: 'Item name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              _numberField(_fridgeHoursController, 'Expires in hours (negative = already expired)'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _run(
                  context,
                  () => admin.service.addTestFridgeItem(
                    _fridgeNameController.text.trim().isEmpty ? 'Test Item' : _fridgeNameController.text.trim(),
                    int.tryParse(_fridgeHoursController.text) ?? -1,
                  ),
                  successMessage: 'Test fridge item added',
                  onSuccess: [() => context.read<FridgeProvider>().loadItems()],
                ),
                child: const Text('Add Test Fridge Item'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _boostButton(BuildContext context, String color, Color swatch, AuthProvider auth) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: swatch, foregroundColor: Colors.white),
      onPressed: () => _run(
        context,
        () => context.read<AdminProvider>().service.setBoost(color, 30),
        successMessage: '${color[0].toUpperCase()}${color.substring(1)} Energy active (30m)',
        onSuccess: [auth.refreshProfile],
      ),
      child: Text('${color[0].toUpperCase()}${color.substring(1)} +30m'),
    );
  }
}

// การ์ดพับได้ 1 กลุ่มระบบ — ใช้ซ้ำทุก section ในหน้านี้
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ],
      ),
    );
  }
}
