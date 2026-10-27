import 'package:flutter/material.dart';

import '../../data/property_store.dart';
import '../../models/property.dart';
import '../../services/auth_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/listing_grid.dart';
import '../../widgets/page_header.dart';
import '../../widgets/toast.dart';
import '../auth/gate.dart';
import '../property/property_detail_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  void _open(BuildContext context, Property p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailScreen(
          propertyId: p.id,
          initial: p,
          heroTag: 'saved-photo-${p.id}',
        ),
      ),
    );
  }

  Future<void> _unsave(BuildContext context, Property p) async {
    final error = await PropertyStore.instance.toggleSave(p.id);
    if (error != null && context.mounted) showToast(context, error, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([PropertyStore.instance, AuthStore.instance]),
      builder: (context, _) {
        if (!AuthStore.instance.isLoggedIn) {
          return const GuestGate(
            title: 'Saralanganlar',
            message: "Yoqqan e'lonlarni saqlash va keyin qaytib ko'rish uchun hisobingizga kiring.",
          );
        }
        final saved = PropertyStore.instance.saved;
        final bottom = MediaQuery.of(context).padding.bottom;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Saralanganlar',
                subtitle: saved.isEmpty ? null : "${saved.length} ta e'lon",
              ),
            ),
            if (saved.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: 'Hali hech narsa yo\'q',
                  message: "E'londagi yurak belgisini bosing: u shu yerda saqlanadi.",
                ),
              )
            else
              SliverListingGrid(
                items: saved,
                heroPrefix: 'saved',
                onOpen: (p) => _open(context, p),
                onToggleSave: (p) => _unsave(context, p),
              ),
            SliverToBoxAdapter(child: SizedBox(height: bottom + BSpace.xl)),
          ],
        );
      },
    );
  }
}
