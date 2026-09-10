import 'package:flutter/material.dart';
import '../../models/achievement_model.dart';
import '../../models/public_profile_model.dart';
import '../../services/user_service.dart';
import '../../widgets/profile_sections.dart';

// โปรไฟล์สาธารณะของผู้เล่นคนอื่น — ดูอย่างเดียว แก้ไขอะไรไม่ได้
// เข้าได้จากการกดแถวสมาชิกในหน้า Party (ไม่ใช่แถวของตัวเอง)
// ไม่ได้ลงทะเบียนใน app_routes.dart เพราะทุก route ในนั้นเป็น const ไม่รับ argument
// ใช้ MaterialPageRoute ตรงๆ เหมือนที่ QuestDetailPage ทำ
class PlayerProfilePage extends StatefulWidget {
  final String userId;
  // ใช้โชว์บน top bar ทันทีระหว่างรอโหลดข้อมูลจริง กันหัวข้อว่างเปล่าตอนเปิดหน้า
  final String displayName;

  const PlayerProfilePage({super.key, required this.userId, required this.displayName});

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  final _service = UserService();
  PublicProfileModel? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _service.fetchPublicProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ProfileBackground()),
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
                  children: [
                    _TopBar(title: profile?.displayName ?? widget.displayName),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                          : profile == null
                              ? _ErrorState(message: _errorMessage, onRetry: _load)
                              : RefreshIndicator(
                                  onRefresh: _load,
                                  color: Colors.green,
                                  child: SingleChildScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        UserHeader(
                                          displayName: profile.displayName,
                                          // ไม่ส่ง avatarPath เพราะเป็น path ในเครื่องเจ้าของรูป
                                          // เครื่องเราเปิดไม่ได้อยู่ดี (ดู backend/models/User.js)
                                          level: profile.level,
                                          rankTier: profile.rank,
                                          xp: profile.progress.xpIntoLevel,
                                          xpToNext: profile.progress.xpForNextLevel,
                                          // onTapAvatar ไม่ใส่ -> ดูอย่างเดียว ไม่มีป้ายกล้อง
                                        ),
                                        const SizedBox(height: 16),
                                        PointsAndRankCard(
                                          points: profile.points,
                                          rankTier: profile.rank,
                                          rankXp: profile.progress.rankXpIntoTier,
                                          rankXpMax: profile.progress.rankXpForNextTier,
                                          pointsLabel: 'Point',
                                        ),
                                        const SizedBox(height: 16),
                                        StatsCard(stats: profile.stats),
                                        const SizedBox(height: 16),
                                        _MedalsCard(medals: profile.medals),
                                        const SizedBox(height: 16),
                                        QuestHistoryCard(history: profile.history),
                                      ],
                                    ),
                                  ),
                                ),
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

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
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
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        // เว้นที่ว่างเท่าปุ่มย้อนกลับฝั่งซ้าย เพื่อให้หัวข้ออยู่กึ่งกลางจอจริงๆ
        const SizedBox(width: 36),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.white.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Could not load this player\'s profile',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// การ์ดเหรียญ Achievement ของผู้เล่นคนนี้ — โชว์ทั้งที่ปลดล็อกแล้วและยัง (สีเทาถ้ายังไม่ปลดล็อก)
// เรียงให้อันที่ปลดล็อกแล้วขึ้นก่อน เหมือนหน้า Inventory ของตัวเอง
class _MedalsCard extends StatelessWidget {
  final List<AchievementMedalModel> medals;
  const _MedalsCard({required this.medals});

  @override
  Widget build(BuildContext context) {
    final sorted = [...medals]
      ..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        return (b.progress / b.required).compareTo(a.progress / a.required);
      });

    return ProfileGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Achievements',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (sorted.isEmpty)
              const Text('No medals yet', style: TextStyle(color: Colors.white54, fontSize: 12))
            else
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  for (final medal in sorted)
                    SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: (medal.unlocked ? medal.color : Colors.grey)
                                .withValues(alpha: 0.18),
                            child: Icon(
                              medal.icon,
                              color: medal.unlocked ? medal.color : Colors.grey.shade400,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            medal.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: medal.unlocked ? Colors.white : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
