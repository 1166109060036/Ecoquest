import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message_model.dart';
import '../../models/friend_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/party_provider.dart';
import '../../services/chat_socket_service.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/pressable_scale.dart';

// แท็บย่อย "Chat" ของหน้า Community — แชทแบบ real-time ผ่าน WebSocket (ดู
// chat_socket_service.dart/chat_provider.dart) มี 3 ห้อง: World (ทุกคน) เปิดได้เสมอ, Party (คุยกับ
// สมาชิกปาร์ตี้ปัจจุบัน) เปิดได้เฉพาะตอนอยู่ปาร์ตี้, Friend (DM) เปิดได้เฉพาะตอนมีเพื่อนอย่างน้อย 1 คน
// (เลือกจากลิสต์เพื่อนก่อนถึงจะคุยได้)
enum _Channel { world, party, friend }

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  _Channel _channel = _Channel.world;
  FriendModel? _selectedFriend;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ChatProvider>();
      provider.connect();
      provider.loadWorldHistory();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectWorld() {
    setState(() => _channel = _Channel.world);
  }

  void _selectParty() {
    setState(() => _channel = _Channel.party);
    context.read<ChatProvider>().loadPartyHistory();
  }

  Future<void> _selectFriend() async {
    final friends = context.read<FriendProvider>().friends;
    if (friends.isEmpty) return;

    final chosen = await showModalBottomSheet<FriendModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FriendPickerSheet(friends: friends),
    );
    if (chosen == null || !mounted) return;

    setState(() {
      _channel = _Channel.friend;
      _selectedFriend = chosen;
    });
    context.read<ChatProvider>().loadFriendHistory(chosen.id);
  }

  void _send() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final provider = context.read<ChatProvider>();
    switch (_channel) {
      case _Channel.world:
        provider.sendWorldMessage(text);
      case _Channel.party:
        provider.sendPartyMessage(text);
      case _Channel.friend:
        final friend = _selectedFriend;
        if (friend != null) provider.sendFriendMessage(friend.id, text);
    }
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final hasParty = context.watch<PartyProvider>().hasParty;
    final hasFriends = context.watch<FriendProvider>().friends.isNotEmpty;

    // ปาร์ตี้ที่เคยเลือกไว้หลุดไปแล้ว (ออกจากปาร์ตี้ระหว่างที่อยู่แท็บนี้) -> เด้งกลับไป World เอง
    if (_channel == _Channel.party && !hasParty) {
      _channel = _Channel.world;
    }

    final messages = switch (_channel) {
      _Channel.world => provider.worldMessages,
      _Channel.party => provider.partyMessages,
      _Channel.friend => _selectedFriend != null ? provider.messagesWithFriend(_selectedFriend!.id) : const [],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ChannelChip(
              label: 'World',
              icon: Icons.public,
              selected: _channel == _Channel.world,
              onTap: _selectWorld,
            ),
            const SizedBox(width: 8),
            _ChannelChip(
              label: 'Party',
              icon: Icons.groups_rounded,
              selected: _channel == _Channel.party,
              enabled: hasParty,
              onTap: hasParty ? _selectParty : null,
            ),
            const SizedBox(width: 8),
            _ChannelChip(
              label: _channel == _Channel.friend && _selectedFriend != null
                  ? _selectedFriend!.displayName
                  : 'Friend',
              icon: Icons.person,
              selected: _channel == _Channel.friend,
              enabled: hasFriends,
              onTap: hasFriends ? _selectFriend : null,
            ),
          ],
        ),
        if (provider.status != ChatConnectionStatus.connected) ...[
          const SizedBox(height: 10),
          _ConnectionBanner(status: provider.status),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: _channel == _Channel.friend && _selectedFriend == null
              ? const _EmptyChat(text: 'Pick a friend above to start chatting')
              : provider.isLoadingHistory && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : messages.isEmpty
                      ? const _EmptyChat(text: 'No messages yet — say hello!')
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
                        ),
        ),
        const SizedBox(height: 8),
        _Composer(controller: _textController, onSend: _send),
      ],
    );
  }
}

class _FriendPickerSheet extends StatelessWidget {
  final List<FriendModel> friends;
  const _FriendPickerSheet({required this.friends});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Chat with a friend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: friends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    onTap: () => Navigator.pop(context, friend),
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                      child: friend.avatarUrl == null
                          ? Icon(Icons.person, color: Colors.grey.shade500)
                          : null,
                    ),
                    title: Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Lv. ${friend.level.toString().padLeft(2, '0')}  ·  ${friend.rank}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ChannelChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled ? Colors.grey.shade400 : (selected ? Colors.white : Colors.green);
    return Tooltip(
      message: enabled ? '' : 'Not available yet',
      child: PressableScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.green : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: !enabled ? Colors.grey.shade200 : Colors.green.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final ChatConnectionStatus status;
  const _ConnectionBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ChatConnectionStatus.connecting => 'Connecting to chat...',
      ChatConnectionStatus.reconnecting => 'Reconnecting...',
      ChatConnectionStatus.disconnected => 'Disconnected — trying to reconnect...',
      ChatConnectionStatus.connected => '',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.fromDisplayName,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(message.text, style: const TextStyle(color: Colors.black87, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Colors.green),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PressableScale(
          child: Material(
            color: Colors.green,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String text;
  const _EmptyChat({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BreathingIcon(child: Icon(Icons.forum_rounded, size: 48, color: Colors.grey.shade400)),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
