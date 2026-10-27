import 'package:flutter/material.dart';

import '../../data/property_store.dart';
import '../../models/filter_criteria.dart';
import '../../models/property.dart';
import '../../services/auth_store.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/uz_data.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/buttons.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass.dart';
import '../../widgets/listing_grid.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import '../../widgets/routes.dart';
import '../../widgets/toast.dart';
import '../auth/auth_screen.dart';
import '../auth/gate.dart';
import '../property/property_detail_screen.dart';
import 'filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  late FilterCriteria _criteria = FilterCriteria(city: SettingsStore.instance.city);
  SortMode _sort = SortMode.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Property> _visible(List<Property> all) {
    final q = _query.trim().toLowerCase();
    final filtered = all.where((p) {
      if (q.isNotEmpty) {
        final hay = '${p.title} ${p.city} ${p.location} ${p.metro ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return _criteria.matches(p);
    }).toList();
    return sortProperties(filtered, _sort);
  }

  Future<void> _pickCity() async {
    final choice = await showOptionSheet<String?>(
      context,
      title: 'Shahar',
      selected: _criteria.city,
      hasSelection: true,
      options: [
        const OptionItem<String?>('Barcha shaharlar', null),
        for (final c in UzData.cities) OptionItem<String?>(c, c),
      ],
    );
    if (choice == null) return;
    final city = choice.value;
    await SettingsStore.instance.setCity(city);
    if (!mounted) return;
    setState(() {
      _criteria = city == null
          ? _criteria.copyWith(clearCity: true, clearDistrict: true)
          : _criteria.copyWith(city: city, clearDistrict: true);
    });
  }

  Future<void> _pickSort() async {
    final choice = await showOptionSheet<SortMode>(
      context,
      title: 'Saralash',
      selected: _sort,
      hasSelection: true,
      options: [for (final m in SortMode.values) OptionItem<SortMode>(m.label, m)],
    );
    if (choice != null) setState(() => _sort = choice.value);
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, _criteria);
    if (result != null) setState(() => _criteria = result);
  }

  void _open(Property p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailScreen(
          propertyId: p.id,
          initial: p,
          heroTag: 'home-photo-${p.id}',
        ),
      ),
    );
  }

  Future<void> _toggleSave(Property p) async {
    if (!await requireLogin(context)) return;
    final error = await PropertyStore.instance.toggleSave(p.id);
    if (error != null && mounted) showToast(context, error, error: true);
  }

  // --- quick filters -------------------------------------------------------

  void _toggleQuick(String key) {
    setState(() {
      switch (key) {
        case 'owner':
          _criteria = _criteria.copyWith(ownerOnly: !_criteria.ownerOnly);
          break;
        case 'student':
          _criteria = _criteria.copyWith(studentOnly: !_criteria.studentOnly);
          break;
        case 'metro':
          _criteria = _criteria.copyWith(nearMetro: !_criteria.nearMetro);
          break;
        case 'furnished':
          final next = Set<String>.of(_criteria.amenities);
          if (!next.remove('Mebel')) next.add('Mebel');
          _criteria = _criteria.copyWith(amenities: next);
          break;
        case 'daily':
          _criteria = _criteria.unit == Property.unitDay
              ? _criteria.copyWith(clearUnit: true)
              : _criteria.copyWith(unit: Property.unitDay);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ListenableBuilder(
      listenable: Listenable.merge([PropertyStore.instance, AuthStore.instance, SettingsStore.instance]),
      builder: (context, _) {
        final store = PropertyStore.instance;
        final items = _visible(store.all);
        final firstLoad = store.isLoading && !store.hasLoadedOnce;
        final failed = store.error != null && !store.hasLoadedOnce;
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return RefreshIndicator(
          color: p.brand,
          backgroundColor: p.surface,
          edgeOffset: 120,
          onRefresh: store.fetchAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _hero(context)),
              SliverToBoxAdapter(child: _quickChips(context)),
              if (_criteria.city != null && UzData.districtsOf(_criteria.city).isNotEmpty)
                SliverToBoxAdapter(child: _districtChips(context)),
              SliverToBoxAdapter(child: _resultsBar(context, items.length, firstLoad)),
              if (firstLoad)
                const SliverListingGrid.skeleton()
              else if (failed)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    title: "Ulanib bo'lmadi",
                    message: store.error ?? '',
                    actionLabel: 'Qayta urinish',
                    onAction: store.fetchAll,
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    title: 'Hech narsa topilmadi',
                    message: store.all.isEmpty
                        ? "Hozircha e'lonlar yo'q. Birinchi bo'lib e'lon joylang."
                        : "Qidiruv yoki filtrlarni o'zgartirib ko'ring.",
                    actionLabel: (_criteria.isActive || _query.isNotEmpty) ? 'Filtrlarni tozalash' : null,
                    onAction: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _criteria = const FilterCriteria();
                      });
                      SettingsStore.instance.setCity(null);
                    },
                  ),
                )
              else
                SliverListingGrid(
                  items: items,
                  heroPrefix: 'home',
                  onOpen: _open,
                  onToggleSave: _toggleSave,
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),
            ],
          ),
        );
      },
    );
  }

  // --- pieces ----------------------------------------------------------------

  Widget _hero(BuildContext context) {
    final user = AuthStore.instance.currentUser;
    final topInset = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final margin = pageMargin(width);
    final firstName = user?.fullName.trim().split(RegExp(r'\s+')).first;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(BRadius.sheet)),
      child: AuroraBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, topInset + 14, margin, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pressable(
                    onTap: _pickCity,
                    haptic: true,
                    semanticLabel: 'Shaharni tanlash',
                    child: Glass(
                      borderRadius: BorderRadius.circular(BRadius.pill),
                      tint: Colors.white,
                      tintAlpha: 0.14,
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_rounded, size: 18, color: BColors.rawOak),
                          const SizedBox(width: 6),
                          Text(
                            _criteria.city ?? 'Barcha shaharlar',
                            style: BType.label(BColors.plaster).copyWith(fontSize: 14),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: BColors.plaster),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (user == null)
                    Pressable(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AuthScreen(popOnSuccess: true)),
                      ),
                      semanticLabel: 'Kirish',
                      child: Glass(
                        borderRadius: BorderRadius.circular(BRadius.pill),
                        tint: BColors.rawOak,
                        tintAlpha: 0.9,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        child: Text('Kirish', style: BType.label(BColors.obsidian).copyWith(fontSize: 14)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              Reveal(
                child: Text(
                  firstName == null ? 'Xush kelibsiz' : 'Salom, $firstName',
                  style: BType.subhead(BColors.rawOak),
                ),
              ),
              const SizedBox(height: 2),
              Reveal(
                index: 1,
                child: Text('Qaysi uy sizga mos?', style: BType.display(BColors.plaster)),
              ),
              const SizedBox(height: 22),
              Reveal(
                index: 2,
                child: Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 10),
                    _filterButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Glass(
      borderRadius: BorderRadius.circular(BRadius.pill),
      tint: Colors.white,
      tintAlpha: 0.16,
      child: SizedBox(
        height: 54,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          cursorColor: BColors.rawOak,
          style: BType.body(BColors.paper).copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: "Tuman, metro yoki sarlavha",
            hintStyle: BType.body(BColors.plaster.withValues(alpha: 0.7)),
            prefixIcon: const Icon(Icons.search_rounded, color: BColors.plaster),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Tozalash',
                    icon: const Icon(Icons.close_rounded, color: BColors.plaster),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _filterButton() {
    final count = _criteria.activeCount;
    return Pressable(
      onTap: _openFilters,
      haptic: true,
      semanticLabel: 'Filtrlar',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Glass(
            borderRadius: BorderRadius.circular(BRadius.pill),
            tint: Colors.white,
            tintAlpha: 0.16,
            child: const SizedBox(
              width: 54,
              height: 54,
              child: Icon(Icons.tune_rounded, color: BColors.paper),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: BColors.rawOak, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '$count',
                  style: BType.label(BColors.obsidian).copyWith(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipRow(BuildContext context, List<Widget> chips, {EdgeInsets? padding}) {
    final margin = pageMargin(MediaQuery.of(context).size.width);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? EdgeInsets.symmetric(horizontal: margin),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _quickChips(BuildContext context) {
    final c = _criteria;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: _chipRow(context, [
        PillChip(label: 'Egasidan', selected: c.ownerOnly, onTap: () => _toggleQuick('owner')),
        PillChip(label: 'Talabalarga', selected: c.studentOnly, onTap: () => _toggleQuick('student')),
        PillChip(label: 'Metro yaqin', selected: c.nearMetro, onTap: () => _toggleQuick('metro')),
        PillChip(label: 'Mebelli', selected: c.amenities.contains('Mebel'), onTap: () => _toggleQuick('furnished')),
        PillChip(label: 'Kunlik', selected: c.unit == Property.unitDay, onTap: () => _toggleQuick('daily')),
      ]),
    );
  }

  Widget _districtChips(BuildContext context) {
    final districts = UzData.districtsOf(_criteria.city);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _chipRow(context, [
        PillChip(
          label: 'Hamma tumanlar',
          selected: _criteria.district == null,
          onTap: () => setState(() => _criteria = _criteria.copyWith(clearDistrict: true)),
        ),
        for (final d in districts)
          PillChip(
            label: d,
            selected: _criteria.district == d,
            onTap: () => setState(() => _criteria = _criteria.copyWith(district: d)),
          ),
      ]),
    );
  }

  Widget _resultsBar(BuildContext context, int count, bool loading) {
    final p = context.c;
    final margin = pageMargin(MediaQuery.of(context).size.width);
    return Padding(
      padding: EdgeInsets.fromLTRB(margin, 14, margin - 8 < 0 ? 0 : margin - 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loading ? "E'lonlar yuklanmoqda" : "$count ta e'lon",
              style: BType.label(p.inkMuted).copyWith(fontSize: 14),
            ),
          ),
          TextAction(label: _sort.label, onTap: _pickSort),
          Icon(Icons.expand_more_rounded, size: 20, color: p.brand),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
