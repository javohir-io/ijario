import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/property_store.dart';
import '../data/viewing_store.dart';
import '../services/auth_store.dart';
import '../services/chat_store.dart';
import '../theme/tokens.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_nav_bar.dart';
import '../widgets/toast.dart';
import 'auth/gate.dart';
import 'chat/conversations_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'property/add_listing_screen.dart';
import 'saved/saved_screen.dart';

/// The app proper: four tabs behind a floating glass bar.
///
/// It also owns the "session lifecycle": when someone signs in or out it
/// reloads the listings (so saved hearts match the person) and starts or
/// stops the live chat connection.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int? _lastUserId;

  @override
  void initState() {
    super.initState();
    _lastUserId = AuthStore.instance.currentUser?.id;
    AuthStore.instance.addListener(_onAuthChanged);
    PropertyStore.instance.fetchAll();
    if (AuthStore.instance.isLoggedIn) _startPrivateServices();
  }

  @override
  void dispose() {
    AuthStore.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _startPrivateServices() {
    ChatStore.instance.connect();
    ChatStore.instance.loadConversations();
    ViewingStore.instance.load();
  }

  void _onAuthChanged() {
    final id = AuthStore.instance.currentUser?.id;
    if (id == _lastUserId) return;
    _lastUserId = id;

    PropertyStore.instance.fetchAll();
    if (id != null) {
      _startPrivateServices();
    } else if (AuthStore.instance.sessionExpired && mounted) {
      AuthStore.instance.sessionExpired = false;
      showToast(context, 'Sessiya tugadi. Qaytadan kiring.', error: true);
    }
    if (mounted) setState(() => _index = id == null ? 0 : _index);
  }

  Future<void> _addListing() async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const AddListingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The home tab opens with the dark aurora, so its status bar icons are
    // light; other tabs follow the theme.
    final lightIcons = _index == 0 || dark;

    final pages = <Widget>[
      const HomeScreen(),
      const SavedScreen(),
      const ConversationsScreen(),
      const ProfileScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        backgroundColor: dark ? BColors.obsidian : BColors.plasterTint,
        body: Stack(
          children: [
            // Fixed glow behind the tabs: the translucent cards float over it.
            const Positioned.fill(child: AppBackdrop()),
            IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < pages.length; i++)
                  // Tabs that aren't showing stop their animations.
                  TickerMode(enabled: _index == i, child: pages[i]),
              ],
            ),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: Listenable.merge([ChatStore.instance, ViewingStore.instance]),
          builder: (context, _) {
            return GlassNavBar(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
              onAdd: _addListing,
              chatBadge: ChatStore.instance.unreadTotal,
              profileBadge: ViewingStore.instance.pendingForMe,
            );
          },
        ),
      ),
    );
  }
}
