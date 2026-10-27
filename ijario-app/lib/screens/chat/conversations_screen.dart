import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/auth_store.dart';
import '../../services/chat_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/routes.dart';
import '../auth/gate.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ChatStore.instance, AuthStore.instance]),
      builder: (context, _) {
        if (!AuthStore.instance.isLoggedIn) {
          return const GuestGate(
            title: 'Xabarlar',
            message: "E'lon egalari bilan yozishish uchun hisobingizga kiring.",
          );
        }
        final store = ChatStore.instance;
        final items = store.conversations;
        final bottom = MediaQuery.of(context).padding.bottom;
        final margin = pageMargin(MediaQuery.of(context).size.width, maxContent: 760);

        return RefreshIndicator(
          color: context.c.brand,
          onRefresh: store.loadConversations,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: PageHeader(title: 'Xabarlar')),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: store.loadingConversations
                      ? const Center(child: CircularProgressIndicator())
                      : const EmptyState(
                          title: "Hali xabar yo'q",
                          message: "E'lon sahifasidagi xabar tugmasi orqali egasiga yozing.",
                        ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: margin),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: context.c.line),
                    itemBuilder: (context, i) => _ConversationTile(conversation: items[i]),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottom + 96)),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final other = conversation.otherUser;
    final last = conversation.lastMessage;
    final mine = last.senderId == AuthStore.instance.currentUser?.id;
    final unread = conversation.unreadCount;

    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(other: other, propertyId: last.propertyId),
        ),
      ),
      semanticLabel: other.fullName,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Avatar(name: other.fullName, url: other.avatarUrl, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    other.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BType.title(p.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mine ? 'Siz: ${last.content}' : last.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BType.small(unread > 0 ? p.ink : p.inkMuted).copyWith(
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatChatStamp(last.createdAt), style: BType.small(p.inkMuted).copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.selectedFill, borderRadius: BorderRadius.circular(11)),
                    child: Text(
                      '$unread',
                      style: BType.label(p.onSelected).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
