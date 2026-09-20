import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/friend_model.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/decorated_avatar.dart';
import '../../widgets/liquid_glass_dialog.dart';
import '../../widgets/pressable_scale.dart';
import '../profile/player_profile_page.dart';

// แท็บย่อย "Friend" ของหน้า Community — ค้นหาผู้เล่นด้วยชื่อ/ส่งคำขอเพื่อน, คำขอที่รอตอบ (เข้า/ออก),
// ลิสต์เพื่อนที่มีอยู่แล้ว ข้อมูลจริงจาก GET/POST /api/friends/* (ดู friend_provider.dart)
class FriendTab extends StatefulWidget {
  const FriendTab({super.key});

  @override
  State<FriendTab> createState() => _FriendTabState();
}

class _FriendTabState extends State<FriendTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FriendProvider>();
      provider.loadFriends();
      provider.loadRequests();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // หน่วงไว้ 400ms ก่อนยิงค้นหาจริง กันยิง API รัวๆ ทุกตัวอักษรที่พิมพ์
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<FriendProvider>().search(value);
    });
  }

  void _openProfile(FriendModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(userId: user.id, displayName: user.displayName),
      ),
    );
  }

  Future<void> _confirmRemoveFriend(FriendModel friend) async {
    final confirmed = await LiquidGlassDialog.show<bool>(
      context: context,
      icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 28),
      title: 'Remove friend?',
      content: Text(
        '${friend.displayName} will be removed from your friends list.',
        textAlign: TextAlign.center,
        style: LiquidGlassDialog.messageStyle,
      ),
      actions: [
        LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
        LiquidGlassAction(
          label: 'Remove',
          color: Colors.redAccent,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed != true || !mounted) return;
    final provider = context.read<FriendProvider>();
    final ok = await provider.removeFriend(friend.id);
    if (!mounted || ok) return;
    showBubbleToast(context, provider.errorMessage ?? 'Failed to remove this friend');
  }

  Future<void> _sendRequest(FriendSearchResultModel result) async {
    final provider = context.read<FriendProvider>();
    final ok = await provider.sendRequest(result.user.id);
    if (!mounted) return;
    if (ok) {
      // รีเฟรชผลค้นหาเดิมด้วย ให้ปุ่ม Add ตรงแถวนี้เปลี่ยนเป็น Pending/Friends ทันทีโดยไม่ต้องพิมพ์ค้นหาใหม่
      await provider.search(_searchController.text);
    } else {
      showBubbleToast(context, provider.errorMessage ?? 'Failed to send friend request');
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    final provider = context.read<FriendProvider>();
    final ok = await provider.acceptRequest(request.id);
    if (!mounted || ok) return;
    showBubbleToast(context, provider.errorMessage ?? 'Failed to accept this request');
  }

  Future<void> _rejectRequest(FriendRequestModel request) async {
    final provider = context.read<FriendProvider>();
    final ok = await provider.rejectRequest(request.id);
    if (!mounted || ok) return;
    showBubbleToast(context, provider.errorMessage ?? 'Failed to reject this request');
  }

  Future<void> _cancelRequest(FriendRequestModel request) async {
    final provider = context.read<FriendProvider>();
    final ok = await provider.cancelRequest(request.id);
    if (!mounted || ok) return;
    showBubbleToast(context, provider.errorMessage ?? 'Failed to cancel this request');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendProvider>();
    final isSearchMode = _searchController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {}); // สลับ search mode <-> ลิสต์เพื่อนปกติทันทีตามที่พิมพ์
            _onSearchChanged(value);
          },
          decoration: InputDecoration(
            hintText: 'Search players by name...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
            suffixIcon: isSearchMode
                ? IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      context.read<FriendProvider>().search('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.green),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: isSearchMode
              ? _SearchResultsList(
                  isSearching: provider.isSearching,
                  errorMessage: provider.searchErrorMessage,
                  results: provider.searchResults,
                  isBusy: provider.isBusy,
                  onTap: _openProfile,
                  onAdd: _sendRequest,
                )
              : _FriendsAndRequestsList(
                  isLoadingFriends: provider.isLoadingFriends,
                  isLoadingRequests: provider.isLoadingRequests,
                  friends: provider.friends,
                  incomingRequests: provider.incomingRequests,
                  outgoingRequests: provider.outgoingRequests,
                  isBusy: provider.isBusy,
                  onTapUser: _openProfile,
                  onRemoveFriend: _confirmRemoveFriend,
                  onAccept: _acceptRequest,
                  onReject: _rejectRequest,
                  onCancel: _cancelRequest,
                ),
        ),
      ],
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  final bool isSearching;
  final String? errorMessage;
  final List<FriendSearchResultModel> results;
  final bool isBusy;
  final ValueChanged<FriendModel> onTap;
  final ValueChanged<FriendSearchResultModel> onAdd;

  const _SearchResultsList({
    required this.isSearching,
    required this.errorMessage,
    required this.results,
    required this.isBusy,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching && results.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }
    if (errorMessage != null) {
      return _EmptyHint(icon: Icons.cloud_off, text: errorMessage!);
    }
    if (results.isEmpty) {
      return const _EmptyHint(icon: Icons.search_off, text: 'No players found');
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final result = results[index];
        return _FriendUserRow(
          user: result.user,
          onTap: () => onTap(result.user),
          trailing: _RelationshipAction(
            relationship: result.relationship,
            isBusy: isBusy,
            onAdd: () => onAdd(result),
          ),
        );
      },
    );
  }
}

class _RelationshipAction extends StatelessWidget {
  final FriendRelationship relationship;
  final bool isBusy;
  final VoidCallback onAdd;

  const _RelationshipAction({required this.relationship, required this.isBusy, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    switch (relationship) {
      case FriendRelationship.friends:
        return const _StatusPill(label: 'Friends', color: Colors.green);
      case FriendRelationship.pendingOutgoing:
        return const _StatusPill(label: 'Pending', color: Colors.orange);
      case FriendRelationship.pendingIncoming:
        return const _StatusPill(label: 'Respond below', color: Colors.blue);
      case FriendRelationship.none:
        return PressableScale(
          child: ElevatedButton(
            onPressed: isBusy ? null : onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _FriendsAndRequestsList extends StatelessWidget {
  final bool isLoadingFriends;
  final bool isLoadingRequests;
  final List<FriendModel> friends;
  final List<FriendRequestModel> incomingRequests;
  final List<FriendRequestModel> outgoingRequests;
  final bool isBusy;
  final ValueChanged<FriendModel> onTapUser;
  final ValueChanged<FriendModel> onRemoveFriend;
  final ValueChanged<FriendRequestModel> onAccept;
  final ValueChanged<FriendRequestModel> onReject;
  final ValueChanged<FriendRequestModel> onCancel;

  const _FriendsAndRequestsList({
    required this.isLoadingFriends,
    required this.isLoadingRequests,
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.isBusy,
    required this.onTapUser,
    required this.onRemoveFriend,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingFriends && friends.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    final hasAnything = friends.isNotEmpty || incomingRequests.isNotEmpty || outgoingRequests.isNotEmpty;
    if (!hasAnything) {
      return const _EmptyHint(
        icon: Icons.person_add_alt_1_rounded,
        text: 'No friends yet — search for players above to add some',
      );
    }

    return ListView(
      children: [
        if (incomingRequests.isNotEmpty) ...[
          const _SectionLabel('Incoming requests'),
          const SizedBox(height: 8),
          for (final request in incomingRequests) ...[
            _FriendUserRow(
              user: request.user,
              onTap: () => onTapUser(request.user),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PressableScale(
                    child: IconButton(
                      onPressed: isBusy ? null : () => onReject(request),
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      tooltip: 'Reject',
                    ),
                  ),
                  PressableScale(
                    child: IconButton(
                      onPressed: isBusy ? null : () => onAccept(request),
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: 'Accept',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],
        if (outgoingRequests.isNotEmpty) ...[
          const _SectionLabel('Sent requests'),
          const SizedBox(height: 8),
          for (final request in outgoingRequests) ...[
            _FriendUserRow(
              user: request.user,
              onTap: () => onTapUser(request.user),
              trailing: TextButton(
                onPressed: isBusy ? null : () => onCancel(request),
                child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],
        if (friends.isNotEmpty) ...[
          const _SectionLabel('Friends'),
          const SizedBox(height: 8),
          for (final friend in friends) ...[
            _FriendUserRow(
              user: friend,
              onTap: () => onTapUser(friend),
              trailing: PressableScale(
                child: IconButton(
                  onPressed: isBusy ? null : () => onRemoveFriend(friend),
                  icon: Icon(Icons.person_remove_outlined, color: Colors.grey.shade500, size: 20),
                  tooltip: 'Remove friend',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }
}

// แถวผู้เล่น 1 คน ใช้ซ้ำทั้งผลค้นหา/คำขอเข้า-ออก/ลิสต์เพื่อน — ต่างกันแค่ trailing widget
class _FriendUserRow extends StatelessWidget {
  final FriendModel user;
  final VoidCallback onTap;
  final Widget trailing;

  const _FriendUserRow({required this.user, required this.onTap, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              DecoratedAvatar(
                avatarUrl: user.avatarUrl,
                size: 40,
                frameItemType: user.cosmetics.frame,
                placeholderBackgroundColor: Colors.grey.shade200,
                placeholderIconColor: Colors.grey.shade500,
                placeholderIconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Lv. ${user.level.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathingIcon(child: Icon(icon, size: 48, color: Colors.grey.shade400)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
