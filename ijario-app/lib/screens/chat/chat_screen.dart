import 'package:flutter/material.dart';

import '../../data/property_store.dart';
import '../../models/chat_message.dart';
import '../../models/person.dart';
import '../../services/auth_store.dart';
import '../../services/chat_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/launcher.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/avatar.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/pressable.dart';
import '../../widgets/property_photo.dart';
import '../../widgets/toast.dart';
import '../property/property_detail_screen.dart';

/// A one-to-one conversation. When it was opened from a listing, that
/// listing stays pinned at the top so both sides remember what they're
/// talking about.
class ChatScreen extends StatefulWidget {
  final Person other;
  final int? propertyId;

  const ChatScreen({super.key, required this.other, this.propertyId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  bool _hasText = false;

  static const _quickReplies = [
    "Salom! E'lon hali dolzarbmi?",
    "Ko'rishga kelsam bo'ladimi?",
    "Narxni kelishsak bo'ladimi?",
  ];

  @override
  void initState() {
    super.initState();
    ChatStore.instance.loadHistory(widget.other.id);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _hasText = false);
    final error = await ChatStore.instance.sendMessage(
      receiverId: widget.other.id,
      content: text,
      propertyId: widget.propertyId,
    );
    if (error != null && mounted) {
      _input.text = text;
      setState(() => _hasText = true);
      showToast(context, error, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return BackdropScaffold(
      titleWidget: Row(
        children: [
          Avatar(name: widget.other.fullName, url: widget.other.avatarUrl, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.other.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BType.title(p.ink),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.other.phone != null && widget.other.phone!.isNotEmpty)
          IconButton(
            tooltip: "Qo'ng'iroq qilish",
            icon: Icon(Icons.call_rounded, color: p.brand),
            onPressed: () => openPhone(widget.other.phone!),
          ),
      ],
      body: Column(
        children: [
          if (widget.propertyId != null) _propertyBanner(context),
          Expanded(
            child: ListenableBuilder(
              listenable: ChatStore.instance,
              builder: (context, _) {
                final messages = ChatStore.instance.messagesFor(widget.other.id).reversed.toList();
                if (messages.isEmpty) return _emptyChat(context);
                final myId = AuthStore.instance.currentUser?.id;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(BSpace.page, 12, BSpace.page, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    return _Bubble(message: m, mine: m.senderId == myId);
                  },
                );
              },
            ),
          ),
          _composer(context),
        ],
      ),
    );
  }

  Widget _propertyBanner(BuildContext context) {
    final p = context.c;
    final property = PropertyStore.instance.byId(widget.propertyId!);
    if (property == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(BSpace.page, 4, BSpace.page, 8),
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PropertyDetailScreen(propertyId: property.id, initial: property),
          ),
        ),
        semanticLabel: property.title,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BDeco.card(p, radius: BRadius.field),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BRadius.all(BRadius.thumb),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: PropertyPhoto(url: property.coverUrl, seed: property.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(property.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BType.label(p.ink).copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(priceWithUnit(property), style: BType.small(p.inkMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkFaint),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyChat(BuildContext context) {
    final p = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suhbatni boshlang', style: BType.headline(p.ink)),
            const SizedBox(height: 8),
            Text(
              'Savolingizni yozing yoki tayyor xabarlardan birini yuboring.',
              textAlign: TextAlign.center,
              style: BType.body(p.inkMuted),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _quickReplies) PillChip(label: q, selected: false, onTap: () => _send(q)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final p = context.c;
    return Container(
      padding: EdgeInsets.fromLTRB(BSpace.page, 10, BSpace.page - 4, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: p.bg.withValues(alpha: 0.72),
        border: Border(top: BorderSide(color: p.cardRim)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BDeco.card(p, radius: 26, raised: false),
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) {
                  final has = v.trim().isNotEmpty;
                  if (has != _hasText) setState(() => _hasText = has);
                },
                style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Xabar yozing',
                  hintStyle: BType.body(p.inkFaint),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: _hasText ? _send : null,
            haptic: true,
            semanticLabel: 'Yuborish',
            child: AnimatedContainer(
              duration: BMotion.state,
              curve: BMotion.ease,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasText ? p.primaryFill : p.surfaceAlt,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: _hasText ? p.onPrimary : p.inkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    final fg = mine ? p.onSelected : p.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: maxWidth > 520 ? 520 : maxWidth),
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: mine ? [p.selectedTop, p.selectedFill] : [p.cardTop, p.cardBottom],
          ),
          border: Border.all(color: mine ? p.selectedBorder : p.cardRim),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(mine ? 22 : 6),
            bottomRight: Radius.circular(mine ? 6 : 22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(message.content, style: BType.body(fg).copyWith(fontSize: 15.5)),
            ),
            const SizedBox(height: 3),
            Text(
              formatTime(message.createdAt),
              style: BType.small(fg.withValues(alpha: 0.7)).copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
