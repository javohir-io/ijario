import 'package:flutter/material.dart';

import '../../data/property_store.dart';
import '../../models/property.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../widgets/buttons.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/property_photo.dart';
import '../../widgets/reveal.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/routes.dart';
import '../../widgets/toast.dart';
import '../property/add_listing_screen.dart';
import '../property/property_detail_screen.dart';

/// Everything the person has posted, with the numbers that matter to a
/// landlord (views, saves) and one-tap "rented / active again".
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  @override
  void initState() {
    super.initState();
    PropertyStore.instance.fetchMine();
  }

  Future<void> _add() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => const AddListingScreen()),
    );
  }

  Future<void> _edit(Property pr) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => AddListingScreen(editing: pr)),
    );
  }

  Future<void> _toggleRented(Property pr) async {
    try {
      final updated = await PropertyStore.instance.setRented(pr.id, !pr.isRented);
      if (mounted) {
        showToast(context, updated.isRented ? "E'lon band deb belgilandi" : "E'lon yana qidiruvda ko'rinadi");
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Property pr) async {
    final ok = await confirmDialog(
      context,
      title: "E'lonni o'chirish",
      message: "\"${pr.title}\" va uning rasmlari butunlay o'chiriladi.",
      confirmLabel: "O'chirish",
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await PropertyStore.instance.deleteProperty(pr.id);
      if (mounted) showToast(context, "E'lon o'chirildi");
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return BackdropScaffold(
      title: "E'lonlarim",
      body: ListenableBuilder(
        listenable: PropertyStore.instance,
        builder: (context, _) {
          final store = PropertyStore.instance;
          final items = store.mine;
          final margin = pageMargin(MediaQuery.of(context).size.width, maxContent: 680);

          if (items.isEmpty) {
            return store.isLoadingMine
                ? Center(child: CircularProgressIndicator(color: p.brand))
                : EmptyState(
                    title: "Hali e'lon yo'q",
                    message: "Birinchi e'loningizni joylang: bir necha daqiqa vaqt oladi.",
                    actionLabel: "E'lon joylash",
                    onAction: _add,
                  );
          }

          return RefreshIndicator(
            color: p.brand,
            onRefresh: store.fetchMine,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(margin, 8, margin, 40),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final pr = items[i];
                return Reveal(
                  key: ValueKey<int>(pr.id),
                  index: i,
                  child: _MineTile(
                    property: pr,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PropertyDetailScreen(propertyId: pr.id, initial: pr),
                      ),
                    ),
                    onEdit: () => _edit(pr),
                    onToggleRented: () => _toggleRented(pr),
                    onDelete: () => _delete(pr),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MineTile extends StatelessWidget {
  final Property property;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onToggleRented;
  final VoidCallback onDelete;

  const _MineTile({
    required this.property,
    required this.onOpen,
    required this.onEdit,
    required this.onToggleRented,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final pr = property;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BDeco.card(p),
      child: Column(
        children: [
          Pressable(
            onTap: onOpen,
            semanticLabel: pr.title,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BRadius.all(BRadius.field),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: PropertyPhoto(url: pr.coverUrl, seed: pr.id),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: pr.isRented ? p.surfaceAlt : p.success.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              pr.isRented ? 'Band' : 'Faol',
                              style: BType.label(pr.isRented ? p.inkMuted : p.success).copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(pr.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BType.title(p.ink).copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(priceWithUnit(pr), style: BType.small(p.inkMuted).copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: p.inkMuted),
              const SizedBox(width: 6),
              Text("${pr.views} ko'rish", style: BType.small(p.inkMuted)),
              const SizedBox(width: 18),
              Icon(Icons.favorite_border_rounded, size: 18, color: p.inkMuted),
              const SizedBox(width: 6),
              Text('${pr.savesCount} saralash', style: BType.small(p.inkMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: 'Tahrirlash', compact: true, onPressed: onEdit)),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  compact: true,
                  label: pr.isRented ? 'Faollashtirish' : 'Band qilish',
                  onPressed: onToggleRented,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: "O'chirish",
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: p.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
