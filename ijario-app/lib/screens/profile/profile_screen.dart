import 'package:flutter/material.dart';

import '../../data/viewing_store.dart';
import '../../services/auth_store.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatar.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/routes.dart';
import '../../widgets/segmented.dart';
import '../admin/admin_screen.dart';
import '../auth/gate.dart';
import '../viewings/viewings_screen.dart';
import 'edit_profile_screen.dart';
import 'my_listings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Chiqishni xohlaysizmi?',
      message: "Hisobingizdan chiqasiz. Istalgan vaqt qayta kirishingiz mumkin.",
      confirmLabel: 'Chiqish',
      destructive: true,
    );
    if (ok) AuthStore.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthStore.instance, ViewingStore.instance, SettingsStore.instance]),
      builder: (context, _) {
        final user = AuthStore.instance.currentUser;
        final p = context.c;
        final margin = pageMargin(MediaQuery.of(context).size.width, maxContent: 760);
        final bottom = MediaQuery.of(context).padding.bottom;
        final themeIndex = SettingsStore.instance.themeMode == ThemeMode.system
            ? 0
            : (SettingsStore.instance.themeMode == ThemeMode.light ? 1 : 2);

        final themePicker = Padding(
          padding: EdgeInsets.fromLTRB(margin, 0, margin, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text("Ko'rinish", style: BType.title(p.ink)),
              ),
              Segmented(
                options: const ['Tizim', "Yorug'", "Qorong'i"],
                index: themeIndex,
                onChanged: (i) => SettingsStore.instance.setThemeMode(
                  i == 0 ? ThemeMode.system : (i == 1 ? ThemeMode.light : ThemeMode.dark),
                ),
              ),
            ],
          ),
        );

        if (user == null) {
          return ListView(
            padding: EdgeInsets.only(bottom: bottom + 96),
            children: [
              const PageHeader(title: 'Profil'),
              const SizedBox(
                height: 300,
                child: GuestGate(
                  title: 'Hisobingizga kiring',
                  message: "E'lon joylash, xabar yozish va ko'rishga yozilish uchun hisob kerak.",
                ),
              ),
              themePicker,
            ],
          );
        }

        final pending = ViewingStore.instance.pendingForMe;
        return ListView(
          padding: EdgeInsets.only(bottom: bottom + 110),
          children: [
            const PageHeader(title: 'Profil'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Pressable(
                onTap: () => _push(context, const EditProfileScreen()),
                semanticLabel: 'Profilni tahrirlash',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BDeco.card(p),
                  child: Row(
                    children: [
                      Avatar(name: user.fullName, url: user.avatarUrl, size: 68),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: BType.headline(p.ink)),
                            const SizedBox(height: 2),
                            Text(
                              (user.phone != null && user.phone!.isNotEmpty) ? formatPhoneDisplay(user.phone) : user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BType.small(p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_outlined, color: p.inkMuted, size: 22),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Container(
                decoration: BDeco.card(p),
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.home_work_outlined,
                      title: "E'lonlarim",
                      onTap: () => _push(context, const MyListingsScreen()),
                    ),
                    Divider(height: 1, indent: 64, color: p.line),
                    _MenuRow(
                      icon: Icons.event_available_outlined,
                      title: "Ko'rish so'rovlari",
                      badge: pending,
                      onTap: () => _push(context, const ViewingsScreen()),
                    ),
                    if (user.isAdmin) ...[
                      Divider(height: 1, indent: 64, color: p.line),
                      _MenuRow(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Boshqaruv paneli',
                        onTap: () => _push(context, const AdminScreen()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            themePicker,
            const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Container(
                decoration: BDeco.card(p),
                child: _MenuRow(
                  icon: Icons.logout_rounded,
                  title: 'Chiqish',
                  destructive: true,
                  showChevron: false,
                  onTap: () => _logout(context),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Center(child: Text('Ijario 2.0', style: BType.small(p.inkFaint))),
          ],
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final int badge;
  final bool destructive;
  final bool showChevron;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge = 0,
    this.destructive = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final color = destructive ? p.danger : p.ink;
    return Pressable(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 24, color: destructive ? p.danger : p.brand),
            const SizedBox(width: 18),
            Expanded(child: Text(title, style: BType.body(color).copyWith(fontWeight: FontWeight.w700))),
            if (badge > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: p.selectedFill, borderRadius: BorderRadius.circular(12)),
                child: Text('$badge', style: BType.label(p.onSelected).copyWith(fontWeight: FontWeight.w800)),
              ),
            if (showChevron) Icon(Icons.chevron_right_rounded, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}
