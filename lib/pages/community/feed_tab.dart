import 'package:flutter/material.dart';
import '../../models/impact_model.dart';
import '../../models/submission_model.dart';
import '../../services/feed_service.dart';
import '../../services/submission_service.dart';
import '../../utils/co2_format.dart';
import '../../utils/date_format.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/decorated_avatar.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/liquid_glass_dialog.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/staggered_fade_in.dart';
import '../../widgets/state_cross_fade.dart';
import '../profile/player_profile_page.dart';
import 'reported_posts_page.dart';

// แท็บ Feed ใน Community (แท็บแรก) — อาจารย์ให้คนอื่นเห็นข้อมูลภารกิจ และให้รู้สึกว่าภารกิจช่วยโลกจริง (28 ก.ย. 2026)
//   1) การ์ด "Ebetsu's impact" — CO2 ที่ผู้เล่นทั้งเมืองลดได้รวมกัน + เทียบเป็นต้นสนดูดซับ (backend/routes/impact.js)
//   2) แอดมินเท่านั้น: แบนเนอร์ "N reported posts" -> ReportedPostsPage (ซ่อนถ้าไม่มี)
//   3) ฟีดภารกิจวันนี้ของทุกคน ใหม่สุดก่อน + ปุ่ม Cheer + เมนูรายงาน/ถอนโพสต์ (backend/routes/feed.js)
//      7 ต.ค. 2026: ส่งรูปแล้วขึ้นฟีดทันที (เลิกให้ผู้เล่นตรวจ) — ผู้เล่นช่วยดูแลด้วยการรายงานโพสต์ที่ดูไม่ได้ทำจริงแทน
// state อยู่ในหน้านี้เอง ไม่มี provider — ไม่มีหน้าอื่นใช้ข้อมูลชุดนี้ร่วม
class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> with AutomaticKeepAliveClientMixin {
  final _feedService = FeedService();
  final _submissionService = SubmissionService();
  final _scroll = ScrollController();

  ImpactSummary? _impact;
  int _reportCount = 0; // แอดมิน: โพสต์ที่ถูกรายงานรอดู (ผู้เล่นทั่วไป = 0 เสมอ)
  List<SubmissionModel> _posts = [];
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  // สลับแท็บย่อยแล้วกลับมาไม่ต้องโหลดใหม่/ไม่เสียตำแหน่งเลื่อน
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // 3 ส่วนไม่ขึ้นต่อกัน ยิงพร้อมกัน — โพสต์ที่ถูกรายงาน/ผลกระทบพังไม่ควรทำให้ฟีดทั้งหน้าพัง
      final results = await Future.wait([
        _feedService.fetchFeed(),
        _feedService.fetchImpact().then<ImpactSummary?>((v) => v).catchError((_) => null),
        _submissionService.fetchQueue().then<ReportQueue?>((q) => q).catchError((_) => null),
      ]);
      if (!mounted) return;
      final feed = results[0] as ({List<SubmissionModel> items, bool hasMore});
      setState(() {
        _posts = feed.items;
        _hasMore = feed.hasMore;
        _impact = results[1] as ImpactSummary?;
        final queue = results[2] as ReportQueue?;
        _reportCount = queue != null && queue.isAdmin ? queue.pendingCount : 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (!_hasMore || _isLoadingMore || _posts.isEmpty) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 400) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final feed = await _feedService.fetchFeed(before: _posts.last.submittedAt);
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...feed.items];
        _hasMore = feed.hasMore;
      });
    } catch (_) {
      // โหลดหน้าถัดไปไม่ได้ก็แค่หยุดตรงนี้ ปัดลงรีเฟรชเพื่อลองใหม่ได้
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // กด cheer แล้วเปลี่ยนในเครื่องทันที (optimistic) แล้วค่อยใช้ค่าจริงจาก server — พลาดก็ย้อนกลับ
  Future<void> _toggleCheer(SubmissionModel post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;
    final optimistic = post.copyWith(
      cheeredByMe: !post.cheeredByMe,
      cheers: post.cheers + (post.cheeredByMe ? -1 : 1),
    );
    setState(() => _posts[index] = optimistic);
    try {
      final result = await _feedService.toggleCheer(post.id);
      if (!mounted) return;
      setState(() => _posts[index] = post.copyWith(cheers: result.cheers, cheeredByMe: result.cheeredByMe));
    } catch (_) {
      if (mounted) setState(() => _posts[index] = post);
    }
  }

  // ถอนโพสต์ (แอดมิน/เจ้าของ) — ยืนยันก่อน เพราะลบรูปทิ้งถาวร
  Future<void> _confirmRemove(SubmissionModel post) async {
    final confirmed = await LiquidGlassDialog.show<bool>(
      context: context,
      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
      title: 'Remove this post?',
      content: Text(
        'The photo will be deleted and the post will no longer appear in the feed. Points already earned are kept.',
        textAlign: TextAlign.center,
        style: LiquidGlassDialog.messageStyle,
      ),
      actions: [
        LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
        LiquidGlassAction(label: 'Remove', color: Colors.redAccent, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (confirmed != true || !mounted) return;
    try {
      await _feedService.removePost(post.id);
      if (!mounted) return;
      setState(() => _posts = _posts.where((p) => p.id != post.id).toList());
      showBubbleToast(context, 'Post removed');
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // รายงานโพสต์ — เลือกเหตุผลก่อน (ยกเลิกได้) แล้วเปลี่ยนปุ่มเป็น "Reported" ในเครื่องทันที
  Future<void> _report(SubmissionModel post) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReportReasonSheet(),
    );
    if (reason == null || !mounted) return;
    try {
      await _feedService.reportPost(post.id, reason);
      if (!mounted) return;
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index >= 0) setState(() => _posts[index] = _posts[index].copyWith(reportedByMe: true));
      showBubbleToast(context, 'Thanks — an admin will take a look');
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openReports() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportedPostsPage()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StateCrossFade(
      stateKey: _isLoading ? 'loading' : 'feed',
      child: _isLoading ? const _FeedSkeleton() : _buildFeed(),
    );
  }

  Widget _buildFeed() {
    final children = <Widget>[
      if (_impact != null) _ImpactCard(impact: _impact!),
      if (_reportCount > 0) ...[
        const SizedBox(height: 12),
        _ReportsBanner(count: _reportCount, onTap: _openReports),
      ],
      const SizedBox(height: 16),
      // Today Feed — backend ส่งมาแค่ของวันนี้ ขึ้นวันใหม่ (เที่ยงคืนเวลาญี่ปุ่น) รูปเมื่อวานถูกลบ (backend/routes/feed.js)
      const Text("Today's quests",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 2),
      Text("Starts fresh every midnight · tap ⋮ to report a photo that doesn't look right",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      const SizedBox(height: 10),
      if (_error != null)
        _FeedEmpty(icon: Icons.cloud_off, text: _error!)
      else if (_posts.isEmpty)
        const _FeedEmpty(
          icon: Icons.eco_outlined,
          text: 'No quests today yet — complete one and it will show up here',
        )
      else
        for (var i = 0; i < _posts.length; i++) ...[
          FadeSlideIn(
            key: ValueKey(_posts[i].id),
            delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
            child: _FeedPostCard(
              post: _posts[i],
              onCheer: () => _toggleCheer(_posts[i]),
              onRemove: _posts[i].canRemove ? () => _confirmRemove(_posts[i]) : null,
              onReport: _posts[i].canReport && !_posts[i].reportedByMe ? () => _report(_posts[i]) : null,
            ),
          ),
          const SizedBox(height: 12),
        ],
      if (_isLoadingMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
        ),
      const SizedBox(height: 20),
    ];

    return LeafRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

// โครงรอโหลด (การ์ดผลกระทบ + โพสต์ 2 ใบ) แทนวงหมุน — เฟดเป็นเนื้อหาจริงผ่าน StateCrossFade
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonBox(height: 150, borderRadius: 22),
        SizedBox(height: 28),
        SkeletonBox(width: 120, height: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 240, borderRadius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 240, borderRadius: 18),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ผลกระทบรวมของเมือง
// ---------------------------------------------------------------------------
class _ImpactCard extends StatelessWidget {
  final ImpactSummary impact;
  const _ImpactCard({required this.impact});

  @override
  Widget build(BuildContext context) {
    final all = impact.allTime;
    final week = impact.thisWeek;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ),
        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text("${impact.city}'s impact",
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          // นับขึ้นทีละ 0.01 kg (CountUpNumber รับ int — เก็บเป็นหน่วย 10 กรัมแล้วแปลงกลับตอนโชว์)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpNumber(
                value: (all.co2eKg * 100).round(),
                duration: const Duration(milliseconds: 1200),
                formatter: (v) => (v / 100).toStringAsFixed(2),
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('kgCO2e', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('saved together by ${all.players} player${all.players == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.park_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('≈ ${all.treeComparison}',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // ผลกระทบแบบนับชิ้น (เช่น ภาชนะที่ส่งคืนร้าน จากเควส Return Containers) — โผล่เมื่อมีคนกรอกแล้ว
          for (final c in all.counted) ...[
            const SizedBox(height: 8),
            _CountedImpactRow(impact: c, thisWeek: week.countedFor(c.label)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ImpactStat(label: 'This week', value: formatCo2e(week.co2eKg)),
              _ImpactStat(label: 'Quests done', value: '${all.questsCompleted}'),
              _ImpactStat(label: 'This week', value: '${week.questsCompleted} quests'),
            ],
          ),
        ],
      ),
    );
  }
}

// "♻ 37 items · Containers Returned   +5 this week"
class _CountedImpactRow extends StatelessWidget {
  final CountedImpact impact;
  final int thisWeek;
  const _CountedImpactRow({required this.impact, required this.thisWeek});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.recycling_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${impact.total} ${impact.metric}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' · ${impact.label}'),
                ],
              ),
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (thisWeek > 0)
            Text('+$thisWeek this week', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String label;
  final String value;
  const _ImpactStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// แอดมิน: มีโพสต์ที่ถูกรายงานรอดู
// ---------------------------------------------------------------------------
class _ReportsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _ReportsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, color: Colors.orange.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(count == 1 ? '1 reported post' : '$count reported posts',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.orange.shade900)),
                      Text('Players flagged these photos — take a look',
                          style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.orange.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// เลือกเหตุผลที่รายงาน (backend/utils/submissions.js REPORT_REASONS) — คืน key หรือ null ถ้าปิดไป
class _ReportReasonSheet extends StatelessWidget {
  const _ReportReasonSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 2),
              child: Text('Report this post',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('An admin will check it. The player is not told who reported.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            for (final entry in reportReasonLabels.entries)
              ListTile(
                leading: Icon(_reasonIcon(entry.key), color: Colors.orange.shade700),
                title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _reasonIcon(String key) => switch (key) {
        'not_done' => Icons.help_outline_rounded,
        'personal_info' => Icons.privacy_tip_outlined,
        'inappropriate' => Icons.block_rounded,
        _ => Icons.more_horiz_rounded,
      };
}

// ---------------------------------------------------------------------------
// โพสต์ในฟีด
// ---------------------------------------------------------------------------
class _FeedPostCard extends StatelessWidget {
  final SubmissionModel post;
  final VoidCallback onCheer;
  final VoidCallback? onRemove; // null = ถอนโพสต์นี้ไม่ได้ (ไม่ใช่แอดมิน/เจ้าของ)
  final VoidCallback? onReport; // null = รายงานไม่ได้ (ของตัวเอง / guest / รายงานไปแล้ว)
  const _FeedPostCard({required this.post, required this.onCheer, this.onRemove, this.onReport});

  @override
  Widget build(BuildContext context) {
    final user = post.user;
    final quest = post.quest;
    final co2 = quest?.co2PerSubmission;
    final action = post.isParty
        ? 'completed a party event'
        : post.isCheckIn
            ? 'checked in Day ${post.checkInDay}/${post.checkInTotal}'
            : 'completed';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: user == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerProfilePage(userId: user.id, displayName: user.displayName),
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  DecoratedAvatar(
                    avatarUrl: user?.avatarUrl,
                    size: 38,
                    frameItemType: user?.cosmetics.frame,
                    placeholderBackgroundColor: Colors.grey.shade200,
                    placeholderIconColor: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            children: [
                              TextSpan(
                                  text: user?.displayName ?? 'Player',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: ' $action'),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(formatRelativeTime(post.submittedAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  if (post.reportedByMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text('Reported', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                    ),
                  if (onRemove != null || onReport != null)
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500),
                      onSelected: (v) => v == 'report' ? onReport?.call() : onRemove?.call(),
                      itemBuilder: (_) => [
                        if (onReport != null)
                          const PopupMenuItem(
                            value: 'report',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.flag_outlined),
                              title: Text('Report post'),
                            ),
                          ),
                        if (onRemove != null)
                          const PopupMenuItem(
                            value: 'remove',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('Remove post'),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              post.photoUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Container(color: Colors.grey.shade100),
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey.shade200,
                child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 36),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quest?.title ?? 'Quest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                      // ข้อมูลที่ผู้ส่งกรอก (เช่น "Food trays · 6 items · at …") — backend/utils/proofForm.js
                      if (post.details != null && post.details!.summary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(post.details!.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 4),
                      if (co2 != null && co2 > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.lightBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('−${formatCo2e(co2)}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue.shade700)),
                        ),
                    ],
                  ),
                ),
                _CheerButton(count: post.cheers, active: post.cheeredByMe, onTap: onCheer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheerButton extends StatelessWidget {
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _CheerButton({required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.grey.shade600;
    return PressableScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.15 : 1,
                duration: const Duration(milliseconds: 180),
                child: Icon(active ? Icons.eco_rounded : Icons.eco_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 4),
              Text(count > 0 ? '$count' : 'Cheer',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeedEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          BreathingIcon(child: Icon(icon, size: 46, color: Colors.grey.shade400)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}
