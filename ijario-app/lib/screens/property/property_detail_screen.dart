import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/property_store.dart';
import '../../data/viewing_store.dart';
import '../../models/property.dart';
import '../../services/api_exception.dart';
import '../../services/auth_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/launcher.dart';
import '../../utils/uz_data.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/price_insight_view.dart';
import '../../widgets/property_photo.dart';
import '../../widgets/reveal.dart';
import '../../widgets/save_button.dart';
import '../../widgets/stat_row.dart';
import '../../widgets/toast.dart';
import '../auth/gate.dart';
import '../chat/chat_screen.dart';
import '../viewings/viewings_screen.dart';
import 'add_listing_screen.dart';
import 'report_sheet.dart';
import 'viewing_sheet.dart';

class PropertyDetailScreen extends StatefulWidget {
  final int propertyId;
  final Property? initial;
  final String? heroTag;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
    this.initial,
    this.heroTag,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  Property? _fallback;
  String? _loadError;
  final _pages = PageController();
  int _page = 0;
  bool _descriptionOpen = false;

  @override
  void initState() {
    super.initState();
    _fallback = widget.initial ?? PropertyStore.instance.byId(widget.propertyId);
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Loads the full listing (price insight, current counts).
  Future<void> _load() async {
    final fresh = await PropertyStore.instance.refreshOne(widget.propertyId);
    if (!mounted) return;
    setState(() {
      if (fresh != null) {
        _fallback = fresh;
        _loadError = null;
      } else if (_fallback == null) {
        _loadError = "E'lonni yuklab bo'lmadi";
      }
    });
  }

  Property? get _property => PropertyStore.instance.byId(widget.propertyId) ?? _fallback;

  // --- actions -----------------------------------------------------------------

  Future<void> _toggleSave(Property pr) async {
    if (!await requireLogin(context)) return;
    final error = await PropertyStore.instance.toggleSave(pr.id);
    if (error != null && mounted) showToast(context, error, error: true);
  }

  Future<void> _call(Property pr) async {
    if (!await requireLogin(context)) return;
    // Contact details are only sent to signed-in people: reload to get them.
    final fresh = await PropertyStore.instance.refreshOne(pr.id) ?? pr;
    final phone = fresh.owner.phone;
    if (!mounted) return;
    if (phone == null || phone.isEmpty) {
      showToast(context, "E'lon egasi telefon raqam qoldirmagan", error: true);
      return;
    }
    if (!await openPhone(phone) && mounted) {
      showToast(context, "Qo'ng'iroq qilib bo'lmadi. Raqam: ${formatPhoneDisplay(phone)}", error: true);
    }
  }

  Future<void> _telegram(Property pr) async {
    if (!await requireLogin(context)) return;
    final fresh = await PropertyStore.instance.refreshOne(pr.id) ?? pr;
    final name = fresh.owner.telegram;
    if (!mounted) return;
    if (name == null || name.isEmpty) {
      showToast(context, "E'lon egasi Telegram qoldirmagan", error: true);
      return;
    }
    if (!await openTelegram(name) && mounted) {
      showToast(context, 'Telegramni ochib bo\'lmadi', error: true);
    }
  }

  Future<void> _chat(Property pr) async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(other: pr.owner, propertyId: pr.id),
      ),
    );
  }

  Future<void> _book(Property pr) async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    final sent = await showViewingSheet(context, pr);
    if (sent == true && mounted) {
      showToast(context, "So'rov yuborildi. Egasi javob berganda xabar olasiz.");
    }
  }

  void _openViewings() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ViewingsScreen()));
  }

  Future<void> _share(Property pr) async {
    final text = '${pr.title}\n${priceWithUnit(pr)}\n${pr.placeLabel}\nIjario ilovasida';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showToast(context, "E'lon ma'lumotlari nusxalandi");
  }

  Future<void> _report(Property pr) async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    final sent = await showReportSheet(context, pr);
    if (sent == true && mounted) showToast(context, 'Shikoyat yuborildi. Rahmat!');
  }

  Future<void> _edit(Property pr) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => AddListingScreen(editing: pr),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _toggleRented(Property pr) async {
    try {
      final updated = await PropertyStore.instance.setRented(pr.id, !pr.isRented);
      if (!mounted) return;
      setState(() => _fallback = updated);
      showToast(
        context,
        updated.isRented
            ? "E'lon band deb belgilandi va qidiruvdan olib tashlandi"
            : "E'lon yana qidiruvda ko'rinadi",
      );
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Property pr, {required bool asAdmin}) async {
    final ok = await confirmDialog(
      context,
      title: "E'lonni o'chirish",
      message: asAdmin
          ? "Bu e'lon moderator sifatida butunlay o'chiriladi."
          : "E'lon va uning rasmlari butunlay o'chiriladi. Buni qaytarib bo'lmaydi.",
      confirmLabel: "O'chirish",
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      if (asAdmin) {
        await PropertyStore.instance.adminDeleteProperty(pr.id);
      } else {
        await PropertyStore.instance.deleteProperty(pr.id);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, "E'lon o'chirildi");
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _more(Property pr, bool isOwner) async {
    final choice = await showOptionSheet<String>(
      context,
      title: "Boshqa amallar",
      options: [
        const OptionItem<String>('Ulashish (nusxalash)', 'share', icon: Icons.ios_share_rounded),
        if (isOwner) const OptionItem<String>("E'lonni tahrirlash", 'edit', icon: Icons.edit_outlined),
        if (isOwner)
          const OptionItem<String>("E'lonni o'chirish", 'delete', icon: Icons.delete_outline_rounded, destructive: true),
        if (!isOwner) const OptionItem<String>('Shikoyat qilish', 'report', icon: Icons.flag_outlined),
        if (!isOwner && AuthStore.instance.isAdmin)
          const OptionItem<String>("Moderator: o'chirish", 'admin_delete', icon: Icons.gavel_rounded, destructive: true),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice.value) {
      case 'share':
        _share(pr);
        break;
      case 'edit':
        _edit(pr);
        break;
      case 'delete':
        _delete(pr, asAdmin: false);
        break;
      case 'report':
        _report(pr);
        break;
      case 'admin_delete':
        _delete(pr, asAdmin: true);
        break;
    }
  }

  // --- build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ListenableBuilder(
      listenable: Listenable.merge([PropertyStore.instance, AuthStore.instance, ViewingStore.instance]),
      builder: (context, _) {
        final pr = _property;
        if (pr == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: p.bg,
              surfaceTintColor: Colors.transparent,
              leading: const BackButton(),
            ),
            body: _loadError != null
                ? EmptyState(
                    title: 'Topilmadi',
                    message: _loadError!,
                    actionLabel: 'Qayta urinish',
                    onAction: _load,
                  )
                : Center(child: CircularProgressIndicator(color: p.brand)),
          );
        }
        final isOwner = AuthStore.instance.currentUser?.id == pr.owner.id;
        return _scaffold(context, pr, isOwner);
      },
    );
  }

  Widget _scaffold(BuildContext context, Property pr, bool isOwner) {
    final p = context.c;
    final topInset = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final expanded = (width * 0.92).clamp(320.0, 500.0).toDouble();

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                expandedHeight: expanded,
                toolbarHeight: 64,
                backgroundColor: p.bg,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _gallery(pr, p),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(BSpace.page, 0, BSpace.page, 0),
                      child: _content(context, pr, isOwner),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 132 + MediaQuery.of(context).padding.bottom)),
            ],
          ),
          // Floating controls over the gallery.
          Positioned(
            top: topInset + 8,
            left: 12,
            child: GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              semanticLabel: 'Orqaga',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: topInset + 8,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SaveButton(saved: pr.isSaved, onTap: () => _toggleSave(pr)),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.more_horiz_rounded,
                  semanticLabel: 'Boshqa amallar',
                  onTap: () => _more(pr, isOwner),
                ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _actionBar(context, pr, isOwner)),
        ],
      ),
    );
  }

  Widget _gallery(Property pr, BPalette p) {
    final images = pr.images;
    final count = images.isEmpty ? 1 : images.length;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pages,
          itemCount: count,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            final photo = PropertyPhoto(url: images.isEmpty ? null : images[i].url, seed: pr.id);
            if (i == 0 && widget.heroTag != null) {
              return Hero(tag: widget.heroTag!, child: photo);
            }
            return photo;
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        // The content sheet rises over the bottom edge of the photo.
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          height: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(color: p.bg, borderRadius: BRadius.top(BRadius.sheet)),
          ),
        ),
        if (count > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: BMotion.state,
                    curve: BMotion.ease,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == _page ? 0.95 : 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _content(BuildContext context, Property pr, bool isOwner) {
    final p = context.c;
    final description = pr.description.trim();
    final longDescription = description.length > 220;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatMoney(pr.price, pr.currency),
                        style: BType.price(p.ink).copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('/ ${unitLabel(pr.priceUnit)}', style: BType.body(p.inkMuted)),
                  ),
                ],
              ),
              if (pr.currency == 'USD')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'taxminan ${formatMoney(pr.priceUzs, 'UZS')}',
                    style: BType.small(p.inkMuted),
                  ),
                ),
              const SizedBox(height: 12),
              Text(pr.title, style: BType.display(p.ink).copyWith(fontSize: 34)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 18, color: p.brand),
                  const SizedBox(width: 6),
                  Expanded(child: Text(pr.placeLabel, style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
                ],
              ),
              if (pr.hasMetro) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.subway_rounded, size: 18, color: p.brand),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Metro: ${pr.metro}', style: BType.body(p.inkMuted))),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Reveal(
          index: 1,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pr.isRented) const _Tag(label: 'Band', icon: Icons.lock_outline_rounded),
              _Tag(
                label: pr.isPostedByOwner ? 'Egasidan' : 'Rieltor',
                icon: pr.isPostedByOwner ? Icons.person_outline_rounded : Icons.business_center_outlined,
              ),
              if (pr.studentFriendly) const _Tag(label: 'Talabalarga mos', icon: Icons.school_outlined),
              if (pr.utilitiesIncluded) const _Tag(label: 'Kommunal kiritilgan', icon: Icons.receipt_long_outlined),
              _Tag(label: pr.renovation, icon: Icons.format_paint_outlined),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Reveal(
          index: 2,
          child: StatRow(
            stats: [
              Stat('${pr.bedrooms}', 'xona'),
              Stat('${pr.bathrooms}', 'vannaxona'),
              Stat(pr.area > 0 ? '${pr.area.round()}' : '–', 'm²'),
              Stat('${pr.floor}', 'qavat'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(rows: [
          _InfoRow('Ijara turi', pr.isDaily ? 'Kunlik' : 'Oylik'),
          _InfoRow('Garov (depozit)', pr.deposit > 0 ? formatMoney(pr.deposit, pr.currency) : "Ko'rsatilmagan"),
          _InfoRow("Kommunal to'lovlar", pr.utilitiesIncluded ? 'Narxga kiritilgan' : "Alohida to'lanadi"),
        ]),
        if (pr.insight != null) ...[
          const SizedBox(height: 16),
          PriceInsightView(property: pr, insight: pr.insight!),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Tavsif', style: BType.headline(p.ink)),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: BMotion.state,
            curve: BMotion.ease,
            alignment: Alignment.topCenter,
            child: Text(
              description,
              maxLines: (longDescription && !_descriptionOpen) ? 4 : null,
              overflow: (longDescription && !_descriptionOpen) ? TextOverflow.fade : TextOverflow.visible,
              style: BType.body(p.ink),
            ),
          ),
          if (longDescription)
            TextAction(
              label: _descriptionOpen ? 'Kamroq' : "Ko'proq",
              onTap: () => setState(() => _descriptionOpen = !_descriptionOpen),
            ),
        ],
        if (pr.amenities.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Qulayliklar', style: BType.headline(p.ink)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in pr.amenities) _Tag(label: a, icon: UzData.amenityIcon(a), large: true),
            ],
          ),
        ],
        const SizedBox(height: 28),
        isOwner ? _ownerStats(context, pr) : _ownerCard(context, pr),
        const SizedBox(height: 18),
        Text(
          "E'lon ${timeAgo(pr.createdAt)} joylangan",
          style: BType.small(p.inkMuted),
        ),
        if (!isOwner)
          TextAction(label: "Bu e'lon haqida shikoyat qilish", color: p.inkMuted, onTap: () => _report(pr)),
      ],
    );
  }

  Widget _ownerCard(BuildContext context, Property pr) {
    final p = context.c;
    final hasPhone = pr.owner.phone != null && pr.owner.phone!.isNotEmpty;
    final loggedIn = AuthStore.instance.isLoggedIn;
    final hasTelegram = pr.owner.telegram != null && pr.owner.telegram!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BDeco.card(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: pr.owner.fullName, url: pr.owner.avatarUrl, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pr.owner.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: BType.title(p.ink)),
                    Text(
                      pr.isPostedByOwner ? "E'lon egasi" : 'Rieltor',
                      style: BType.small(p.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!loggedIn) ...[
            const SizedBox(height: 14),
            Text(
              "Telefon va Telegram aloqasini ko'rish uchun hisobingizga kiring.",
              style: BType.small(p.inkMuted),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: "Qo'ng'iroq",
                  icon: Icons.call_rounded,
                  onPressed: (loggedIn && !hasPhone) ? null : () => _call(pr),
                ),
              ),
              if (!loggedIn || hasTelegram) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: 'Telegram',
                    icon: Icons.send_rounded,
                    onPressed: () => _telegram(pr),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _ownerStats(BuildContext context, Property pr) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BDeco.card(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bu sizning e'loningiz", style: BType.headline(p.ink)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Number(value: '${pr.views}', label: "marta ko'rilgan")),
              Expanded(child: _Number(value: '${pr.savesCount}', label: 'saralagan')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context, Property pr, bool isOwner) {
    final p = context.c;
    final bottom = MediaQuery.of(context).padding.bottom;
    final open = ViewingStore.instance.openFor(pr.id);

    Widget primary;
    if (isOwner) {
      primary = Row(
        children: [
          Expanded(child: SecondaryButton(label: 'Tahrirlash', icon: Icons.edit_outlined, onPressed: () => _edit(pr))),
          const SizedBox(width: 10),
          Expanded(
            child: PrimaryButton(
              label: pr.isRented ? 'Faollashtirish' : 'Band qilish',
              onPressed: () => _toggleRented(pr),
            ),
          ),
        ],
      );
    } else if (pr.isRented) {
      primary = const PrimaryButton(label: 'Bu uy band', onPressed: null);
    } else {
      primary = Row(
        children: [
          GlassIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            semanticLabel: "Egasiga xabar yozish",
            size: 56,
            iconColor: p.ink,
            tint: p.ink,
            tintAlpha: 0.08,
            onTap: () => _chat(pr),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: open != null
                ? SecondaryButton(
                    label: open.isConfirmed ? "Ko'rish tasdiqlangan" : "So'rov yuborilgan",
                    icon: open.isConfirmed ? Icons.event_available_rounded : Icons.schedule_rounded,
                    onPressed: _openViewings,
                  )
                : PrimaryButton(
                    label: "Ko'rishga yozilish",
                    icon: Icons.event_rounded,
                    onPressed: () => _book(pr),
                  ),
          ),
        ],
      );
    }

    return Glass(
      borderRadius: BRadius.top(BRadius.sheet),
      blur: 26,
      tint: p.bg,
      tintAlpha: 0.82,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: EdgeInsets.fromLTRB(BSpace.page, 14, BSpace.page, 14 + bottom),
            child: primary,
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool large;

  const _Tag({required this.label, required this.icon, this.large = false});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 12, vertical: large ? 11 : 8),
      decoration: BDeco.card(p, radius: BRadius.pill, raised: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 18 : 16, color: p.brand),
          const SizedBox(width: 7),
          Text(label, style: BType.label(p.ink).copyWith(fontSize: large ? 13.5 : 13)),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(Divider(height: 1, thickness: 1, color: p.line));
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(rows[i].label, style: BType.body(p.inkMuted))),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  rows[i].value,
                  textAlign: TextAlign.right,
                  style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BDeco.card(p),
      child: Column(children: children),
    );
  }
}

class _Number extends StatelessWidget {
  final String value;
  final String label;

  const _Number({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: BType.display(p.brand).copyWith(fontSize: 40)),
        Text(label, style: BType.small(p.inkMuted)),
      ],
    );
  }
}
