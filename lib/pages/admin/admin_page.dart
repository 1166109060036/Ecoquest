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
import '../community/reported_posts_page.dart';
import 'org_requests_page.dart';
import '../../l10n/tr.dart';

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
  final _fridgeNameController = TextEditingController(text: tr('Test Milk'));
  final _fridgeHoursController = TextEditingController(text: '-1');

  String? _selectedQuestId;
  String? _selectedItemType;
  String? _selectedUpgradeType;

  List<Map<String, dynamic>> _parties = [];
  bool _loadingParties = false;

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
        SnackBar(content: Text(adminProvider.errorMessage ?? tr('Action failed')), backgroundColor: Colors.red.shade700),
      );
      return;
    }

    for (final refresh in onSuccess) {
      await refresh();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(successMessage)), backgroundColor: Colors.green.shade700));
  }

  Future<bool> _confirm(BuildContext context, String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Confirm'), style: TextStyle(color: Colors.red)),
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

  Future<void> _showRawUser(BuildContext context) async {
    final admin = context.read<AdminProvider>();
    final raw = await admin.run(() => admin.service.debugMe());
    if (!context.mounted) return;

    if (raw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? tr('Failed to load'))),
      );
      return;
    }

    const encoder = JsonEncoder.withIndent('  ');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Raw User Document')),
        content: SingleChildScrollView(
          child: SelectableText(encoder.convert(raw), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Close')))],
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
        title: Text(tr('Admin Tools')),
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
          Text(
            tr('dev/QA only — actions here bypass normal game rules and affect your own account directly.'),
            style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),

          // ---- โพสต์ที่ถูกรายงาน (7 ต.ค. 2026 แทนคิวตรวจหลักฐาน — ส่งรูปแล้วผ่านทันที) ----
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(tr('Reported posts')),
              subtitle: Text(tr('Keep, remove the photo, or take back points')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportedPostsPage())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.apartment_rounded),
              title: Text(tr('Organizations')),
              subtitle: Text(tr('Approve, reject or suspend organization accounts')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrgRequestsPage())),
            ),
          ),
          const SizedBox(height: 8),

          // ---- User ----
          _Section(
            title: tr('User'),
            icon: Icons.person,
            children: [
              Row(
                children: [
                  Expanded(child: _numberField(_pointsController, tr('Points'))),
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
                  successMessage: tr('Stats updated'),
                  onSuccess: [auth.refreshProfile],
                ),
                child: Text(tr('Set Points / XP')),
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
                      successMessage: tr('Boosts cleared'),
                      onSuccess: [auth.refreshProfile],
                    ),
                    child: Text(tr('Clear Boosts')),
                  ),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _showRawUser(context),
                    child: Text(tr('View Raw User JSON')),
                  ),
                  OutlinedButton(
                    onPressed: () => auth.updateAvatar(null),
                    child: Text(tr('Clear Avatar')),
                  ),
                ],
              ),
              const Divider(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                onPressed: () async {
                  if (!await _confirm(context, tr('Reset account?'),
                      tr('Wipes quest history, achievements, inventory and upgrades, and resets points/xp/level/streak. This cannot be undone.'))) {
                    return;
                  }
                  if (!context.mounted) return;
                  await _run(
                    context,
                    admin.service.resetAccount,
                    successMessage: tr('Account reset'),
                    onSuccess: [
                      auth.refreshProfile,
                      () => context.read<QuestProvider>().loadQuests(),
                      () => context.read<AchievementProvider>().loadAchievements(),
                      () => context.read<InventoryProvider>().loadInventory(),
                      () => context.read<UpgradeProvider>().loadUpgrades(),
                    ],
                  );
                },
                child: Text(tr('Reset Account (destructive)')),
              ),
            ],
          ),

          // ---- Quest ----
          _Section(
            title: tr('Quest'),
            icon: Icons.flag,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedQuestId,
                decoration: InputDecoration(labelText: tr('Quest'), border: OutlineInputBorder()),
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
                          successMessage: tr('Quest force-completed'),
                          onSuccess: [
                            auth.refreshProfile,
                            () => context.read<QuestProvider>().loadQuests(),
                            () => context.read<AchievementProvider>().loadAchievements(),
                          ],
                        ),
                child: Text(tr('Force Complete Selected Quest')),
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _run(
                      context,
                      admin.service.resetQuestsToday,
                      successMessage: tr("Today's quests reset"),
                      onSuccess: [() => context.read<QuestProvider>().loadQuests()],
                    ),
                    child: Text(tr("Reset Today's Quests")),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      if (!await _confirm(context, tr('Reset all quest history?'), tr('Deletes every completion record for your account.'))) {
                        return;
                      }
                      if (!context.mounted) return;
                      await _run(
                        context,
                        admin.service.resetQuestsAll,
                        successMessage: tr('All quest history reset'),
                        onSuccess: [() => context.read<QuestProvider>().loadQuests()],
                      );
                    },
                    child: Text(tr('Reset All Quest History')),
                  ),
                ],
              ),
            ],
          ),

          // ---- Party ----
          _Section(
            title: tr('Party'),
            icon: Icons.groups,
            children: [
              OutlinedButton(
                onPressed: _loadingParties ? null : () => _loadParties(context),
                child: Text(_loadingParties ? tr('Loading...') : tr('Load Parties (latest 50)')),
              ),
              const SizedBox(height: 8),
              for (final p in _parties)
                Card(
                  child: ListTile(
                    dense: true,
                    title: Text('${p['name']} — ${p['questTitle']}'),
                    subtitle: Text(tr('{0} · {1} member(s)', [p['status'], p['memberCount']])),
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
                                    successMessage: tr('Party force-started'),
                                    onSuccess: [() => _loadParties(context)],
                                  ),
                                  child: Text(tr('Start')),
                                ),
                              TextButton(
                                onPressed: () => _run(
                                  context,
                                  () => admin.service.forceCompleteParty(p['id']),
                                  successMessage: tr('Party force-completed'),
                                  onSuccess: [() => _loadParties(context)],
                                ),
                                child: Text(tr('Complete')),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),

          // ---- Achievement ----
          _Section(
            title: tr('Achievement'),
            icon: Icons.emoji_events,
            children: [
              for (final m in medals)
                Card(
                  child: ListTile(
                    dense: true,
                    title: Text(m.title),
                    // เหรียญหลายขั้น — กดแต่ละครั้งปลดล็อกขั้นถัดไป (backend /admin/achievements/:medalType/unlock)
                    subtitle: Text(tr('{0} · {1} quests', [m.tierLabel ?? 'Locked', m.count])),
                    trailing: m.maxed
                        ? Icon(Icons.check_circle, color: m.tierColor)
                        : TextButton(
                            onPressed: () => _run(
                              context,
                              () => admin.service.unlockAchievement(m.medalType),
                              successMessage: '${m.title} ${m.nextTierLabel ?? ''} unlocked',
                              onSuccess: [
                                () => context.read<AchievementProvider>().loadAchievements(),
                                () => context.read<InventoryProvider>().loadInventory(),
                              ],
                            ),
                            child: Text(tr('Unlock {0}', [m.nextTierLabel ?? '']).trim()),
                          ),
                  ),
                ),
              const Divider(),
              OutlinedButton(
                onPressed: () async {
                  if (!await _confirm(context, tr('Reset achievements?'), tr('Removes every unlocked medal for your account.'))) {
                    return;
                  }
                  if (!context.mounted) return;
                  await _run(
                    context,
                    admin.service.resetAchievements,
                    successMessage: tr('Achievements reset'),
                    onSuccess: [() => context.read<AchievementProvider>().loadAchievements()],
                  );
                },
                child: Text(tr('Reset Achievements')),
              ),
            ],
          ),

          // ---- Inventory ----
          _Section(
            title: tr('Inventory'),
            icon: Icons.inventory_2,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedItemType,
                decoration: InputDecoration(labelText: tr('Item'), border: OutlineInputBorder()),
                items: [
                  for (final i in items) DropdownMenuItem(value: i.itemType, child: Text(i.title)),
                ],
                onChanged: (v) => setState(() => _selectedItemType = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_grantQuantityController, tr('Quantity'))),
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
                              successMessage: tr('Item granted'),
                              onSuccess: [() => context.read<InventoryProvider>().loadInventory()],
                            ),
                    child: Text(tr('Grant')),
                  ),
                ],
              ),
              const Divider(),
              OutlinedButton(
                onPressed: () async {
                  if (!await _confirm(context, tr('Reset inventory?'), tr('Removes every item (starter items are re-granted automatically).'))) {
                    return;
                  }
                  if (!context.mounted) return;
                  await _run(
                    context,
                    admin.service.resetInventory,
                    successMessage: tr('Inventory reset'),
                    onSuccess: [() => context.read<InventoryProvider>().loadInventory()],
                  );
                },
                child: Text(tr('Reset Inventory')),
              ),
            ],
          ),

          // ---- Upgrade ----
          _Section(
            title: tr('Upgrade'),
            icon: Icons.bolt,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedUpgradeType,
                decoration: InputDecoration(labelText: tr('Upgrade'), border: OutlineInputBorder()),
                items: [
                  for (final u in upgrades)
                    DropdownMenuItem(value: u.upgradeType, child: Text(tr('{0} (max {1})', [u.title, u.maxLevel]))),
                ],
                onChanged: (v) => setState(() => _selectedUpgradeType = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_upgradeLevelController, tr('Level'))),
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
                              successMessage: tr('Upgrade level set'),
                              onSuccess: [() => context.read<UpgradeProvider>().loadUpgrades()],
                            ),
                    child: Text(tr('Set Level')),
                  ),
                ],
              ),
            ],
          ),

          // ---- Notification ----
          _Section(
            title: tr('Notification'),
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
                        successMessage: tr('Test notification sent'),
                        onSuccess: [() => context.read<NotificationProvider>().loadNotifications()],
                      ),
                      child: Text(tr('Test: {0}', [type])),
                    ),
                ],
              ),
            ],
          ),

          // ---- Fridge ----
          _Section(
            title: tr('Fridge'),
            icon: Icons.kitchen,
            children: [
              TextField(
                controller: _fridgeNameController,
                decoration: InputDecoration(labelText: tr('Item name'), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              _numberField(_fridgeHoursController, tr('Expires in hours (negative = already expired)')),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _run(
                  context,
                  () => admin.service.addTestFridgeItem(
                    _fridgeNameController.text.trim().isEmpty ? tr('Test Item') : _fridgeNameController.text.trim(),
                    int.tryParse(_fridgeHoursController.text) ?? -1,
                  ),
                  successMessage: tr('Test fridge item added'),
                  onSuccess: [() => context.read<FridgeProvider>().loadItems()],
                ),
                child: Text(tr('Add Test Fridge Item')),
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
        successMessage: tr('{0}{1} Energy active (30m)', [color[0].toUpperCase(), color.substring(1)]),
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
