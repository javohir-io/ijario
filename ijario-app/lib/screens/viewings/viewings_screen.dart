import 'package:flutter/material.dart';

import '../../data/viewing_store.dart';
import '../../models/viewing.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/routes.dart';
import '../../widgets/segmented.dart';
import '../../widgets/toast.dart';
import '../chat/chat_screen.dart';
import '../property/property_detail_screen.dart';

/// Viewing requests, in two tabs: the ones I made, and the ones I received
/// as a landlord (where I can confirm or decline).
class ViewingsScreen extends StatefulWidget {
  const ViewingsScreen({super.key});

  @override
  State<ViewingsScreen> createState() => _ViewingsScreenState();
}

class _ViewingsScreenState extends State<ViewingsScreen> {
  int _tab = 0; // 0 = made by me, 1 = received

  @override
  void initState() {
    super.initState();
    ViewingStore.instance.load();
  }

  Future<void> _setStatus(Viewing v, String status, String doneMessage) async {
    final error = await ViewingStore.instance.setStatus(v.id, status);
    if (!mounted) return;
    showToast(context, error ?? doneMessage, error: error != null);
  }

  Future<void> _cancel(Viewing v) async {
    final ok = await confirmDialog(
      context,
      title: "Ko'rishni bekor qilasizmi?",
      message: "${formatViewingTime(v.scheduledAt)} dagi ko'rish bekor qilinadi va egasiga xabar boradi.",
      confirmLabel: 'Bekor qilish',
      cancelLabel: 'Yo\'q',
      destructive: true,
    );
    if (ok) await _setStatus(v, Viewing.cancelled, "Ko'rish bekor qilindi");
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return BackdropScaffold(
      title: "Ko'rish so'rovlari",
      body: ListenableBuilder(
        listenable: ViewingStore.instance,
        builder: (context, _) {
          final store = ViewingStore.instance;
          final list = _tab == 0 ? store.asRenter : store.asOwner;
          final open = list.where((v) => !v.isClosed).toList();
          final closed = list.where((v) => v.isClosed).toList().reversed.toList();
          final margin = pageMargin(MediaQuery.of(context).size.width, maxContent: 680);

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(margin, 8, margin, 14),
                child: Segmented(
                  options: [
                    'Men yozilganlar',
                    store.pendingForMe > 0 ? 'Menga kelgan (${store.pendingForMe})' : 'Menga kelganlar',
                  ],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? (store.isLoading
                        ? Center(child: CircularProgressIndicator(color: p.brand))
                        : EmptyState(
                            title: _tab == 0 ? "So'rov yo'q" : "Hali so'rov kelmagan",
                            message: _tab == 0
                                ? "E'lon sahifasida \"Ko'rishga yozilish\" tugmasini bosing: egasi vaqtni tasdiqlaydi."
                                : "Ijarachilar e'loningizni ko'rishga yozilganda, bu yerda paydo bo'ladi.",
                          ))
                    : RefreshIndicator(
                        color: p.brand,
                        onRefresh: store.load,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(margin, 0, margin, 40),
                          children: [
                            for (var i = 0; i < open.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Reveal(
                                  key: ValueKey<int>(open[i].id),
                                  index: i,
                                  child: _ViewingCard(
                                    viewing: open[i],
                                    onConfirm: () => _setStatus(open[i], Viewing.confirmed, 'Ko\'rish tasdiqlandi'),
                                    onDecline: () => _setStatus(open[i], Viewing.declined, "So'rov rad etildi"),
                                    onCancel: () => _cancel(open[i]),
                                  ),
                                ),
                              ),
                            if (closed.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 14, 0, 12),
                                child: Text('Tugagan', style: BType.title(p.inkMuted)),
                              ),
                              for (final v in closed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _ViewingCard(
                                    viewing: v,
                                    onConfirm: () {},
                                    onDecline: () {},
                                    onCancel: () {},
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ViewingCard extends StatelessWidget {
  final Viewing viewing;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const _ViewingCard({
    required this.viewing,
    required this.onConfirm,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final v = viewing;
    final other = v.counterpart;
    final expired = v.scheduledAt.isBefore(DateTime.now()) && (v.isPending || v.isConfirmed);

    final Color statusColor;
    final String statusText;
    if (expired) {
      statusColor = p.inkMuted;
      statusText = "Muddati o'tgan";
    } else if (v.isConfirmed) {
      statusColor = p.success;
      statusText = v.statusLabel;
    } else if (v.isPending) {
      statusColor = p.brand;
      statusText = v.statusLabel;
    } else {
      statusColor = p.inkMuted;
      statusText = v.statusLabel;
    }

    final List<Widget> actions = [];
    if (!v.isClosed) {
      if (v.isOwnerSide && v.isPending) {
        actions.addAll([
          Expanded(child: PrimaryButton(label: 'Tasdiqlash', onPressed: onConfirm)),
          const SizedBox(width: 10),
          Expanded(child: SecondaryButton(label: 'Rad etish', onPressed: onDecline)),
        ]);
      } else if (!v.isOwnerSide) {
        actions.add(Expanded(child: SecondaryButton(label: 'Bekor qilish', compact: true, onPressed: onCancel)));
      }
    }

    return Opacity(
      opacity: v.isClosed ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BDeco.card(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusText, style: BType.label(statusColor).copyWith(fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${weekdayName(v.scheduledAt)}, ${formatDayMonth(v.scheduledAt)}',
              style: BType.headline(p.ink).copyWith(fontSize: 30),
            ),
            Text(formatTime(v.scheduledAt), style: BType.title(p.brand).copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Pressable(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PropertyDetailScreen(propertyId: v.property.id)),
              ),
              semanticLabel: v.property.title,
              child: Text(
                v.property.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BType.title(p.ink).copyWith(fontSize: 16, decoration: TextDecoration.underline, decorationColor: p.line),
              ),
            ),
            const SizedBox(height: 2),
            Text('${v.property.city}, ${v.property.location}', style: BType.small(p.inkMuted)),
            if (v.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('"${v.note}"', style: BType.body(p.inkMuted).copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            Divider(height: 1, color: p.line),
            const SizedBox(height: 14),
            Row(
              children: [
                Avatar(name: other.fullName, url: other.avatarUrl, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    other.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextAction(
                  label: 'Xabar',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(other: other, propertyId: v.property.id),
                    ),
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
